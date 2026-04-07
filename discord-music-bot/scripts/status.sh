#!/usr/bin/env bash
# =============================================================================
# status.sh — Muestra el estado del Music Bot
# Uso: bash scripts/status.sh
# =============================================================================

BOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAVALINK_PID_FILE="$BOT_DIR/.lavalink.pid"
BOT_PID_FILE="$BOT_DIR/.bot.pid"
BOT_LOG="$BOT_DIR/logs/bot.log"
LAVALINK_LOG="$BOT_DIR/logs/lavalink.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

running() { echo -e "${GREEN}● Corriendo${NC}"; }
stopped() { echo -e "${RED}○ Detenido${NC}"; }
unknown() { echo -e "${YELLOW}? Desconocido${NC}"; }

echo ""
echo "======================================================"
echo "   🎵  Music Bot — Estado"
echo "======================================================"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Bot de Discord
# ──────────────────────────────────────────────────────────────────────────────
echo -n "Bot de Discord:  "
if [ -f "$BOT_PID_FILE" ]; then
    pid=$(cat "$BOT_PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
        running
        echo "   PID: $pid"
        MEM=$(ps -o rss= -p "$pid" 2>/dev/null | awk '{printf "%.1f MB", $1/1024}')
        echo "   Memoria: $MEM"
    else
        stopped
        echo "   (PID $pid ya no existe)"
    fi
else
    stopped
fi

echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Lavalink
# ──────────────────────────────────────────────────────────────────────────────
echo -n "Lavalink:        "
if [ -f "$LAVALINK_PID_FILE" ]; then
    pid=$(cat "$LAVALINK_PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
        running
        echo "   PID: $pid"
        MEM=$(ps -o rss= -p "$pid" 2>/dev/null | awk '{printf "%.1f MB", $1/1024}')
        echo "   Memoria: $MEM"
        PORT=$(grep "^  port:" "$BOT_DIR/lavalink/application.yml" 2>/dev/null | awk '{print $2}')
        echo "   Puerto: ${PORT:-2333}"
    else
        stopped
        echo "   (PID $pid ya no existe)"
    fi
else
    stopped
fi

echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Archivos
# ──────────────────────────────────────────────────────────────────────────────
echo "────────────────────────────────────────────────────"
echo "Archivos:"
[ -f "$BOT_DIR/.env" ]                   && echo -e "  .env:            ${GREEN}✓${NC}" || echo -e "  .env:            ${RED}✗ Falta${NC}"
[ -f "$BOT_DIR/lavalink/Lavalink.jar" ]  && echo -e "  Lavalink.jar:    ${GREEN}✓${NC}" || echo -e "  Lavalink.jar:    ${YELLOW}✗ No descargado${NC}"
[ -d "$BOT_DIR/venv" ]                   && echo -e "  venv:            ${GREEN}✓${NC}" || echo -e "  venv:            ${RED}✗ No instalado${NC}"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Últimas líneas del log
# ──────────────────────────────────────────────────────────────────────────────
if [ -f "$BOT_LOG" ]; then
    echo "────────────────────────────────────────────────────"
    echo "Últimas líneas del log del bot:"
    tail -n 5 "$BOT_LOG"
    echo ""
fi

echo "======================================================"
echo "Comandos:"
echo "  Iniciar:    bash scripts/start.sh"
echo "  Detener:    bash scripts/stop.sh"
echo "  Actualizar: bash scripts/update.sh"
echo "  Log bot:    tail -f $BOT_LOG"
echo "  Log lava:   tail -f $LAVALINK_LOG"
echo "======================================================"
echo ""
