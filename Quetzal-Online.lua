-- =====================================================================
--  Quetzal Online
--  Play Pokemon Quetzal's own Mplayer co-op over the internet.
--  The script stands in for the link cable: it fakes the cable handshake
--  and carries Mplayer's link messages between the two games.
--
--  How to use (both players):
--    1. Load this script in mGBA (Tools > Scripting > File > Load script).
--    2. In game: START > MPLAYER > 2P on both games.
--    3. The host gets "Press A to start". Press A and you're in co-op.
--
--  Do NOT load GBA-PK.lua at the same time (it would draw a second copy
--  of your partner). Do not use mGBA's multiplayer window either.
-- =====================================================================

-- "auto" = join a game at IPAddress if one is running, otherwise host one. (default)
-- "host" = always host.   "join" = always join.
local Mode = "auto"

-- Only used when joining: the host's IP address.
-- Same PC: "127.0.0.1". Same house: the host's local IP (like 192.168.1.20).
-- Internet: the host's public IP, and the host must port-forward Port (TCP).
-- Tunnel/VPN: a name works too, e.g. "something.playit.gg" (then use the Port it gives you).
local IPAddress = "127.0.0.1"
local Port = 2655

-- ---------------------------------------------------------------------
-- Quetzal (Alpha 9) addresses, found by reverse engineering. Do not edit.
local GL = 0x3003510                       -- gLink
local SENDQ, SENDPOS, SENDCNT = GL + 0x18, GL + 0x338, GL + 0x339
local RECVQ, RECVPOS, RECVCNT = GL + 0x33C, GL + 0xFBC, GL + 0xFBD
local CAP = 50                             -- link queue capacity
local WATCHDOG = 0x3000d8c                 -- frames without a serial interrupt (joiner drops link at 11)
local HS_COUNT = 0x3000d93                 -- player count seen during the handshake
local CB2 = 0x3002664                      -- gMain.callback2
local CB2_OVERWORLD = 0x80c2989
local ST_HANDSHAKE, ST_INIT_TIMER, ST_CONNECTED = 2, 3, 4
local STATE_MSG = 0xBEBE                   -- Mplayer's per-frame "here I am" message

-- Two tiny code patches (emulator memory only, never your ROM file), active only during a session:
--  CheckMasterOrSlave: decides host/joiner from the link port, which says "joiner" with no cable.
--  GetMultiplayerId:   reads your player number from the link port, which says 0 with no cable.
local PATCHES = {
	{at = 0xd4e4, expect = {0x6801, 0x200C, 0x4001}, host = {0x2108, 0x46C0, 0x46C0}, join = {0x210C, 0x46C0, 0x46C0}},
	{at = 0xc1ca, expect = {0x4803, 0x6800, 0x0680, 0x0F80}, host = {0x2000, 0x46C0, 0x46C0, 0x46C0}, join = {0x2001, 0x46C0, 0x46C0, 0x46C0}},
}

-- ---------------------------------------------------------------------
local Console = console:createBuffer("Quetzal Online")
local partnerTid, sameSaveWarned = nil, false
local lastSentState = -1
local function say(row, text) Console:moveCursor(0, row); Console:print(text .. string.rep(" ", 60)) end
local function note(text) console:log("[Quetzal Online] " .. text) end

local role = nil            -- "host" or "join" once decided
local server, sock = nil, nil
local enabled = false
local n = 0
local inbuf = ""
local partnerQ = {}
local partnerState = 0
local goReceived = false
local lastPartnerState, lastSelfState = nil, nil
local phase = "idle"
local hsFrames = 0
local sawOverworld = false  -- the game opens the link briefly at boot; only react once we're in the game
local partnerAway = 0       -- frames the partner's link has been out of the session while ours is connected
local cableLost = false     -- we stopped faking a healthy cable so our game notices the partner is gone
local patched = nil

local function romCheck()
	local code, title = "", ""
	pcall(function() code = emu:getGameCode() end)
	pcall(function() title = string.gsub(emu:getGameTitle(), "%z", "") end)
	if code ~= "AGB-BPEE" or title ~= "PKM QUETZAL" then
		return false, "This is not Pokemon Quetzal (" .. tostring(title) .. "). Script disabled."
	end
	local rom = emu.memory.cart0
	for _, p in ipairs(PATCHES) do
		for i, v in ipairs(p.expect) do
			if rom:read16(p.at + (i - 1) * 2) ~= v then
				return false, "Unsupported Quetzal version (link code differs). Script disabled."
			end
		end
	end
	return true
end

local function setPatches(on)
	local rom = emu.memory.cart0
	if on and not patched then
		for _, p in ipairs(PATCHES) do
			local words = (role == "host") and p.host or p.join
			for i, v in ipairs(words) do rom:write16(p.at + (i - 1) * 2, v) end
		end
		patched = true
	elseif not on and patched then
		for _, p in ipairs(PATCHES) do
			for i, v in ipairs(p.expect) do rom:write16(p.at + (i - 1) * 2, v) end
		end
		patched = nil
	end
end

-- ---------------------------------------------------------------- network
-- Everything for one frame goes out in a single packet: the game's link waits on every round
-- trip, and many tiny packets get held back by the network stack (Nagle) on real connections.
local outbuf = {}
local function send(s)
	if sock then outbuf[#outbuf + 1] = s end
end
local function flushOut()
	if #outbuf == 0 then return end
	local data = table.concat(outbuf)
	outbuf = {}
	if not sock then return end
	local ok, err = sock:send(data)
	if not ok and err then note("send failed: " .. tostring(err)) end
end

local function dropConnection(why)
	if sock then pcall(function() sock:close() end) end
	sock = nil
	inbuf, partnerQ, partnerState, goReceived, outbuf = "", {}, 0, false, {}
	say(2, "Partner: not connected (" .. why .. ")")
	note("connection lost: " .. why)
end

local function startHosting()
	role = "host"
	server = socket.bind(nil, Port)
	if not server then
		say(1, "Could not host on port " .. Port .. ". Is another copy already hosting?")
		enabled = false
		return
	end
	server:listen()
	say(1, "Hosting on port " .. Port .. ". You are the host (press A to start in Mplayer).")
	say(2, "Partner: waiting for someone to join...")
end

local PROTOCOL = 1 -- bump when the network format changes; both players need the same version
local joinRetryAt = 0
local function tryJoin()
	local c = socket.tcp()
	local t0 = os.time()
	local ok = c:connect(IPAddress, Port)
	if not ok and os.time() - t0 >= 3 then
		-- the address didn't answer at all (wrong IP, port not forwarded, firewall): each try freezes
		-- the emulator for a while, so wait much longer before the next one
		joinRetryAt = n + 60 * 30
		say(2, "Partner: " .. IPAddress .. ":" .. Port .. " not answering. Check IP/port. Retrying in 30s")
	else
		joinRetryAt = n + 120
	end
	if ok then
		sock = c
		role = "join"
		send("V" .. string.char(PROTOCOL))
		say(1, "Joined " .. IPAddress .. ":" .. Port .. ". You are the joiner.")
		say(2, "Partner: connected")
		note("connected to host")
		return true
	end
	pcall(function() c:close() end)
	return false
end

local function pollNet()
	if role == "host" and server and not sock then
		if server:hasdata() then
			local c = server:accept()
			if c then sock = c; send("V" .. string.char(PROTOCOL)); say(2, "Partner: connected"); note("partner connected") end
		end
	elseif role == "join" and not sock and n >= joinRetryAt then
		if tryJoin() then phase = "idle" end
	end
	if not sock then return end
	while true do
		local has, herr = sock:hasdata()
		if herr then dropConnection(tostring(herr)) return end
		if not has then break end
		local d, err = sock:receive(4096)
		if not d then dropConnection(tostring(err)) return end
		inbuf = inbuf .. d
	end
	-- messages: "C"+16 bytes (link command), "S"+1 byte (partner link state), "G" (session started)
	while #inbuf > 0 do
		local t = string.sub(inbuf, 1, 1)
		if t == "C" then
			if #inbuf < 17 then break end
			local cmd = {string.unpack("<I2I2I2I2I2I2I2I2", inbuf, 2)}
			cmd[9] = nil
			partnerQ[#partnerQ + 1] = cmd
			inbuf = string.sub(inbuf, 18)
		elseif t == "S" then
			if #inbuf < 2 then break end
			partnerState = string.byte(inbuf, 2)
			inbuf = string.sub(inbuf, 3)
		elseif t == "V" then
			if #inbuf < 2 then break end
			local v = string.byte(inbuf, 2)
			if v ~= PROTOCOL then
				say(4, "Version mismatch! Partner has protocol " .. v .. ", you have " .. PROTOCOL .. ". Use the same script.")
				note("partner uses a different Quetzal-Online.lua version")
			end
			inbuf = string.sub(inbuf, 3)
		elseif t == "T" then
			if #inbuf < 5 then break end
			partnerTid = string.sub(inbuf, 2, 5)
			inbuf = string.sub(inbuf, 6)
		elseif t == "G" then
			if phase == "handshake" then goReceived = true end -- stale "go" from an old session is ignored
			partnerState = ST_CONNECTED
			inbuf = string.sub(inbuf, 2)
		else
			inbuf = string.sub(inbuf, 2)
		end
	end
end

-- ---------------------------------------------------------------- link emulation
-- What the real cable handshake leaves in gLink, written every frame while both games wait.
local function fakeHandshake()
	local master = (role == "host")
	emu:write8(WATCHDOG, 0)
	if emu:read8(GL + 1) ~= ST_HANDSHAKE then return end -- the game moves 1 -> 2 itself
	emu:write8(GL + 0, master and 8 or 0)              -- isMaster
	emu:write8(GL + 2, master and 0 or 1)              -- localId
	emu:write8(GL + 3, 2)                              -- playerCount
	emu:write16(GL + 4, 0xB9A0); emu:write16(GL + 6, 0xB9A0)
	emu:write16(GL + 8, 0xFFFF); emu:write16(GL + 10, 0xFFFF)
	emu:write8(GL + 0xF, 1)
	emu:write8(HS_COUNT, 2)
	emu:write8(WATCHDOG, 0)
end

-- The cable's "everything is fine" signals: no hardware/checksum/queue/lag errors.
local function keepHealthy()
	emu:write8(GL + 0x10, 0); emu:write8(GL + 0x11, 0); emu:write8(GL + 0x12, 0); emu:write8(GL + 0x13, 0)
	if emu:read8(GL) ~= 0 then emu:write8(GL + 0xD, 9) else emu:write8(GL + 0xD, 0) end
	emu:write8(WATCHDOG, 0)
end

-- One frame of cable: send what our game queued, deliver what the partner sent.
local function relayFrame()
	local localId = emu:read8(GL + 2)
	local partnerId = 1 - localId
	local spos, scnt = emu:read8(SENDPOS), emu:read8(SENDCNT)
	local outgoing = {}
	for k = 0, scnt - 1 do
		local slot = (spos + k) % CAP
		local cmd = {}
		for j = 0, 7 do cmd[j + 1] = emu:read16(SENDQ + (j * CAP + slot) * 2) end
		outgoing[#outgoing + 1] = cmd
		if cmd[1] == STATE_MSG then lastSelfState = cmd end
	end
	emu:write8(SENDPOS, (spos + scnt) % CAP)
	emu:write8(SENDCNT, 0)
	if #outgoing > 0 then
		local parts = {}
		for _, cmd in ipairs(outgoing) do parts[#parts + 1] = "C" .. string.pack("<I2I2I2I2I2I2I2I2", table.unpack(cmd)) end
		send(table.concat(parts))
	end

	local rpos, rcnt = emu:read8(RECVPOS), emu:read8(RECVCNT)
	local function put(selfcmd, pcmd)
		local slot = (rpos + rcnt) % CAP
		for j = 0, 7 do
			emu:write16(RECVQ + ((localId * 8 + j) * CAP + slot) * 2, selfcmd and selfcmd[j + 1] or 0)
			emu:write16(RECVQ + ((partnerId * 8 + j) * CAP + slot) * 2, pcmd and pcmd[j + 1] or 0)
			for p = 2, 3 do emu:write16(RECVQ + ((p * 8 + j) * CAP + slot) * 2, 0) end
		end
		rcnt = rcnt + 1
	end
	-- Lag/drift control: "here I am" messages only matter as the latest state, so if the partner's
	-- messages pile up, keep every other message but only the newest "here I am".
	if #partnerQ > 4 then
		local newest = nil
		for i = #partnerQ, 1, -1 do if partnerQ[i][1] == STATE_MSG then newest = i break end end
		local kept = {}
		for i, c in ipairs(partnerQ) do
			if c[1] ~= STATE_MSG or i == newest then kept[#kept + 1] = c end
		end
		partnerQ = kept
	end
	for _, cmd in ipairs(outgoing) do
		if rcnt >= CAP then break end
		local pcmd = table.remove(partnerQ, 1)
		if pcmd then
			if pcmd[1] == STATE_MSG then lastPartnerState = pcmd end
		else
			pcmd = lastPartnerState -- the cable always carries the partner's latest "here I am"
		end
		put(cmd, pcmd)
	end
	while #partnerQ > 0 and rcnt < 3 do
		local pcmd = table.remove(partnerQ, 1)
		if pcmd[1] == STATE_MSG then lastPartnerState = pcmd end
		put(lastSelfState, pcmd)
	end
	emu:write8(RECVCNT, rcnt)
	keepHealthy()
end

local function toIdle(why)
	phase = "idle"; goReceived = false; hsFrames = 0; partnerAway = 0; cableLost = false
	lastPartnerState, lastSelfState = nil, nil
	partnerQ = {} -- nothing from the old link session may leak into the next one
	setPatches(false)
	say(3, "Mplayer: " .. why)
end

local function myTrainerId()
	local sb2 = emu:read32(0x30055c0)
	if sb2 < 0x2000000 or sb2 >= 0x2040000 then return nil end
	return string.pack("<I4", emu:read32(sb2 + 0xA))
end

-- Two windows loading the SAME .sav file share it live (mGBA memory-maps saves), so when both
-- games save at once (trades, after battles) they overwrite each other and the save hangs.
local function checkSameSave()
	if sameSaveWarned or not sock or not sawOverworld then return end
	local mine = myTrainerId()
	if not mine then return end
	if n % 120 == 0 then send("T" .. mine) end
	if partnerTid and partnerTid == mine and mine ~= "\0\0\0\0" then
		sameSaveWarned = true
		say(4, "Note: same Trainer ID as your partner. On one PC, each window needs its own .sav file!")
		note("both players have the same Trainer ID: if both windows load the same .sav file, saving during trades will freeze. Copy the .sav for player 2.")
	end
end

local function frameLogic()
	n = n + 1
	pollNet()
	local state = emu:read8(GL + 1)
	if emu:read32(CB2) == CB2_OVERWORLD then sawOverworld = true end
	if sock and (n % 4 == 0 or state ~= lastSentState) then send("S" .. string.char(state)); lastSentState = state end
	checkSameSave()

	if phase == "idle" then
		-- (battles and trades close the link and reopen it from their own screens, so after the
		-- first visit to the overworld a handshake is allowed anywhere)
		if sock and sawOverworld and state >= 1 and state <= ST_HANDSHAKE and partnerState >= 1 then
			phase = "handshake"; hsFrames = 0; setPatches(true)
			say(3, role == "host" and "Mplayer: partner found, press A to start" or "Mplayer: partner found, waiting for host")
		end
	elseif phase == "handshake" then
		if state == 0 or not sock then toIdle("closed") return end
		-- The host's game asks to start (A pressed in the menu, or automatically after a battle/trade).
		-- Only go ahead once the joiner's game is in the handshake too; until then the request waits.
		if role == "host" and state == ST_HANDSHAKE and emu:read8(GL + 0xE) ~= 0
			and partnerState >= ST_HANDSHAKE then
			emu:write8(GL + 1, ST_INIT_TIMER)
			emu:write16(GL + 4, 0x8FFF)
			keepHealthy()
		end
		if role == "host" and emu:read8(GL + 1) >= ST_INIT_TIMER then
			emu:write8(GL + 1, ST_CONNECTED)
			send("G"); keepHealthy()
			phase = "connected"; say(3, "Mplayer: co-op session running")
		elseif role == "join" and goReceived then
			emu:write8(GL + 1, ST_CONNECTED); emu:write16(GL + 4, 0x8FFF); keepHealthy()
			phase = "connected"; say(3, "Mplayer: co-op session running")
		else
			fakeHandshake()
		end
	elseif phase == "connected" then
		if state == 0 then toIdle("session ended") return end
		if not sock then
			-- partner gone: let the game notice the link is down
			toIdle("partner disconnected")
			return
		end
		if role == "host" and partnerState >= 1 and partnerState < ST_CONNECTED and n % 8 == 0 then
			send("G") -- the joiner reopened its link later than us: tell it again that we're running
		end
		-- If the partner's game left the link session without us (whiteout, reset, crash...), a real
		-- cable would simply go quiet. After a short grace period (normal battle/trade transitions
		-- close both sides within a few frames), stop faking a healthy cable so our game reacts the
		-- same way it would to a real cable losing its partner.
		if partnerState < ST_CONNECTED then partnerAway = partnerAway + 1 else partnerAway = 0 end
		if partnerAway > 90 then
			if not cableLost then cableLost = true; say(3, "Mplayer: partner left the session") end
			return
		end
		relayFrame()
	end
end

local function onFrame()
	if not enabled then return end
	frameLogic()
	flushOut()
end

local function start()
	Console:clear()
	local ok, why = romCheck()
	if not ok then say(0, why); enabled = false; return end
	enabled = true
	say(0, "Quetzal Online ready. Mode: " .. Mode)
	local m = string.lower(Mode)
	if m == "host" then
		startHosting()
	elseif m == "join" then
		role = "join"
		say(1, "Joining " .. IPAddress .. ":" .. Port .. " ...")
		say(2, "Partner: not connected (retrying every 2 seconds)")
		tryJoin()
	else
		if not tryJoin() then startHosting() end
	end
	say(3, "Mplayer: open START > MPLAYER > 2P when you're both ready")
end

callbacks:add("frame", onFrame)
callbacks:add("reset", function() toIdle("game reset") end)
callbacks:add("shutdown", function() setPatches(false); if sock then pcall(function() sock:close() end) end end)
if emu then start() else callbacks:add("start", start) end
