pipeline {
    agent any

    // Mencegah build yang sama berjalan dua kali di job yang sama
    // (tidak mempengaruhi job kelompok lain — mereka tetap bisa jalan bersamaan)
    options {
        disableConcurrentBuilds()
    }

    environment {
        JOB_BASE_NAME  = "${JOB_NAME.split('/').last()}"
        IMAGE_NAME     = "${JOB_BASE_NAME}"
        IMAGE_TAG      = "${BUILD_NUMBER}"
        IMAGE_PREV_TAG = "${BUILD_NUMBER.toInteger() - 1}"
        CONTAINER_NAME = "${JOB_BASE_NAME}-app"
        APP_PORT       = "8084"   // Ganti per kelompok: 8081 / 8082 / 8083 / 8084
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
                sh "docker build --build-arg BUILD_NUMBER=${BUILD_NUMBER} -t ${IMAGE_NAME}:${IMAGE_TAG} ."
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
                sh "docker run -d --name ${CONTAINER_NAME} -p ${APP_PORT}:5000 -e BUILD_NUMBER=${BUILD_NUMBER} ${IMAGE_NAME}:${IMAGE_TAG}"
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