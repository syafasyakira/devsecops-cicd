# 03 - Konfigurasi Jenkins

Panduan ini menjelaskan cara mengkonfigurasi Jenkins setelah instalasi: menambahkan credentials, membuat pipeline job, dan menghubungkan dengan Git repository.

---

## 1. Tambahkan SSH Private Key ke Jenkins Credentials

Jenkins membutuhkan private key untuk SSH ke App Server.

1. Buka **Manage Jenkins → Credentials → System → Global credentials → Add Credentials**
2. Isi form:

| Field | Nilai |
|-------|-------|
| Kind | `SSH Username with private key` |
| Scope | `Global` |
| ID | `deploy-ssh-key` |
| Description | `SSH key untuk deploy ke App Server` |
| Username | `deploy` |
| Private Key | Pilih **Enter directly**, lalu paste isi `/var/lib/jenkins/.ssh/id_deploy` |

```bash
# Untuk melihat private key di Jenkins Server:
sudo cat /var/lib/jenkins/.ssh/id_deploy
```

3. Klik **Create**.

---

## 2. Tambahkan Docker Hub Credentials

Pipeline akan push image ke Docker Hub.

1. Pergi ke **Manage Jenkins → Credentials → System → Global credentials → Add Credentials**
2. Isi form:

| Field | Nilai |
|-------|-------|
| Kind | `Username with password` |
| Scope | `Global` |
| ID | `dockerhub-credentials` |
| Description | `Docker Hub login` |
| Username | `username-dockerhub-kamu` |
| Password | `password-dockerhub-kamu` |

3. Klik **Create**.

---

## 3. Buat Pipeline Job

1. Klik **New Item** di halaman utama Jenkins
2. Masukkan nama job: `webapp-cicd`
3. Pilih **Pipeline**
4. Klik **OK**

### 3.1 Konfigurasi General

- Centang **"Discard old builds"**
  - Max # of builds: `5`
- Centang **"GitHub project"** (jika menggunakan GitHub)
  - Project URL: `https://github.com/username/webapp-cicd`

### 3.2 Konfigurasi Build Triggers

Pilih salah satu (atau keduanya):

**Opsi A: Poll SCM (Jenkins mengecek perubahan secara berkala)**
- Centang **"Poll SCM"**
- Schedule: `H/5 * * * *` (cek setiap 5 menit)

**Opsi B: Webhook (GitHub/GitLab push langsung trigger Jenkins)** ← Lebih disarankan
- Centang **"GitHub hook trigger for GITScm polling"**
- Di GitHub: pergi ke repo → Settings → Webhooks → Add webhook
  - Payload URL: `http://10.34.100.200:8080/github-webhook/`
  - Content type: `application/json`
  - Event: pilih **"Just the push event"**

### 3.3 Konfigurasi Pipeline

Pilih **"Pipeline script from SCM"**:

| Field | Nilai |
|-------|-------|
| SCM | Git |
| Repository URL | `https://github.com/username/webapp-cicd.git` |
| Credentials | Tambahkan credential GitHub jika repo private |
| Branches to build | `*/main` |
| Script Path | `Jenkinsfile` |

Klik **Save**.

---

## 4. Konfigurasi Global Tools (Opsional)

Pergi ke **Manage Jenkins → Tools**:

- **Git installations:** pastikan Git sudah terdeteksi
- **Docker installations:** Tambahkan Docker (gunakan instalasi otomatis atau path `/usr/bin/docker`)

---

## 5. Jalankan Build Pertama (Manual)

1. Buka job `webapp-cicd`
2. Klik **"Build Now"**
3. Klik nomor build yang muncul
4. Klik **"Console Output"** untuk melihat log

---

## 6. Verifikasi Environment Variables

Sebelum pipeline berjalan, pastikan variabel berikut sudah diatur dengan benar di `Jenkinsfile`:

```groovy
environment {
    DOCKER_IMAGE   = "username-dockerhub/webapp"  // ganti username
    DOCKER_TAG     = "${BUILD_NUMBER}"
    APP_PORT       = "80"
    CONTAINER_NAME = "webapp"
    APP_SERVERS    = "10.34.100.178 10.34.100.179 10.34.100.180 10.34.100.181"
}
```

---

## Troubleshooting Umum

**"Got permission denied while trying to connect to the Docker daemon":**
```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

**"Host key verification failed":**
```bash
# Dari user jenkins, connect manual dulu ke setiap app server
sudo su - jenkins
ssh -i ~/.ssh/id_deploy deploy@10.34.100.178
# ketik 'yes' untuk accept fingerprint
```

**"error: unable to resolve reference 'refs/remotes/origin/main'":**
- Pastikan nama branch di Jenkins (`*/main`) sesuai dengan branch di repository

**Lanjut ke:** [04 - Pipeline Walkthrough](04-pipeline-walkthrough.md)
