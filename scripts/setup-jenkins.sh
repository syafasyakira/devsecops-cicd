#!/usr/bin/env bash
# =============================================================================
# setup-jenkins.sh
# Script otomatis untuk setup Jenkins Server (VM-0)
# Jalankan sebagai: sudo bash setup-jenkins.sh
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Pastikan dijalankan sebagai root
[[ $EUID -ne 0 ]] && error "Jalankan script ini dengan sudo atau sebagai root"

info "=== Setup Jenkins Server dimulai ==="

# ── 1. Update sistem ──────────────────────────────────────────────────────────
info "Update sistem..."
apt update && apt upgrade -y
apt install -y curl wget gnupg lsb-release ca-certificates git

# ── 2. Set hostname ──────────────────────────────────────────────────────────
info "Set hostname ke 'jenkins-server'..."
hostnamectl set-hostname jenkins-server

# ── 3. Tambahkan /etc/hosts ──────────────────────────────────────────────────
info "Mengkonfigurasi /etc/hosts..."
if ! grep -q "app-server-1" /etc/hosts; then
    cat >> /etc/hosts <<EOF

# CI/CD Lab Nodes
10.34.100.200  jenkins-server
10.34.100.178  app-server-1
10.34.100.179  app-server-2
10.34.100.180  app-server-3
10.34.100.181  app-server-4
EOF
fi

# ── 4. Install Java 17 ───────────────────────────────────────────────────────
info "Install OpenJDK 17..."
apt install -y fontconfig openjdk-17-jre
java -version

# ── 5. Install Jenkins ───────────────────────────────────────────────────────
info "Install Jenkins..."
wget -O /usr/share/keyrings/jenkins-keyring.asc \
    https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key

echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
    https://pkg.jenkins.io/debian-stable binary/" \
    > /etc/apt/sources.list.d/jenkins.list

apt update
apt install -y jenkins
systemctl start jenkins
systemctl enable jenkins

# ── 6. Install Docker ────────────────────────────────────────────────────────
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

# Tambahkan user jenkins ke grup docker
usermod -aG docker jenkins
info "User jenkins ditambahkan ke grup docker"

# ── 7. Buat SSH key untuk deploy ─────────────────────────────────────────────
info "Membuat SSH deploy key untuk user jenkins..."
JENKINS_HOME="/var/lib/jenkins"
SSH_DIR="$JENKINS_HOME/.ssh"

mkdir -p "$SSH_DIR"
if [[ ! -f "$SSH_DIR/id_deploy" ]]; then
    sudo -u jenkins ssh-keygen -t ed25519 -C "jenkins-deploy" \
        -f "$SSH_DIR/id_deploy" -N ""
    info "SSH key dibuat di $SSH_DIR/id_deploy"
else
    warn "SSH key sudah ada, dilewati."
fi

# Konfigurasi SSH client
cat > "$SSH_DIR/config" <<EOF
Host app-server-*
    StrictHostKeyChecking no
    IdentityFile ~/.ssh/id_deploy
    User deploy
EOF
chmod 600 "$SSH_DIR/config"
chown jenkins:jenkins "$SSH_DIR/config"

# ── 8. Restart Jenkins ───────────────────────────────────────────────────────
info "Restart Jenkins..."
systemctl restart jenkins
sleep 5

# ── 9. Tampilkan info penting ────────────────────────────────────────────────
INIT_PASSWORD=$(cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo "Belum tersedia")
PUBLIC_KEY=$(cat "$SSH_DIR/id_deploy.pub" 2>/dev/null || echo "Tidak ditemukan")

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ Setup Jenkins Server Selesai!                         ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  URL Jenkins: http://$(hostname -I | awk '{print $1}'):8080                ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  Initial Admin Password:                                 ║${NC}"
echo -e "${YELLOW}  $INIT_PASSWORD${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  Deploy Public Key (SALIN ke tiap App Server):           ║${NC}"
echo -e "${YELLOW}  $PUBLIC_KEY${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
info "Salin public key di atas ke /home/deploy/.ssh/authorized_keys pada tiap App Server"
