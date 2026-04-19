# Konfigurasi Jenkins Multi Project

Panduan ini menjelaskan cara mengkonfigurasi Jenkins agar dapat digunakan untuk multi project / multi kelompok, misalnya dalam satu kelas dengan beberapa tim yang memiliki repository berbeda.

---

## 🎯 Tujuan

- Mendukung banyak project dalam satu Jenkins
- Setiap kelompok memiliki repository GitHub masing-masing
- Menghindari konflik antar project
- Menerapkan best practice CI/CD skala kecil–menengah (tanpa Docker Hub)

---

## 🧩 1. Konsep Dasar

Dalam Jenkins:

> **1 Project = 1 Pipeline Job**

Contoh:

```
webapp-kelompok-a
webapp-kelompok-b
webapp-kelompok-c
webapp-kelompok-d
```

---

## 📁 2. Gunakan Folder untuk Organisasi

Agar rapi, gunakan fitur **Folder** di Jenkins.

### Langkah:

1. Klik **New Item**
2. Pilih **Folder**
3. Nama: `kelas-devops-2026`
4. Klik **OK**

### Struktur yang terbentuk:

```
kelas-devops-2026/
├── kelompok-a
├── kelompok-b
├── kelompok-c
└── kelompok-d
```

---

## 🔧 3. Membuat 4 Pipeline per Kelompok

Setiap kelompok memiliki **1 Pipeline Job** yang terhubung ke repository GitHub mereka sendiri.

### Langkah membuat pipeline (lakukan 4 kali):

1. Masuk ke dalam folder `kelas-devops-2026`
2. Klik **New Item**
3. Isi nama sesuai kelompok (lihat tabel di bawah)
4. Pilih **Pipeline**
5. Klik **OK**

### Konfigurasi 4 Pipeline:

| Job Name         | Repository URL                                       | Branch   | Script Path  |
|------------------|------------------------------------------------------|----------|--------------|
| `kelompok-a`     | `https://github.com/kelompok-a/project.git`          | `*/main` | `Jenkinsfile` |
| `kelompok-b`     | `https://github.com/kelompok-b/project.git`          | `*/main` | `Jenkinsfile` |
| `kelompok-c`     | `https://github.com/kelompok-c/project.git`          | `*/main` | `Jenkinsfile` |
| `kelompok-d`     | `https://github.com/kelompok-d/project.git`          | `*/main` | `Jenkinsfile` |

> Sesuaikan URL repository dengan akun GitHub masing-masing kelompok.

### Pengaturan tiap Pipeline (Definition):

1. Pada bagian **Pipeline**, pilih **Pipeline script from SCM**
2. SCM: **Git**
3. Isi **Repository URL** sesuai tabel di atas
4. Branch: `*/main`
5. Script Path: `Jenkinsfile`
6. Klik **Save**

---

## 🔁 4. Jenkinsfile Template (Tanpa Docker Hub)

Setiap kelompok menaruh `Jenkinsfile` di root repository GitHub mereka. Pipeline hanya melakukan **clone → build → test → deploy** secara lokal, **tanpa push ke Docker Hub**.

Template ini dirancang agar **semua 4 pipeline dapat berjalan bersamaan** tanpa saling konflik:

- Nama image, container, dan port **unik per kelompok** menggunakan `${JOB_NAME}`
- `disableConcurrentBuilds()` mencegah satu job bertabrakan dengan dirinya sendiri
- Cleanup hanya menghapus image **milik job sendiri**, tidak menyentuh image kelompok lain

### Prasyarat: Jumlah Executor Jenkins

Agar 4 pipeline dapat berjalan **bersamaan**, pastikan jumlah executor Jenkins cukup:

1. **Manage Jenkins** → **Manage Nodes and Clouds** → klik node **Built-In Node**
2. Ubah **Number of executors** menjadi **4** (atau lebih)
3. Klik **Save**

> Default Jenkins hanya **2 executor**. Jika kurang dari 4, pipeline ketiga dan keempat akan antri menunggu.

---

### Contoh `Jenkinsfile` (template per kelompok):

```groovy
pipeline {
    agent any

    // Mencegah build yang sama berjalan dua kali di job yang sama
    // (tidak mempengaruhi job kelompok lain — mereka tetap bisa jalan bersamaan)
    options {
        disableConcurrentBuilds()
    }

    environment {
        IMAGE_NAME     = "${JOB_NAME}"
        IMAGE_TAG      = "${BUILD_NUMBER}"
        IMAGE_PREV_TAG = "${BUILD_NUMBER.toInteger() - 1}"
        CONTAINER_NAME = "${JOB_NAME}-app"
        APP_PORT       = "8081"   // Ganti per kelompok: 8081 / 8082 / 8083 / 8084
    }

    stages {
        stage('Clone') {
            steps {
                // Otomatis clone dari SCM yang dikonfigurasi — tidak perlu hardcode URL
                checkout scm
            }
        }

        stage('Build') {
            steps {
                sh "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} ."
            }
        }

        stage('Test') {
            steps {
                sh "docker run --rm ${IMAGE_NAME}:${IMAGE_TAG} python -m pytest tests/ -v"
            }
        }

        stage('Deploy') {
            steps {
                sh "docker stop ${CONTAINER_NAME} || true"
                sh "docker rm   ${CONTAINER_NAME} || true"
                sh "docker run -d --name ${CONTAINER_NAME} -p ${APP_PORT}:5000 ${IMAGE_NAME}:${IMAGE_TAG}"
            }
        }

        stage('Cleanup') {
            steps {
                // Hanya hapus image LAMA milik job ini — tidak menyentuh image kelompok lain
                // yang mungkin sedang berjalan bersamaan
                script {
                    def prevTag = BUILD_NUMBER.toInteger() - 1
                    sh "docker rmi ${IMAGE_NAME}:${prevTag} || true"
                }
            }
        }
    }

    post {
        success {
            echo "✅ Deploy ${JOB_NAME} build #${BUILD_NUMBER} berhasil! Akses di port ${APP_PORT}"
        }
        failure {
            echo "❌ Build ${JOB_NAME} #${BUILD_NUMBER} gagal. Periksa log di atas."
            // Pastikan container lama tidak tertinggal jika deploy gagal di tengah jalan
            sh "docker stop ${CONTAINER_NAME} || true"
            sh "docker rm   ${CONTAINER_NAME} || true"
        }
    }
}
```

---

### Ringkasan isolasi antar kelompok:

| Aspek              | Kelompok A          | Kelompok B          | Kelompok C          | Kelompok D          |
|--------------------|---------------------|---------------------|---------------------|---------------------|
| Nama image         | `kelompok-a:<n>`    | `kelompok-b:<n>`    | `kelompok-c:<n>`    | `kelompok-d:<n>`    |
| Nama container     | `kelompok-a-app`    | `kelompok-b-app`    | `kelompok-c-app`    | `kelompok-d-app`    |
| Port host          | `8081`              | `8082`              | `8083`              | `8084`              |
| Cleanup            | Hapus image sendiri | Hapus image sendiri | Hapus image sendiri | Hapus image sendiri |

> Dengan isolasi ini, push dari keempat kelompok secara bersamaan akan memicu 4 pipeline **paralel** tanpa saling mengganggu.

---

## ⚙️ 5. Perbedaan Port antar Kelompok

Karena semua pipeline berjalan di server yang sama, pastikan setiap kelompok menggunakan **port yang berbeda** agar tidak konflik.

| Kelompok     | Container Name        | Port Host | Port Container |
|--------------|-----------------------|-----------|----------------|
| `kelompok-a` | `kelompok-a-app`      | `8081`    | `5000`         |
| `kelompok-b` | `kelompok-b-app`      | `8082`    | `5000`         |
| `kelompok-c` | `kelompok-c-app`      | `8083`    | `5000`         |
| `kelompok-d` | `kelompok-d-app`      | `8084`    | `5000`         |

### Cara mengatur port di Jenkinsfile per kelompok:

Cukup ubah nilai `APP_PORT` di bagian `environment` sesuai tabel di atas:

```groovy
environment {
    APP_PORT = "8081"   // Ganti sesuai kelompok masing-masing
}
```

---

## 🔐 6. Manajemen Credentials

Karena tidak menggunakan Docker Hub, credentials yang dibutuhkan hanya untuk **akses private GitHub repository** (jika repo bersifat private).

### Opsi 1 — Credential Global (Sederhana)

Gunakan satu credential SSH yang dapat dipakai semua job:

| Credential ID    | Jenis               | Keterangan                              |
|------------------|---------------------|-----------------------------------------|
| `github-ssh-key` | SSH Username + Key  | Akses clone dari GitHub (repo private)  |
| `deploy-ssh-key` | SSH Username + Key  | Akses SSH ke app server untuk deploy    |

**Cara menambahkan:**
> **Manage Jenkins** → **Credentials** → **System** → **Global credentials** → **Add Credentials**

### Opsi 2 — Credential per Kelompok (Lebih Aman)

Buat credential SSH terpisah per kelompok agar tiap kelompok tidak bisa mengakses repo kelompok lain:

```
github-key-kelompok-a
github-key-kelompok-b
github-key-kelompok-c
github-key-kelompok-d
```

> Gunakan **Folder-scoped credentials** di folder masing-masing kelompok.

### Menggunakan credential di Jenkinsfile (repo private):

Jika menggunakan HTTPS dengan token:

```groovy
stage('Clone') {
    steps {
        withCredentials([string(credentialsId: 'github-token-kelompok-a', variable: 'TOKEN')]) {
            git credentialsId: 'github-token-kelompok-a', \
                branch: 'main', \
                url: 'https://github.com/kelompok-a/project.git'
        }
    }
}
```

> Jika repository GitHub bersifat **public**, bagian credentials tidak diperlukan — cukup gunakan `checkout scm`.

---

## 🌐 7. Konfigurasi Webhook

Setiap repository harus memiliki webhook agar Jenkins otomatis ter-trigger saat ada push.

### URL Webhook:

```
http://<jenkins-server>:8080/github-webhook/
```

### Langkah konfigurasi di GitHub:

1. Buka repository → **Settings** → **Webhooks** → **Add webhook**
2. Isi konfigurasi:

   | Field          | Nilai                        |
   |----------------|------------------------------|
   | Payload URL    | `http://<jenkins-server>:8080/github-webhook/` |
   | Content type   | `application/json`           |
   | Which events?  | **Just the push event**      |

3. Klik **Add webhook**

> Pastikan port `8080` Jenkins dapat diakses dari internet (atau gunakan IP publik / ngrok untuk testing lokal).

---

## 📌 8. Naming Convention (Penting)

Gunakan penamaan yang konsisten untuk memudahkan pengelolaan.

### Contoh struktur yang direkomendasikan:

```
kelas-devops/
├── kelompok-a-webapp
├── kelompok-b-webapp
├── kelompok-c-api
└── kelompok-d-ml
```

### Aturan penamaan:

| Komponen         | Format                           | Contoh                          |
|------------------|----------------------------------|---------------------------------|
| Folder utama     | `kelas-<tahun>`                  | `kelas-devops-2026`             |
| Job pipeline     | `kelompok-<id>`                  | `kelompok-a`                    |
| Docker image     | `<job-name>:<build-number>`      | `kelompok-a:42`                 |
| Container name   | `<job-name>-app`                 | `kelompok-a-app`                |
| Credential ID    | `github-key-<kelompok>`          | `github-key-kelompok-a`         |

---

## ✅ Ringkasan

| Langkah | Aksi                                                              |
|---------|-------------------------------------------------------------------|
| 1       | Buat Folder `kelas-devops-2026` di Jenkins                        |
| 2       | Buat 4 Pipeline job: `kelompok-a`, `b`, `c`, `d`                  |
| 3       | Arahkan tiap job ke repository GitHub kelompok masing-masing      |
| 4       | Pastikan setiap repo memiliki `Jenkinsfile` (copy dari template)   |
| 5       | Sesuaikan `APP_PORT` di `Jenkinsfile` agar tidak bentrok          |
| 6       | Tambahkan credentials GitHub (jika repo private)                  |
| 7       | Konfigurasi webhook di setiap repository GitHub                   |
| 8       | Jalankan build pertama untuk verifikasi tiap pipeline             |
