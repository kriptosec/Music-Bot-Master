#!/usr/bin/env bash
# =============================================================================
# install.sh — Instala el Music Bot (TypeScript + Lavalink)
# Detecta qué está instalado, instala lo que falta, verifica todo al final.
# Uso: bash scripts/install.sh
# =============================================================================

BOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAVALINK_DIR="$BOT_DIR/lavalink"
LAVALINK_JAR="$LAVALINK_DIR/Lavalink.jar"
LAVALINK_JAR_TMP="$LAVALINK_JAR.tmp"
LAVALINK_URL="https://github.com/lavalink-devs/Lavalink/releases/latest/download/Lavalink.jar"
NODE_MIN_MAJOR=18

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

# Registro de resultados para el resumen final
ISSUES=()
add_issue() { ISSUES+=("$1"); }

echo ""
echo "======================================================"
echo -e "   🎵  ${BOLD}Music Bot — Instalación${NC}"
echo "======================================================"

cd "$BOT_DIR"

# ──────────────────────────────────────────────────────────────────────────────
# PASO 0: Permisos de los scripts
# ──────────────────────────────────────────────────────────────────────────────
step "Paso 0: Permisos de scripts"
chmod +x "$BOT_DIR"/scripts/*.sh 2>/dev/null && success "Scripts con permisos de ejecución."

# ──────────────────────────────────────────────────────────────────────────────
# PASO 1: Verificar Node.js
# ──────────────────────────────────────────────────────────────────────────────
step "Paso 1: Node.js"
NODE_OK=false
if ! command -v node &>/dev/null; then
    error "Node.js NO encontrado."
    warn  "Instala Node.js 20 LTS con:"
    warn  "  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -"
    warn  "  sudo apt-get install -y nodejs"
    add_issue "Node.js no instalado (requerido)"
else
    NODE_MAJOR=$(node -e "process.stdout.write(process.version.slice(1).split('.')[0])")
    if [ "$NODE_MAJOR" -lt "$NODE_MIN_MAJOR" ]; then
        error "Node.js v$(node -v | tr -d 'v') es muy antiguo. Se requiere Node.js ${NODE_MIN_MAJOR}+."
        warn  "Actualiza con: curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && sudo apt-get install -y nodejs"
        add_issue "Node.js v$(node -v) es menor a v${NODE_MIN_MAJOR}"
    else
        NODE_OK=true
        success "Node.js $(node -v) OK"
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# PASO 2: Verificar gestor de paquetes
# ──────────────────────────────────────────────────────────────────────────────
step "Paso 2: Gestor de paquetes"
PKG_MANAGER=""
if command -v npm &>/dev/null && $NODE_OK; then
    PKG_MANAGER="npm"
    success "npm $(npm -v) OK"
    if command -v pnpm &>/dev/null; then
        PKG_MANAGER="pnpm"
        success "pnpm $(pnpm -v) disponible (se usará pnpm)"
    fi
elif ! $NODE_OK; then
    warn "Saltando (Node.js no disponible)"
else
    error "npm no encontrado. Instala Node.js correctamente."
    add_issue "npm no encontrado"
fi

# ──────────────────────────────────────────────────────────────────────────────
# PASO 3: Instalar dependencias de Node.js
# ──────────────────────────────────────────────────────────────────────────────
step "Paso 3: Dependencias de Node.js"
DEPS_OK=false
if [ -n "$PKG_MANAGER" ]; then
    if [ "$PKG_MANAGER" = "pnpm" ]; then
        # Sin --frozen-lockfile para evitar fallo si no hay lockfile
        if pnpm install --prefer-offline 2>/dev/null || pnpm install; then
            DEPS_OK=true
            success "Dependencias instaladas con pnpm."
        else
            error "Error al instalar dependencias con pnpm."
            add_issue "Fallo al instalar dependencias de Node.js"
        fi
    else
        if npm install; then
            DEPS_OK=true
            success "Dependencias instaladas con npm."
        else
            error "Error al instalar dependencias con npm."
            add_issue "Fallo al instalar dependencias de Node.js"
        fi
    fi

    # Verificar que los módulos clave se instalaron
    if $DEPS_OK; then
        for pkg in discord.js "lavalink-client" dotenv; do
            if [ ! -d "$BOT_DIR/node_modules/${pkg}" ] && [ ! -d "$BOT_DIR/node_modules/$(echo $pkg | tr -d '@')" ]; then
                # Check more carefully for scoped packages
                if ls "$BOT_DIR/node_modules/" 2>/dev/null | grep -q "^discord.js\|^lavalink\|^dotenv"; then
                    true
                fi
            fi
        done
        if [ -d "$BOT_DIR/node_modules/discord.js" ] && [ -d "$BOT_DIR/node_modules/lavalink-client" ]; then
            success "Módulos principales verificados: discord.js ✓ lavalink-client ✓"
        else
            warn "No se pudieron verificar los módulos. Puede haber un problema de instalación."
            add_issue "Módulos de Node.js posiblemente incompletos"
        fi
    fi
else
    warn "Saltando (no hay gestor de paquetes disponible)"
    add_issue "Dependencias de Node.js no instaladas"
fi

# ──────────────────────────────────────────────────────────────────────────────
# PASO 4: Compilar TypeScript
# ──────────────────────────────────────────────────────────────────────────────
step "Paso 4: Compilar TypeScript"
BUILD_OK=false
if $DEPS_OK; then
    info "Ejecutando compilación..."
    BUILD_OUTPUT=""
    if [ "$PKG_MANAGER" = "pnpm" ]; then
        BUILD_OUTPUT=$(pnpm run build 2>&1) && BUILD_OK=true || BUILD_OK=false
    else
        BUILD_OUTPUT=$(npm run build 2>&1) && BUILD_OK=true || BUILD_OK=false
    fi

    if $BUILD_OK; then
        # Verificar que el archivo principal existe
        if [ -f "$BOT_DIR/dist/index.js" ]; then
            success "TypeScript compilado. Archivo principal: dist/index.js ✓"
        else
            BUILD_OK=false
            error "El build terminó pero dist/index.js no fue generado."
            echo "$BUILD_OUTPUT"
            add_issue "Compilación de TypeScript incompleta"
        fi
    else
        error "Error al compilar TypeScript:"
        echo "$BUILD_OUTPUT"
        add_issue "Error de compilación de TypeScript"
    fi
else
    warn "Saltando compilación (dependencias no instaladas)"
    add_issue "TypeScript no compilado"
fi

# ──────────────────────────────────────────────────────────────────────────────
# PASO 5: Verificar Java (para Lavalink)
# ──────────────────────────────────────────────────────────────────────────────
step "Paso 5: Java (para Lavalink)"
JAVA_OK=false
if command -v java &>/dev/null; then
    JAVA_VER=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d. -f1)
    if [ "${JAVA_VER:-0}" -ge 17 ] 2>/dev/null; then
        JAVA_OK=true
        success "Java $JAVA_VER OK"
    else
        error "Java $JAVA_VER encontrado. Lavalink requiere Java 17+."
        warn  "Instala con: sudo apt install openjdk-17-jre"
        add_issue "Java $JAVA_VER es menor a 17 (requerido para Lavalink)"
    fi
else
    error "Java NO encontrado. Lavalink no podrá iniciarse."
    warn  "Instala con: sudo apt install openjdk-17-jre"
    add_issue "Java 17+ no instalado (requerido para Lavalink)"
fi

# ──────────────────────────────────────────────────────────────────────────────
# PASO 6: Descargar Lavalink.jar
# ──────────────────────────────────────────────────────────────────────────────
step "Paso 6: Lavalink.jar"
mkdir -p "$LAVALINK_DIR/logs"

if [ -f "$LAVALINK_JAR" ]; then
    JAR_SIZE=$(stat -c%s "$LAVALINK_JAR" 2>/dev/null || echo 0)
    if [ "$JAR_SIZE" -gt 1000000 ]; then
        success "Lavalink.jar ya existe ($(( JAR_SIZE / 1024 / 1024 )) MB)."
    else
        warn "Lavalink.jar existe pero parece corrupto o incompleto ($JAR_SIZE bytes). Volviendo a descargar..."
        rm -f "$LAVALINK_JAR"
    fi
fi

if [ ! -f "$LAVALINK_JAR" ]; then
    DOWNLOAD_OK=false
    # Limpiar posible archivo temporal anterior
    rm -f "$LAVALINK_JAR_TMP"

    if command -v wget &>/dev/null; then
        info "Descargando Lavalink.jar con wget..."
        wget -q --show-progress -O "$LAVALINK_JAR_TMP" "$LAVALINK_URL" && DOWNLOAD_OK=true
    elif command -v curl &>/dev/null; then
        info "Descargando Lavalink.jar con curl..."
        curl -L --progress-bar -o "$LAVALINK_JAR_TMP" "$LAVALINK_URL" && DOWNLOAD_OK=true
    else
        error "wget y curl no están disponibles. No se puede descargar Lavalink.jar."
        warn  "Instala wget: sudo apt install wget"
        warn  "Luego descarga manualmente y guarda en: $LAVALINK_JAR"
        add_issue "wget/curl no disponibles — Lavalink.jar no descargado"
    fi

    if $DOWNLOAD_OK; then
        # Verificar que el archivo descargado no está vacío/corrupto
        DOWNLOADED_SIZE=$(stat -c%s "$LAVALINK_JAR_TMP" 2>/dev/null || echo 0)
        if [ "$DOWNLOADED_SIZE" -gt 1000000 ]; then
            mv "$LAVALINK_JAR_TMP" "$LAVALINK_JAR"
            success "Lavalink.jar descargado correctamente ($(( DOWNLOADED_SIZE / 1024 / 1024 )) MB)."
        else
            rm -f "$LAVALINK_JAR_TMP"
            error "Lavalink.jar descargado parece corrupto ($DOWNLOADED_SIZE bytes). Revisa la conexión a internet."
            add_issue "Lavalink.jar descargado pero corrupto"
        fi
    elif [ -z "$(command -v wget 2>/dev/null)$(command -v curl 2>/dev/null)" ]; then
        : # ya se informó el error
    else
        rm -f "$LAVALINK_JAR_TMP"
        error "Descarga de Lavalink.jar falló."
        warn  "Descarga manualmente desde: https://github.com/lavalink-devs/Lavalink/releases/latest"
        warn  "Guarda el archivo en: $LAVALINK_JAR"
        add_issue "No se pudo descargar Lavalink.jar"
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# PASO 7: Verificar y crear directorios necesarios
# ──────────────────────────────────────────────────────────────────────────────
step "Paso 7: Directorios del sistema"
mkdir -p "$BOT_DIR/logs"
mkdir -p "$LAVALINK_DIR/logs"
success "Directorios logs/ y lavalink/logs/ creados."

# ──────────────────────────────────────────────────────────────────────────────
# PASO 8: Verificar .env y token
# ──────────────────────────────────────────────────────────────────────────────
step "Paso 8: Configuración (.env)"
ENV_OK=false
if [ ! -f "$BOT_DIR/.env" ]; then
    if [ -f "$BOT_DIR/.env.example" ]; then
        cp "$BOT_DIR/.env.example" "$BOT_DIR/.env"
        warn ".env no encontrado. Creado desde .env.example."
        warn "Edita el archivo .env y reemplaza TU_TOKEN_AQUI con tu token real de Discord."
        add_issue ".env requiere configuración manual del DISCORD_TOKEN"
    else
        error ".env y .env.example no encontrados."
        add_issue ".env no existe — no se puede iniciar el bot"
    fi
else
    TOKEN=$(grep "^DISCORD_TOKEN=" "$BOT_DIR/.env" 2>/dev/null | cut -d= -f2- | tr -d '[:space:]')
    if [ -z "$TOKEN" ]; then
        error "DISCORD_TOKEN está vacío en .env"
        add_issue "DISCORD_TOKEN vacío en .env"
    elif [ "$TOKEN" = "TU_TOKEN_AQUI" ]; then
        error "DISCORD_TOKEN todavía tiene el valor por defecto en .env"
        warn  "Edita .env y reemplaza TU_TOKEN_AQUI con tu token real."
        add_issue "DISCORD_TOKEN no configurado en .env (aún tiene el valor ejemplo)"
    else
        ENV_OK=true
        success ".env encontrado y DISCORD_TOKEN configurado."
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
    local label="$1"
    local ok="$2"
    local detail="${3:-}"
    if [ "$ok" = "true" ]; then
        echo -e "  ${GREEN}✓${NC} $label${detail:+  ($detail)}"
    else
        echo -e "  ${RED}✗${NC} $label${detail:+  → $detail}"
    fi
}

check_item "Node.js"          "$NODE_OK"  "$(node -v 2>/dev/null || echo 'no encontrado')"
check_item "Dependencias npm" "$DEPS_OK"
check_item "Build TypeScript" "$BUILD_OK" "dist/index.js"
check_item "Java 17+"         "$JAVA_OK"  "$(java -version 2>&1 | head -1 | awk -F '"' '{print $2}' || echo 'no encontrado')"
check_item "Lavalink.jar"     "$([ -f "$LAVALINK_JAR" ] && echo true || echo false)"
check_item "Directorios logs" "true"
check_item ".env configurado" "$ENV_OK"

echo ""

if [ ${#ISSUES[@]} -eq 0 ]; then
    echo -e "   ${GREEN}${BOLD}✅  Instalación completa. Todo OK.${NC}"
    echo ""
    echo "Para iniciar el bot:"
    echo "  bash scripts/start.sh"
    echo ""
    echo "Para ver el estado:"
    echo "  bash scripts/status.sh"
else
    echo -e "   ${YELLOW}${BOLD}⚠️  Instalación con problemas. Revisa los puntos marcados:${NC}"
    echo ""
    for issue in "${ISSUES[@]}"; do
        echo -e "   ${RED}•${NC} $issue"
    done
    echo ""
    echo "Corrige los problemas y vuelve a ejecutar:"
    echo "  bash scripts/install.sh"
fi

echo "======================================================"
echo ""
