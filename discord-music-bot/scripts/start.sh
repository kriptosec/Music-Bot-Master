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
# Verificar build compilado
# ──────────────────────────────────────────────────────────────────────────────
if [ ! -f "$BOT_DIR/dist/index.js" ]; then
    warn "Build no encontrado. Compilando TypeScript..."
    if command -v pnpm &>/dev/null; then
        pnpm run build || error "Error al compilar. Revisa los errores de TypeScript."
    elif command -v npm &>/dev/null; then
        npm run build || error "Error al compilar. Revisa los errores de TypeScript."
    else
        error "npm/pnpm no encontrado. Ejecuta 'bash scripts/install.sh' primero."
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# Verificar .env
# ──────────────────────────────────────────────────────────────────────────────
[ ! -f "$BOT_DIR/.env" ] && error ".env no encontrado. Ejecuta 'bash scripts/install.sh' primero."

TOKEN=$(grep "^DISCORD_TOKEN=" "$BOT_DIR/.env" | cut -d= -f2-)
if [ -z "$TOKEN" ] || [ "$TOKEN" = "TU_TOKEN_AQUI" ]; then
    error "DISCORD_TOKEN no configurado en .env"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Iniciar Lavalink
# ──────────────────────────────────────────────────────────────────────────────
lava_pid=""
if [ -f "$LAVALINK_PID_FILE" ]; then
    lava_pid=$(cat "$LAVALINK_PID_FILE")
    if ! kill -0 "$lava_pid" 2>/dev/null; then
        rm -f "$LAVALINK_PID_FILE"
        lava_pid=""
    fi
fi

if [ -n "$lava_pid" ]; then
    success "Lavalink ya está corriendo (PID: $lava_pid)"
elif [ -f "$LAVALINK_JAR" ] && command -v java &>/dev/null; then
    info "Iniciando Lavalink..."
    cd "$LAVALINK_DIR"
    nohup java -Xmx512m -jar Lavalink.jar > "$LAVALINK_LOG" 2>&1 &
    echo $! > "$LAVALINK_PID_FILE"
    success "Lavalink iniciado (PID: $(cat $LAVALINK_PID_FILE))"
    cd "$BOT_DIR"

    info "Esperando que Lavalink esté listo (45s máx)..."
    for i in $(seq 1 45); do
        sleep 1
        if grep -q "Lavalink is ready to accept connections" "$LAVALINK_LOG" 2>/dev/null; then
            success "Lavalink listo."
            break
        fi
        if [ "$i" -eq 45 ]; then
            warn "Lavalink tardó más de lo esperado. Continuando de todas formas..."
        fi
    done
else
    [ ! -f "$LAVALINK_JAR" ] && warn "Lavalink.jar no encontrado. El bot iniciará sin audio."
    ! command -v java &>/dev/null && warn "Java no encontrado. Instala Java 17+."
fi

# ──────────────────────────────────────────────────────────────────────────────
# Iniciar el bot de Discord
# ──────────────────────────────────────────────────────────────────────────────
info "Iniciando bot de Discord..."
nohup node "$BOT_DIR/dist/index.js" >> "$BOT_LOG" 2>&1 &
BOT_PID=$!
echo $BOT_PID > "$BOT_PID_FILE"

sleep 2
if kill -0 "$BOT_PID" 2>/dev/null; then
    success "Bot de Discord iniciado (PID: $BOT_PID)"
else
    error "El bot falló al iniciar. Revisa los logs:\n  tail -f $BOT_LOG"
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
