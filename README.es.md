# Quetzal Online

[English](README.md) · **Español**

Juega el **Mplayer de Pokémon Quetzal por internet**, sin necesidad de cable link.

Quetzal ya tiene un modo multijugador completo (Mplayer) hecho para el cable link de mGBA. Quetzal Online es un solo script de Lua que hace que el juego *crea* que hay un cable conectado, y envía los datos del link entre dos jugadores por internet. Todo lo que ves es el multijugador propio de Quetzal: mundo sincronizado, skins, combates en el Coliseo, Centro de Intercambio, Espectar e Info de Jugadores.

---

## Qué necesitas

- **mGBA 0.10 o más nuevo** (los scripts ya vienen incluidos): https://mgba.io
- **Pokémon Quetzal Alpha 9.** Si detecta otra versión, el script se desactiva solo para no arriesgar tu partida.
- **Tu propio archivo de guardado.** Cada jugador necesita su propio `.sav` (mira la sección Importante).
- **Los dos jugadores con la misma versión** de `Quetzal-Online.lua`.
- **Los dos jugadores con exactamente la misma versión de Quetzal** (la misma ROM).

Esta descarga **no** incluye la ROM. Consigue Quetzal desde sus fuentes oficiales.

---

## Configuración

### 1. Ajustes

Abre `Quetzal-Online.lua` con cualquier editor de texto. Los ajustes están arriba del todo:

```lua
local Mode = "auto"            -- "auto", "host" (anfitrión) o "join" (unirse)
local IPAddress = "127.0.0.1"  -- la dirección del ANFITRIÓN (solo para quien se une)
local Port = 2655
```

| Situación | El anfitrión pone | Quien se une pone |
|---|---|---|
| Mismo PC (pruebas) | nada | nada |
| Misma casa / mismo Wi-Fi | `Mode = "host"` | `Mode = "join"`, `IPAddress` = IP local del anfitrión (ej. `192.168.1.20`) |
| Internet, abriendo puertos | `Mode = "host"`, abrir el puerto TCP 2655 en el router | `Mode = "join"`, `IPAddress` = IP pública del anfitrión |
| Internet, playit.gg (lo más fácil) | `Mode = "host"`, usar playit.gg con un túnel TCP al puerto 2655 | `Mode = "join"`, `IPAddress` = la dirección de playit (ej. `algo.playit.gg`), `Port` = el puerto que muestra playit |
| Internet, VPN (Tailscale / ZeroTier / Radmin) | `Mode = "host"` | `Mode = "join"`, `IPAddress` = IP de la VPN del anfitrión |

Con **playit.gg**, solo el anfitrión instala algo. Quien se une solo escribe la dirección.

### 2. Abre el juego y el script

1. Abre Quetzal en mGBA y carga tu partida.
2. **Tools → Scripting…** (Herramientas → Scripts), luego **File → Load script** y elige `Quetzal-Online.lua`.
3. La ventana del script debe decir `Quetzal Online ready`, y luego `Partner: connected` cuando estén los dos.

### 3. Empieza el co-op

1. Los dos jugadores: **START → MPLAYER → 2P**.
2. Al anfitrión le aparece **"partner found, press A to start"**. Pulsa A.
3. El script dice **"co-op session running"**. ¡Ya están conectados!

A partir de ahí, abre **START → MPLAYER** para Coliseo, Centro de Intercambio, Espectar, Info de Jugadores y Desconectar.

---

## ⚠️ Importante

- **Nunca uses el mismo archivo `.sav` en dos ventanas.** mGBA comparte el archivo entre ventanas en tiempo real, así que guardar durante un intercambio puede congelar o dañar la partida. Para probar en un solo PC, copia la ROM y el guardado como pareja (ej. `Quetzal2.gba` + `Quetzal2.sav`) para el jugador 2. El script te avisa si los dos jugadores tienen el mismo ID de entrenador.
- **Haz una copia de seguridad de tu partida** antes de jugar online. Es un proyecto de fans.
- **No uses la ventana multijugador propia de mGBA**, y no cargues GBA-PK al mismo tiempo.
- **No edites nada debajo de los ajustes.** Esas direcciones son específicas de Quetzal Alpha 9.

---

## Qué funciona

| Función | Estado |
|---|---|
| Co-op en el mundo (verse, skins, surf, correr) | ✅ Funciona |
| Coliseo: Combate Individual | ✅ Funciona |
| Coliseo: Combate Doble | ✅ Funciona |
| Centro de Intercambio (incluido el guardado) | ✅ Funciona |
| Espectar (seguir a tu compañero) | ✅ Funciona |
| Info de Jugadores | ✅ Funciona |
| Desconectar | ✅ Funciona |
| El compañero se va o pierde la conexión | ✅ La sesión termina bien; nadie se queda congelado |
| Espectar el **combate** de tu compañero | ❓ Sin probar |
| Coliseo: Combate Múltiple | ❌ Necesita 4 jugadores; esta versión es para 2 |

## Problemas conocidos

- **El retraso depende del ping.** Los combates e intercambios esperan varias idas y vueltas por turno, así que con un compañero lejos verás más tiempo de "Link standby…". En el mundo el lag casi no se nota.
- **Conectarse a una dirección equivocada o bloqueada congela mGBA un momento** mientras lo intenta (es un límite de los scripts de mGBA). Después el script espera 30 segundos entre intentos y te pide revisar la IP y el puerto.
- **Debilitarse (whiteout)** puede cerrar la sesión de Mplayer. Solo vuelve a abrir START → MPLAYER → 2P. Si alguna vez te quedas atascado sin poder moverte después de un whiteout, repórtalo con tu partida.

---

## Reportar un error

Incluye por favor:

1. **Qué pasó** y qué esperabas que pasara.
2. **Quién era el anfitrión y quién se unió.**
3. **Qué mostraba cada pantalla**, con capturas si puedes.
4. **El texto de la ventana "Quetzal Online"** de *los dos* jugadores. Es lo más útil.
5. **Tu `.sav`** si el error se puede repetir (por ejemplo, problemas con el whiteout).

Puedes escribir el reporte en español o en inglés.

---

## Créditos

- **TenmaRH**, creador de **Pokémon Quetzal** y de su modo multijugador Mplayer. Quetzal Online solo transporta el link; todo el multijugador es obra de TenmaRH.
  [Sitio oficial](https://pokemonquetzal.app)
- **TheHunterManX**, creador de **PK-GBA Multiplayer**, el proyecto multijugador en Lua para mGBA que inspiró este.
  [GitHub](https://github.com/TheHunterManX/GBA-PK-multiplayer) · [Hilo en PokéCommunity](https://www.pokecommunity.com/threads/pk-gba-multiplayer.484949/)
- **endrift** y el equipo de mGBA, por mGBA y su sistema de scripts.
- **Lost**, Quetzal Online.

Pokémon es © Nintendo / Creatures Inc. / GAME FREAK inc. Este es un proyecto de fans gratuito y sin fines de lucro. No se distribuyen ROMs.
