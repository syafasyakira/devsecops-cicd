# 01 - Setup Jenkins Server (VM-0)

**Target:** `10.34.100.200` | OS: Ubuntu 22.04 LTS

---

## 1. Persiapan Sistem

Login ke VM-0 (Jenkins Server), lalu jalankan perintah berikut:

```bash
# Update sistem
sudo apt update && sudo apt upgrade -y

# Set hostname
sudo hostnamectl set-hostname jenkins-server

# Edit /etc/hosts agar semua VM bisa berkomunikasi via nama host
sudo tee -a /etc/hosts <<EOF

10.34.100.189  jenkins-server
10.34.100.178  app-server-1
10.34.100.179  app-server-2
10.34.100.180  app-server-3
10.34.100.181  app-server-4
EOF
```

---

## 2. Install Java (OpenJDK 17)

Jenkins membutuhkan Java untuk berjalan.

```bash
sudo apt install -y fontconfig openjdk-17-jre

# Verifikasi
java -version
# Output: openjdk version "17.x.x" ...
```

---

## 3. Install Jenkins

```bash
# Tambahkan GPG key dan repository Jenkins
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key

echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian-stable binary/ | \
  sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

# Install Jenkins
sudo apt update
sudo apt install -y jenkins

# Start dan enable Jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Cek status
sudo systemctl status jenkins
```

---

## 4. Install Docker

Jenkins akan menggunakan Docker untuk build image.

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

# Tambahkan user jenkins ke grup docker
# (agar Jenkins bisa menjalankan Docker tanpa sudo)
sudo usermod -aG docker jenkins

# Start dan enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Verifikasi
docker --version
```

> **Penting:** Setelah menambahkan `jenkins` ke grup `docker`, restart Jenkins:
> ```bash
> sudo systemctl restart jenkins
> ```

---

## 5. Buat SSH Key untuk Deploy

Jenkins akan menggunakan SSH untuk deploy ke App Server. Buat key pair di bawah user `jenkins`:

```bash
# Masuk sebagai user jenkins
sudo su - jenkins

# Buat SSH key (tanpa passphrase untuk otomatisasi)
ssh-keygen -t ed25519 -C "jenkins-deploy" -f ~/.ssh/id_deploy -N ""

# Tampilkan public key (akan dikopi ke tiap App Server)
cat ~/.ssh/id_deploy.pub
```

**Salin output public key**, akan digunakan pada langkah setup App Server.

```bash
# Konfigurasi SSH agar tidak prompt "known_hosts" saat pertama connect
cat > ~/.ssh/config <<EOF
Host app-server-*
    StrictHostKeyChecking no
    IdentityFile ~/.ssh/id_deploy
    User deploy
EOF

chmod 600 ~/.ssh/config

# Kembali ke user normal
exit
```

---

## 6. Akses Jenkins Web UI

Buka browser dan akses:

```
http://10.34.100.200:8080
```

### 6.1 Unlock Jenkins

```bash
# Dapatkan initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Masukkan password tersebut di halaman web.

### 6.2 Install Suggested Plugins

Klik **"Install suggested plugins"** dan tunggu hingga selesai.

### 6.3 Buat Admin User

Isi form dengan data berikut (sesuaikan):
- Username: `admin`
- Password: `admin123` ← gunakan password yang lebih kuat di produksi
- Full Name: `Admin`
- Email: `admin@example.com`

### 6.4 Plugin Tambahan yang Diperlukan

Pergi ke **Manage Jenkins → Plugins → Available plugins**, cari dan install:

| Plugin | Fungsi |
|--------|--------|
| `SSH Agent` | Menggunakan SSH key credential |
| `Pipeline` | Mendukung Jenkinsfile (sudah ada di suggested) |
| `Docker Pipeline` | Perintah Docker dalam pipeline |
| `Git` | Integrasi dengan Git repository |
| `Workspace Cleanup` | Bersihkan workspace setelah build |
| `AnsiColor` | Warna pada console output |

Setelah install, klik **"Restart Jenkins when installation is complete"**.

---

## 7. Verifikasi Instalasi

```bash
# Cek versi
java -version
jenkins --version  # atau cek di UI: Manage Jenkins → About Jenkins
docker --version
git --version

# Cek Jenkins service
sudo systemctl status jenkins

# Cek port 8080 terbuka
ss -tlnp | grep 8080
```

---

## Ringkasan

Setelah langkah ini selesai, kamu memiliki:
- [x] Jenkins terinstall dan berjalan di port 8080
- [x] Docker terinstall, user `jenkins` bisa akses Docker
- [x] SSH key siap untuk deploy ke App Server

**Lanjut ke:** [02 - Setup App Servers](02-setup-app-servers.md)
