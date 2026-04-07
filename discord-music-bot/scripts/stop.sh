#!/usr/bin/env bash
# =============================================================================
# stop.sh — Detiene el Music Bot (Lavalink + Bot de Discord)
# Uso: bash scripts/stop.sh
# =============================================================================

BOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAVALINK_PID_FILE="$BOT_DIR/.lavalink.pid"
BOT_PID_FILE="$BOT_DIR/.bot.pid"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }

echo ""
echo "======================================================"
echo "   🎵  Music Bot — Deteniendo"
echo "======================================================"
echo ""

# Detener bot de Discord
if [ -f "$BOT_PID_FILE" ]; then
    pid=$(cat "$BOT_PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
        info "Deteniendo bot (PID: $pid)..."
        kill -TERM "$pid" 2>/dev/null
        sleep 2
        kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null
        success "Bot detenido."
    else
        warn "Bot no está corriendo (PID $pid no existe)."
    fi
    rm -f "$BOT_PID_FILE"
else
    warn "Bot no está corriendo (sin archivo PID)."
fi

# Detener Lavalink
if [ -f "$LAVALINK_PID_FILE" ]; then
    pid=$(cat "$LAVALINK_PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
        info "Deteniendo Lavalink (PID: $pid)..."
        kill -TERM "$pid" 2>/dev/null
        sleep 3
        kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null
        success "Lavalink detenido."
    else
        warn "Lavalink no está corriendo (PID $pid no existe)."
    fi
    rm -f "$LAVALINK_PID_FILE"
else
    warn "Lavalink no está corriendo (sin archivo PID)."
fi

echo ""
echo -e "   ${GREEN}✅  Todo detenido.${NC}"
echo ""
