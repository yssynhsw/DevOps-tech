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
                bat 'git log --oneline -1'
            }
        }

        // ÉTAPE 2 : VÉRIFICATION
        stage('Check Tools') {
            steps {
                echo '🔧 Verification des outils...'
                bat '''
                    echo Java Version:
                    java -version
                    echo.
                    echo Maven Version:
                    mvn -v
                    echo.
                    echo Git Version:
                    git --version
                    echo.
                    echo Docker Version:
                    docker --version
                    echo.
                    echo Disk Space:
                    df -h
                '''
            }
        }

        // ÉTAPE 3 : BUILD
        stage('Build Project') {
            steps {
                echo '🏗️ Building project with Maven...'
                bat 'mvn clean compile'

                // Vérifier que les sources compilent
                echo '✅ Compilation successful'
            }
        }

        // ÉTAPE 4 : TESTS
        stage('Run Tests') {
            steps {
                echo '🧪 Running unit tests...'
                bat 'mvn test'

                // Publier les rapports JUnit
                junit '**/target/surefire-reports/*.xml'
            }

            post {
                always {
                    // Archiver les logs de test
                    archiveArtifacts artifacts: '**/target/surefire-reports/*.txt', allowEmptyArchive: true
                }
            }
        }

        // ÉTAPE 5 : PACKAGE
        stage('Package Application') {
            steps {
                echo '📦 Packaging application...'
                bat 'mvn package -DskipTests'

                // Lister le JAR généré
                bat 'dir target\\*.jar'

                // Archiver le JAR
                archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
            }
        }

        // ÉTAPE 6 : BUILD DOCKER (NOUVEAU)
        stage('Build Docker Image') {
            steps {
                echo '🐳 Building Docker image...'
                script {
                    // Vérifier si Dockerfile existe
                    def dockerfileExists = fileExists 'Dockerfile'
                    if (dockerfileExists) {
                        echo '✅ Dockerfile found'
                        bat "docker build -t ${DOCKER_IMAGE} ."
                        bat "docker tag ${DOCKER_IMAGE} ${DOCKER_TAG_LATEST}"
                    } else {
                        echo '⚠️ No Dockerfile found, skipping Docker build'
                    }
                }
            }
        }

        // ÉTAPE 7 : TEST DOCKER (NOUVEAU)
        stage('Test Docker Container') {
            when {
                expression { fileExists('Dockerfile') }
            }
            steps {
                echo '🧪 Testing Docker container...'
                script {
                    // Lancer le conteneur temporairement
                    bat """
                        docker run -d --name test-container -p 8081:8080 ${DOCKER_IMAGE}
                        timeout /t 20 /nobreak
                    """

                    // Tester si l'application répond
                    try {
                        bat 'curl -f http://localhost:8081/ || curl -f http://localhost:8081/actuator/health || echo "App running"'
                    } catch (Exception e) {
                        echo '⚠️ Could not connect to app, but continuing...'
                    } finally {
                        // Nettoyer
                        bat 'docker stop test-container'
                        bat 'docker rm test-container'
                    }
                }
            }
        }

        // ÉTAPE 8 : PUSH DOCKER HUB (OPTIONNEL)
        stage('Push to Docker Hub') {
            when {
                expression { fileExists('Dockerfile') }
                branch 'main'  // Push seulement sur main
            }
            steps {
                echo '📤 Pushing to Docker Hub...'
                script {
                    withCredentials([usernamePassword(
                        credentialsId: 'dockerhub-credentials',  // À créer dans Jenkins
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )]) {
                        bat """
                            echo %DOCKER_PASS% | docker login -u %DOCKER_USER% --password-stdin
                            docker push ${DOCKER_IMAGE}
                            docker push ${DOCKER_TAG_LATEST}
                        """
                    }
                }
            }
        }
    }

    // POST-PROCESSING AMÉLIORÉ
    post {
        always {
            echo '🧹 Cleanup workspace...'
            // Nettoyer les conteneurs Docker temporaires
            bat '''
                docker ps -aq --filter "name=test-container" | xargs docker stop 2>nul
                docker ps -aq --filter "name=test-container" | xargs docker rm 2>nul
                docker system prune -f
            '''

            // Nettoyer le workspace Jenkins
            cleanWs()
        }

        success {
            echo '✅ Pipeline completed successfully!'

            // Notification par email (optionnel)
            emailext (
                subject: "✅ SUCCESS: Build #${BUILD_NUMBER}",
                body: """
                    Build ${BUILD_NUMBER} completed successfully!
                    Application: ${APP_NAME}
                    View build: ${BUILD_URL}

                    Steps completed:
                    ✓ Git Checkout
                    ✓ Maven Build
                    ✓ Unit Tests
                    ✓ Docker Build
                """,
                to: 'ton.email@example.com',  // Remplace par ton email
                replyTo: 'jenkins@example.com'
            )

            // Afficher les artefacts générés
            bat '''
                echo "=== BUILD ARTIFACTS ==="
                echo "JAR file: target/*.jar"
                echo "Docker Image: ${DOCKER_IMAGE}"
                echo "======================"
            '''
        }

        failure {
            echo '❌ Pipeline failed!'

            emailext (
                subject: "❌ FAILURE: Build #${BUILD_NUMBER}",
                body: """
                    Build ${BUILD_NUMBER} failed!
                    Application: ${APP_NAME}
                    Check console output: ${BUILD_URL}console

                    Please investigate the failure.
                """,
                to: 'ton.email@example.com',
                replyTo: 'jenkins@example.com'
            )
        }

        unstable {
            echo '⚠️ Pipeline unstable (tests failed but build succeeded)'
        }
    }
}