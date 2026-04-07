#!/usr/bin/env bash
# =============================================================================
# update.sh — Trae el código nuevo de GitHub, recompila y reinicia el bot
# Uso: bash scripts/update.sh
# =============================================================================

BOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOT_PID_FILE="$BOT_DIR/.bot.pid"
LAVALINK_PID_FILE="$BOT_DIR/.lavalink.pid"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $1"; }
success() { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
step()    { echo -e "\n${BOLD}── $1${NC}"; }

echo ""
echo "======================================================"
echo -e "   🔄  ${BOLD}Music Bot — Actualización${NC}"
echo "======================================================"

cd "$BOT_DIR"

# ──────────────────────────────────────────────────────────────────────────────
# PASO 1: git pull
# ──────────────────────────────────────────────────────────────────────────────
step "Paso 1: Trayendo cambios desde GitHub"

if ! git -C "$BOT_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
    error "Este directorio no es un repositorio git. Clona el bot con git clone."
fi

# Eliminar archivos generados localmente que puedan causar conflicto con el pull
rm -f "$BOT_DIR/package-lock.json" "$BOT_DIR/pnpm-lock.yaml"

BEFORE=$(git -C "$BOT_DIR" rev-parse HEAD 2>/dev/null)

if ! git -C "$BOT_DIR" pull --ff-only 2>&1; then
    error "git pull falló. Puede haber conflictos. Revisa manualmente con: git status"
fi

AFTER=$(git -C "$BOT_DIR" rev-parse HEAD 2>/dev/null)

if [ "$BEFORE" = "$AFTER" ]; then
    success "Ya tenías el código más reciente — sin cambios en GitHub."
    echo ""
    echo "   No hay nada que actualizar."
    echo "======================================================"
    echo ""
    exit 0
fi

# Mostrar qué commits llegaron
success "Código actualizado. Cambios:"
git -C "$BOT_DIR" log --oneline "${BEFORE}..${AFTER}" | while read -r line; do
    echo "     • $line"
done

# ──────────────────────────────────────────────────────────────────────────────
# PASO 2: Detener bot y Lavalink si están corriendo
# ──────────────────────────────────────────────────────────────────────────────
step "Paso 2: Deteniendo servicios"

BOT_WAS_RUNNING=false
LAVALINK_WAS_RUNNING=false

if [ -f "$BOT_PID_FILE" ]; then
    pid=$(cat "$BOT_PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
        BOT_WAS_RUNNING=true
    fi
fi

if [ -f "$LAVALINK_PID_FILE" ]; then
    pid=$(cat "$LAVALINK_PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
        LAVALINK_WAS_RUNNING=true
    fi
fi

if $BOT_WAS_RUNNING || $LAVALINK_WAS_RUNNING; then
    bash "$BOT_DIR/scripts/stop.sh"
    sleep 2
    success "Servicios detenidos."
else
    info "Ningún servicio estaba corriendo."
fi

# ──────────────────────────────────────────────────────────────────────────────
# PASO 3: Actualizar yt-dlp (crítico — YouTube cambia frecuentemente)
# ──────────────────────────────────────────────────────────────────────────────
step "Paso 3: Actualizando yt-dlp"

_YTDLP_URL="https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp"
_YTDLP_DEST="/usr/local/bin/yt-dlp"

update_ytdlp_binary() {
    if command -v wget &>/dev/null; then
        wget -q -O "$_YTDLP_DEST" "$_YTDLP_URL" && chmod a+rx "$_YTDLP_DEST" && return 0
    elif command -v curl &>/dev/null; then
        curl -sL -o "$_YTDLP_DEST" "$_YTDLP_URL" && chmod a+rx "$_YTDLP_DEST" && return 0
    fi
    return 1
}

if command -v yt-dlp &>/dev/null; then
    # Try self-update first (works if installed as binary with -U support)
    if yt-dlp -U 2>/dev/null | grep -q "up to date\|Updated"; then
        success "yt-dlp $(yt-dlp --version) al día."
    else
        # Re-download binary (most reliable for standalone binary installs)
        if update_ytdlp_binary; then
            success "yt-dlp $(yt-dlp --version) actualizado."
        else
            warn "No se pudo actualizar yt-dlp. Usa:"
            warn "  sudo wget -O /usr/local/bin/yt-dlp $YTDLP_BINARY_URL"
        fi
    fi
else
    warn "yt-dlp no encontrado. Instalando..."
    if update_ytdlp_binary; then
        success "yt-dlp $(yt-dlp --version) instalado."
    else
        warn "Instala manualmente:"
        warn "  sudo wget -O /usr/local/bin/yt-dlp $_YTDLP_URL"
        warn "  sudo chmod a+rx /usr/local/bin/yt-dlp"
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# PASO 4: Recompilar TypeScript
# ──────────────────────────────────────────────────────────────────────────────
step "Paso 4: Recompilando"

rm -rf "$BOT_DIR/dist"

BUILD_OUTPUT=$(npm run build 2>&1)
BUILD_EXIT=$?

if [ $BUILD_EXIT -eq 0 ] && [ -f "$BOT_DIR/dist/index.js" ]; then
    success "Compilación exitosa."
else
    echo "$BUILD_OUTPUT"
    error "Error de compilación. El bot no se reiniciará."
fi

# ──────────────────────────────────────────────────────────────────────────────
# PASO 5: Reiniciar lo que estaba corriendo
# ──────────────────────────────────────────────────────────────────────────────
step "Paso 5: Reiniciando servicios"

echo ""
echo "======================================================"
echo -e "   ${GREEN}${BOLD}✅  Actualización completa${NC}"
echo "======================================================"
echo ""

if $BOT_WAS_RUNNING || $LAVALINK_WAS_RUNNING; then
    info "Reiniciando bot..."
    bash "$BOT_DIR/scripts/start.sh"
else
    echo "   El bot no estaba corriendo."
    echo "   Para iniciarlo:  bash scripts/start.sh"
    echo ""
fi
