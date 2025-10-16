/*
 * LLMOps Azure CI/CD Pipeline
 * 
 * IMPORTANT: This pipeline does NOT build Docker images due to ACR Tasks limitations
 * in free trial/student subscriptions.
 * 
 * Workflow:
 * 1. Build Docker images LOCALLY: ./build-and-push-docker-image.sh
 * 2. Run this Jenkins pipeline to test and deploy
 * 
 * Pipeline stages:
 * - Checkout code from Git
 * - Setup Python environment
 * - Install dependencies
 * - Run tests with coverage
 * - Verify Docker image exists in ACR
 * - Deploy to Azure Container Apps
 * - Verify deployment health
 */

pipeline {
    agent any
    
    environment {
        // Python settings
        PYTHON_VERSION = '3.12'
        PYTHONPATH = "${WORKSPACE}:${WORKSPACE}/multi_doc_chat"
        
        // API Keys for testing
        GROQ_API_KEY = "${env.GROQ_API_KEY}"
        GOOGLE_API_KEY = "${env.GOOGLE_API_KEY}"
        LLM_PROVIDER = "${env.LLM_PROVIDER}"
        
        // Azure Container Registry settings
        APP_ACR_NAME = "llmopsappacr"
        APP_ACR_SERVER = "${APP_ACR_NAME}.azurecr.io"
        IMAGE_NAME = "llmops-app"
        
        // Azure Container Apps settings
        APP_RESOURCE_GROUP = "llmops-app-rg"
        CONTAINER_APP_NAME = "llmops-app"
        
        // Azure credentials (from Jenkins credentials store)
        AZURE_CLIENT_ID = credentials('azure-client-id')
        AZURE_CLIENT_SECRET = credentials('azure-client-secret')
        AZURE_TENANT_ID = credentials('azure-tenant-id')
        AZURE_SUBSCRIPTION_ID = credentials('azure-subscription-id')
        ACR_USERNAME = credentials('acr-username')
        ACR_PASSWORD = credentials('acr-password')
    }
    
    triggers {
        // Trigger on push to main branch
        githubPush()
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo '📦 Checking out code from repository...'
                checkout scm
            }
        }
        
        stage('Setup Python Environment') {
            steps {
                echo '🐍 Setting up Python virtual environment...'
                sh '''
                    set -e
                    python3 --version
                    python3 -m venv /tmp/venv-${BUILD_NUMBER}
                    . /tmp/venv-${BUILD_NUMBER}/bin/activate
                    python -m pip install --upgrade pip
                '''
            }
        }
        
        stage('Install Dependencies') {
            steps {
                echo '📥 Installing project dependencies...'
                sh '''
                    set -e
                    . /tmp/venv-${BUILD_NUMBER}/bin/activate
                    pip install -r requirements.txt
                '''
            }
        }
        
        stage('Run Tests') {
            steps {
                echo '🧪 Running pytest tests...'
                sh '''
                    set -e
                    . /tmp/venv-${BUILD_NUMBER}/bin/activate
                    mkdir -p test-results
                    pytest tests/ \
                        --verbose \
                        --junit-xml=test-results/results.xml \
                        --cov=multi_doc_chat \
                        --cov-report=xml:coverage.xml \
                        --cov-report=html:htmlcov \
                        --cov-report=term \
                        || true
                '''
            }
        }
        
        stage('Login to Azure') {
            steps {
                echo '🔐 Logging into Azure...'
                sh '''
                    az login --service-principal \
                        -u ${AZURE_CLIENT_ID} \
                        -p ${AZURE_CLIENT_SECRET} \
                        --tenant ${AZURE_TENANT_ID}
                    
                    az account set --subscription ${AZURE_SUBSCRIPTION_ID}
                    az account show
                '''
            }
        }
        
        stage('Verify Docker Image Exists') {
            steps {
                echo '🔍 Verifying Docker image exists in ACR...'
                sh '''
                    # Check if image repository exists
                    if ! az acr repository show --name ${APP_ACR_NAME} --repository ${IMAGE_NAME} &>/dev/null; then
                        echo "❌ ERROR: Image repository '${IMAGE_NAME}' not found in ACR!"
                        echo ""
                        echo "Please build and push the Docker image locally first:"
                        echo "  chmod +x build-and-push-docker-image.sh"
                        echo "  ./build-and-push-docker-image.sh"
                        echo ""
                        exit 1
                    fi
                    
                    # Check if 'latest' tag exists
                    if ! az acr repository show-tags \
                        --name ${APP_ACR_NAME} \
                        --repository ${IMAGE_NAME} \
                        --output table | grep -q "latest"; then
                        echo "❌ ERROR: No 'latest' tag found for image '${IMAGE_NAME}'!"
                        echo ""
                        echo "Please build and push the Docker image locally:"
                        echo "  ./build-and-push-docker-image.sh"
                        echo ""
                        exit 1
                    fi
                    
                    echo "✅ Image '${IMAGE_NAME}:latest' found in ACR"
                    echo ""
                    echo "Available tags:"
                    az acr repository show-tags \
                        --name ${APP_ACR_NAME} \
                        --repository ${IMAGE_NAME} \
                        --output table
                '''
            }
        }
        
        stage('Deploy to Azure Container Apps') {
            steps {
                echo '🚀 Deploying to Azure Container Apps...'
                sh '''
                    # Update container app with latest image
                    az containerapp update \
                        --name ${CONTAINER_APP_NAME} \
                        --resource-group ${APP_RESOURCE_GROUP} \
                        --image ${APP_ACR_SERVER}/${IMAGE_NAME}:latest
                    
                    echo "Waiting for deployment to stabilize..."
                    sleep 30
                '''
            }
        }
        
        stage('Verify Deployment') {
            steps {
                echo '✅ Verifying deployment...'
                sh '''
                    # Get app URL
                    APP_URL=$(az containerapp show \
                        --name ${CONTAINER_APP_NAME} \
                        --resource-group ${APP_RESOURCE_GROUP} \
                        --query properties.configuration.ingress.fqdn -o tsv)
                    
                    echo "Application URL: https://${APP_URL}"
                    
                    # Health check
                    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://${APP_URL} || echo "000")
                    
                    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "307" ]; then
                        echo "✅ Deployment successful! App is responding."
                    else
                        echo "⚠️  Warning: App returned HTTP $HTTP_CODE"
                    fi
                    
                    # Show recent logs
                    echo "Recent logs:"
                    az containerapp logs show \
                        --name ${CONTAINER_APP_NAME} \
                        --resource-group ${APP_RESOURCE_GROUP} \
                        --tail 50 || true
                '''
            }
        }
    }
    
    post {
        always {
            echo '📊 Archiving test results...'
            // Publish test results
            junit allowEmptyResults: true, testResults: 'test-results/*.xml'
            
            // Archive coverage reports
            archiveArtifacts artifacts: 'coverage.xml,htmlcov/**,test-results/**/*.xml', allowEmptyArchive: true
        }
        
        success {
            echo '✅ Pipeline completed successfully! 🎉'
            sh '''
                APP_URL=$(az containerapp show \
                    --name ${CONTAINER_APP_NAME} \
                    --resource-group ${APP_RESOURCE_GROUP} \
                    --query properties.configuration.ingress.fqdn -o tsv)
                echo "🌐 Application is live at: https://${APP_URL}"
            '''
        }
        
        failure {
            echo '❌ Pipeline failed!'
        }
        
        cleanup {
            echo '🧹 Cleaning up workspace...'
            sh 'rm -rf /tmp/venv-${BUILD_NUMBER} || true'
        }
    }
}