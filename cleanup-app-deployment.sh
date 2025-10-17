#!/bin/bash

# Configuration
APP_RESOURCE_GROUP="llmops-app-rg"
CONTAINER_APP_NAME="llmops-app"
APP_ACR_NAME="llmopsappacr"
IMAGE_NAME="llmops-app"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║   Cleaning Up Application Deployment              ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════╝${NC}\n"

echo -e "${YELLOW}This will delete:${NC}"
echo "  • Container App: $CONTAINER_APP_NAME"
echo "  • Docker Images in ACR"
echo ""
echo -e "${GREEN}This will NOT delete:${NC}"
echo "  • Resource Group: $APP_RESOURCE_GROUP"
echo "  • Container Registry: $APP_ACR_NAME"
echo "  • Container App Environment: llmops-env"
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 1
fi

echo ""
echo -e "${GREEN}🗑️  Removing deployed application...${NC}"

# Delete Container App
echo "Deleting container app..."
az containerapp delete \
  --name $CONTAINER_APP_NAME \
  --resource-group $APP_RESOURCE_GROUP \
  --yes 2>/dev/null || echo "  ℹ️  Container app not found or already deleted"

# Delete images from ACR
echo "Deleting images from ACR..."
az acr repository delete \
  --name $APP_ACR_NAME \
  --repository $IMAGE_NAME \
  --yes 2>/dev/null || echo "  ℹ️  Repository not found or already deleted"

echo ""
echo -e "${GREEN}✅ Application deployment cleaned up!${NC}"
echo ""
echo -e "${YELLOW}Note:${NC} ACR and Container App Environment still exist (minimal cost ~$11/mo)"
echo ""
echo "To redeploy:"
echo "  1. Run: ./build-and-push-docker-image.sh"
echo "  2. Run Jenkins pipeline"


