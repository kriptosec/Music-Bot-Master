#!/usr/bin/env bash
# =============================================================================
# logs.sh — Visor de logs en tiempo real del Music Bot
# Uso:
#   bash scripts/logs.sh           → ambos logs (bot + lavalink)
#   bash scripts/logs.sh bot       → solo el bot
#   bash scripts/logs.sh lavalink  → solo Lavalink
#   bash scripts/logs.sh error     → solo líneas con ERROR o WARN
#   bash scripts/logs.sh -n 100    → últimas 100 líneas y luego tiempo real
# =============================================================================

BOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOT_LOG="$BOT_DIR/logs/bot.log"
LAVALINK_LOG="$BOT_DIR/logs/lavalink.log"

# ── Colores ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ── Parámetros ────────────────────────────────────────────────────────────────
MODE="${1:-both}"       # bot | lavalink | error | both
LINES="${2:-50}"        # últimas N líneas para el inicio
if [[ "$1" == "-n" ]]; then
    MODE="both"
    LINES="${2:-50}"
fi

# ── Función para colorear una línea del log ────────────────────────────────────
colorize_bot() {
    local line="$1"
    if echo "$line" | grep -q "\[ERROR\]"; then
        echo -e "${RED}${line}${NC}"
    elif echo "$line" | grep -q "\[WARN \]"; then
        echo -e "${YELLOW}${line}${NC}"
    elif echo "$line" | grep -q "\[INFO \]"; then
        echo -e "${GREEN}${line}${NC}"
    elif echo "$line" | grep -q "\[DEBUG\]"; then
        echo -e "${DIM}${CYAN}${line}${NC}"
    else
        echo "$line"
    fi
}

colorize_lava() {
    local line="$1"
    if echo "$line" | grep -qiE "error|exception|failed|fatal"; then
        echo -e "${RED}[LAVA] ${line}${NC}"
    elif echo "$line" | grep -qiE "warn"; then
        echo -e "${YELLOW}[LAVA] ${line}${NC}"
    elif echo "$line" | grep -qiE "connected|ready|started"; then
        echo -e "${MAGENTA}${BOLD}[LAVA] ${line}${NC}"
    else
        echo -e "${MAGENTA}[LAVA]${NC} ${DIM}${line}${NC}"
    fi
}

# ── Header ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}======================================================"
echo -e "   🎵  Music Bot — Logs en tiempo real"
echo -e "======================================================${NC}"

case "$MODE" in
    bot)      echo -e "   Mostrando: ${GREEN}Bot únicamente${NC}" ;;
    lavalink) echo -e "   Mostrando: ${MAGENTA}Lavalink únicamente${NC}" ;;
    error)    echo -e "   Mostrando: ${RED}Solo ERROR y WARN${NC}" ;;
    *)        echo -e "   Mostrando: ${GREEN}Bot${NC} + ${MAGENTA}Lavalink${NC}" ;;
esac

echo -e "   Últimas líneas al inicio: $LINES"
echo -e "   ${DIM}Ctrl+C para salir${NC}"
echo -e "${BOLD}------------------------------------------------------${NC}"
echo ""

# ── Verificar que existan los archivos ────────────────────────────────────────
case "$MODE" in
    bot|both|error)
        if [ ! -f "$BOT_LOG" ]; then
            echo -e "${YELLOW}[WARN]${NC}  $BOT_LOG no existe todavía. ¿Está el bot corriendo?"
            echo -e "         Inicia con: ${BOLD}bash scripts/start.sh${NC}"
        fi
        ;;
esac

case "$MODE" in
    lavalink|both|error)
        if [ ! -f "$LAVALINK_LOG" ]; then
            echo -e "${YELLOW}[WARN]${NC}  $LAVALINK_LOG no existe todavía."
        fi
        ;;
esac

# ── Mostrar logs ───────────────────────────────────────────────────────────────

if [ "$MODE" = "both" ]; then
    # Ambos logs intercalados con tail -f de ambos archivos
    touch "$BOT_LOG" "$LAVALINK_LOG" 2>/dev/null

    tail -n "$LINES" -F "$BOT_LOG" "$LAVALINK_LOG" 2>/dev/null | while IFS= read -r line; do
        if echo "$line" | grep -q "==> $BOT_LOG"; then
            echo -e "\n${GREEN}${BOLD}── BOT LOG ──────────────────────────────────────────${NC}"
        elif echo "$line" | grep -q "==> $LAVALINK_LOG"; then
            echo -e "\n${MAGENTA}${BOLD}── LAVALINK LOG ─────────────────────────────────────${NC}"
        elif echo "$line" | grep -qE "\[ERROR\]|\[WARN"; then
            echo -e "${RED}${line}${NC}"
        elif echo "$line" | grep -q "\[INFO"; then
            echo -e "${GREEN}${line}${NC}"
        elif echo "$line" | grep -q "\[DEBUG\]"; then
            echo -e "${DIM}${CYAN}${line}${NC}"
        elif echo "$line" | grep -qiE "error|exception|failed|fatal" && ! echo "$line" | grep -q "==>"; then
            echo -e "${RED}[LAVA] ${line}${NC}"
        elif echo "$line" | grep -qiE "connected|ready|started" && ! echo "$line" | grep -q "==>"; then
            echo -e "${MAGENTA}${BOLD}[LAVA] ${line}${NC}"
        else
            if ! echo "$line" | grep -q "==>"; then
                echo -e "${MAGENTA}[LAVA]${NC} ${DIM}${line}${NC}"
            fi
        fi
    done

elif [ "$MODE" = "bot" ]; then
    if [ ! -f "$BOT_LOG" ]; then
        echo "Esperando a que se cree bot.log..."
        while [ ! -f "$BOT_LOG" ]; do sleep 1; done
    fi
    tail -n "$LINES" -F "$BOT_LOG" | while IFS= read -r line; do
        colorize_bot "$line"
    done

elif [ "$MODE" = "lavalink" ]; then
    if [ ! -f "$LAVALINK_LOG" ]; then
        echo "Esperando a que se cree lavalink.log..."
        while [ ! -f "$LAVALINK_LOG" ]; do sleep 1; done
    fi
    tail -n "$LINES" -F "$LAVALINK_LOG" | while IFS= read -r line; do
        colorize_lava "$line"
    done

elif [ "$MODE" = "error" ]; then
    touch "$BOT_LOG" "$LAVALINK_LOG" 2>/dev/null
    echo -e "${DIM}Filtrando solo ERROR y WARN de ambos logs...${NC}"
    echo ""
    tail -n "$LINES" -F "$BOT_LOG" "$LAVALINK_LOG" 2>/dev/null | grep --line-buffered -iE "ERROR|WARN|exception|failed|fatal" | while IFS= read -r line; do
        echo -e "${RED}${line}${NC}"
    done
fi
