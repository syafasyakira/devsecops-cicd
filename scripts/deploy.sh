#!/usr/bin/env bash
# =============================================================================
# deploy.sh
# Script deploy manual — digunakan oleh Jenkins pipeline atau untuk rollback
#
# Usage:
#   ./deploy.sh <docker_image> <tag> [app_port] [container_name]
#
# Contoh:
#   ./deploy.sh your-dockerhub/webapp-cicd 42 80 webapp
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ── Parse argumen ─────────────────────────────────────────────────────────────
DOCKER_IMAGE="${1:-}"
DOCKER_TAG="${2:-latest}"
APP_PORT="${3:-80}"
CONTAINER_PORT="${4:-5000}"
CONTAINER_NAME="${5:-webapp}"

# Variabel dari environment (bisa di-override)
APP_SERVERS="${APP_SERVERS:-10.34.100.178 10.34.100.179 10.34.100.180 10.34.100.181}"
SSH_USER="${SSH_USER:-deploy}"
SSH_KEY="${SSH_KEY:-/var/lib/jenkins/.ssh/id_deploy}"

[[ -z "$DOCKER_IMAGE" ]] && error "Usage: $0 <docker_image> [tag] [app_port] [container_port] [container_name]"

FULL_IMAGE="${DOCKER_IMAGE}:${DOCKER_TAG}"

info "=== Deploy dimulai ==="
info "Image     : $FULL_IMAGE"
info "Port      : $APP_PORT → $CONTAINER_PORT"
info "Container : $CONTAINER_NAME"
info "Servers   : $APP_SERVERS"
echo ""

# ── Deploy ke setiap server ──────────────────────────────────────────────────
FAILED_SERVERS=()

for SERVER in $APP_SERVERS; do
    info "── Deploy ke $SERVER ──"

    if ssh -i "$SSH_KEY" \
           -o StrictHostKeyChecking=no \
           -o ConnectTimeout=10 \
           "${SSH_USER}@${SERVER}" \
           "
            set -e
            echo '[remote] Pull image: $FULL_IMAGE'
            docker pull $FULL_IMAGE

            echo '[remote] Stop container lama...'
            docker stop $CONTAINER_NAME 2>/dev/null || true
            docker rm   $CONTAINER_NAME 2>/dev/null || true

            echo '[remote] Run container baru...'
            docker run -d \
                --name $CONTAINER_NAME \
                --restart unless-stopped \
                -p $APP_PORT:$CONTAINER_PORT \
                -e APP_VERSION=$DOCKER_TAG \
                $FULL_IMAGE

            echo '[remote] Status container:'
            docker ps --filter name=$CONTAINER_NAME --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
           "; then
        echo -e "${GREEN}✓ $SERVER — Deploy berhasil${NC}"
    else
        echo -e "${RED}✗ $SERVER — Deploy GAGAL${NC}"
        FAILED_SERVERS+=("$SERVER")
    fi
    echo ""
done

# ── Health Check ─────────────────────────────────────────────────────────────
info "Menunggu 10 detik untuk container startup..."
sleep 10

info "=== Health Check ==="
UNHEALTHY=()

for SERVER in $APP_SERVERS; do
    # Lewati server yang memang gagal deploy
    if [[ " ${FAILED_SERVERS[*]:-} " =~ " $SERVER " ]]; then
        UNHEALTHY+=("$SERVER")
        continue
    fi

    HTTP_CODE=$(ssh -i "$SSH_KEY" \
                    -o StrictHostKeyChecking=no \
                    -o ConnectTimeout=10 \
                    "${SSH_USER}@${SERVER}" \
                    "curl -s -o /dev/null -w '%{http_code}' http://localhost:${APP_PORT}/health" 2>/dev/null || echo "000")

    if [[ "$HTTP_CODE" == "200" ]]; then
        echo -e "${GREEN}✓ $SERVER — HTTP $HTTP_CODE (sehat)${NC}"
    else
        echo -e "${RED}✗ $SERVER — HTTP $HTTP_CODE (tidak sehat)${NC}"
        UNHEALTHY+=("$SERVER")
    fi
done

# ── Ringkasan ───────────────────────────────────────────────────────────────
echo ""
TOTAL=$(echo "$APP_SERVERS" | wc -w)
FAIL_COUNT=${#UNHEALTHY[@]}
SUCCESS_COUNT=$(( TOTAL - FAIL_COUNT ))

echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Deploy Selesai                      ║${NC}"
echo -e "${GREEN}║  Berhasil : $SUCCESS_COUNT / $TOTAL server(s)         ║${NC}"

if [[ $FAIL_COUNT -gt 0 ]]; then
    echo -e "${RED}║  Gagal    : ${UNHEALTHY[*]}  ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
    exit 1
else
    echo -e "${GREEN}║  Semua server berjalan normal        ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
fi
