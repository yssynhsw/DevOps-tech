pipeline {
    agent any

    options {
        skipDefaultCheckout(true)
    }

    tools {
        jdk 'jdk-22'
        maven 'maven-3.9.11'
    }

    environment {
        APP_NAME = 'student-management'
        DOCKER_IMAGE = "yssynhsw/${APP_NAME}:${BUILD_NUMBER}"
        DOCKER_TAG_LATEST = "yssynhsw/${APP_NAME}:latest"
        BUILD_DATE = new Date().format('yyyyMMdd-HHmm')
        JAR_PATH = 'target/student-management-0.0.1-SNAPSHOT.jar'
    }

    stages {

        /* =======================
           1️⃣ GIT CHECKOUT
        ======================= */
        stage('Git Checkout') {
            steps {
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: '*/main']],
                    userRemoteConfigs: [[
                        url: 'https://github.com/yssynhsw/DevOps-tech.git',
                        credentialsId: 'yssynhsw-gitaccess'
                    ]]
                ])

                bat 'git log --oneline -1'
            }
        }

        /* =======================
           2️⃣ CHECK TOOLS
        ======================= */
        stage('Check Tools') {
            steps {
                bat '''
                    java -version
                    mvn -v
                    docker --version
                '''
            }
        }

        /* =======================
           3️⃣ BUILD & PACKAGE
        ======================= */
        stage('Build & Package') {
            steps {
                bat '''
                    mvn clean package -DskipTests

                    if not exist target\\*.jar (
                        echo ERROR: JAR not created
                        exit 1
                    )
                '''
                archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
            }
        }

        /* =======================
           4️⃣ RUN TESTS
        ======================= */
        stage('Run Tests') {
            steps {
                bat 'mvn test'
            }
            post {
                always {
                    junit '**/target/surefire-reports/*.xml'
                }
            }
        }

        /* =======================
           5️⃣ BUILD DOCKER IMAGE
        ======================= */
        stage('Build Docker Image') {
            when {
                expression { fileExists(env.JAR_PATH) && fileExists('Dockerfile') }
            }
            steps {
                bat """
                    docker build --no-cache -t "${DOCKER_IMAGE}" .
                    docker tag "${DOCKER_IMAGE}" "${DOCKER_TAG_LATEST}"
                """
            }
        }

        /* =======================
           6️⃣ TEST DOCKER CONTAINER
        ======================= */
        stage('Test Docker Container') {
            when {
                expression { fileExists(env.JAR_PATH) }
            }
            steps {
                script {
                    def cname = "test-${APP_NAME}-${BUILD_NUMBER}"
                    try {
                        bat """
                            docker run -d --name ${cname} -p 8081:8080 ${DOCKER_IMAGE}
                            timeout /t 20 /nobreak
                            docker logs ${cname}
                        """
                    } finally {
                        bat """
                            docker stop ${cname} 2>nul
                            docker rm ${cname} 2>nul
                        """
                    }
                }
            }
        }

        /* =======================
           7️⃣ PUSH TO DOCKER HUB
        ======================= */
        stage('Push to Docker Hub') {
            when {
                branch 'main'
            }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-credentials',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    bat """
                        echo %DOCKER_PASS% | docker login -u %DOCKER_USER% --password-stdin
                        docker push "${DOCKER_IMAGE}"
                        docker push "${DOCKER_TAG_LATEST}"
                    """
                }
            }
        }

        /* =======================
           8️⃣ BUILD REPORT
        ======================= */
        stage('Build Report') {
            steps {
                writeFile file: 'build-report.html', text: """
                <html><body>
                <h1>Build Report</h1>
                <ul>
                    <li>App: ${APP_NAME}</li>
                    <li>Build #: ${BUILD_NUMBER}</li>
                    <li>Date: ${BUILD_DATE}</li>
                    <li>Image: ${DOCKER_IMAGE}</li>
                    <li>Status: SUCCESS</li>
                </ul>
                </body></html>
                """
                archiveArtifacts 'build-report.html'
            }
        }
    }

    post {
        always {
            bat 'docker system prune -f 2>nul'
            cleanWs()
        }

        success {
            echo '✅ PIPELINE SUCCESS'
        }

        failure {
            echo '❌ PIPELINE FAILED'
        }
    }
}
