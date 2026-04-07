# 🎵 Music Bot — Discord

Bot de música para Discord con soporte de YouTube, Spotify y SoundCloud, usando Lavalink para audio de alta calidad.

## Características

- ▶️ Reproducción de YouTube, Spotify, SoundCloud y URLs directas
- 📋 Cola de reproducción con gestión completa
- 🔁 Modos de repetición (canción, cola, apagado)
- 🔀 Mezcla aleatoria
- ⏩ Seek (saltar a posición en la canción)
- 🎚️ Filtros de audio (bass boost, nightcore, slowed, etc.)
- 🔊 Control de volumen (0–200%)
- 🔍 Búsqueda interactiva con selección
- 📊 Información de reproducción con barra de progreso

## Requisitos del sistema

- Python 3.10 o superior
- Java 17 o superior (para Lavalink)
- Sistema operativo: Linux (Ubuntu/Debian recomendado para VPS)

## Instalación rápida (VPS)

```bash
# 1. Clonar o copiar el proyecto al servidor
git clone <tu-repositorio> discord-music-bot
cd discord-music-bot

# 2. Instalar Java si no lo tienes
sudo apt update && sudo apt install -y openjdk-17-jre python3 python3-pip python3-venv wget

# 3. Ejecutar el instalador
bash scripts/install.sh

# 4. Configurar el bot (ya viene pre-configurado, verificar el token)
nano .env

# 5. Iniciar
bash scripts/start.sh
```

## Scripts disponibles

| Script | Descripción |
|--------|-------------|
| `bash scripts/install.sh` | Instala dependencias, descarga Lavalink |
| `bash scripts/start.sh` | Inicia Lavalink + bot |
| `bash scripts/stop.sh` | Detiene todo |
| `bash scripts/status.sh` | Ver estado y últimos logs |
| `bash scripts/update.sh` | Actualiza dependencias y Lavalink |
| `bash scripts/update.sh --force` | Reinstala todo desde cero |

## Configuración (.env)

```env
DISCORD_TOKEN=tu_token_aqui
LAVALINK_HOST=127.0.0.1
LAVALINK_PORT=2333
LAVALINK_PASSWORD=r2dd2pass
BOT_PREFIX=!
INACTIVE_TIMEOUT=300
```

## Comandos del bot

### Reproducción
| Comando | Alias | Descripción |
|---------|-------|-------------|
| `!play <canción>` | `!p`, `!tocar` | Reproduce o agrega a la cola |
| `!search <canción>` | `!buscar` | Busca y elige una canción |
| `!pause` | `!pausar` | Pausa/reanuda |
| `!resume` | `!reanudar` | Reanuda si está pausado |
| `!stop` | `!detener` | Detiene y limpia la cola |
| `!skip` | `!s`, `!saltar` | Salta la canción actual |
| `!skipto <n>` | `!st` | Salta a posición en cola |
| `!seek <tiempo>` | `!ir` | Salta a tiempo (`1:30` o `90`) |
| `!nowplaying` | `!np`, `!ahora` | Muestra la canción actual |

### Cola
| Comando | Alias | Descripción |
|---------|-------|-------------|
| `!queue [página]` | `!q`, `!cola` | Ver la cola |
| `!remove <n>` | `!eliminar` | Eliminar canción de la cola |
| `!move <de> <a>` | `!mover` | Mover canción en la cola |
| `!shuffle` | `!mezclar` | Mezclar aleatoriamente |
| `!clear` | `!limpiar` | Limpiar toda la cola |
| `!loop <track\|queue\|off>` | `!repetir` | Modo de repetición |

### Audio
| Comando | Alias | Descripción |
|---------|-------|-------------|
| `!volume <0-200>` | `!vol` | Ajustar volumen |
| `!filters [preset]` | `!filtros` | Filtros de audio |

### Info
| Comando | Descripción |
|---------|-------------|
| `!help` | Muestra esta ayuda |
| `!ping` | Latencia del bot |
| `!info` | Información del bot |
| `!disconnect` | Desconectar el bot |

## Estructura del proyecto

```
discord-music-bot/
├── main.py                    # Punto de entrada del bot
├── config.py                  # Configuración desde .env
├── requirements.txt           # Dependencias de Python
├── .env                       # Variables de entorno (privado)
├── .env.example               # Ejemplo de configuración
├── .gitignore
├── cogs/
│   ├── music.py               # Comandos de música
│   └── help.py                # Comandos de ayuda e info
├── lavalink/
│   ├── Lavalink.jar           # Servidor de audio (auto-descargado)
│   └── application.yml        # Configuración de Lavalink
├── logs/
│   ├── bot.log
│   └── lavalink.log
└── scripts/
    ├── install.sh
    ├── start.sh
    ├── stop.sh
    ├── status.sh
    └── update.sh
```

## Solución de problemas

### El bot no reproduce YouTube
- Verifica que Lavalink esté corriendo: `bash scripts/status.sh`
- El plugin de YouTube usa OAuth — revisa `lavalink/application.yml`
- El token OAuth puede expirar. Si falla, ejecuta Lavalink y sigue las instrucciones en consola

### Lavalink no inicia
- Verifica Java 17+: `java -version`
- Revisa los logs: `tail -f logs/lavalink.log`
- Puerto 2333 libre: `ss -tlnp | grep 2333`

### Error de conexión al bot
- Verifica el token en `.env`
- El bot debe tener los permisos: `Send Messages`, `Connect`, `Speak`
- Activa los "Privileged Intents" en el portal de Discord Developer

## Mantenimiento con systemd (opcional)

Para que el bot arranque automáticamente al reiniciar la VPS, crea un servicio systemd:

```ini
# /etc/systemd/system/music-bot.service
[Unit]
Description=Discord Music Bot
After=network.target

[Service]
Type=forking
User=tu_usuario
WorkingDirectory=/ruta/al/discord-music-bot
ExecStart=/bin/bash /ruta/al/discord-music-bot/scripts/start.sh
ExecStop=/bin/bash /ruta/al/discord-music-bot/scripts/stop.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable music-bot
sudo systemctl start music-bot
```
