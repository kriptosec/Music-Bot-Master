#!/usr/bin/env bash
# =============================================================================
# update.sh — Actualiza y/o reinstala el Music Bot desde cero
# Uso: bash scripts/update.sh [--force]
# --force: Reinstala todo aunque no haya cambios detectados
# =============================================================================

set -e

BOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAVALINK_DIR="$BOT_DIR/lavalink"
LAVALINK_JAR="$LAVALINK_DIR/Lavalink.jar"
LAVALINK_URL="https://github.com/lavalink-devs/Lavalink/releases/latest/download/Lavalink.jar"
FORCE=false

for arg in "$@"; do [ "$arg" = "--force" ] && FORCE=true; done

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
echo "   🔄  Music Bot — Actualización"
echo "======================================================"
echo ""

cd "$BOT_DIR"

# ──────────────────────────────────────────────────────────────────────────────
# 1. Verificar si bot estaba corriendo y detenerlo
# ──────────────────────────────────────────────────────────────────────────────
BOT_PID_FILE="$BOT_DIR/.bot.pid"
was_running=false

if [ -f "$BOT_PID_FILE" ]; then
    pid=$(cat "$BOT_PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
        was_running=true
        info "Deteniendo bot para actualizar..."
        bash "$BOT_DIR/scripts/stop.sh"
        sleep 2
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# 2. Verificar Node.js
# ──────────────────────────────────────────────────────────────────────────────
info "Verificando Node.js..."
command -v node &>/dev/null || error "Node.js no encontrado. Instala Node.js 18+."
NODE_VER=$(node -e "process.stdout.write(process.version.slice(1).split('.')[0])")
[ "$NODE_VER" -lt 18 ] && error "Node.js 18+ requerido. Versión actual: v$(node -v)"
success "Node.js $(node -v) OK"

# ──────────────────────────────────────────────────────────────────────────────
# 3. Instalar/actualizar dependencias de Node.js
# ──────────────────────────────────────────────────────────────────────────────
info "Actualizando dependencias de Node.js..."
PKG_MANAGER=""
command -v pnpm &>/dev/null && PKG_MANAGER="pnpm" || PKG_MANAGER="npm"

if [ "$FORCE" = true ]; then
    info "Reinstalando node_modules desde cero (--force)..."
    rm -rf "$BOT_DIR/node_modules"
fi

if [ "$PKG_MANAGER" = "pnpm" ]; then
    pnpm install 2>/dev/null || pnpm install --no-frozen-lockfile
else
    npm install
fi
success "Dependencias actualizadas."

# ──────────────────────────────────────────────────────────────────────────────
# 4. Recompilar TypeScript
# ──────────────────────────────────────────────────────────────────────────────
info "Compilando TypeScript..."
rm -rf "$BOT_DIR/dist"
if [ "$PKG_MANAGER" = "pnpm" ]; then
    pnpm run build
else
    npm run build
fi
success "Compilación exitosa."

# ──────────────────────────────────────────────────────────────────────────────
# 5. Verificar Java
# ──────────────────────────────────────────────────────────────────────────────
info "Verificando Java..."
if command -v java &>/dev/null; then
    JAVA_VER=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d. -f1)
    if [ "${JAVA_VER:-0}" -ge 17 ] 2>/dev/null; then
        success "Java $JAVA_VER OK"
    else
        warn "Java $JAVA_VER detectado. Se requiere Java 17+."
    fi
else
    warn "Java no encontrado. Necesario para Lavalink."
fi

# ──────────────────────────────────────────────────────────────────────────────
# 6. Verificar/actualizar Lavalink.jar
# ──────────────────────────────────────────────────────────────────────────────
mkdir -p "$LAVALINK_DIR/logs"

if [ ! -f "$LAVALINK_JAR" ]; then
    NEED_DOWNLOAD=true
    info "Lavalink.jar no encontrado. Descargando..."
elif [ "$FORCE" = true ]; then
    NEED_DOWNLOAD=true
    info "Actualizando Lavalink.jar (--force)..."
else
    NEED_DOWNLOAD=false
    info "Verificando actualización de Lavalink..."
    if command -v curl &>/dev/null; then
        REMOTE=$(curl -sI "$LAVALINK_URL" 2>/dev/null | grep -i content-length | awk '{print $2}' | tr -d '\r')
        LOCAL=$(stat -c%s "$LAVALINK_JAR" 2>/dev/null || echo "0")
        [ -n "$REMOTE" ] && [ "$REMOTE" != "$LOCAL" ] && NEED_DOWNLOAD=true && info "Nueva versión de Lavalink disponible."
        [ "$NEED_DOWNLOAD" = false ] && success "Lavalink.jar ya está actualizado."
    fi
fi

if [ "$NEED_DOWNLOAD" = true ]; then
    if command -v wget &>/dev/null; then
        wget -q --show-progress -O "$LAVALINK_JAR.tmp" "$LAVALINK_URL" && mv "$LAVALINK_JAR.tmp" "$LAVALINK_JAR"
        success "Lavalink.jar actualizado."
    elif command -v curl &>/dev/null; then
        curl -L --progress-bar -o "$LAVALINK_JAR.tmp" "$LAVALINK_URL" && mv "$LAVALINK_JAR.tmp" "$LAVALINK_JAR"
        success "Lavalink.jar actualizado."
    else
        warn "No se puede descargar automáticamente. Descarga manualmente:"
        warn "  https://github.com/lavalink-devs/Lavalink/releases/latest"
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# 7. Verificar .env
# ──────────────────────────────────────────────────────────────────────────────
if [ ! -f "$BOT_DIR/.env" ]; then
    [ -f "$BOT_DIR/.env.example" ] && cp "$BOT_DIR/.env.example" "$BOT_DIR/.env"
    warn ".env no encontrado o creado desde .env.example. Revisa tu DISCORD_TOKEN."
else
    success ".env OK"
fi

# ──────────────────────────────────────────────────────────────────────────────
# 8. Reiniciar si estaba corriendo
# ──────────────────────────────────────────────────────────────────────────────
echo ""
if [ "$was_running" = true ]; then
    info "Reiniciando bot..."
    bash "$BOT_DIR/scripts/start.sh"
else
    echo "======================================================"
    echo -e "   ${GREEN}✅  Actualización completada${NC}"
    echo "======================================================"
    echo ""
    echo "Para iniciar: bash scripts/start.sh"
    echo ""
fi
