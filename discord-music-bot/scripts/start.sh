#!/usr/bin/env bash
# =============================================================================
# start.sh — Inicia el Music Bot (Lavalink + Bot de Discord)
# Uso: bash scripts/start.sh
# =============================================================================

BOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAVALINK_DIR="$BOT_DIR/lavalink"
LAVALINK_JAR="$LAVALINK_DIR/Lavalink.jar"
LAVALINK_PID_FILE="$BOT_DIR/.lavalink.pid"
BOT_PID_FILE="$BOT_DIR/.bot.pid"
PROXY_PID_FILE="$BOT_DIR/.proxy.pid"
LAVALINK_LOG="$BOT_DIR/logs/lavalink.log"
BOT_LOG="$BOT_DIR/logs/bot.log"
PROXY_LOG="$BOT_DIR/logs/proxy.log"
ENV_FILE="$BOT_DIR/.env"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC}   $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

echo ""
echo "======================================================"
echo -e "   🎵  ${BOLD}Music Bot — Iniciando${NC}"
echo "======================================================"
echo ""

cd "$BOT_DIR"
mkdir -p "$BOT_DIR/logs" "$LAVALINK_DIR/logs"

# ──────────────────────────────────────────────────────────────────────────────
# 1. Verificar que no esté ya corriendo
# ──────────────────────────────────────────────────────────────────────────────
if [ -f "$BOT_PID_FILE" ]; then
    pid=$(cat "$BOT_PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
        warn "El bot ya está corriendo (PID $pid). Usa 'bash scripts/stop.sh' primero."
        exit 1
    else
        rm -f "$BOT_PID_FILE"
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# 2. Verificar .env y cargar variables de entorno
# ──────────────────────────────────────────────────────────────────────────────
[ ! -f "$ENV_FILE" ] && error ".env no encontrado. Ejecuta 'bash scripts/install.sh' primero."

TOKEN=$(grep "^DISCORD_TOKEN=" "$ENV_FILE" | cut -d= -f2-)
if [ -z "$TOKEN" ] || [ "$TOKEN" = "TU_TOKEN_AQUI" ]; then
    error "DISCORD_TOKEN no configurado en .env"
fi

# Exportar TODAS las variables del .env al entorno del shell.
# Esto es crítico para que Lavalink lea ${YOUTUBE_OAUTH_REFRESH_TOKEN}
# desde application.yml usando la sintaxis de Spring Boot.
info "Cargando variables de entorno desde .env..."
set -a  # auto-export
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a
success "Variables de entorno cargadas (YOUTUBE_OAUTH_REFRESH_TOKEN, DISCORD_TOKEN, etc.)."

# ──────────────────────────────────────────────────────────────────────────────
# 3. Verificar build compilado
# ──────────────────────────────────────────────────────────────────────────────
if [ ! -f "$BOT_DIR/dist/index.js" ]; then
    warn "Build no encontrado. Compilando TypeScript..."
    npm run build || error "Error al compilar. Revisa los errores de TypeScript."
fi

# ──────────────────────────────────────────────────────────────────────────────
# 4. Iniciar Lavalink
# ──────────────────────────────────────────────────────────────────────────────
lava_pid=""
if [ -f "$LAVALINK_PID_FILE" ]; then
    lava_pid=$(cat "$LAVALINK_PID_FILE")
    if ! kill -0 "$lava_pid" 2>/dev/null; then
        rm -f "$LAVALINK_PID_FILE"
        lava_pid=""
    fi
fi

if [ -n "$lava_pid" ]; then
    success "Lavalink ya está corriendo (PID $lava_pid)"
elif [ -f "$LAVALINK_JAR" ] && command -v java &>/dev/null; then
    info "Iniciando Lavalink..."
    cd "$LAVALINK_DIR"

    # Iniciar Lavalink con el entorno completo (incluye YOUTUBE_OAUTH_REFRESH_TOKEN)
    nohup java -Xmx512m -jar Lavalink.jar > "$LAVALINK_LOG" 2>&1 &
    echo $! > "$LAVALINK_PID_FILE"
    success "Lavalink iniciado (PID $(cat $LAVALINK_PID_FILE))"
    cd "$BOT_DIR"

    # Esperar hasta 3 minutos (la primera vez descarga el plugin de YouTube)
    MAX_WAIT=180
    info "Esperando que Lavalink esté listo (máx ${MAX_WAIT}s — la 1ra vez descarga el plugin de YouTube)..."
    LAVALINK_READY=false
    for i in $(seq 1 $MAX_WAIT); do
        sleep 1
        if grep -q "Lavalink is ready to accept connections" "$LAVALINK_LOG" 2>/dev/null; then
            LAVALINK_READY=true
            success "Lavalink listo en ${i}s."
            break
        fi
        # Detectar error crítico de Lavalink (crash al arrancar)
        if grep -qiE "APPLICATION FAILED TO START|Unable to start|BUILD FAILURE" "$LAVALINK_LOG" 2>/dev/null; then
            echo ""
            error "Lavalink falló al arrancar. Últimas líneas del log:\n$(tail -20 $LAVALINK_LOG)"
        fi
        # Mostrar progreso cada 15 segundos
        if [ $(( i % 15 )) -eq 0 ]; then
            info "Aún esperando Lavalink... (${i}s)"
            # Mostrar si está descargando el plugin
            if grep -q "Downloading" "$LAVALINK_LOG" 2>/dev/null; then
                info "  → Descargando plugin de YouTube (solo ocurre la primera vez)..."
            fi
        fi
    done

    if ! $LAVALINK_READY; then
        warn "Lavalink no respondió en ${MAX_WAIT}s."
        warn "Últimas líneas del log de Lavalink:"
        tail -10 "$LAVALINK_LOG" | while read -r line; do warn "  $line"; done
        warn "El bot iniciará de todas formas e intentará reconectarse a Lavalink."
    fi
else
    [ ! -f "$LAVALINK_JAR" ] && warn "Lavalink.jar no encontrado. Ejecuta 'bash scripts/install.sh'."
    ! command -v java &>/dev/null && warn "Java no encontrado. Instala Java 17+."
    warn "El bot iniciará sin audio."
fi

# ──────────────────────────────────────────────────────────────────────────────
# 5. Iniciar el proxy yt-dlp (YouTube audio bridge)
# ──────────────────────────────────────────────────────────────────────────────
proxy_pid=""
if [ -f "$PROXY_PID_FILE" ]; then
    proxy_pid=$(cat "$PROXY_PID_FILE")
    if ! kill -0 "$proxy_pid" 2>/dev/null; then
        rm -f "$PROXY_PID_FILE"
        proxy_pid=""
    fi
fi

if [ -n "$proxy_pid" ]; then
    success "Proxy yt-dlp ya está corriendo (PID $proxy_pid)"
else
    PROXY_SCRIPT="$BOT_DIR/scripts/ytdlp-proxy.cjs"
    if [ -f "$PROXY_SCRIPT" ] && command -v node &>/dev/null; then
        # Verificar que yt-dlp esté instalado
        if ! command -v yt-dlp &>/dev/null; then
            warn "yt-dlp no encontrado. Instalando binario..."
            _YTDLP_DEST="/usr/local/bin/yt-dlp"
            _YTDLP_URL="https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp"
            _INSTALLED=false
            if command -v wget &>/dev/null; then
                wget -q -O "$_YTDLP_DEST" "$_YTDLP_URL" && chmod a+rx "$_YTDLP_DEST" && _INSTALLED=true
            elif command -v curl &>/dev/null; then
                curl -sL -o "$_YTDLP_DEST" "$_YTDLP_URL" && chmod a+rx "$_YTDLP_DEST" && _INSTALLED=true
            fi
            if $_INSTALLED; then
                success "yt-dlp instalado en $_YTDLP_DEST."
            else
                warn "No se pudo instalar yt-dlp automáticamente."
                warn "Instala manualmente:"
                warn "  sudo wget -O /usr/local/bin/yt-dlp https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp"
                warn "  sudo chmod a+rx /usr/local/bin/yt-dlp"
            fi
        else
            success "yt-dlp $(yt-dlp --version) encontrado."
        fi

        info "Iniciando proxy yt-dlp..."
        nohup node "$PROXY_SCRIPT" >> "$PROXY_LOG" 2>&1 &
        PROXY_PID=$!
        echo $PROXY_PID > "$PROXY_PID_FILE"
        sleep 1
        if kill -0 "$PROXY_PID" 2>/dev/null; then
            success "Proxy yt-dlp iniciado (PID $PROXY_PID)"
        else
            warn "Proxy yt-dlp no pudo iniciar. YouTube puede no funcionar."
        fi
    else
        warn "Proxy yt-dlp no encontrado. YouTube puede no funcionar."
    fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# 6. Iniciar el bot de Discord
# ──────────────────────────────────────────────────────────────────────────────
info "Iniciando bot de Discord..."
nohup node "$BOT_DIR/dist/index.js" >> "$BOT_LOG" 2>&1 &
BOT_PID=$!
echo $BOT_PID > "$BOT_PID_FILE"

sleep 2
if kill -0 "$BOT_PID" 2>/dev/null; then
    success "Bot iniciado (PID $BOT_PID)"
else
    error "El bot falló al iniciar. Revisa los logs:\n  bash scripts/logs.sh"
fi

# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "======================================================"
echo -e "   ${GREEN}${BOLD}✅  Music Bot corriendo${NC}"
echo "======================================================"
echo ""
echo "   Ver logs en tiempo real:"
echo "     bash scripts/logs.sh"
echo ""
echo "   Solo errores:"
echo "     bash scripts/logs.sh error"
echo ""
echo "   Estado:   bash scripts/status.sh"
echo "   Detener:  bash scripts/stop.sh"
echo ""
