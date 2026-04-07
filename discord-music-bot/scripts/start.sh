#!/usr/bin/env bash
# =============================================================================
# start.sh — Inicia el Music Bot (Lavalink + Bot de Discord)
# Uso: bash scripts/start.sh
# =============================================================================

BOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAVALINK_DIR="$BOT_DIR/lavalink"
LAVALINK_JAR="$LAVALINK_DIR/Lavalink.jar"
LAVALINK_PID_FILE="$BOT_DIR/.lavalink.pid"
BOT_PID_FILE="$BOT_DIR/.bot.pid"
LAVALINK_LOG="$BOT_DIR/logs/lavalink.log"
BOT_LOG="$BOT_DIR/logs/bot.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

echo ""
echo "======================================================"
echo "   🎵  Music Bot — Iniciando"
echo "======================================================"
echo ""

cd "$BOT_DIR"
mkdir -p "$BOT_DIR/logs" "$LAVALINK_DIR/logs"

# ──────────────────────────────────────────────────────────────────────────────
# Verificar que no esté ya corriendo
# ──────────────────────────────────────────────────────────────────────────────
if [ -f "$BOT_PID_FILE" ]; then
    pid=$(cat "$BOT_PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
        warn "El bot ya está corriendo (PID: $pid). Usa 'bash scripts/stop.sh' primero."
        exit 1
    else
        rm -f "$BOT_PID_FILE"
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# Verificar entorno virtual
# ──────────────────────────────────────────────────────────────────────────────
if [ ! -d "$BOT_DIR/venv" ]; then
    warn "Entorno virtual no encontrado. Ejecuta 'bash scripts/install.sh' primero."
    exit 1
fi

# ──────────────────────────────────────────────────────────────────────────────
# Verificar .env
# ──────────────────────────────────────────────────────────────────────────────
if [ ! -f "$BOT_DIR/.env" ]; then
    error ".env no encontrado. Ejecuta 'bash scripts/install.sh' primero."
fi

TOKEN=$(grep "^DISCORD_TOKEN=" "$BOT_DIR/.env" | cut -d= -f2-)
if [ -z "$TOKEN" ] || [ "$TOKEN" = "TU_TOKEN_AQUI" ]; then
    error "DISCORD_TOKEN no configurado en .env"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Iniciar Lavalink
# ──────────────────────────────────────────────────────────────────────────────
if [ -f "$LAVALINK_JAR" ] && command -v java &>/dev/null; then
    if [ -f "$LAVALINK_PID_FILE" ]; then
        lava_pid=$(cat "$LAVALINK_PID_FILE")
        if kill -0 "$lava_pid" 2>/dev/null; then
            success "Lavalink ya está corriendo (PID: $lava_pid)"
        else
            rm -f "$LAVALINK_PID_FILE"
            lava_pid=""
        fi
    fi

    if [ -z "${lava_pid:-}" ]; then
        info "Iniciando Lavalink..."
        cd "$LAVALINK_DIR"
        nohup java -jar Lavalink.jar > "$LAVALINK_LOG" 2>&1 &
        echo $! > "$LAVALINK_PID_FILE"
        success "Lavalink iniciado (PID: $(cat $LAVALINK_PID_FILE))"
        cd "$BOT_DIR"

        info "Esperando que Lavalink esté listo (30s máx)..."
        for i in $(seq 1 30); do
            sleep 1
            if grep -q "Lavalink is ready to accept connections" "$LAVALINK_LOG" 2>/dev/null; then
                success "Lavalink listo."
                break
            fi
            if [ "$i" -eq 30 ]; then
                warn "Lavalink tardó más de lo esperado. Continuando de todas formas..."
            fi
        done
    fi
else
    if [ ! -f "$LAVALINK_JAR" ]; then
        warn "Lavalink.jar no encontrado. El bot iniciará pero sin audio."
    fi
    if ! command -v java &>/dev/null; then
        warn "Java no encontrado. Instala Java 17+ para habilitar audio."
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# Iniciar el bot de Discord
# ──────────────────────────────────────────────────────────────────────────────
info "Iniciando el bot de Discord..."
source "$BOT_DIR/venv/bin/activate"
nohup python "$BOT_DIR/main.py" >> "$BOT_LOG" 2>&1 &
BOT_PID=$!
echo $BOT_PID > "$BOT_PID_FILE"

sleep 2
if kill -0 "$BOT_PID" 2>/dev/null; then
    success "Bot de Discord iniciado (PID: $BOT_PID)"
else
    error "El bot falló al iniciar. Revisa los logs: $BOT_LOG"
fi

echo ""
echo "======================================================"
echo -e "   ${GREEN}✅  Music Bot corriendo${NC}"
echo "======================================================"
echo ""
echo "Logs del bot:      tail -f $BOT_LOG"
echo "Logs de Lavalink:  tail -f $LAVALINK_LOG"
echo "Estado:            bash scripts/status.sh"
echo "Detener:           bash scripts/stop.sh"
echo ""
