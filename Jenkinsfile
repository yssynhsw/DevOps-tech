pipeline {
    agent any

    tools {
        jdk 'jdk-22'
        maven 'maven-3.9.11'
    }

    environment {
        APP_NAME = 'student-management'
        DOCKER_IMAGE = "yssynhsw/${APP_NAME}:${BUILD_NUMBER}"
        DOCKER_TAG_LATEST = "yssynhsw/${APP_NAME}:latest"
        BUILD_DATE = new Date().format('yyyyMMdd-HHmm')
    }

    stages {

        /* =======================
           1️⃣ GIT CHECKOUT
        ======================= */
        stage('GIT Checkout') {
            steps {
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: '*/main']],
                    userRemoteConfigs: [[
                        url: 'https://github.com/yssynhsw/DevOps-tech.git',
                        credentialsId: 'yssynhsw-gitaccess'
                    ]]
                ])

                bat '''
                    echo === GIT INFO ===
                    git log --oneline -1
                '''
            }
        }

        /* =======================
           2️⃣ CHECK TOOLS
        ======================= */
        stage('Check Tools & Workspace') {
            steps {
                bat '''
                    echo === WORKSPACE ===
                    dir
                    echo.
                    java -version 2>&1
                    echo.
                    mvn -v
                    echo.
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
                    echo === MAVEN BUILD ===
                    mvn clean package -DskipTests

                    if exist target\\*.jar (
                        echo JAR generated successfully
                    ) else (
                        echo ERROR: No JAR generated
                        exit 1
                    )
                '''

                script {
                    def jars = findFiles(glob: 'target/*.jar')
                    if (jars.isEmpty()) {
                        error 'Packaging succeeded but no JAR found'
                    }
                    env.JAR_FILENAME = jars[0].name
                    archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
                }
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
                expression {
                    fileExists('Dockerfile') &&
                    !findFiles(glob: 'target/*.jar').isEmpty()
                }
            }
            steps {
                bat """
                    docker build --no-cache -t "${DOCKER_IMAGE}" .
                    docker tag "${DOCKER_IMAGE}" "${DOCKER_TAG_LATEST}"
                    docker images | findstr "${APP_NAME}"
                """
            }
        }

        /* =======================
           6️⃣ TEST DOCKER CONTAINER
        ======================= */
        stage('Test Docker Container') {
            when {
                expression {
                    !findFiles(glob: 'target/*.jar').isEmpty()
                }
            }
            steps {
                script {
                    def cname = "test-${APP_NAME}-${BUILD_NUMBER}"
                    try {
                        bat """
                            docker run -d --name "${cname}" -p 8081:8080 "${DOCKER_IMAGE}"
                            timeout /t 30 /nobreak
                            docker logs "${cname}" --tail 20
                        """
                    } finally {
                        bat """
                            docker stop "${cname}" 2>nul
                            docker rm "${cname}" 2>nul
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
                allOf {
                    branch 'main'
                    expression { !findFiles(glob: 'target/*.jar').isEmpty() }
                }
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
        stage('Generate Build Report') {
            steps {
                script {
                    writeFile file: 'build-report.html', text: """
                    <html>
                    <body>
                        <h1>Build Report</h1>
                        <ul>
                            <li>App: ${APP_NAME}</li>
                            <li>Build: #${BUILD_NUMBER}</li>
                            <li>Date: ${BUILD_DATE}</li>
                            <li>Image: ${DOCKER_IMAGE}</li>
                            <li>Status: ${currentBuild.result ?: 'SUCCESS'}</li>
                        </ul>
                    </body>
                    </html>
                    """
                    archiveArtifacts 'build-report.html'
                }
            }
        }
    }

    /* =======================
       POST ACTIONS
    ======================= */
    post {
        always {
            bat '''
                docker system prune -f 2>nul
            '''
            cleanWs()
        }

        success {
            echo '✅ PIPELINE SUCCESS'
            bat '''
                echo =============================
                echo BUILD SUCCESSFUL
                echo Docker Image: ${DOCKER_IMAGE}
                echo JAR: ${JAR_FILENAME}
                echo =============================
            '''
        }

        failure {
            echo '❌ PIPELINE FAILED'
        }

        unstable {
            echo '⚠️ PIPELINE UNSTABLE'
        }

        aborted {
            echo '⏹️ PIPELINE ABORTED'
        }
    }
}
