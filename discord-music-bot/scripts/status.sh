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

echo ""
echo "======================================================"
echo "   🎵  Music Bot — Estado"
echo "======================================================"
echo ""

# Bot de Discord
echo -n "Bot de Discord:  "
if [ -f "$BOT_PID_FILE" ]; then
    pid=$(cat "$BOT_PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
        running
        echo "   PID: $pid"
        MEM=$(ps -o rss= -p "$pid" 2>/dev/null | awk '{printf "%.1f MB", $1/1024}')
        CPU=$(ps -o %cpu= -p "$pid" 2>/dev/null | tr -d ' ')
        [ -n "$MEM" ] && echo "   Memoria: $MEM | CPU: ${CPU}%"
    else
        stopped
        echo "   (PID $pid ya no existe)"
    fi
else
    stopped
fi

echo ""

# Lavalink
echo -n "Lavalink:        "
if [ -f "$LAVALINK_PID_FILE" ]; then
    pid=$(cat "$LAVALINK_PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
        running
        echo "   PID: $pid"
        MEM=$(ps -o rss= -p "$pid" 2>/dev/null | awk '{printf "%.1f MB", $1/1024}')
        CPU=$(ps -o %cpu= -p "$pid" 2>/dev/null | tr -d ' ')
        [ -n "$MEM" ] && echo "   Memoria: $MEM | CPU: ${CPU}%"
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
echo "────────────────────────────────────────────────────"
echo "Archivos del sistema:"
[ -f "$BOT_DIR/.env" ]                  && echo -e "  .env:             ${GREEN}✓${NC}" || echo -e "  .env:             ${RED}✗ Falta${NC}"
[ -d "$BOT_DIR/node_modules" ]          && echo -e "  node_modules:     ${GREEN}✓${NC}" || echo -e "  node_modules:     ${RED}✗ Ejecuta install.sh${NC}"
[ -d "$BOT_DIR/dist" ]                  && echo -e "  dist (compilado): ${GREEN}✓${NC}" || echo -e "  dist (compilado): ${YELLOW}✗ Ejecuta install.sh${NC}"
[ -f "$BOT_DIR/lavalink/Lavalink.jar" ] && echo -e "  Lavalink.jar:     ${GREEN}✓${NC}" || echo -e "  Lavalink.jar:     ${YELLOW}✗ Descarga pendiente${NC}"

echo ""

if [ -f "$BOT_LOG" ]; then
    echo "────────────────────────────────────────────────────"
    echo "Últimas líneas del bot:"
    tail -n 6 "$BOT_LOG"
    echo ""
fi

echo "======================================================"
echo "Comandos:"
echo "  Iniciar:    bash scripts/start.sh"
echo "  Detener:    bash scripts/stop.sh"
echo "  Actualizar: bash scripts/update.sh"
echo "  Log bot:    tail -f $BOT_LOG"
if [ -n "$LAVALINK_LOG" ]; then
    echo "  Log lava:   tail -f $LAVALINK_LOG"
fi
echo "======================================================"
echo ""
