# Quetzal Online

Play **Pokémon Quetzal's own Mplayer co-op over the internet**, no link cable needed.

Quetzal already has a full multiplayer mode (Mplayer) built for mGBA's link cable. Quetzal Online is a single Lua script that makes the game *think* a cable is plugged in, then carries the link data between two players over the network. Everything you see is Quetzal's own multiplayer: synced overworld, skins, Colosseum battles, Trade Center, Spectate and Players Info.

---

## What you need

- **mGBA 0.10 or newer** (scripting is built in): https://mgba.io
- **Pokémon Quetzal Alpha 9.** Other versions are detected and the script turns itself off rather than risk your save.
- **Your own save file.** Each player needs their own `.sav` (see Important below).
- **Both players using the same version** of `Quetzal-Online.lua`.

This download does **not** include the ROM. Get Quetzal from its official sources.

---

## Setup

### 1. Settings

Open `Quetzal-Online.lua` in any text editor. The settings are at the top:

```lua
local Mode = "auto"            -- "auto", "host" or "join"
local IPAddress = "127.0.0.1"  -- the HOST's address (joiners only)
local Port = 2655
```

| Situation | Host sets | Joiner sets |
|---|---|---|
| Same PC (testing) | nothing | nothing |
| Same house / Wi-Fi | `Mode = "host"` | `Mode = "join"`, `IPAddress` = host's local IP (e.g. `192.168.1.20`) |
| Internet, port forwarding | `Mode = "host"`, forward TCP port 2655 on the router | `Mode = "join"`, `IPAddress` = host's public IP |
| Internet, playit.gg (easiest) | `Mode = "host"`, run playit.gg with a TCP tunnel to port 2655 | `Mode = "join"`, `IPAddress` = the playit address (e.g. `something.playit.gg`), `Port` = the port playit shows |
| Internet, VPN (Tailscale / ZeroTier / Radmin) | `Mode = "host"` | `Mode = "join"`, `IPAddress` = host's VPN IP |

With **playit.gg**, only the host installs anything. The joiner just types in the address.

### 2. Load the game and the script

1. Open Quetzal in mGBA and load your save.
2. **Tools → Scripting…**, then **File → Load script** and pick `Quetzal-Online.lua`.
3. The scripting window should say `Quetzal Online ready`, then `Partner: connected` once you're both in.

### 3. Start co-op

1. Both players: **START → MPLAYER → 2P**.
2. The host sees **"partner found, press A to start"**. Press A.
3. The script says **"co-op session running"**. You're linked.

From then on, open **START → MPLAYER** for Colosseum, Trade Center, Spectate, Players Info and Disconnect.

---

## ⚠️ Important

- **Never let two windows use the same `.sav` file.** mGBA shares the save file between windows live, so saving during a trade will freeze or corrupt it. To test on one PC, copy the ROM and save as a pair (e.g. `Quetzal2.gba` + `Quetzal2.sav`) for player 2. The script warns you if both players have the same Trainer ID.
- **Back up your save** before playing online. This is a fan project.
- **Don't use mGBA's own multiplayer window**, and don't load GBA-PK at the same time.
- **Don't edit anything below the settings.** Those addresses are specific to Quetzal Alpha 9.

---

## What works

| Feature | Status |
|---|---|
| Overworld co-op (see each other, skins, surfing, running) | ✅ Working |
| Colosseum: Single Battle | ✅ Working |
| Colosseum: Double Battle | ✅ Working |
| Trade Center (including saving) | ✅ Working |
| Spectate (follow your partner around) | ✅ Working |
| Players Info | ✅ Working |
| Disconnect | ✅ Working |
| Partner leaves or loses connection | ✅ Session ends cleanly; nobody freezes |
| Spectating a partner's **battle** | ❓ Untested |
| Colosseum: Multi Battle | ❌ Needs 4 players; this version supports 2 |

## Known issues

- **Delay scales with ping.** Battles and trades wait on several round trips per turn, so a partner far away means longer "Link standby…" screens. The overworld handles lag fine.
- **Connecting to a wrong or blocked address freezes mGBA briefly** while it tries (a limit of mGBA scripting). The script then waits 30 seconds between tries and tells you to check the IP/port.
- **Whiting out** may end the Mplayer session. Just reopen START → MPLAYER → 2P. If you ever get stuck in place after a whiteout, please report it with your save.

---

## Reporting a bug

Please include:

1. **What happened** and what you expected.
2. **Who was host and who was joiner.**
3. **What each screen showed**, with screenshots if possible.
4. **The text in the "Quetzal Online" scripting window** from *both* players. This is the most useful part.
5. **Your `.sav`** if the bug can be repeated (e.g. whiteout problems).

---

## Credits

- **TenmaRH**, creator of **Pokémon Quetzal** and its Mplayer multiplayer mode. Quetzal Online only carries the link; all the multiplayer itself is TenmaRH's work.
  [pokemonquetzal.app]((https://pokemonquetzal.app/)) · [Quetzal Discord](https://discord.gg/ccfKrzscP)
- **TheHunterManX**, creator of **PK-GBA Multiplayer**, the mGBA Lua multiplayer project that inspired this one and that early versions were built on.
  [GitHub](https://github.com/TheHunterManX/GBA-PK-multiplayer) · [PokéCommunity thread](https://www.pokecommunity.com/threads/pk-gba-multiplayer.484949/)
- **endrift** and the mGBA team, for mGBA and its scripting API.
- **Lost**, Quetzal Online.

Pokémon is © Nintendo / Creatures Inc. / GAME FREAK inc. This is a free, non-commercial fan project. No ROMs are distributed.
