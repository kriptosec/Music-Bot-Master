#!/usr/bin/env bash
# =============================================================================
# install.sh — Instala todas las dependencias del Music Bot (TypeScript/Node.js)
# Uso: bash scripts/install.sh
# =============================================================================

set -e

BOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAVALINK_DIR="$BOT_DIR/lavalink"
LAVALINK_JAR="$LAVALINK_DIR/Lavalink.jar"
LAVALINK_URL="https://github.com/lavalink-devs/Lavalink/releases/latest/download/Lavalink.jar"
NODE_MIN_MAJOR=18

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
# 1. Verificar Node.js
# ──────────────────────────────────────────────────────────────────────────────
info "Verificando Node.js..."
if ! command -v node &>/dev/null; then
    error "Node.js no encontrado. Instala Node.js 18+ desde: https://nodejs.org o con:\n  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -\n  sudo apt-get install -y nodejs"
fi

NODE_VERSION=$(node -e "process.stdout.write(process.version.slice(1).split('.')[0])")
if [ "$NODE_VERSION" -lt "$NODE_MIN_MAJOR" ]; then
    error "Node.js v$NODE_VERSION encontrado. Se requiere Node.js 18+."
fi
success "Node.js v$(node -v | tr -d 'v') OK"

# ──────────────────────────────────────────────────────────────────────────────
# 2. Verificar npm o instalar pnpm
# ──────────────────────────────────────────────────────────────────────────────
info "Verificando gestor de paquetes..."
PKG_MANAGER=""
if command -v pnpm &>/dev/null; then
    PKG_MANAGER="pnpm"
    success "pnpm encontrado: $(pnpm -v)"
elif command -v npm &>/dev/null; then
    PKG_MANAGER="npm"
    success "npm encontrado: $(npm -v)"
else
    error "npm/pnpm no encontrado. Instala Node.js correctamente."
fi

# ──────────────────────────────────────────────────────────────────────────────
# 3. Instalar dependencias de Node.js
# ──────────────────────────────────────────────────────────────────────────────
info "Instalando dependencias de Node.js..."
if [ "$PKG_MANAGER" = "pnpm" ]; then
    pnpm install --frozen-lockfile 2>/dev/null || pnpm install
else
    npm install
fi
success "Dependencias instaladas."

# ──────────────────────────────────────────────────────────────────────────────
# 4. Compilar TypeScript
# ──────────────────────────────────────────────────────────────────────────────
info "Compilando TypeScript..."
if [ "$PKG_MANAGER" = "pnpm" ]; then
    pnpm run build
else
    npm run build
fi
success "TypeScript compilado en ./dist/"

# ──────────────────────────────────────────────────────────────────────────────
# 5. Verificar Java para Lavalink
# ──────────────────────────────────────────────────────────────────────────────
info "Verificando Java (requerido para Lavalink)..."
if command -v java &>/dev/null; then
    JAVA_VER=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d. -f1)
    if [ "${JAVA_VER:-0}" -ge 17 ] 2>/dev/null; then
        success "Java $JAVA_VER OK"
    else
        warn "Java $JAVA_VER encontrado. Se requiere Java 17+."
        warn "Instala con: sudo apt install openjdk-17-jre"
    fi
else
    warn "Java no encontrado. Lavalink requiere Java 17+."
    warn "Instala con: sudo apt install openjdk-17-jre"
fi

# ──────────────────────────────────────────────────────────────────────────────
# 6. Descargar Lavalink.jar si no existe
# ──────────────────────────────────────────────────────────────────────────────
mkdir -p "$LAVALINK_DIR/logs"
if [ ! -f "$LAVALINK_JAR" ]; then
    info "Descargando Lavalink.jar..."
    if command -v wget &>/dev/null; then
        wget -q --show-progress -O "$LAVALINK_JAR" "$LAVALINK_URL" || warn "No se pudo descargar automáticamente."
    elif command -v curl &>/dev/null; then
        curl -L --progress-bar -o "$LAVALINK_JAR" "$LAVALINK_URL" || warn "No se pudo descargar automáticamente."
    else
        warn "wget/curl no disponibles. Descarga Lavalink.jar manualmente:"
        warn "  https://github.com/lavalink-devs/Lavalink/releases/latest"
        warn "  → Guárdalo en: $LAVALINK_JAR"
    fi
    [ -f "$LAVALINK_JAR" ] && success "Lavalink.jar descargado."
else
    success "Lavalink.jar ya existe."
fi

# ──────────────────────────────────────────────────────────────────────────────
# 7. Verificar .env
# ──────────────────────────────────────────────────────────────────────────────
if [ ! -f "$BOT_DIR/.env" ]; then
    warn ".env no encontrado. Creando desde .env.example..."
    [ -f "$BOT_DIR/.env.example" ] && cp "$BOT_DIR/.env.example" "$BOT_DIR/.env"
    warn "Por favor edita .env y agrega tu DISCORD_TOKEN."
else
    success ".env OK"
fi

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
