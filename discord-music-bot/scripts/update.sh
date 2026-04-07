#!/usr/bin/env bash
# =============================================================================
# update.sh — Actualiza el Music Bot desde GitHub y reinstala/recompila todo
# Uso: bash scripts/update.sh [--force]
# --force: Borra node_modules y Lavalink.jar y reinstala todo desde cero
# =============================================================================

BOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAVALINK_DIR="$BOT_DIR/lavalink"
LAVALINK_JAR="$LAVALINK_DIR/Lavalink.jar"
LAVALINK_URL="https://github.com/lavalink-devs/Lavalink/releases/latest/download/Lavalink.jar"
BOT_PID_FILE="$BOT_DIR/.bot.pid"
FORCE=false

for arg in "$@"; do [ "$arg" = "--force" ] && FORCE=true; done

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
# PASO 1: git pull — traer últimos cambios desde GitHub
# ──────────────────────────────────────────────────────────────────────────────
step "Paso 1: Actualizando código desde GitHub"

# El npm install genera package-lock.json que no está en git.
# Lo eliminamos antes de hacer pull para evitar conflictos.
rm -f "$BOT_DIR/package-lock.json" "$BOT_DIR/pnpm-lock.yaml"

# Verificar que estamos en un repo git
if ! git -C "$BOT_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
    warn "Este directorio no es un repositorio git. Saltando git pull."
    warn "Si instalaste el bot manualmente (no con git clone), las actualizaciones"
    warn "deben hacerse descargando el código nuevo manualmente."
else
    # Obtener el commit actual para saber si hubo cambios
    BEFORE=$(git -C "$BOT_DIR" rev-parse HEAD 2>/dev/null)

    if git -C "$BOT_DIR" pull --ff-only 2>&1; then
        AFTER=$(git -C "$BOT_DIR" rev-parse HEAD 2>/dev/null)
        if [ "$BEFORE" = "$AFTER" ]; then
            success "Ya tenías el código más reciente (sin cambios)."
        else
            CHANGES=$(git -C "$BOT_DIR" log --oneline "${BEFORE}..${AFTER}" 2>/dev/null)
            success "Código actualizado. Cambios aplicados:"
            echo "$CHANGES" | while read -r line; do echo "    • $line"; done
        fi
    else
        warn "git pull falló. Intentando con --rebase..."
        if git -C "$BOT_DIR" pull --rebase 2>&1; then
            success "Código actualizado con rebase."
        else
            error "No se pudo actualizar el código. Revisa conflictos en el repositorio."
        fi
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# PASO 2: Detener el bot si estaba corriendo
# ──────────────────────────────────────────────────────────────────────────────
step "Paso 2: Verificando proceso del bot"
was_running=false

if [ -f "$BOT_PID_FILE" ]; then
    pid=$(cat "$BOT_PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
        was_running=true
        info "Bot corriendo (PID $pid). Deteniéndolo para actualizar..."
        bash "$BOT_DIR/scripts/stop.sh"
        sleep 2
        success "Bot detenido."
    else
        rm -f "$BOT_PID_FILE"
        info "Bot no estaba corriendo."
    fi
else
    info "Bot no estaba corriendo."
fi

# ──────────────────────────────────────────────────────────────────────────────
# PASO 3: Node.js
# ──────────────────────────────────────────────────────────────────────────────
step "Paso 3: Verificando Node.js"
command -v node &>/dev/null || error "Node.js no encontrado. Ejecuta bash scripts/install.sh primero."
NODE_VER=$(node -e "process.stdout.write(process.version.slice(1).split('.')[0])")
[ "$NODE_VER" -lt 18 ] && error "Node.js 18+ requerido. Versión actual: $(node -v)"
success "Node.js $(node -v) OK"

# ──────────────────────────────────────────────────────────────────────────────
# PASO 4: Actualizar dependencias de Node.js
# ──────────────────────────────────────────────────────────────────────────────
step "Paso 4: Dependencias de Node.js"

if [ "$FORCE" = true ]; then
    info "Borrando node_modules (--force)..."
    rm -rf "$BOT_DIR/node_modules"
fi

info "Ejecutando npm install..."
if npm install; then
    success "Dependencias actualizadas."
else
    error "npm install falló. Revisa la conexión a internet o ejecuta con --force."
fi

# ──────────────────────────────────────────────────────────────────────────────
# PASO 5: Recompilar TypeScript
# ──────────────────────────────────────────────────────────────────────────────
step "Paso 5: Compilando TypeScript"
rm -rf "$BOT_DIR/dist"

BUILD_OUTPUT=$(npm run build 2>&1)
BUILD_EXIT=$?

if [ $BUILD_EXIT -eq 0 ] && [ -f "$BOT_DIR/dist/index.js" ]; then
    TS_COUNT=$(find "$BOT_DIR/dist" -name "*.js" | wc -l)
    success "TypeScript compilado ($TS_COUNT archivos)."
else
    echo "$BUILD_OUTPUT"
    error "Error de compilación TypeScript. Revisa los errores."
fi

# ──────────────────────────────────────────────────────────────────────────────
# PASO 6: Java
# ──────────────────────────────────────────────────────────────────────────────
step "Paso 6: Verificando Java"
if command -v java &>/dev/null; then
    JAVA_VER=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d. -f1)
    if [ "${JAVA_VER:-0}" -ge 17 ] 2>/dev/null; then
        success "Java $JAVA_VER OK"
    else
        warn "Java $JAVA_VER detectado. Lavalink requiere Java 17+."
        warn "Actualiza con: sudo apt install openjdk-21-jre-headless"
    fi
else
    warn "Java no encontrado. Lavalink no podrá iniciarse."
    warn "Instala con: sudo apt install openjdk-21-jre-headless"
fi

# ──────────────────────────────────────────────────────────────────────────────
# PASO 7: Lavalink.jar
# ──────────────────────────────────────────────────────────────────────────────
step "Paso 7: Lavalink.jar"
mkdir -p "$LAVALINK_DIR/logs"

if [ ! -f "$LAVALINK_JAR" ]; then
    info "Lavalink.jar no encontrado. Descargando..."
    NEED_DOWNLOAD=true
elif [ "$FORCE" = true ]; then
    info "Actualizando Lavalink.jar (--force)..."
    rm -f "$LAVALINK_JAR"
    NEED_DOWNLOAD=true
else
    JAR_SIZE=$(stat -c%s "$LAVALINK_JAR" 2>/dev/null || echo 0)
    if [ "$JAR_SIZE" -lt 1000000 ]; then
        warn "Lavalink.jar parece corrupto ($JAR_SIZE bytes). Descargando de nuevo..."
        rm -f "$LAVALINK_JAR"
        NEED_DOWNLOAD=true
    else
        success "Lavalink.jar OK ($(( JAR_SIZE / 1024 / 1024 )) MB)."
        NEED_DOWNLOAD=false
    fi
fi

if [ "$NEED_DOWNLOAD" = true ]; then
    JAR_TMP="$LAVALINK_JAR.tmp"
    rm -f "$JAR_TMP"
    DL_OK=false
    if command -v wget &>/dev/null; then
        wget -q --show-progress -O "$JAR_TMP" "$LAVALINK_URL" && DL_OK=true
    elif command -v curl &>/dev/null; then
        curl -L --progress-bar -o "$JAR_TMP" "$LAVALINK_URL" && DL_OK=true
    else
        warn "wget/curl no disponibles. Descarga Lavalink.jar manualmente:"
        warn "  https://github.com/lavalink-devs/Lavalink/releases/latest → $LAVALINK_JAR"
    fi

    if $DL_OK; then
        DSIZE=$(stat -c%s "$JAR_TMP" 2>/dev/null || echo 0)
        if [ "$DSIZE" -gt 1000000 ]; then
            mv "$JAR_TMP" "$LAVALINK_JAR"
            success "Lavalink.jar descargado ($(( DSIZE / 1024 / 1024 )) MB)."
        else
            rm -f "$JAR_TMP"
            warn "Archivo descargado parece corrupto. Revisa tu conexión."
        fi
    else
        rm -f "$JAR_TMP" 2>/dev/null
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# PASO 8: Verificar .env
# ──────────────────────────────────────────────────────────────────────────────
step "Paso 8: Configuración (.env)"
if [ ! -f "$BOT_DIR/.env" ]; then
    [ -f "$BOT_DIR/.env.example" ] && cp "$BOT_DIR/.env.example" "$BOT_DIR/.env"
    warn ".env no encontrado. Creado desde .env.example. Edita con: nano $BOT_DIR/.env"
else
    success ".env OK"
fi

# ──────────────────────────────────────────────────────────────────────────────
# PASO 9: Reiniciar si estaba corriendo
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "======================================================"
if [ "$was_running" = true ]; then
    echo -e "   ${GREEN}${BOLD}✅  Actualización completa — reiniciando bot${NC}"
    echo "======================================================"
    echo ""
    bash "$BOT_DIR/scripts/start.sh"
else
    echo -e "   ${GREEN}${BOLD}✅  Actualización completa${NC}"
    echo "======================================================"
    echo ""
    echo "   Para iniciar el bot:  bash scripts/start.sh"
    echo ""
fi
