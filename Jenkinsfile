pipeline {
    agent any
    
    environment {
        PYTHON_VERSION = '3.12'
        GROQ_API_KEY = "${env.GROQ_API_KEY}"
        GOOGLE_API_KEY = "${env.GOOGLE_API_KEY}"
        LLM_PROVIDER = "${env.LLM_PROVIDER}"
        PYTHONPATH = "${WORKSPACE}:${WORKSPACE}/multi_doc_chat"
    }
    
    triggers {
        // Trigger on push to main branch
        githubPush()
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out code from repository...'
                checkout scm
            }
        }
        
        stage('Setup Environment') {
            steps {
                echo 'Setting up Python environment...'
                sh '''
                    python3 --version
                    python3 -m pip --version
                '''
            }
        }
        
        stage('Install Dependencies') {
            steps {
                echo 'Installing project dependencies...'
                sh '''
                    python3 -m pip install --upgrade pip
                    python3 -m pip install -r requirements.txt
                '''
            }
        }
        
        stage('Run Tests') {
            steps {
                echo 'Running pytest tests...'
                sh '''
                    python3 -m pytest tests/ \
                        --verbose \
                        --junit-xml=test-results/results.xml \
                        --cov=multi_doc_chat \
                        --cov-report=xml:coverage.xml \
                        --cov-report=html:htmlcov \
                        --cov-report=term
                '''
            }
        }
    }
    
    post {
        always {
            echo 'Archiving test results...'
            // Publish test results
            junit allowEmptyResults: true, testResults: 'test-results/*.xml'
            
            // Archive coverage reports
            archiveArtifacts artifacts: 'coverage.xml,htmlcov/**', allowEmptyArchive: true
        }
        
        success {
            echo 'Pipeline completed successfully! ✓'
        }
        
        failure {
            echo 'Pipeline failed! ✗'
        }
    }
}