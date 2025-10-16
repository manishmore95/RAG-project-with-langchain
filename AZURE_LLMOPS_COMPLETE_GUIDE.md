Here's a comprehensive documentation file with all scripts and instructions:

```markdown
# Azure LLMOps CI/CD - Complete Setup & Management Guide

This guide contains all scripts and instructions to set up, deploy, and manage your LLMOps project on Azure with Jenkins CI/CD.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Initial Setup - Deploy Jenkins](#1-initial-setup---deploy-jenkins)
3. [Deploy Project Using Jenkins Pipeline](#2-deploy-project-using-jenkins-pipeline)
4. [Remove Deployed Project & Images](#3-remove-deployed-project--images)
5. [Remove Jenkins Infrastructure](#4-remove-jenkins-infrastructure)
6. [Complete Deep Cleanup (Zero Charges)](#5-complete-deep-cleanup-zero-charges)
7. [Resume Services](#6-resume-services)

---

## Prerequisites

```bash
# Install Azure CLI if not installed
# macOS: brew install azure-cli
# Linux: curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Login to Azure
az login

# Set environment variables (required for deployment)
export GROQ_API_KEY="your-groq-api-key"
export GOOGLE_API_KEY="your-google-api-key"
```

---

## 1. Initial Setup - Deploy Jenkins

### Script: `azure-deploy-jenkins.sh`

```bash
#!/bin/bash

# Configuration
RESOURCE_GROUP="llmops-jenkins-rg"
LOCATION="eastus"
STORAGE_ACCOUNT="llmopsjenkinsstore"
FILE_SHARE_NAME="jenkins-data"
ACR_NAME="llmopsjenkinsacr"
CONTAINER_NAME="jenkins-llmops"
DNS_NAME="jenkins-llmops-${RANDOM}"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== Azure Jenkins Deployment Script ===${NC}\n"

# Step 1: Create Resource Group
echo -e "${GREEN}Step 1: Creating Resource Group...${NC}"
az group create --name $RESOURCE_GROUP --location $LOCATION

# Step 2: Create Storage Account
echo -e "${GREEN}Step 2: Creating Storage Account...${NC}"
az storage account create \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS

# Step 3: Get Storage Key
echo -e "${GREEN}Step 3: Getting Storage Key...${NC}"
STORAGE_KEY=$(az storage account keys list \
  --resource-group $RESOURCE_GROUP \
  --account-name $STORAGE_ACCOUNT \
  --query '[0].value' -o tsv)

# Step 4: Create File Share
echo -e "${GREEN}Step 4: Creating File Share...${NC}"
az storage share create \
  --name $FILE_SHARE_NAME \
  --account-name $STORAGE_ACCOUNT \
  --account-key $STORAGE_KEY \
  --quota 10

# Step 5: Create Container Registry
echo -e "${GREEN}Step 5: Creating Azure Container Registry...${NC}"
az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --sku Basic

az acr update --name $ACR_NAME --admin-enabled true

# Step 6: Get ACR Credentials
echo -e "${GREEN}Step 6: Getting ACR Credentials...${NC}"
ACR_USERNAME=$(az acr credential show --name $ACR_NAME --query username -o tsv)
ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query 'passwords[0].value' -o tsv)

# Step 7: Build and Push Image
echo -e "${GREEN}Step 7: Building and Pushing Jenkins Image...${NC}"
az acr login --name $ACR_NAME
docker build --platform linux/amd64 -f Dockerfile.jenkins -t $ACR_NAME.azurecr.io/jenkins-python:latest .
docker push $ACR_NAME.azurecr.io/jenkins-python:latest

# Step 8: Deploy Container
echo -e "${GREEN}Step 8: Deploying Jenkins Container...${NC}"
az container create \
  --resource-group $RESOURCE_GROUP \
  --name $CONTAINER_NAME \
  --image $ACR_NAME.azurecr.io/jenkins-python:latest \
  --os-type Linux \
  --registry-login-server $ACR_NAME.azurecr.io \
  --registry-username $ACR_USERNAME \
  --registry-password $ACR_PASSWORD \
  --dns-name-label $DNS_NAME \
  --ports 8080 50000 \
  --cpu 2 \
  --memory 4 \
  --azure-file-volume-account-name $STORAGE_ACCOUNT \
  --azure-file-volume-account-key $STORAGE_KEY \
  --azure-file-volume-share-name $FILE_SHARE_NAME \
  --azure-file-volume-mount-path /var/jenkins_home \
  --environment-variables \
    GROQ_API_KEY="${GROQ_API_KEY}" \
    GOOGLE_API_KEY="${GOOGLE_API_KEY}" \
    LLM_PROVIDER=google

# Get Jenkins URL
JENKINS_URL=$(az container show \
  --resource-group $RESOURCE_GROUP \
  --name $CONTAINER_NAME \
  --query ipAddress.fqdn -o tsv)

echo -e "\n${GREEN}=== Deployment Complete! ===${NC}"
echo -e "Jenkins URL: ${BLUE}http://${JENKINS_URL}:8080${NC}"
echo -e "\nWait 2-3 minutes for Jenkins to start, then get admin password:"
echo -e "${BLUE}az container exec --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME --exec-command \"cat /var/jenkins_home/secrets/initialAdminPassword\"${NC}"
```

### Usage:
```bash
chmod +x azure-deploy-jenkins.sh
./azure-deploy-jenkins.sh
```

### Post-Setup: Configure Jenkins

1. Access Jenkins at the provided URL
2. Get initial admin password:
   ```bash
   az container exec -g llmops-jenkins-rg -n jenkins-llmops \
     --exec-command "cat /var/jenkins_home/secrets/initialAdminPassword"
   ```
3. Install suggested plugins (including **GitHub Plugin**)
4. Create admin user
5. Add these Jenkins credentials:
   - `azure-client-id`: Azure Service Principal App ID
   - `azure-client-secret`: Azure Service Principal Password
   - `azure-tenant-id`: Azure Tenant ID
   - `azure-subscription-id`: Azure Subscription ID
   - `acr-username`: From app ACR (created by pipeline)
   - `acr-password`: From app ACR (created by pipeline)

### Configure GitHub Webhook (Required for Auto-Triggering)

To automatically trigger Jenkins builds on git push:

1. **Get your Jenkins URL:**
   ```bash
   az container show -g llmops-jenkins-rg -n jenkins-llmops \
     --query "ipAddress.fqdn" -o tsv
   ```

2. **In your GitHub repository:**
   - Go to **Settings** → **Webhooks** → **Add webhook**
   - **Payload URL:** `http://<jenkins-url>:8080/github-webhook/`
     - Example: `http://jenkins-llmops-31002.eastus.azurecontainer.io:8080/github-webhook/`
     - ⚠️ **Important:** Note the trailing `/` after `github-webhook/`
   - **Content type:** `application/json`
   - **Events:** Just the push event
   - **Active:** ✅ Checked
   - Click **Add webhook**

3. **Verify webhook:**
   - GitHub will send a test ping
   - Check for green ✅ checkmark
   - If red ❌, click webhook to see error details

4. **Test the setup:**
   ```bash
   # Make a test commit
   echo "Test webhook" >> test.txt
   git add test.txt
   git commit -m "Test: webhook trigger"
   git push
   
   # Jenkins should automatically start a build!
   ```

**Troubleshooting:** If webhook doesn't trigger, see `JENKINS_WEBHOOK_TROUBLESHOOTING.md`

---

## 2. Deploy Project Using Jenkins Pipeline

### Create Jenkins Pipeline Job

1. In Jenkins, click "New Item"
2. Enter name: "LLMOps-Azure-Pipeline"
3. Select "Pipeline"
4. Under "Pipeline" section:
   - Definition: "Pipeline script from SCM"
   - SCM: Git
   - Repository URL: `https://github.com/yourusername/your-repo.git`
   - Branch: `*/AddingJenkins` (or your branch)
   - Script Path: `Jenkinsfile`

### Create App Infrastructure First

Before running the pipeline, create the app infrastructure:

```bash
#!/bin/bash
# Save as: setup-app-infrastructure.sh

APP_RESOURCE_GROUP="llmops-app-rg"
LOCATION="eastus"
APP_ACR_NAME="llmopsappacr"
CONTAINER_APP_ENV="llmops-env"

echo "Creating app resource group..."
az group create --name $APP_RESOURCE_GROUP --location $LOCATION

echo "Creating app container registry..."
az acr create \
  --resource-group $APP_RESOURCE_GROUP \
  --name $APP_ACR_NAME \
  --sku Basic

az acr update --name $APP_ACR_NAME --admin-enabled true

echo "Creating Container Apps environment..."
az containerapp env create \
  --name $CONTAINER_APP_ENV \
  --resource-group $APP_RESOURCE_GROUP \
  --location $LOCATION

echo "Getting ACR credentials..."
ACR_USERNAME=$(az acr credential show --name $APP_ACR_NAME --query username -o tsv)
ACR_PASSWORD=$(az acr credential show --name $APP_ACR_NAME --query 'passwords[0].value' -o tsv)

echo ""
echo "=== Setup Complete ==="
echo "Add these to Jenkins credentials:"
echo "acr-username: $ACR_USERNAME"
echo "acr-password: $ACR_PASSWORD"
```

Run:
```bash
chmod +x setup-app-infrastructure.sh
./setup-app-infrastructure.sh
```

### Build and Push Docker Image (Local Machine)

**Important:** Due to ACR Tasks limitations in certain Azure subscriptions (free trial, student, etc.), 
we build Docker images locally and push them to ACR, rather than building in Jenkins.

Script: `build-and-push-docker-image.sh`

```bash
#!/bin/bash

APP_ACR_NAME="llmopsappacr"
IMAGE_NAME="llmops-app"
BUILD_TAG="${1:-latest}"

echo "🐳 Building Docker image locally..."

# Login to ACR
az acr login --name $APP_ACR_NAME

# Build image
docker build \
    --platform linux/amd64 \
    -t ${APP_ACR_NAME}.azurecr.io/${IMAGE_NAME}:${BUILD_TAG} \
    -t ${APP_ACR_NAME}.azurecr.io/${IMAGE_NAME}:latest \
    -f Dockerfile .

# Push both tags
echo "📤 Pushing to ACR..."
docker push ${APP_ACR_NAME}.azurecr.io/${IMAGE_NAME}:${BUILD_TAG}
docker push ${APP_ACR_NAME}.azurecr.io/${IMAGE_NAME}:latest

echo "✅ Build and push complete!"
echo "Now run your Jenkins pipeline to test and deploy."
```

Usage:
```bash
chmod +x build-and-push-docker-image.sh

# Build with 'latest' tag
./build-and-push-docker-image.sh

# Or build with specific version tag
./build-and-push-docker-image.sh v1.0.0
```

### Run Pipeline

1. **First, build and push the Docker image locally:**
   ```bash
   ./build-and-push-docker-image.sh
   ```

2. **Then, run the Jenkins pipeline:**
   - Go to your pipeline job in Jenkins
   - Click "Build Now"
   - Monitor the build progress

The pipeline will:
- Run tests
- Verify Docker image exists in ACR
- Deploy to Azure Container Apps
- Verify deployment

**Workflow:**
- **Local Machine:** Build Docker images when code changes
- **Jenkins Pipeline:** Run tests, verify image, deploy to Azure

---

## 3. Remove Deployed Project & Images

### Script: `cleanup-app-deployment.sh`

```bash
#!/bin/bash

# Configuration
APP_RESOURCE_GROUP="llmops-app-rg"
CONTAINER_APP_NAME="llmops-app"
APP_ACR_NAME="llmopsappacr"
IMAGE_NAME="llmops-app"

echo "🗑️  Removing deployed application..."

# Delete Container App
echo "Deleting container app..."
az containerapp delete \
  --name $CONTAINER_APP_NAME \
  --resource-group $APP_RESOURCE_GROUP \
  --yes 2>/dev/null || echo "Container app not found or already deleted"

# Delete images from ACR
echo "Deleting images from ACR..."
az acr repository delete \
  --name $APP_ACR_NAME \
  --repository $IMAGE_NAME \
  --yes 2>/dev/null || echo "Repository not found or already deleted"

echo "✅ Application deployment cleaned up!"
echo "Note: ACR and Container App Environment still exist (minimal cost)"
```

### Jenkinsfile Stage for Cleanup

Add this to your Jenkinsfile for automated cleanup:

```groovy
stage('Cleanup Deployment') {
    when {
        expression { params.CLEANUP_DEPLOYMENT == true }
    }
    steps {
        echo '🗑️ Cleaning up deployment...'
        sh '''
            # Delete container app
            az containerapp delete \
                --name ${CONTAINER_APP_NAME} \
                --resource-group ${APP_RESOURCE_GROUP} \
                --yes || true
            
            # Delete images
            az acr repository delete \
                --name ${APP_ACR_NAME} \
                --repository ${IMAGE_NAME} \
                --yes || true
        '''
    }
}
```

### Usage:
```bash
chmod +x cleanup-app-deployment.sh
./cleanup-app-deployment.sh
```

---

## 4. Remove Jenkins Infrastructure

### Script: `azure-destroy-jenkins.sh`

```bash
#!/bin/bash

RESOURCE_GROUP="llmops-jenkins-rg"
CONTAINER_NAME="jenkins-llmops"
ACR_NAME="llmopsjenkinsacr"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${RED}=== Jenkins Infrastructure Removal ===${NC}\n"

read -p "This will delete Jenkins container. Your data in Azure Files will be preserved. Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 1
fi

echo "Deleting Jenkins container..."
az container delete \
  --resource-group $RESOURCE_GROUP \
  --name $CONTAINER_NAME \
  --yes

echo -e "\n${GREEN}Jenkins container deleted!${NC}"
echo "Note: Storage, ACR, and your Jenkins data are preserved."
echo ""
echo "To delete everything including data:"
echo "  az group delete --name $RESOURCE_GROUP --yes"
```

### Usage:
```bash
chmod +x azure-destroy-jenkins.sh
./azure-destroy-jenkins.sh
```

---

## 5. Complete Deep Cleanup (Zero Charges)

### Script: `complete-deep-cleanup.sh`

```bash
#!/bin/bash

# This script removes EVERYTHING to ensure zero charges

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║   COMPLETE AZURE CLEANUP - ZERO CHARGES MODE     ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════╝${NC}\n"

echo -e "${YELLOW}This will delete ALL Azure resources including:${NC}"
echo "  • Jenkins Container Instance"
echo "  • Jenkins ACR and all images"
echo "  • Jenkins Storage Account (including Jenkins data)"
echo "  • App Container Apps"
echo "  • App ACR and all images"
echo "  • App Container App Environment"
echo "  • ALL Resource Groups"
echo ""
echo -e "${RED}⚠️  THIS CANNOT BE UNDONE!${NC}"
echo ""
read -p "Type 'DELETE-EVERYTHING' to confirm: " confirmation

if [ "$confirmation" != "DELETE-EVERYTHING" ]; then
    echo "Cancelled."
    exit 1
fi

echo ""
echo "🔍 Scanning for resources..."

# Resource Groups
JENKINS_RG="llmops-jenkins-rg"
APP_RG="llmops-app-rg"

# Function to check and delete resource group
delete_resource_group() {
    local rg=$1
    if az group exists --name $rg | grep -q "true"; then
        echo "📦 Found resource group: $rg"
        
        # List all resources
        echo "   Resources in $rg:"
        az resource list --resource-group $rg --query "[].{Name:name, Type:type}" -o table
        
        echo "   Deleting $rg..."
        az group delete --name $rg --yes --no-wait
        echo "   ✅ Deletion initiated for $rg"
    else
        echo "   ℹ️  Resource group $rg not found (already deleted or never created)"
    fi
}

# Delete Jenkins Resource Group
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🗑️  Removing Jenkins Infrastructure..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
delete_resource_group $JENKINS_RG

# Delete App Resource Group
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🗑️  Removing Application Infrastructure..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
delete_resource_group $APP_RG

# Check for any orphaned resources
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Checking for orphaned resources..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check for any container instances
echo "Container Instances:"
az container list --query "[?starts_with(name, 'jenkins-llmops') || starts_with(name, 'llmops-app')].{Name:name, ResourceGroup:resourceGroup, Status:containers[0].instanceView.currentState.state}" -o table

# Check for any ACRs
echo ""
echo "Container Registries:"
az acr list --query "[?starts_with(name, 'llmops')].{Name:name, ResourceGroup:resourceGroup, LoginServer:loginServer}" -o table

# Check for any container apps
echo ""
echo "Container Apps:"
az containerapp list --query "[?starts_with(name, 'llmops')].{Name:name, ResourceGroup:resourceGroup, Fqdn:properties.configuration.ingress.fqdn}" -o table

# Check for any storage accounts
echo ""
echo "Storage Accounts:"
az storage account list --query "[?starts_with(name, 'llmops')].{Name:name, ResourceGroup:resourceGroup}" -o table

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ Cleanup Complete!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Note: Resource group deletions are running in the background."
echo "It may take 5-10 minutes for all resources to be fully deleted."
echo ""
echo "To verify everything is gone, run:"
echo "  az group list --query \"[?starts_with(name, 'llmops')].name\" -o table"
echo ""
echo "💰 Expected charges: $0.00/month"
```

### Usage:
```bash
chmod +x complete-deep-cleanup.sh
./complete-deep-cleanup.sh
```

---

## 6. Resume Services

### Script: `resume-services.sh`

```bash
#!/bin/bash

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Resuming Azure Services                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}\n"

# Check for required environment variables
if [ -z "$GROQ_API_KEY" ] || [ -z "$GOOGLE_API_KEY" ]; then
    echo -e "${YELLOW}⚠️  Warning: API keys not set${NC}"
    echo "Please export:"
    echo "  export GROQ_API_KEY='your-key'"
    echo "  export GOOGLE_API_KEY='your-key'"
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Resume Jenkins
echo -e "${GREEN}🔄 Resuming Jenkins...${NC}"

STORAGE_KEY=$(az storage account keys list \
  --resource-group llmops-jenkins-rg \
  --account-name llmopsjenkinsstore \
  --query '[0].value' -o tsv)

ACR_USERNAME=$(az acr credential show --name llmopsjenkinsacr --query username -o tsv)
ACR_PASSWORD=$(az acr credential show --name llmopsjenkinsacr --query 'passwords[0].value' -o tsv)

az container create \
  --resource-group llmops-jenkins-rg \
  --name jenkins-llmops \
  --image llmopsjenkinsacr.azurecr.io/jenkins-python:latest \
  --os-type Linux \
  --registry-login-server llmopsjenkinsacr.azurecr.io \
  --registry-username $ACR_USERNAME \
  --registry-password $ACR_PASSWORD \
  --dns-name-label jenkins-llmops-${RANDOM} \
  --ports 8080 50000 \
  --cpu 2 \
  --memory 4 \
  --azure-file-volume-account-name llmopsjenkinsstore \
  --azure-file-volume-account-key $STORAGE_KEY \
  --azure-file-volume-share-name jenkins-data \
  --azure-file-volume-mount-path /var/jenkins_home \
  --environment-variables \
    GROQ_API_KEY="${GROQ_API_KEY}" \
    GOOGLE_API_KEY="${GOOGLE_API_KEY}" \
    LLM_PROVIDER=google

echo -e "${GREEN}✅ Jenkins resumed!${NC}"

JENKINS_URL=$(az container show \
  --resource-group llmops-jenkins-rg \
  --name jenkins-llmops \
  --query ipAddress.fqdn -o tsv)

echo -e "${BLUE}🌐 Jenkins URL: http://${JENKINS_URL}:8080${NC}"

echo ""
echo -e "${GREEN}🔄 Checking LLM App...${NC}"

if az containerapp show --name llmops-app --resource-group llmops-app-rg &>/dev/null; then
    echo "App exists, scaling up..."
    az containerapp update \
      --name llmops-app \
      --resource-group llmops-app-rg \
      --min-replicas 1 \
      --max-replicas 3
    
    APP_URL=$(az containerapp show \
      --name llmops-app \
      --resource-group llmops-app-rg \
      --query properties.configuration.ingress.fqdn -o tsv)
    
    echo -e "${GREEN}✅ App resumed!${NC}"
    echo -e "${BLUE}🌐 App URL: https://${APP_URL}${NC}"
else
    echo -e "${YELLOW}⚠️  App doesn't exist. Deploy it using Jenkins pipeline.${NC}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ Resume Complete!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

### Usage:
```bash
chmod +x resume-services.sh
export GROQ_API_KEY="your-key"
export GOOGLE_API_KEY="your-key"
./resume-services.sh
```

---

## Quick Reference Commands

### Check Status
```bash
# Check Jenkins
az container show -g llmops-jenkins-rg -n jenkins-llmops --query "{Name:name, Status:containers[0].instanceView.currentState.state, URL:ipAddress.fqdn}" -o table

# Check App
az containerapp show -n llmops-app -g llmops-app-rg --query "{Name:name, Status:properties.runningStatus, URL:properties.configuration.ingress.fqdn}" -o table

# Check all resource groups
az group list --query "[?starts_with(name, 'llmops')].{Name:name, Location:location}" -o table
```

### Pause Services (Minimize Costs)
```bash
# Stop Jenkins (data preserved)
az container delete -g llmops-jenkins-rg -n jenkins-llmops --yes

# Stop App
az containerapp delete -n llmops-app -g llmops-app-rg --yes
```

### Cost Estimation

| Service | Running | Stopped | Deleted |
|---------|---------|---------|---------|
| Jenkins Container Instance | ~$30/mo | $0 | $0 |
| Jenkins ACR (Basic) | $5/mo | $5/mo | $0 |
| Jenkins Storage Account | <$1/mo | <$1/mo | $0 |
| App Container Apps | ~$30/mo | $0 | $0 |
| App ACR (Basic) | $5/mo | $5/mo | $0 |
| **Total** | **~$71/mo** | **~$11/mo** | **$0** |

---

## Troubleshooting

### GitHub webhook not triggering Jenkins build
**Most common issue!** See detailed guide: `JENKINS_WEBHOOK_TROUBLESHOOTING.md`

Quick checks:
```bash
# 1. Verify Jenkins is accessible
curl -I http://<jenkins-url>:8080/github-webhook/

# 2. Check webhook in GitHub
# Go to: Repository → Settings → Webhooks
# Look for green ✅ (success) or red ❌ (failure)

# 3. Check Jenkins logs
az container logs -g llmops-jenkins-rg -n jenkins-llmops --tail 100 | grep -i github
```

**Quick fix:**
1. Go to your GitHub repo → Settings → Webhooks → Add webhook
2. URL: `http://<jenkins-url>:8080/github-webhook/` (note trailing `/`)
3. Content type: `application/json`
4. Events: Just the push event

### Jenkins won't start
```bash
# Check logs
az container logs -g llmops-jenkins-rg -n jenkins-llmops --tail 100

# Check events
az container show -g llmops-jenkins-rg -n jenkins-llmops --query "containers[0].instanceView.events" -o table
```

### Pipeline fails with git safe.directory error
Already fixed in Dockerfile.jenkins - ensure you've rebuilt the image.

### Pipeline fails with venv error
Already fixed in Jenkinsfile - using `/tmp/venv-${BUILD_NUMBER}`.

### ACR Tasks not allowed error
```
ERROR: (TasksOperationsNotAllowed) ACR Tasks requests are not permitted
```

**Solution:** This occurs with free trial/student subscriptions. Build Docker images locally:
```bash
./build-and-push-docker-image.sh
```

The Jenkinsfile has been updated to verify images exist instead of building them in Jenkins.

---

## File Checklist

Ensure you have these files in your repository:

- ✅ `azure-deploy-jenkins.sh` - Initial Jenkins setup
- ✅ `setup-app-infrastructure.sh` - Create app infrastructure
- ✅ `build-and-push-docker-image.sh` - Build and push app Docker image locally
- ✅ `cleanup-app-deployment.sh` - Remove deployed app
- ✅ `azure-destroy-jenkins.sh` - Remove Jenkins container
- ✅ `complete-deep-cleanup.sh` - Remove everything
- ✅ `resume-services.sh` - Resume all services
- ✅ `Jenkinsfile` - CI/CD pipeline
- ✅ `Dockerfile.jenkins` - Jenkins image with Python & Azure CLI
- ✅ `Dockerfile` - Application image
- ✅ `JENKINS_WEBHOOK_TROUBLESHOOTING.md` - GitHub webhook troubleshooting guide
- ✅ `AZURE_LLMOPS_COMPLETE_GUIDE.md` - This complete guide

---

## Support

For issues, check:
1. Azure Portal > Resource Groups > Your resources
2. Jenkins logs: `az container logs -g llmops-jenkins-rg -n jenkins-llmops`
3. App logs: `az containerapp logs show -n llmops-app -g llmops-app-rg`

---

**Last Updated:** October 2025  
**Tested On:** Azure CLI 2.x, Jenkins 2.528.1
```

Save this as `AZURE_LLMOPS_COMPLETE_GUIDE.md` in your repository root! 🚀