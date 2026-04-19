# 02 - Setup App Servers (VM-1 s/d VM-4)

**Target:** VM-1 (`10.34.100.178`) hingga VM-4 (`10.34.100.181`)  
**Langkah ini diulang untuk setiap App Server.**

---

## Cara Efisien: Jalankan Script Otomatis

Salin dan jalankan script berikut di setiap App Server (ubah variabel `NODE_IP` dan `NODE_NAME`):

```bash
# Jalankan di masing-masing App Server
# Ubah sesuai VM yang sedang dikonfigurasi:
export NODE_NAME="app-server-1"   # app-server-1, app-server-2, dst
export NODE_IP="10.34.100.178"   # IP sesuai VM

curl -fsSL https://raw.githubusercontent.com/your-repo/scripts/setup-appserver.sh | bash
```

> Atau ikuti langkah manual di bawah.

---

## Langkah Manual (Per VM)

### 1. Persiapan Sistem

```bash
# Update sistem
sudo apt update && sudo apt upgrade -y

# Set hostname (ganti sesuai VM yang sedang dikonfigurasi)
sudo hostnamectl set-hostname app-server-1  # ubah angkanya

# Edit /etc/hosts
sudo tee -a /etc/hosts <<EOF

10.34.100.200  jenkins-server
10.34.100.178  app-server-1
10.34.100.179  app-server-2
10.34.100.180  app-server-3
10.34.100.181  app-server-4
EOF
```

---

### 2. Install Docker

```bash
# Install dependensi
sudo apt install -y ca-certificates curl gnupg lsb-release

# Tambahkan Docker GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Tambahkan Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start dan enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Verifikasi
docker --version
```

---

### 3. Buat User Deploy

Jenkins akan SSH menggunakan user khusus bernama `deploy` (bukan root).

```bash
# Buat user deploy
sudo useradd -m -s /bin/bash deploy

# Tambahkan ke grup docker
sudo usermod -aG docker deploy

# Buat direktori SSH
sudo mkdir -p /home/deploy/.ssh
sudo chmod 700 /home/deploy/.ssh
```

---

### 4. Daftarkan SSH Public Key Jenkins

Kopi public key yang sudah dibuat di Jenkins Server (`cat ~/.ssh/id_deploy.pub`) ke file `authorized_keys` pada setiap App Server:

```bash
# Paste isi public key Jenkins ke dalam file ini
sudo tee /home/deploy/.ssh/authorized_keys <<'EOF'
ssh-ed25519 AAAAC3Nza... jenkins-deploy
EOF
# ↑ Ganti dengan isi public key Jenkins yang sebenarnya

# Set permission yang benar
sudo chmod 600 /home/deploy/.ssh/authorized_keys
sudo chown -R deploy:deploy /home/deploy/.ssh
```

**Cara alternatif dari Jenkins Server:**
```bash
# Jalankan dari Jenkins Server (VM-0) sebagai user jenkins
sudo su - jenkins

ssh-copy-id -i ~/.ssh/id_deploy.pub deploy@10.34.100.178
ssh-copy-id -i ~/.ssh/id_deploy.pub deploy@10.34.100.179
ssh-copy-id -i ~/.ssh/id_deploy.pub deploy@10.34.100.180
ssh-copy-id -i ~/.ssh/id_deploy.pub deploy@10.34.100.181
```

---

### 5. Buat Direktori Aplikasi

```bash
# Buat direktori untuk menyimpan docker-compose file
sudo mkdir -p /opt/webapp
sudo chown deploy:deploy /opt/webapp
```

---

### 6. Konfigurasi Firewall (Opsional)

```bash
# Izinkan SSH dan port aplikasi web
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 8080/tcp
sudo ufw --force enable
```

---

### 7. Test Koneksi SSH dari Jenkins Server

Setelah semua App Server dikonfigurasi, coba koneksi dari Jenkins Server:

```bash
# Dari VM-0 (Jenkins), sebagai user jenkins
sudo su - jenkins

# Test satu per satu
ssh deploy@10.34.100.178 "echo 'VM-1 OK' && docker --version"
ssh deploy@10.34.100.179 "echo 'VM-2 OK' && docker --version"
ssh deploy@10.34.100.180 "echo 'VM-3 OK' && docker --version"
ssh deploy@10.34.100.181 "echo 'VM-4 OK' && docker --version"
```

Output yang diharapkan:
```
VM-1 OK
Docker version 24.x.x, build xxxxx
```

---

## Ringkasan Checklist Per VM

| Langkah | VM-1 | VM-2 | VM-3 | VM-4 |
|---------|------|------|------|------|
| Update sistem | ☐ | ☐ | ☐ | ☐ |
| Set hostname | ☐ | ☐ | ☐ | ☐ |
| Install Docker | ☐ | ☐ | ☐ | ☐ |
| Buat user deploy | ☐ | ☐ | ☐ | ☐ |
| Daftarkan SSH key | ☐ | ☐ | ☐ | ☐ |
| Buat /opt/webapp | ☐ | ☐ | ☐ | ☐ |
| Test SSH dari Jenkins | ☐ | ☐ | ☐ | ☐ |

---

## Troubleshooting SSH

**Permission denied:**
```bash
# Cek permission file
ls -la /home/deploy/.ssh/
# authorized_keys harus: -rw------- (600)
# .ssh/ harus: drwx------ (700)
```

**Docker: permission denied:**
```bash
# Pastikan user deploy ada di grup docker
groups deploy
# Output harus mengandung: deploy docker
```

**Lanjut ke:** [03 - Konfigurasi Jenkins](03-jenkins-configuration.md)
