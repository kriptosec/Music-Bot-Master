#!/usr/bin/env bash
# =============================================================================
# install.sh — Instala todas las dependencias del Music Bot
# Uso: bash scripts/install.sh
# =============================================================================

set -e

BOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAVALINK_DIR="$BOT_DIR/lavalink"
LAVALINK_JAR="$LAVALINK_DIR/Lavalink.jar"
LAVALINK_URL="https://github.com/lavalink-devs/Lavalink/releases/latest/download/Lavalink.jar"
PYTHON_MIN_VERSION="3.10"

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
echo "   🎵  Music Bot — Instalación"
echo "======================================================"
echo ""

cd "$BOT_DIR"

# ──────────────────────────────────────────────────────────────────────────────
# 1. Verificar Python
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
            success "Python $version encontrado en '$cmd'"
            break
        fi
    fi
done

if [ -z "$PYTHON_CMD" ]; then
    error "Se requiere Python 3.10+. Instálalo con: sudo apt install python3 python3-pip"
fi

# ──────────────────────────────────────────────────────────────────────────────
# 2. Verificar pip
# ──────────────────────────────────────────────────────────────────────────────
info "Verificando pip..."
PIP_CMD=""
for cmd in pip3 pip; do
    if command -v "$cmd" &>/dev/null; then
        PIP_CMD="$cmd"
        break
    fi
done

if [ -z "$PIP_CMD" ]; then
    warn "pip no encontrado. Intentando instalar..."
    "$PYTHON_CMD" -m ensurepip --upgrade || error "No se pudo instalar pip."
    PIP_CMD="$PYTHON_CMD -m pip"
fi
success "pip encontrado: $PIP_CMD"

# ──────────────────────────────────────────────────────────────────────────────
# 3. Instalar dependencias de Python
# ──────────────────────────────────────────────────────────────────────────────
info "Instalando dependencias de Python..."
if [ -d "venv" ]; then
    info "Entorno virtual existente encontrado. Actualizando..."
else
    info "Creando entorno virtual en ./venv ..."
    "$PYTHON_CMD" -m venv venv
fi

source venv/bin/activate
pip install --upgrade pip --quiet
pip install -r requirements.txt --quiet
success "Dependencias de Python instaladas."

# ──────────────────────────────────────────────────────────────────────────────
# 4. Verificar Java para Lavalink
# ──────────────────────────────────────────────────────────────────────────────
info "Verificando Java (requerido para Lavalink)..."
if command -v java &>/dev/null; then
    java_version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d. -f1)
    if [ "$java_version" -ge 17 ] 2>/dev/null; then
        success "Java $java_version encontrado."
    else
        warn "Java $java_version encontrado pero se requiere Java 17+."
        warn "Instala con: sudo apt install openjdk-17-jre"
    fi
else
    warn "Java no encontrado. Lavalink requiere Java 17+."
    warn "Instala con: sudo apt install openjdk-17-jre"
fi

# ──────────────────────────────────────────────────────────────────────────────
# 5. Descargar Lavalink.jar si no existe
# ──────────────────────────────────────────────────────────────────────────────
mkdir -p "$LAVALINK_DIR/logs"
if [ ! -f "$LAVALINK_JAR" ]; then
    info "Descargando Lavalink.jar..."
    if command -v wget &>/dev/null; then
        wget -q --show-progress -O "$LAVALINK_JAR" "$LAVALINK_URL" || {
            warn "No se pudo descargar Lavalink.jar automáticamente."
            warn "Descárgalo manualmente desde:"
            warn "  https://github.com/lavalink-devs/Lavalink/releases/latest"
            warn "Y colócalo en: $LAVALINK_JAR"
        }
    elif command -v curl &>/dev/null; then
        curl -L -o "$LAVALINK_JAR" "$LAVALINK_URL" || {
            warn "No se pudo descargar Lavalink.jar automáticamente."
        }
    else
        warn "wget y curl no disponibles. Descarga Lavalink.jar manualmente desde:"
        warn "  https://github.com/lavalink-devs/Lavalink/releases/latest"
        warn "Y colócalo en: $LAVALINK_JAR"
    fi

    if [ -f "$LAVALINK_JAR" ]; then
        success "Lavalink.jar descargado."
    fi
else
    success "Lavalink.jar ya existe."
fi

# ──────────────────────────────────────────────────────────────────────────────
# 6. Verificar .env
# ──────────────────────────────────────────────────────────────────────────────
if [ ! -f "$BOT_DIR/.env" ]; then
    warn ".env no encontrado. Creando desde .env.example..."
    if [ -f "$BOT_DIR/.env.example" ]; then
        cp "$BOT_DIR/.env.example" "$BOT_DIR/.env"
        warn "Por favor edita .env y agrega tu DISCORD_TOKEN."
    fi
else
    success "Archivo .env encontrado."
fi

# ──────────────────────────────────────────────────────────────────────────────
# Fin
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "======================================================"
echo -e "   ${GREEN}✅  Instalación completada${NC}"
echo "======================================================"
echo ""
echo "Para iniciar el bot:"
echo "  bash scripts/start.sh"
echo ""
echo "Para ver el estado:"
echo "  bash scripts/status.sh"
echo ""
