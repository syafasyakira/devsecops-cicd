# Hands-On CI/CD dengan Jenkins & Docker

> Topik: Continuous Integration / Continuous Deployment

---

## Materi: Konsep CI/CD & Jenkins

### Apa itu CI/CD?

**CI/CD** adalah praktik pengembangan perangkat lunak modern yang mengotomasi proses integrasi kode, pengujian, dan deployment.

| Singkatan | Kepanjangan | Pengertian |
|-----------|-------------|------------|
| **CI** | Continuous Integration | Praktik menggabungkan (merge) perubahan kode ke repository utama secara sering dan otomatis menjalankan build + test setiap ada perubahan |
| **CD** | Continuous Delivery | Mengekstensikan CI dengan memastikan kode selalu siap di-deploy ke environment production kapan saja |
| **CD** | Continuous Deployment | Selangkah lebih jauh — setiap perubahan yang lolos test langsung di-deploy ke production secara otomatis |

```
Tanpa CI/CD (Manual):             Dengan CI/CD (Otomatis):
                                  
Developer → (manual build)        Developer → git push
         → (manual test)                   → [otomatis] build
         → (manual upload)                 → [otomatis] test
         → (manual deploy)                 → [otomatis] deploy
         ≈ berjam-jam, error-prone         ≈ menit, konsisten
```

---

### Apa itu Jenkins?

**Jenkins** adalah server otomasi open-source berbasis Java yang paling banyak digunakan untuk implementasi CI/CD. Jenkins berfungsi sebagai **orchestrator** — ia mengawasi repository, memicu build, menjalankan test, dan mendistribusikan aplikasi ke server.

#### Sejarah Singkat
- Awalnya bernama **Hudson**, dibuat oleh Kohsuke Kawaguchi di Sun Microsystems (2004)
- Berganti nama menjadi **Jenkins** pada 2011 setelah konflik dengan Oracle
- Saat ini dikelola oleh **Jenkins community** (open-source), diunduh >1 juta kali/bulan

#### Mengapa Jenkins?
- **Open-source & gratis** — tidak ada biaya lisensi
- **Plugin ekosistem luas** — lebih dari 1.800 plugin (Git, Docker, Kubernetes, Slack, dll.)
- **Fleksibel** — mendukung berbagai bahasa, tools, dan platform
- **Pipeline as Code** — pipeline didefinisikan dalam file `Jenkinsfile` yang disimpan di Git
- **Distributed builds** — mendukung arsitektur master-agent untuk build paralel

---

### Komponen Utama Jenkins

```
┌────────────────────────────────────────────────────┐
│                  Jenkins Server                    │
│                                                    │
│  ┌─────────────┐   ┌──────────────┐                │
│  │   Job /     │   │   Pipeline   │                │
│  │   Project   │   │  (Jenkinsfile│                │
│  └─────────────┘   └──────────────┘                │
│                                                    │
│  ┌─────────────┐   ┌──────────────┐                │
│  │  Credentials│   │   Plugins    │                │
│  │  (SSH, token│   │  (Git, Docker│                │
│  │   password) │   │   SSH Agent) │                │
│  └─────────────┘   └──────────────┘                │
│                                                    │
│  ┌─────────────────────────────────┐               │
│  │         Build History           │               │
│  │  #1 ✓  #2 ✓  #3 ✗  #4 ✓         │               │
│  └─────────────────────────────────┘               │
└────────────────────────────────────────────────────┘
```

| Komponen | Fungsi |
|----------|--------|
| **Job / Project** | Unit kerja di Jenkins. Berisi konfigurasi apa yang harus dijalankan |
| **Pipeline** | Rangkaian stage yang membentuk alur CI/CD, didefinisikan via Jenkinsfile |
| **Stage** | Satu langkah besar dalam pipeline (misal: Build, Test, Deploy) |
| **Step** | Perintah spesifik di dalam sebuah stage |
| **Build** | Satu eksekusi pipeline (Build #1, #2, dst.) |
| **Workspace** | Direktori di Jenkins server tempat kode di-checkout & di-build |
| **Credentials** | Penyimpanan aman untuk password, SSH key, API token |
| **Agent** | Mesin yang menjalankan pipeline (`agent any` = pakai server Jenkins itu sendiri) |
| **Executor** | Slot eksekusi; satu executor menjalankan satu build pada satu waktu |
| **Plugin** | Ekstensi untuk menambah kemampuan Jenkins |

---

### Jenkinsfile: Pipeline as Code

**Jenkinsfile** adalah file teks (groovy DSL) yang mendefinisikan seluruh alur CI/CD. Disimpan di dalam repository, memungkinkan pipeline di-version control bersama kode aplikasi.

**Dua syntax Pipeline:**

```groovy
// 1. Declarative Pipeline (direkomendasikan, lebih terstruktur)
pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                sh 'docker build -t myapp .'
            }
        }
    }
}

// 2. Scripted Pipeline (lebih fleksibel, syntax Groovy penuh)
node {
    stage('Build') {
        sh 'docker build -t myapp .'
    }
}
```

> Lab ini menggunakan **Declarative Pipeline**.

---

### Jenis-Jenis Job di Jenkins

| Jenis | Keterangan | Kapan Digunakan |
|-------|------------|-----------------|
| **Freestyle Project** | Job klasik, konfigurasi via UI | Tugas sederhana, tidak butuh pipeline kompleks |
| **Pipeline** | Job berbasis Jenkinsfile | CI/CD modern, direkomendasikan |
| **Multibranch Pipeline** | Otomatis membuat pipeline per branch | Proyek dengan banyak branch (GitFlow) |
| **Folder** | Mengelompokkan job | Organisasi proyek besar |
| **GitHub Organization** | Scan semua repo dalam org GitHub | Enterprise / organisasi besar |

> Lab ini menggunakan job **Pipeline**.

---

### Build Triggers (Cara Memicu Pipeline)

```
1. Manual          → Klik "Build Now" di Jenkins UI
                     
2. Poll SCM        → Jenkins aktif memeriksa Git secara berkala
   (H/5 * * * *)     (setiap 5 menit, cek ada commit baru?)
                     
3. Webhook         → GitHub/GitLab push → kirim HTTP POST ke Jenkins
   (paling cepat)    Jenkins langsung bereaksi dalam hitungan detik
                     
4. Trigger dari    → Pipeline lain memanggil pipeline ini
   pipeline lain     (pipeline chain / upstream-downstream)
                     
5. Jadwal          → Seperti cron job, build pada waktu tertentu
   (H 2 * * 1-5)     (misalnya: setiap hari kerja jam 02.00)
```

---

### Credentials Management

Jenkins menyediakan **Credentials Store** yang aman untuk menyimpan informasi sensitif. Credential **tidak pernah** ditampilkan plain-text di log.

| Tipe Credential | Contoh Penggunaan |
|-----------------|-------------------|
| `Username with password` | Login Docker Hub, akun Git private |
| `SSH Username with private key` | Deploy ke server via SSH |
| `Secret text` | API token, webhook secret |
| `Certificate` | Client certificate untuk koneksi aman |

Dalam Jenkinsfile, credential dipanggil dengan:
```groovy
// Menggunakan SSH key
sshagent(credentials: ['deploy-ssh-key']) {
    sh 'ssh deploy@10.34.100.178 "docker ps"'
}

// Menggunakan username/password
withCredentials([usernamePassword(
    credentialsId: 'dockerhub-credentials',
    usernameVariable: 'USER',
    passwordVariable: 'PASS'
)]) {
    sh 'docker login -u $USER -p $PASS'
}
```

---

### Post Actions & Notifikasi

Blok `post` dijalankan setelah semua stage selesai, tergantung kondisi hasil build:

```groovy
post {
    always   { ... }  // Selalu dijalankan (cleanup, archive)
    success  { ... }  // Hanya jika pipeline SUKSES
    failure  { ... }  // Hanya jika pipeline GAGAL
    unstable { ... }  // Jika ada test yang gagal tapi build sukses
    changed  { ... }  // Jika status berubah dari build sebelumnya
}
```

---

### Perbandingan Jenkins vs Tools CI/CD Lain

| Fitur | Jenkins | GitHub Actions | GitLab CI | CircleCI |
|-------|---------|----------------|-----------|----------|
| Open-source | ✓ | ✗ (proprietary) | ✓ (partial) | ✗ |
| Self-hosted | ✓ | ✓ (runner) | ✓ | ✓ (runner) |
| Cloud-hosted | ✗ (perlu setup) | ✓ | ✓ | ✓ |
| Plugin ekosistem | ✓✓✓ (1800+) | ✓✓ (marketplace) | ✓ | ✓ |
| Kurva belajar | Sedang | Rendah | Rendah | Rendah |
| Cocok untuk | On-premise, enterprise | Open-source, GitHub | GitLab user | Tim kecil-menengah |

> Jenkins unggul untuk **on-premise deployment** dan lingkungan yang membutuhkan kontrol penuh atas infrastruktur — cocok untuk skenario DevSecOps di production environment sendiri.

---

## Deskripsi Lab

Pada lab ini, kamu akan membangun pipeline CI/CD menggunakan **Jenkins** untuk men-deploy aplikasi web berbasis container ke beberapa server secara otomatis.

### Arsitektur Sistem

```
┌─────────────────────────────────────────────────────────────────┐
│                        Developer                                │
│                    (push code ke Git)                           │
└──────────────────────────┬──────────────────────────────────────┘
                           │ webhook / polling
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│              VM-0: Jenkins Server (10.34.100.189)              │
│  ┌──────────────┐  ┌────────────────┐  ┌────────────────────┐  │
│  │   Jenkins    │  │  Docker        │  │  SSH Key / Agent   │  │
│  │  (port 8080) │  │  (build image) │  │  (deploy ke VMs)   │  │
│  └──────────────┘  └────────────────┘  └────────────────────┘  │
└──────────────────────────┬──────────────────────────────────────┘
                           │ SSH Deploy
          ┌────────────────┼────────────────┐
          ▼                ▼                ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│   VM-1       │  │   VM-2       │  │   VM-3       │
│ App Server 1 │  │ App Server 2 │  │ App Server 3 │
│10.34.100.178│  │10.34.100.179│  │10.34.100.180│
│ Docker       │  │ Docker       │  │ Docker       │
│ [web-app]    │  │ [web-app]    │  │ [web-app]    │
└──────────────┘  └──────────────┘  └──────────────┘
          
          ┌──────────────┐
          │   VM-4       │
          │ App Server 4 │
          │10.34.100.181│
          │ Docker       │
          │ [web-app]    │
          └──────────────┘
```

### Spesifikasi VM

| VM   | Nama Host          | IP Address       | RAM  | CPU | Peran              |
|------|--------------------|------------------|------|-----|--------------------|
| VM-0 | jenkins-server     | 10.34.100.200   | 2 GB | 2   | Jenkins CI/CD      |
| VM-1 | app-server-1       | 10.34.100.178   | 1 GB | 1   | App Node 1         |
| VM-2 | app-server-2       | 10.34.100.179   | 1 GB | 1   | App Node 2         |
| VM-3 | app-server-3       | 10.34.100.180   | 1 GB | 1   | App Node 3         |
| VM-4 | app-server-4       | 10.34.100.181   | 1 GB | 1   | App Node 4         |

> OS: Ubuntu 22.04 LTS (semua VM)

---

## Alur CI/CD Pipeline

```
Code Push
    │
    ▼
[Stage 1: Checkout]
    │  Clone repo dari Git
    ▼
[Stage 2: Build]
    │  Build Docker image
    ▼
[Stage 3: Test]
    │  Jalankan unit test dalam container
    ▼
[Stage 4: Push Image]
    │  Push image ke Docker Hub / Registry
    ▼
[Stage 5: Deploy]
    │  SSH ke 4 VM, pull & run container baru
    ▼
[Stage 6: Health Check]
    │  Verifikasi container berjalan
    ▼
[Notifikasi Selesai]
```

---

## Struktur File Lab

```
CI:CD/
├── README.md                    ← Dokumen ini
├── 01-setup-jenkins.md          ← Panduan instalasi Jenkins
├── 02-setup-app-servers.md      ← Panduan setup App Server
├── 03-jenkins-configuration.md  ← Konfigurasi Jenkins & credentials
├── 04-pipeline-walkthrough.md   ← Penjelasan pipeline & Jenkinsfile
├── app/
│   ├── Dockerfile               ← Docker image untuk web app
│   ├── app.py                   ← Aplikasi web (Flask)
│   ├── requirements.txt         ← Python dependencies
│   ├── templates/
│   │   └── index.html           ← Halaman web
│   └── tests/
│       └── test_app.py          ← Unit tests
├── jenkins/
│   ├── Jenkinsfile              ← Pipeline script
│   └── jenkins-plugins.txt      ← Daftar plugin Jenkins
└── scripts/
    ├── setup-jenkins.sh         ← Script otomatis setup Jenkins VM
    ├── setup-appserver.sh       ← Script otomatis setup App VM
    └── deploy.sh                ← Script deploy ke App VM
```

---

## Prasyarat

- Hypervisor: VirtualBox / VMware / Proxmox / cloud (GCP/AWS)
- 5 VM Ubuntu 22.04 LTS sudah berjalan dan bisa saling berkomunikasi
- Akses internet dari semua VM
- Akun Docker Hub (gratis)
- Akun GitHub / GitLab (gratis)

---

## Mulai Dari Sini

1. [01 - Setup Jenkins Server](01-setup-jenkins.md)
2. [02 - Setup App Servers](02-setup-app-servers.md)
3. [03 - Konfigurasi Jenkins](03-jenkins-configuration.md)
4. [04 - Pipeline Walkthrough](04-pipeline-walkthrough.md)
