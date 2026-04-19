#!/usr/bin/env bash
# =============================================================================
# setup-appserver.sh
# Script otomatis setup App Server (VM-1 s/d VM-4)
# Jalankan sebagai: sudo bash setup-appserver.sh
#
# Environment variables (opsional):
#   NODE_NAME   - nama hostname (default: app-server-X)
#   JENKINS_PUB_KEY - isi public key Jenkins (tempel di sini atau export dulu)
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

[[ $EUID -ne 0 ]] && error "Jalankan script ini dengan sudo atau sebagai root"

# ── Tentukan nama node ───────────────────────────────────────────────────────
NODE_NAME=${NODE_NAME:-"app-server-$(hostname -I | awk '{print $1}' | cut -d. -f4)"}
info "=== Setup App Server: $NODE_NAME ==="

# ── 1. Update sistem ──────────────────────────────────────────────────────────
info "Update sistem..."
apt update && apt upgrade -y
apt install -y curl wget gnupg lsb-release ca-certificates

# ── 2. Set hostname ──────────────────────────────────────────────────────────
info "Set hostname ke '$NODE_NAME'..."
hostnamectl set-hostname "$NODE_NAME"

# ── 3. Tambahkan /etc/hosts ──────────────────────────────────────────────────
info "Mengkonfigurasi /etc/hosts..."
if ! grep -q "jenkins-server" /etc/hosts; then
    cat >> /etc/hosts <<EOF

# CI/CD Lab Nodes
10.34.100.200  jenkins-server
10.34.100.178  app-server-1
10.34.100.179  app-server-2
10.34.100.180  app-server-3
10.34.100.181  app-server-4
EOF
fi

# ── 4. Install Docker ────────────────────────────────────────────────────────
info "Install Docker..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl start docker
systemctl enable docker
docker --version

# ── 5. Buat user deploy ──────────────────────────────────────────────────────
info "Membuat user 'deploy'..."
if ! id deploy &>/dev/null; then
    useradd -m -s /bin/bash deploy
    info "User deploy dibuat"
else
    warn "User deploy sudah ada, dilewati."
fi

usermod -aG docker deploy

# ── 6. Setup SSH authorized_keys ─────────────────────────────────────────────
SSH_DIR="/home/deploy/.ssh"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

AUTH_KEYS="$SSH_DIR/authorized_keys"
touch "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"
chown -R deploy:deploy "$SSH_DIR"

# Jika JENKINS_PUB_KEY diexport sebelum menjalankan script
if [[ -n "${JENKINS_PUB_KEY:-}" ]]; then
    if ! grep -qF "$JENKINS_PUB_KEY" "$AUTH_KEYS" 2>/dev/null; then
        echo "$JENKINS_PUB_KEY" >> "$AUTH_KEYS"
        info "Jenkins public key ditambahkan ke authorized_keys"
    else
        warn "Jenkins public key sudah ada."
    fi
else
    warn "JENKINS_PUB_KEY tidak di-set."
    warn "Tambahkan manual: echo 'PUBLIC_KEY' >> /home/deploy/.ssh/authorized_keys"
fi

# ── 7. Buat direktori aplikasi ───────────────────────────────────────────────
info "Membuat direktori /opt/webapp..."
mkdir -p /opt/webapp
chown deploy:deploy /opt/webapp

# ── 8. Konfigurasi firewall ──────────────────────────────────────────────────
info "Konfigurasi firewall..."
apt install -y ufw
ufw allow 22/tcp  comment "SSH"
ufw allow 80/tcp  comment "HTTP App"
ufw --force enable
ufw status

# ── 9. Verifikasi ────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ Setup App Server Selesai: $NODE_NAME                  ${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  Docker: $(docker --version)                             ${NC}"
echo -e "${GREEN}║  User deploy: $(groups deploy)                           ${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
echo -e "${YELLOW}  Langkah berikutnya:                                     ${NC}"
echo -e "${YELLOW}  Dari Jenkins Server, jalankan:                          ${NC}"
echo -e "${YELLOW}  ssh-copy-id -i ~/.ssh/id_deploy.pub deploy@$(hostname -I | awk '{print $1}')  ${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
