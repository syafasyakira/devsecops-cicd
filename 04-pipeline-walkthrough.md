# 04 - Pipeline Walkthrough

Penjelasan lengkap tentang Jenkinsfile dan alur setiap stage pada pipeline CI/CD multi kelompok, di mana **4 pipeline dapat berjalan bersamaan** tanpa saling konflik.

---

## Prinsip Parallel Pipeline

Setiap kelompok memiliki pipeline **terpisah dan terisolasi**:

| Kelompok   | Job Name     | Image Name       | Container Name    | Port Host |
|------------|--------------|------------------|-------------------|-----------|
| Kelompok A | `kelompok-a` | `kelompok-a:<n>` | `kelompok-a-app`  | `8081`    |
| Kelompok B | `kelompok-b` | `kelompok-b:<n>` | `kelompok-b-app`  | `8082`    |
| Kelompok C | `kelompok-c` | `kelompok-c:<n>` | `kelompok-c-app`  | `8083`    |
| Kelompok D | `kelompok-d` | `kelompok-d:<n>` | `kelompok-d-app`  | `8084`    |

Karena `IMAGE_NAME`, `CONTAINER_NAME`, dan `APP_PORT` masing-masing berbeda, keempat pipeline dapat berjalan di waktu yang sama tanpa konflik nama container maupun port.

> **Prasyarat:** Jumlah executor Jenkins harus ≥ 4.
> **Manage Jenkins** → **Manage Nodes** → **Built-In Node** → **Number of executors** = `4`

---

## Struktur Jenkinsfile

```groovy
pipeline {
    agent any

    options {
        disableConcurrentBuilds()  // Cegah satu job tabrakan dg dirinya sendiri
        timeout(time: 15, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '5'))
    }

    environment { ... }   // IMAGE_NAME, CONTAINER_NAME, APP_PORT — unik per kelompok

    stages {
        stage('Checkout')     { ... }  // Stage 1: Clone repo dari SCM
        stage('Build')        { ... }  // Stage 2: Build Docker image lokal
        stage('Test')         { ... }  // Stage 3: Jalankan unit test
        stage('Deploy')       { ... }  // Stage 4: Deploy container di server ini
        stage('Health Check') { ... }  // Stage 5: Verifikasi endpoint /health
        stage('Cleanup')      { ... }  // Stage 6: Hapus image lama milik job ini
    }

    post { ... }  // Notifikasi & cleanup pada failure
}
```

---

## Penjelasan Per Stage

### Stage 1: Checkout
Jenkins meng-clone repository dari GitHub secara otomatis karena pipeline dikonfigurasi dengan **Pipeline script from SCM**. Cukup gunakan `checkout scm` — tidak perlu hardcode URL. Stage ini juga menampilkan informasi branch dan commit aktif.

### Stage 2: Build
Membangun Docker image dari `Dockerfile` di root repository. Tag image menggunakan `${JOB_NAME}:${BUILD_NUMBER}` sehingga **image tiap kelompok memiliki nama berbeda** dan tidak saling timpa.

```
kelompok-a:42   ← milik kelompok A, build ke-42
kelompok-b:17   ← milik kelompok B, build ke-17
```

### Stage 3: Test
Menjalankan container sementara dari image yang baru dibangun untuk mengeksekusi unit test. Container dihapus setelah test selesai (`--rm`). Jika test gagal, pipeline berhenti dan Deploy tidak dijalankan.

### Stage 4: Deploy
Menghentikan container lama (jika ada) lalu menjalankan container baru dari image hasil build. Setiap kelompok menggunakan `CONTAINER_NAME` dan `APP_PORT` yang berbeda, sehingga deploy kelompok A tidak mempengaruhi container kelompok B, C, maupun D.

```bash
docker stop kelompok-a-app || true
docker rm   kelompok-a-app || true
docker run -d --name kelompok-a-app -p 8081:5000 kelompok-a:42
```

### Stage 5: Health Check
Menunggu beberapa detik agar container selesai startup, lalu memverifikasi bahwa endpoint `/health` merespons HTTP 200. Jika health check gagal, pipeline ditandai FAILURE tanpa mengganggu pipeline kelompok lain.

### Stage 6: Cleanup
Menghapus **hanya image lama milik job yang bersangkutan** (build number sebelumnya). Tidak menggunakan `docker image prune -f` karena perintah tersebut dapat menghapus image kelompok lain yang sedang dibangun secara bersamaan.

```groovy
// Aman untuk parallel — hanya hapus image milik job ini
sh "docker rmi ${IMAGE_NAME}:${BUILD_NUMBER.toInteger() - 1} || true"
```

---

## File Jenkinsfile

Lihat file lengkap di: [jenkins/Jenkinsfile](jenkins/Jenkinsfile)

---

## Memahami Docker dalam Pipeline (Tanpa Docker Hub)

```
Jenkins Server
│
├── checkout scm
│   └── Clone dari GitHub masing-masing kelompok
│
├── docker build -t kelompok-a:42 .
│   └── Membuat image lokal — hanya untuk kelompok-a
│
├── docker run --rm kelompok-a:42 python -m pytest
│   └── Jalankan test, container dihapus setelah selesai
│
├── docker stop kelompok-a-app && docker run -d ... kelompok-a:42
│   └── Deploy container baru di port 8081
│
└── curl http://localhost:8081/health
    └── Verifikasi container berjalan normal
```

---

## Alur Parallel 4 Pipeline (Bersamaan)

```
GitHub Kelompok A ──webhook──► Jenkins Job: kelompok-a ──► port 8081
GitHub Kelompok B ──webhook──► Jenkins Job: kelompok-b ──► port 8082
GitHub Kelompok C ──webhook──► Jenkins Job: kelompok-c ──► port 8083
GitHub Kelompok D ──webhook──► Jenkins Job: kelompok-d ──► port 8084
                                    │
                              (Executor 1-4 berjalan paralel)
```

Ketika keempat kelompok melakukan `git push` hampir bersamaan:

```
Waktu →   t=0s        t=5s        t=30s       t=60s       t=90s
          │           │           │           │           │
Job A:    [Checkout]──[Build]─────[Test]──────[Deploy]────[Health]✓
Job B:    [Checkout]──[Build]─────[Test]──────[Deploy]────[Health]✓
Job C:    [Checkout]──[Build]─────[Test]──────[Deploy]────[Health]✓
Job D:    [Checkout]──[Build]─────[Test]──────[Deploy]────[Health]✓
          └─────────────────── Berjalan bersamaan, 4 executor ──────────────┘
```

---

## Tips & Best Practices

1. **`disableConcurrentBuilds()`** — wajib ada di setiap Jenkinsfile untuk mencegah satu job memicu dirinya sendiri dua kali
2. **Jangan `docker image prune -f`** — berbahaya saat parallel; gunakan `docker rmi <nama-image-spesifik>` saja
3. **Port berbeda per kelompok** — gunakan tabel alokasi port dan jangan gunakan port yang sama
4. **`${JOB_NAME}` sebagai namespace** — pastikan semua nama image dan container mengandung `${JOB_NAME}` agar tidak bentrok
5. **Health check setelah deploy** — deteksi kegagalan sebelum dianggap sukses
6. **`post { failure { ... } }`** — bersihkan container yang gagal di tengah deploy agar port tidak tertahan

---

## Rollback Manual

Jika deploy terbaru bermasalah, rollback ke image build sebelumnya yang masih tersimpan lokal:

```bash
# Cek image yang tersedia
docker images kelompok-a

# Rollback ke build number sebelumnya (misal dari build 42 ke 41)
docker stop kelompok-a-app
docker rm   kelompok-a-app
docker run -d --name kelompok-a-app -p 8081:5000 kelompok-a:41
```

> Atau trigger ulang Jenkins build dari commit yang stabil menggunakan **"Replay"** atau **"Build with Parameters"**.
