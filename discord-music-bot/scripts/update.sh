#!/usr/bin/env bash
# =============================================================================
# update.sh — Actualiza y reinstala el Music Bot desde cero si es necesario
# Uso: bash scripts/update.sh [--force]
# --force: Reinstala todo aunque no haya cambios
# =============================================================================

set -e

BOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAVALINK_DIR="$BOT_DIR/lavalink"
LAVALINK_JAR="$LAVALINK_DIR/Lavalink.jar"
LAVALINK_URL="https://github.com/lavalink-devs/Lavalink/releases/latest/download/Lavalink.jar"
FORCE=false

for arg in "$@"; do
    [ "$arg" = "--force" ] && FORCE=true
done

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
# 1. Detener el bot si está corriendo
# ──────────────────────────────────────────────────────────────────────────────
BOT_PID_FILE="$BOT_DIR/.bot.pid"
LAVALINK_PID_FILE="$BOT_DIR/.lavalink.pid"

was_running=false
if [ -f "$BOT_PID_FILE" ]; then
    pid=$(cat "$BOT_PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
        was_running=true
        info "Deteniendo el bot para actualizar..."
        bash "$BOT_DIR/scripts/stop.sh"
        sleep 2
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# 2. Verificar Python
# ──────────────────────────────────────────────────────────────────────────────
info "Verificando Python..."
PYTHON_CMD=""
for cmd in python3 python; do
    if command -v "$cmd" &>/dev/null; then
        version=$("$cmd" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
        major=$(echo "$version" | cut -d. -f1)
        minor=$(echo "$version" | cut -d. -f2)
        if [ "$major" -ge 3 ] && [ "$minor" -ge 10 ]; then
            PYTHON_CMD="$cmd"
            success "Python $version OK"
            break
        fi
    fi
done
[ -z "$PYTHON_CMD" ] && error "Python 3.10+ requerido. Instala con: sudo apt install python3"

# ──────────────────────────────────────────────────────────────────────────────
# 3. Verificar/Crear entorno virtual
# ──────────────────────────────────────────────────────────────────────────────
if [ ! -d "$BOT_DIR/venv" ] || [ "$FORCE" = true ]; then
    info "Creando/recreando entorno virtual..."
    rm -rf "$BOT_DIR/venv"
    "$PYTHON_CMD" -m venv venv
    success "Entorno virtual creado."
fi

# ──────────────────────────────────────────────────────────────────────────────
# 4. Actualizar dependencias de Python
# ──────────────────────────────────────────────────────────────────────────────
info "Actualizando dependencias de Python..."
source "$BOT_DIR/venv/bin/activate"
pip install --upgrade pip --quiet

CHANGED=false
if [ "$FORCE" = true ]; then
    CHANGED=true
    pip install --upgrade -r requirements.txt --quiet
    success "Dependencias actualizadas (forzado)."
else
    INSTALLED=$(pip freeze 2>/dev/null)
    pip install --upgrade -r requirements.txt --quiet
    NEW_INSTALLED=$(pip freeze 2>/dev/null)
    if [ "$INSTALLED" != "$NEW_INSTALLED" ]; then
        CHANGED=true
        success "Dependencias actualizadas."
    else
        success "Dependencias ya al día."
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# 5. Verificar Java
# ──────────────────────────────────────────────────────────────────────────────
info "Verificando Java..."
if command -v java &>/dev/null; then
    java_version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d. -f1)
    if [ "$java_version" -ge 17 ] 2>/dev/null; then
        success "Java $java_version OK"
    else
        warn "Java $java_version detectado. Se requiere Java 17+."
    fi
else
    warn "Java no encontrado. Lavalink requiere Java 17+."
fi

# ──────────────────────────────────────────────────────────────────────────────
# 6. Verificar/Actualizar Lavalink.jar
# ──────────────────────────────────────────────────────────────────────────────
mkdir -p "$LAVALINK_DIR/logs"
if [ ! -f "$LAVALINK_JAR" ]; then
    info "Lavalink.jar no encontrado. Descargando..."
    NEED_DOWNLOAD=true
elif [ "$FORCE" = true ]; then
    info "Actualizando Lavalink.jar (forzado)..."
    NEED_DOWNLOAD=true
else
    info "Verificando si hay actualización de Lavalink..."
    NEED_DOWNLOAD=false
    if command -v curl &>/dev/null; then
        REMOTE_SIZE=$(curl -sI "$LAVALINK_URL" 2>/dev/null | grep -i content-length | awk '{print $2}' | tr -d '\r')
        LOCAL_SIZE=$(stat -c%s "$LAVALINK_JAR" 2>/dev/null || echo "0")
        if [ -n "$REMOTE_SIZE" ] && [ "$REMOTE_SIZE" != "$LOCAL_SIZE" ]; then
            info "Nueva versión de Lavalink disponible."
            NEED_DOWNLOAD=true
        else
            success "Lavalink.jar ya está actualizado."
        fi
    fi
fi

if [ "$NEED_DOWNLOAD" = true ]; then
    if command -v wget &>/dev/null; then
        wget -q --show-progress -O "$LAVALINK_JAR.tmp" "$LAVALINK_URL" && mv "$LAVALINK_JAR.tmp" "$LAVALINK_JAR"
        success "Lavalink.jar descargado/actualizado."
    elif command -v curl &>/dev/null; then
        curl -L -o "$LAVALINK_JAR.tmp" "$LAVALINK_URL" && mv "$LAVALINK_JAR.tmp" "$LAVALINK_JAR"
        success "Lavalink.jar descargado/actualizado."
    else
        warn "No se puede descargar Lavalink.jar automáticamente."
        warn "Descarga manualmente: https://github.com/lavalink-devs/Lavalink/releases/latest"
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# 7. Verificar .env
# ──────────────────────────────────────────────────────────────────────────────
if [ ! -f "$BOT_DIR/.env" ]; then
    if [ -f "$BOT_DIR/.env.example" ]; then
        cp "$BOT_DIR/.env.example" "$BOT_DIR/.env"
        warn "Archivo .env creado desde .env.example. Edítalo con tu token."
    else
        warn ".env no encontrado. Crea uno con tu DISCORD_TOKEN."
    fi
else
    success ".env OK"
fi

# ──────────────────────────────────────────────────────────────────────────────
# 8. Reiniciar si estaba corriendo o si hubo cambios
# ──────────────────────────────────────────────────────────────────────────────
echo ""
if [ "$was_running" = true ]; then
    info "Reiniciando el bot..."
    bash "$BOT_DIR/scripts/start.sh"
else
    echo "======================================================"
    echo -e "   ${GREEN}✅  Actualización completada${NC}"
    echo "======================================================"
    echo ""
    echo "Para iniciar el bot: bash scripts/start.sh"
    echo ""
fi
