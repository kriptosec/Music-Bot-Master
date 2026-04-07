#!/usr/bin/env bash
# =============================================================================
# install.sh — Instala el Music Bot en Ubuntu/Debian
# Auto-instala Node.js, Java y wget si faltan. Verifica todo y muestra resumen.
# Uso: bash scripts/install.sh
# =============================================================================

BOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAVALINK_DIR="$BOT_DIR/lavalink"
LAVALINK_JAR="$LAVALINK_DIR/Lavalink.jar"
LAVALINK_JAR_TMP="$LAVALINK_JAR.tmp"
LAVALINK_URL="https://github.com/lavalink-devs/Lavalink/releases/latest/download/Lavalink.jar"
NODE_MIN_MAJOR=18
NODE_INSTALL_MAJOR=20  # versión LTS a instalar si no hay una válida

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $1"; }
success() { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }
step()    { echo -e "\n${BOLD}── $1${NC}"; }

ISSUES=()
add_issue() { ISSUES+=("$1"); }

echo ""
echo "======================================================"
echo -e "   🎵  ${BOLD}Music Bot — Instalación (Ubuntu)${NC}"
echo "======================================================"

cd "$BOT_DIR"

# ──────────────────────────────────────────────────────────────────────────────
# HELPER: Verificar si tenemos sudo
# ──────────────────────────────────────────────────────────────────────────────
APT_AVAILABLE=false
SUDO_CMD=""
if command -v apt-get &>/dev/null; then
    APT_AVAILABLE=true
    if [ "$EUID" -eq 0 ]; then
        SUDO_CMD=""           # ya somos root
    elif command -v sudo &>/dev/null && sudo -n true 2>/dev/null; then
        SUDO_CMD="sudo"       # sudo sin contraseña disponible
    elif command -v sudo &>/dev/null; then
        SUDO_CMD="sudo"       # sudo disponible (puede pedir contraseña)
    fi
fi

apt_install() {
    # Instala paquetes con apt. Uso: apt_install "openjdk-21-jre-headless" "Java 21"
    local pkg="$1"
    local label="${2:-$1}"
    if ! $APT_AVAILABLE; then
        error "apt no disponible — no se puede instalar $label automáticamente."
        return 1
    fi
    info "Instalando $label con apt..."
    $SUDO_CMD apt-get install -y "$pkg" -qq 2>&1 | tail -3
    return ${PIPESTATUS[0]}
}

# Actualizar índice apt una sola vez (silencioso)
APT_UPDATED=false
apt_update_once() {
    if ! $APT_UPDATED && $APT_AVAILABLE; then
        info "Actualizando índice de paquetes apt..."
        $SUDO_CMD apt-get update -qq 2>/dev/null && APT_UPDATED=true
    fi
}

# ──────────────────────────────────────────────────────────────────────────────
# PASO 0: Permisos de scripts
# ──────────────────────────────────────────────────────────────────────────────
step "Paso 0: Permisos de scripts"
chmod +x "$BOT_DIR"/scripts/*.sh 2>/dev/null
success "Scripts con permisos de ejecución."

# ──────────────────────────────────────────────────────────────────────────────
# PASO 1: Node.js
# ──────────────────────────────────────────────────────────────────────────────
step "Paso 1: Node.js"
NODE_OK=false

install_nodejs() {
    info "Instalando Node.js $NODE_INSTALL_MAJOR LTS desde NodeSource..."
    apt_update_once
    # Instalar curl si no está (lo necesitamos para el script de NodeSource)
    command -v curl &>/dev/null || apt_install "curl" "curl"
    if curl -fsSL "https://deb.nodesource.com/setup_${NODE_INSTALL_MAJOR}.x" | $SUDO_CMD bash - 2>/dev/null; then
        if $SUDO_CMD apt-get install -y nodejs -qq 2>&1 | tail -2; then
            return 0
        fi
    fi
    return 1
}

if ! command -v node &>/dev/null; then
    error "Node.js NO encontrado."
    if $APT_AVAILABLE; then
        if install_nodejs; then
            success "Node.js $(node -v) instalado correctamente."
            NODE_OK=true
        else
            error "No se pudo instalar Node.js automáticamente."
            add_issue "Node.js no instalado — instala manualmente: https://nodejs.org"
        fi
    else
        error "apt no disponible. Instala Node.js 20 LTS manualmente."
        add_issue "Node.js no instalado (requerido)"
    fi
else
    NODE_MAJOR=$(node -e "process.stdout.write(process.version.slice(1).split('.')[0])")
    if [ "$NODE_MAJOR" -lt "$NODE_MIN_MAJOR" ]; then
        warn "Node.js $(node -v) es muy antiguo (mínimo v${NODE_MIN_MAJOR}). Actualizando..."
        if $APT_AVAILABLE && install_nodejs; then
            success "Node.js actualizado a $(node -v)."
            NODE_OK=true
        else
            error "No se pudo actualizar Node.js automáticamente."
            warn  "Actualiza con: curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash - && sudo apt install nodejs"
            add_issue "Node.js $(node -v) es menor a v${NODE_MIN_MAJOR}"
        fi
    else
        NODE_OK=true
        success "Node.js $(node -v) OK"
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# PASO 2: Gestor de paquetes (npm viene con Node.js)
# ──────────────────────────────────────────────────────────────────────────────
step "Paso 2: Gestor de paquetes"
PKG_MANAGER=""
if $NODE_OK; then
    if command -v npm &>/dev/null; then
        PKG_MANAGER="npm"
        success "npm $(npm -v) OK"
    else
        error "npm no encontrado (debería venir con Node.js). Reinstala Node.js."
        add_issue "npm no encontrado"
    fi
else
    warn "Saltando (Node.js no disponible)"
fi

# ──────────────────────────────────────────────────────────────────────────────
# PASO 3: Dependencias de Node.js (discord.js, lavalink-client, dotenv)
# ──────────────────────────────────────────────────────────────────────────────
step "Paso 3: Dependencias de Node.js"
DEPS_OK=false
if [ -n "$PKG_MANAGER" ]; then
    info "Ejecutando npm install..."
    if npm install 2>&1; then
        DEPS_OK=true
    else
        error "npm install falló."
        add_issue "Fallo al instalar dependencias de Node.js"
    fi

    if $DEPS_OK; then
        if [ -d "$BOT_DIR/node_modules/discord.js" ] && [ -d "$BOT_DIR/node_modules/lavalink-client" ]; then
            success "Módulos verificados: discord.js ✓  lavalink-client ✓  dotenv ✓"
        else
            warn "Módulos instalados pero no se pudo verificar algunos directorios."
            add_issue "Verificación de módulos incompleta — ejecuta 'npm install' manualmente"
        fi
    fi
else
    warn "Saltando (npm no disponible)"
    add_issue "Dependencias de Node.js no instaladas"
fi

# ──────────────────────────────────────────────────────────────────────────────
# PASO 4: Compilar TypeScript → dist/
# ──────────────────────────────────────────────────────────────────────────────
step "Paso 4: Compilar TypeScript"
BUILD_OK=false
if $DEPS_OK; then
    info "Compilando src/ → dist/ ..."
    BUILD_OUTPUT=$(npm run build 2>&1)
    BUILD_EXIT=$?

    if [ $BUILD_EXIT -eq 0 ] && [ -f "$BOT_DIR/dist/index.js" ]; then
        TS_COUNT=$(find "$BOT_DIR/dist" -name "*.js" | wc -l)
        success "TypeScript compilado correctamente ($TS_COUNT archivos JS generados)."
        BUILD_OK=true
    else
        error "Error al compilar TypeScript:"
        echo "$BUILD_OUTPUT" | head -20
        add_issue "Compilación de TypeScript falló — revisa los errores"
    fi
else
    warn "Saltando compilación (dependencias no instaladas)"
    add_issue "TypeScript no compilado"
fi

# ──────────────────────────────────────────────────────────────────────────────
# PASO 5: Java 17+ (para Lavalink)
# ──────────────────────────────────────────────────────────────────────────────
step "Paso 5: Java 17+ (para Lavalink)"
JAVA_OK=false

check_java_version() {
    if command -v java &>/dev/null; then
        java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d. -f1
    fi
}

install_java() {
    apt_update_once
    # Intentar Java 21 primero (LTS más reciente), luego Java 17
    for pkg in "openjdk-21-jre-headless" "openjdk-17-jre-headless" "openjdk-17-jre"; do
        info "Intentando instalar $pkg..."
        if $SUDO_CMD apt-get install -y "$pkg" -qq 2>/dev/null; then
            return 0
        fi
    done
    return 1
}

JAVA_VER=$(check_java_version)
if [ -n "$JAVA_VER" ] && [ "$JAVA_VER" -ge 17 ] 2>/dev/null; then
    JAVA_OK=true
    success "Java $JAVA_VER OK"
elif [ -n "$JAVA_VER" ]; then
    warn "Java $JAVA_VER encontrado pero se requiere Java 17+. Instalando nueva versión..."
    if $APT_AVAILABLE && install_java; then
        NEW_VER=$(check_java_version)
        success "Java actualizado a versión $NEW_VER."
        JAVA_OK=true
    else
        error "No se pudo actualizar Java automáticamente."
        warn  "Instala manualmente: sudo apt install openjdk-21-jre-headless"
        add_issue "Java $JAVA_VER es menor a 17 — actualiza con: sudo apt install openjdk-21-jre-headless"
    fi
else
    warn "Java no encontrado. Instalando automáticamente..."
    if $APT_AVAILABLE && install_java; then
        NEW_VER=$(check_java_version)
        success "Java $NEW_VER instalado correctamente."
        JAVA_OK=true
    else
        error "No se pudo instalar Java automáticamente."
        warn  "Instala manualmente: sudo apt install openjdk-21-jre-headless"
        add_issue "Java no instalado — requerido para Lavalink"
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# PASO 6: wget/curl (para descargar Lavalink.jar)
# ──────────────────────────────────────────────────────────────────────────────
step "Paso 6: Herramienta de descarga (wget/curl)"
if command -v wget &>/dev/null; then
    success "wget $(wget -V 2>&1 | head -1 | awk '{print $3}') disponible"
elif command -v curl &>/dev/null; then
    success "curl $(curl -V 2>&1 | head -1 | awk '{print $2}') disponible"
else
    warn "wget y curl no encontrados. Instalando wget..."
    if $APT_AVAILABLE; then
        apt_update_once
        if apt_install "wget" "wget"; then
            success "wget instalado."
        else
            error "No se pudo instalar wget."
            add_issue "wget/curl no disponibles — descarga de Lavalink.jar puede fallar"
        fi
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# PASO 7: Descargar Lavalink.jar
# ──────────────────────────────────────────────────────────────────────────────
step "Paso 7: Lavalink.jar"
mkdir -p "$LAVALINK_DIR/logs"

# Verificar si el jar ya existe y es válido
if [ -f "$LAVALINK_JAR" ]; then
    JAR_SIZE=$(stat -c%s "$LAVALINK_JAR" 2>/dev/null || echo 0)
    if [ "$JAR_SIZE" -gt 1000000 ]; then
        success "Lavalink.jar ya existe y parece válido ($(( JAR_SIZE / 1024 / 1024 )) MB)."
    else
        warn "Lavalink.jar existe pero parece corrupto ($JAR_SIZE bytes). Descargando de nuevo..."
        rm -f "$LAVALINK_JAR"
    fi
fi

if [ ! -f "$LAVALINK_JAR" ]; then
    DOWNLOAD_OK=false
    rm -f "$LAVALINK_JAR_TMP"

    if command -v wget &>/dev/null; then
        info "Descargando Lavalink.jar con wget..."
        wget -q --show-progress -O "$LAVALINK_JAR_TMP" "$LAVALINK_URL" && DOWNLOAD_OK=true || DOWNLOAD_OK=false
    elif command -v curl &>/dev/null; then
        info "Descargando Lavalink.jar con curl..."
        curl -L --progress-bar -o "$LAVALINK_JAR_TMP" "$LAVALINK_URL" && DOWNLOAD_OK=true || DOWNLOAD_OK=false
    else
        DOWNLOAD_OK=false
        error "Sin herramienta de descarga disponible."
        add_issue "No se pudo descargar Lavalink.jar (falta wget/curl)"
    fi

    if $DOWNLOAD_OK; then
        DSIZE=$(stat -c%s "$LAVALINK_JAR_TMP" 2>/dev/null || echo 0)
        if [ "$DSIZE" -gt 1000000 ]; then
            mv "$LAVALINK_JAR_TMP" "$LAVALINK_JAR"
            success "Lavalink.jar descargado correctamente ($(( DSIZE / 1024 / 1024 )) MB)."
        else
            rm -f "$LAVALINK_JAR_TMP"
            error "Archivo descargado demasiado pequeño ($DSIZE bytes) — posible error de red."
            add_issue "Lavalink.jar descargado parece corrupto — revisa la conexión"
        fi
    else
        rm -f "$LAVALINK_JAR_TMP"
        if command -v wget &>/dev/null || command -v curl &>/dev/null; then
            error "Descarga de Lavalink.jar falló."
            warn  "Descarga manual: https://github.com/lavalink-devs/Lavalink/releases/latest"
            warn  "Guárdalo en: $LAVALINK_JAR"
            add_issue "Descarga de Lavalink.jar falló — descarga manualmente"
        fi
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# PASO 8: Crear directorios necesarios
# ──────────────────────────────────────────────────────────────────────────────
step "Paso 8: Directorios del sistema"
mkdir -p "$BOT_DIR/logs"
mkdir -p "$LAVALINK_DIR/logs"
success "logs/ y lavalink/logs/ listos."

# ──────────────────────────────────────────────────────────────────────────────
# PASO 9: Configuración .env
# ──────────────────────────────────────────────────────────────────────────────
step "Paso 9: Configuración (.env)"
ENV_OK=false

if [ ! -f "$BOT_DIR/.env" ]; then
    if [ -f "$BOT_DIR/.env.example" ]; then
        cp "$BOT_DIR/.env.example" "$BOT_DIR/.env"
        warn ".env no encontrado → creado desde .env.example."
        warn "Edita .env con: nano $BOT_DIR/.env"
        warn "Reemplaza TU_TOKEN_AQUI con tu token de Discord."
        add_issue ".env creado pero necesita configuración del DISCORD_TOKEN"
    else
        error ".env y .env.example no existen."
        add_issue ".env no existe — el bot no puede iniciar sin él"
    fi
else
    TOKEN=$(grep "^DISCORD_TOKEN=" "$BOT_DIR/.env" 2>/dev/null | cut -d= -f2- | tr -d '[:space:]')
    if [ -z "$TOKEN" ]; then
        error "DISCORD_TOKEN está vacío en .env"
        warn  "Edita: nano $BOT_DIR/.env"
        add_issue "DISCORD_TOKEN vacío en .env"
    elif [ "$TOKEN" = "TU_TOKEN_AQUI" ]; then
        error "DISCORD_TOKEN tiene el valor de ejemplo en .env"
        warn  "Edita: nano $BOT_DIR/.env"
        add_issue "DISCORD_TOKEN no configurado (aún dice TU_TOKEN_AQUI)"
    else
        ENV_OK=true
        success ".env OK — DISCORD_TOKEN configurado."
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# RESUMEN FINAL
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "======================================================"
echo -e "   📊  ${BOLD}Resumen de instalación${NC}"
echo "======================================================"
echo ""

check_item() {
    local label="$1" ok="$2" detail="${3:-}"
    if [ "$ok" = "true" ]; then
        echo -e "  ${GREEN}✓${NC} $label${detail:+  (${detail})}"
    else
        echo -e "  ${RED}✗${NC} $label${detail:+  → ${detail}}"
    fi
}

LAVALINK_JAR_OK=$([ -f "$LAVALINK_JAR" ] && echo true || echo false)
NODE_VER_STR=$(node -v 2>/dev/null || echo "no encontrado")
JAVA_VER_STR=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' 2>/dev/null || echo "no encontrado")

check_item "Node.js ${NODE_VER_STR}"       "$NODE_OK"
check_item "Dependencias npm"               "$DEPS_OK"       "discord.js + lavalink-client"
check_item "Build TypeScript"               "$BUILD_OK"      "dist/index.js generado"
check_item "Java ${JAVA_VER_STR}"          "$JAVA_OK"
check_item "Lavalink.jar"                   "$LAVALINK_JAR_OK"
check_item "Directorios logs/"              "true"
check_item ".env configurado"               "$ENV_OK"

echo ""

if [ ${#ISSUES[@]} -eq 0 ]; then
    echo -e "   ${GREEN}${BOLD}✅  Instalación completa — listo para iniciar.${NC}"
    echo ""
    echo -e "   ${BOLD}Iniciar:${NC}  bash scripts/start.sh"
    echo -e "   ${BOLD}Estado:${NC}   bash scripts/status.sh"
else
    echo -e "   ${YELLOW}${BOLD}⚠️  Instalación con problemas:${NC}"
    echo ""
    for issue in "${ISSUES[@]}"; do
        echo -e "   ${RED}•${NC} $issue"
    done
    echo ""
    echo "   Corrige los problemas y vuelve a ejecutar:"
    echo "   bash scripts/install.sh"
fi

echo "======================================================"
echo ""
