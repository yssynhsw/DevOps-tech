pipeline {
    agent any

    tools {
        jdk 'jdk-25'             // JDK configured in Jenkins
        maven 'maven-3.9.11'     // Maven configured in Jenkins
    }

    stages {
        stage('GIT Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/yssynhsw/DevOps-by-yssynhsw.git',
                    credentialsId: 'yssynhsw-gitaccess'
            }
        }

        stage('Check Tools') {
            steps {
                echo 'Verifying Java installation...'
                bat 'java -version'

                echo 'Verifying Maven installation...'
                bat 'mvn -v'

                echo 'Verifying Git installation...'
                bat 'git --version'
            }
        }

        stage('Build Project') {
            steps {
                echo 'Building project with Maven...'
                bat 'mvn clean package'
            }
        }

        stage('Run Tests') {
            steps {
                echo 'Running unit tests...'
                bat 'mvn test'
            }
        }
    }

    post {
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed! Check console output for errors.'
        }
    }
}
