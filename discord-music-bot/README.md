# 🎵 Music Bot — Discord

Bot de música para Discord con soporte de YouTube, Spotify y SoundCloud.
**Stack:** TypeScript + discord.js v14 + lavalink-client v2 + Lavalink v4

## ¿Por qué TypeScript en lugar de Python?

| | Python (wavelink) | TypeScript (lavalink-client) |
|---|---|---|
| Estado | ❌ Archivado en 2024 | ✅ Actualizado activamente |
| Soporte Lavalink v4 | Parcial | ✅ Nativo completo |
| Tipado | Sin tipos | TypeScript completo |
| Rendimiento | Moderado | Alto (V8 engine) |

## Características

- ▶️ Reproducción de YouTube, Spotify, SoundCloud y URLs directas
- 📋 Cola de reproducción con gestión completa (move, remove, shuffle)
- 🔁 Modos de repetición (canción, cola, off)
- 🔀 Mezcla aleatoria
- ⏩ Seek (saltar a posición en la canción)
- 🎚️ Filtros de audio (bass, nightcore, slowed, 8D, pop, rock)
- 🔊 Control de volumen (0–200%)
- 🔍 Búsqueda interactiva con selección de resultados
- 📊 Información detallada de reproducción con barra de progreso
- 🔄 Reconexión automática a Lavalink

## Requisitos del sistema

- Node.js 18+ (recomendado: 20 LTS)
- Java 17+ (para Lavalink)
- Sistema operativo: Linux (Ubuntu/Debian recomendado)

## Instalación rápida (VPS)

```bash
# 1. Instalar Node.js, Java y dependencias del sistema
sudo apt update && sudo apt install -y openjdk-17-jre wget curl

# Instalar Node.js 20 LTS
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# 2. Copiar la carpeta discord-music-bot/ al servidor
# (scp, git clone, rsync, etc.)

# 3. Instalar todo
cd discord-music-bot
bash scripts/install.sh

# 4. Iniciar
bash scripts/start.sh
```

## Scripts disponibles

| Script | Descripción |
|--------|-------------|
| `bash scripts/install.sh` | Instala Node.js deps, compila TypeScript, descarga Lavalink |
| `bash scripts/start.sh` | Inicia Lavalink + bot |
| `bash scripts/stop.sh` | Detiene todo limpiamente |
| `bash scripts/status.sh` | Estado + últimos logs |
| `bash scripts/update.sh` | Actualiza deps + recompila + reinicia |
| `bash scripts/update.sh --force` | Reinstala todo desde cero |

## Configuración (.env)

```env
DISCORD_TOKEN=tu_token_aqui
LAVALINK_HOST=127.0.0.1
LAVALINK_PORT=2333
LAVALINK_PASSWORD=r2dd2pass
LAVALINK_SECURE=false
BOT_PREFIX=!
INACTIVE_TIMEOUT_MS=300000
DEFAULT_VOLUME=80
DEBUG=false
```

## Comandos del bot

### Reproducción
| Comando | Aliases | Descripción |
|---------|---------|-------------|
| `!play <canción>` | `!p`, `!tocar` | Reproduce o agrega a la cola |
| `!search <canción>` | `!buscar` | Busca y elige entre resultados |
| `!pause` | `!pausar` | Pausa la reproducción |
| `!resume` | `!reanudar` | Reanuda la reproducción |
| `!stop` | `!detener` | Detiene y limpia la cola |
| `!skip` | `!s`, `!saltar` | Salta la canción actual |
| `!skipto <n>` | `!st` | Salta a posición en cola |
| `!seek <tiempo>` | `!ir` | Salta a tiempo (`1:30` o `90`) |
| `!nowplaying` | `!np` | Muestra la canción actual |
| `!disconnect` | `!dc`, `!salir` | Desconecta el bot |

### Cola
| Comando | Aliases | Descripción |
|---------|---------|-------------|
| `!queue [página]` | `!q`, `!cola` | Ver la cola |
| `!remove <n>` | `!eliminar`, `!rm` | Eliminar canción de la cola |
| `!move <de> <a>` | `!mover`, `!mv` | Mover canción en la cola |
| `!shuffle` | `!mezclar` | Mezclar aleatoriamente |
| `!clear` | `!limpiar` | Limpiar toda la cola |
| `!loop <track\|queue\|off>` | `!repetir` | Modo de repetición |

### Audio
| Comando | Aliases | Descripción |
|---------|---------|-------------|
| `!volume <0-200>` | `!vol` | Ajustar volumen |
| `!filters [preset]` | `!filtros` | Filtros de audio |

### Filtros disponibles
`bass`, `night`, `slow`, `pop`, `rock`, `8d`, `soft`, `clear`

### Info
| Comando | Descripción |
|---------|-------------|
| `!help` | Lista de comandos |
| `!ping` | Latencia del bot |
| `!info` | Información del bot |

## Estructura del proyecto

```
discord-music-bot/
├── src/
│   ├── index.ts               # Punto de entrada
│   ├── config.ts              # Configuración (.env)
│   ├── types.ts               # Tipos TypeScript
│   ├── commands/
│   │   ├── index.ts           # Registro de comandos
│   │   ├── play.ts            # !play, !search
│   │   ├── controls.ts        # !skip, !pause, !resume, !stop, !seek...
│   │   ├── queue.ts           # !queue, !np, !remove, !move, !loop...
│   │   ├── audio.ts           # !volume, !filters
│   │   └── info.ts            # !help, !ping, !info
│   ├── events/
│   │   ├── ready.ts           # Evento ready
│   │   ├── messageCreate.ts   # Handler de mensajes (prefijo)
│   │   └── lavalink.ts        # Eventos de Lavalink
│   └── utils/
│       ├── format.ts          # Formateo de duración, barras de progreso
│       ├── embeds.ts          # Embeds reutilizables
│       └── logger.ts          # Logger a consola y archivo
├── dist/                      # TypeScript compilado (auto-generado)
├── lavalink/
│   ├── Lavalink.jar           # Servidor de audio (auto-descargado)
│   └── application.yml        # Configuración de Lavalink
├── logs/
│   ├── bot.log
│   └── lavalink.log
├── scripts/
│   ├── install.sh
│   ├── start.sh
│   ├── stop.sh
│   ├── status.sh
│   └── update.sh
├── package.json
├── tsconfig.json
├── .env
└── .env.example
```

## Solución de problemas

### El bot no reproduce YouTube
El youtube-plugin con OAuth ya está configurado. Si falla:
1. `bash scripts/status.sh` — verificar que Lavalink esté corriendo
2. `tail -f logs/lavalink.log` — buscar errores en Lavalink
3. El token OAuth puede expirar. Si ves "Token expired", reinicia Lavalink y sigue el flujo OAuth en la consola

### Lavalink no inicia
```bash
java -version  # verificar Java 17+
ss -tlnp | grep 2333  # verificar que el puerto esté libre
tail -f logs/lavalink.log  # ver logs de error
```

### Error de compilación TypeScript
```bash
bash scripts/update.sh --force  # reinstala todo
```

### El bot se conecta pero no está en la lista de miembros
Activa en Discord Developer Portal → Bot → **Privileged Gateway Intents**:
- ✅ Message Content Intent
- ✅ Server Members Intent (opcional)

## Auto-inicio con systemd (VPS)

```ini
# /etc/systemd/system/music-bot.service
[Unit]
Description=Discord Music Bot
After=network.target

[Service]
Type=forking
User=USUARIO
WorkingDirectory=/ruta/discord-music-bot
ExecStart=/bin/bash /ruta/discord-music-bot/scripts/start.sh
ExecStop=/bin/bash /ruta/discord-music-bot/scripts/stop.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable music-bot
sudo systemctl start music-bot
```
