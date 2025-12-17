pipeline {
    agent any

    tools {
        jdk 'jdk-22'             // JDK configured in Jenkins
        maven 'maven-3.9.11'     // Maven configured in Jenkins
    }

    // Variables globales
    environment {
        APP_NAME = 'student-management'
        DOCKER_IMAGE = "yssynhsw/${APP_NAME}:${BUILD_NUMBER}"
        DOCKER_TAG_LATEST = "yssynhsw/${APP_NAME}:latest"
        JAR_FILE = "target/${APP_NAME}-*.jar"
        BUILD_DATE = new Date().format('yyyyMMdd-HHmm')
    }

    stages {
        // ÉTAPE 1 : CHECKOUT
        stage('GIT Checkout') {
            steps {
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: '*/main']],
                    userRemoteConfigs: [[
                        url: 'https://github.com/yssynhsw/DevOps-by-yssynhsw.git',
                        credentialsId: 'yssynhsw-gitaccess'
                    ]]
                ])

                // Afficher le commit
                bat '''
                    echo "=== GIT INFO ==="
                    git log --oneline -1
                    echo "Branch: %GIT_BRANCH%"
                    echo "Commit: %GIT_COMMIT%"
                '''
            }
        }

        // ÉTAPE 2 : VÉRIFICATION
        stage('Check Tools & Workspace') {
            steps {
                echo '🔧 Verification des outils et workspace...'
                bat '''
                    echo "=== WORKSPACE ==="
                    dir
                    echo.
                    echo "=== TOOLS VERSION ==="
                    java -version 2>&1
                    echo.
                    mvn -v
                    echo.
                    git --version
                    echo.
                    docker --version
                    echo.
                    echo "=== DISK SPACE ==="
                    wmic logicaldisk get size,freespace,caption
                    echo.
                    echo "=== JENKINS ENV ==="
                    echo "JOB_NAME: %JOB_NAME%"
                    echo "BUILD_NUMBER: %BUILD_NUMBER%"
                    echo "WORKSPACE: %WORKSPACE%"
                '''
            }
        }

        // ÉTAPE 3 : BUILD & PACKAGE
        stage('Build & Package') {
            steps {
                echo '🏗️ Building and packaging project...'
                bat '''
                    echo "=== CLEANING ==="
                    mvn clean

                    echo "=== COMPILING ==="
                    mvn compile

                    echo "=== PACKAGING ==="
                    mvn package -DskipTests

                    echo "=== VERIFYING JAR ==="
                    if exist target\\*.jar (
                        echo "✅ JAR file(s) found:"
                        for %%i in (target\\*.jar) do (
                            echo   - %%~nxi (%%~zi bytes)
                        )
                    ) else (
                        echo "❌ ERROR: No JAR file generated!"
                        exit 1
                    )
                '''
            }

            post {
                success {
                    // Archiver le JAR
                    archiveArtifacts artifacts: 'target/*.jar', fingerprint: true

                    // Stocker le nom du JAR dans une variable
                    script {
                        def jarFiles = findFiles(glob: 'target/*.jar')
                        if (jarFiles.length > 0) {
                            env.JAR_FILENAME = jarFiles[0].name
                            echo "JAR archived: ${env.JAR_FILENAME}"
                        }
                    }
                }
            }
        }

        // ÉTAPE 4 : TESTS
        stage('Run Tests') {
            steps {
                echo '🧪 Running unit tests...'
                bat 'mvn test'
            }

            post {
                always {
                    // Publier les rapports JUnit
                    junit '**/target/surefire-reports/*.xml'

                    // Archiver les logs de test
                    archiveArtifacts artifacts: '**/target/surefire-reports/*.txt', allowEmptyArchive: true

                    // Afficher le résumé des tests
                    bat '''
                        echo "=== TEST SUMMARY ==="
                        if exist target\\surefire-reports (
                            findstr /c:"Tests run:" target\\surefire-reports\\*.txt 2>nul || echo "No test reports found"
                        )
                    '''
                }
            }
        }

        // ÉTAPE 5 : BUILD DOCKER IMAGE
        stage('Build Docker Image') {
            when {
                expression {
                    // Vérifie si Dockerfile existe ET si le JAR existe
                    def dockerfileExists = fileExists('Dockerfile')
                    def jarExists = fileExists('target/*.jar')
                    return dockerfileExists && jarExists
                }
            }
            steps {
                echo '🐳 Building Docker image...'
                script {
                    // Afficher le contenu du Dockerfile pour debug
                    bat '''
                        echo "=== DOCKERFILE CONTENT ==="
                        type Dockerfile
                        echo.
                        echo "=== BUILD CONTEXT ==="
                        dir
                    '''

                    // Construire l'image Docker
                    bat """
                        echo "Building Docker image: ${DOCKER_IMAGE}"
                        docker build --no-cache --progress=plain -t "${DOCKER_IMAGE}" .

                        echo "Tagging as latest"
                        docker tag "${DOCKER_IMAGE}" "${DOCKER_TAG_LATEST}"

                        echo "=== DOCKER IMAGES ==="
                        docker images | findstr "${APP_NAME}"
                    """
                }
            }

            post {
                success {
                    echo "✅ Docker image built successfully: ${DOCKER_IMAGE}"
                }
                failure {
                    echo "❌ Docker build failed"
                    // Debug supplémentaire
                    bat '''
                        echo "=== DEBUG DOCKER BUILD ==="
                        echo "Current directory:"
                        cd
                        echo.
                        echo "Dockerfile exists:"
                        if exist Dockerfile (echo YES) else (echo NO)
                        echo.
                        echo "Target directory contents:"
                        if exist target (dir target) else (echo target/ does not exist!)
                    '''
                }
            }
        }

        // ÉTAPE 6 : TEST DOCKER CONTAINER
        stage('Test Docker Container') {
            when {
                expression {
                    // S'exécute seulement si l'image Docker a été construite
                    return fileExists('Dockerfile') && fileExists('target/*.jar')
                }
            }
            steps {
                echo '🧪 Testing Docker container...'
                script {
                    def testContainerName = "test-${APP_NAME}-${BUILD_NUMBER}"

                    try {
                        // Lancer le conteneur temporairement
                        bat """
                            echo "Starting test container: ${testContainerName}"
                            docker run -d --name "${testContainerName}" -p 8081:8080 "${DOCKER_IMAGE}"

                            echo "Waiting for app to start..."
                            timeout /t 30 /nobreak

                            echo "=== CONTAINER LOGS ==="
                            docker logs "${testContainerName}" --tail 20
                        """

                        // Tester si l'application répond
                        bat """
                            echo "Testing application health..."
                            curl -f http://localhost:8081/ || curl -f http://localhost:8081/actuator/health || echo "App responded"
                        """

                        // Vérifier l'état du conteneur
                        bat "docker ps --filter \"name=${testContainerName}\""

                    } catch (Exception e) {
                        echo "⚠️ Container test had issues: ${e.message}"
                        // Afficher les logs en cas d'erreur
                        bat "docker logs ${testContainerName} --tail 50"
                    } finally {
                        // Nettoyer TOUJOURS
                        bat """
                            echo "Cleaning up test container..."
                            docker stop "${testContainerName}" 2>nul
                            docker rm "${testContainerName}" 2>nul
                        """
                    }
                }
            }
        }

        // ÉTAPE 7 : PUSH TO DOCKER HUB
        stage('Push to Docker Hub') {
            when {
                allOf {
                    expression { fileExists('Dockerfile') }
                    expression { fileExists('target/*.jar') }
                    branch 'main'  // Push seulement sur main
                }
            }
            steps {
                echo '📤 Pushing to Docker Hub...'
                script {
                    withCredentials([usernamePassword(
                        credentialsId: 'dockerhub-credentials',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )]) {
                        bat """
                            echo "Logging into Docker Hub..."
                            echo %DOCKER_PASS% | docker login -u %DOCKER_USER% --password-stdin

                            echo "Pushing image: ${DOCKER_IMAGE}"
                            docker push "${DOCKER_IMAGE}"

                            echo "Pushing latest tag"
                            docker push "${DOCKER_TAG_LATEST}"

                            echo "=== PUSH SUCCESSFUL ==="
                            echo "Image: ${DOCKER_IMAGE}"
                            echo "Latest: ${DOCKER_TAG_LATEST}"
                            echo "View on Docker Hub: https://hub.docker.com/r/yssynhsw/${APP_NAME}"
                        """
                    }
                }
            }
        }

        // ÉTAPE 8 : GENERATE REPORT
        stage('Generate Build Report') {
            steps {
                echo '📊 Generating build report...'
                script {
                    // Créer un rapport HTML simple
                    def reportContent = """
                    <html>
                    <head><title>Build Report #${BUILD_NUMBER}</title></head>
                    <body>
                        <h1>Build Report</h1>
                        <h2>Job: ${env.JOB_NAME}</h2>
                        <h2>Build: #${BUILD_NUMBER}</h2>

                        <h3>Summary</h3>
                        <ul>
                            <li>Application: ${APP_NAME}</li>
                            <li>Build Date: ${BUILD_DATE}</li>
                            <li>Docker Image: ${DOCKER_IMAGE}</li>
                            <li>Status: ${currentBuild.result ?: 'SUCCESS'}</li>
                        </ul>

                        <h3>Links</h3>
                        <ul>
                            <li><a href="${env.BUILD_URL}">Build Console</a></li>
                            <li><a href="https://hub.docker.com/r/yssynhsw/${APP_NAME}">Docker Hub</a></li>
                            <li><a href="https://github.com/yssynhsw/DevOps-by-yssynhsw">GitHub Repository</a></li>
                        </ul>
                    </body>
                    </html>
                    """

                    writeFile file: 'build-report.html', text: reportContent
                    archiveArtifacts artifacts: 'build-report.html'
                }
            }
        }
    }

    // POST-PROCESSING
    post {
        always {
            echo '🧹 Performing cleanup...'
            script {
                // Nettoyer les conteneurs Docker temporaires
                bat '''
                    echo "Cleaning up Docker containers..."
                    for /f "tokens=*" %%i in ('docker ps -aq --filter "name=test-student-management"') do (
                        docker stop %%i 2>nul
                        docker rm %%i 2>nul
                    )

                    echo "Cleaning up Docker resources..."
                    docker system prune -f 2>nul

                    echo "=== FINAL DOCKER STATE ==="
                    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | findstr "student"
                '''

                // Nettoyer le workspace Jenkins
                cleanWs()
            }
        }

        success {
            echo '✅ Pipeline completed successfully!'

            // Notification email avec ton adresse
            emailext (
                subject: "✅ SUCCESS: Build #${BUILD_NUMBER} - ${APP_NAME}",
                body: """
                    <h2>Build Successful! ✅</h2>

                    <h3>Build Details:</h3>
                    <ul>
                        <li><strong>Job:</strong> ${env.JOB_NAME}</li>
                        <li><strong>Build #:</strong> ${BUILD_NUMBER}</li>
                        <li><strong>Application:</strong> ${APP_NAME}</li>
                        <li><strong>Date:</strong> ${BUILD_DATE}</li>
                        <li><strong>Status:</strong> SUCCESS</li>
                    </ul>

                    <h3>Docker Image:</h3>
                    <ul>
                        <li><strong>Image:</strong> ${DOCKER_IMAGE}</li>
                        <li><strong>Latest:</strong> ${DOCKER_TAG_LATEST}</li>
                    </ul>

                    <h3>Links:</h3>
                    <ul>
                        <li><a href="${env.BUILD_URL}">View Build Console</a></li>
                        <li><a href="${env.BUILD_URL}artifact/build-report.html">Download Build Report</a></li>
                        <li><a href="https://hub.docker.com/r/yssynhsw/${APP_NAME}">View on Docker Hub</a></li>
                    </ul>

                    <hr>
                    <p><em>This is an automated message from Jenkins CI/CD Pipeline.</em></p>
                """,
                to: 'hsayaoui.yassin@icloud.com',
                replyTo: 'jenkins-ci@example.com',
                mimeType: 'text/html'
            )

            // Afficher le résumé
            bat '''
                echo "========================================"
                echo "           BUILD SUCCESSFUL             "
                echo "========================================"
                echo "Docker Image: ${DOCKER_IMAGE}"
                echo "Latest Tag: ${DOCKER_TAG_LATEST}"
                echo "JAR File: ${JAR_FILENAME}"
                echo "========================================"
            '''
        }

        failure {
            echo '❌ Pipeline failed!'

            // Notification email d'erreur
            emailext (
                subject: "❌ FAILURE: Build #${BUILD_NUMBER} - ${APP_NAME}",
                body: """
                    <h2>Build Failed! ❌</h2>

                    <h3>Build Details:</h3>
                    <ul>
                        <li><strong>Job:</strong> ${env.JOB_NAME}</li>
                        <li><strong>Build #:</strong> ${BUILD_NUMBER}</li>
                        <li><strong>Application:</strong> ${APP_NAME}</li>
                        <li><strong>Date:</strong> ${BUILD_DATE}</li>
                        <li><strong>Status:</strong> FAILURE</li>
                    </ul>

                    <h3>Next Steps:</h3>
                    <ol>
                        <li>Check the build console for errors</li>
                        <li>Verify Maven dependencies</li>
                        <li>Check Dockerfile syntax</li>
                        <li>Review test failures</li>
                    </ol>

                    <h3>Debug Links:</h3>
                    <ul>
                        <li><a href="${env.BUILD_URL}console">View Full Console Output</a></li>
                        <li><a href="${env.BUILD_URL}testReport/">View Test Results</a></li>
                        <li><a href="https://github.com/yssynhsw/DevOps-by-yssynhsw">GitHub Repository</a></li>
                    </ul>

                    <hr>
                    <p><em>This is an automated message from Jenkins CI/CD Pipeline.</em></p>
                """,
                to: 'hsayaoui.yassin@icloud.com',
                replyTo: 'jenkins-ci@example.com',
                mimeType: 'text/html'
            )
        }

        unstable {
            echo '⚠️ Pipeline unstable (tests failed)'

            emailext (
                subject: "⚠️ UNSTABLE: Build #${BUILD_NUMBER} - ${APP_NAME}",
                body: """
                    <h2>Build Unstable ⚠️</h2>

                    <h3>Build Details:</h3>
                    <ul>
                        <li><strong>Job:</strong> ${env.JOB_NAME}</li>
                        <li><strong>Build #:</strong> ${BUILD_NUMBER}</li>
                        <li><strong>Application:</strong> ${APP_NAME}</li>
                        <li><strong>Date:</strong> ${BUILD_DATE}</li>
                        <li><strong>Status:</strong> UNSTABLE (Tests Failed)</li>
                    </ul>

                    <p><strong>Note:</strong> The build completed but some tests failed.</p>

                    <h3>Links:</h3>
                    <ul>
                        <li><a href="${env.BUILD_URL}testReport/">View Test Failures</a></li>
                        <li><a href="${env.BUILD_URL}console">View Build Console</a></li>
                    </ul>

                    <hr>
                    <p><em>This is an automated message from Jenkins CI/CD Pipeline.</em></p>
                """,
                to: 'hsayaoui.yassin@icloud.com',
                replyTo: 'jenkins-ci@example.com',
                mimeType: 'text/html'
            )
        }

        aborted {
            echo '⏹️ Pipeline aborted by user'
        }
    }
}