#!/bin/bash

# This script removes EVERYTHING to ensure zero charges

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║   COMPLETE AZURE CLEANUP - ZERO CHARGES MODE      ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════╝${NC}\n"

echo -e "${YELLOW}⚠️  This will delete ALL Azure resources including:${NC}"
echo ""
echo "  • Jenkins Container Instance"
echo "  • Jenkins ACR and all images"
echo "  • Jenkins Storage Account (including Jenkins data)"
echo "  • App Container Apps"
echo "  • App ACR and all images"
echo "  • App Container App Environment"
echo "  • ALL Resource Groups (llmops-jenkins-rg, llmops-app-rg)"
echo ""
echo -e "${RED}⚠️  THIS CANNOT BE UNDONE!${NC}"
echo -e "${RED}⚠️  ALL YOUR JENKINS CONFIGURATION AND HISTORY WILL BE LOST!${NC}"
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
        echo ""
        echo -e "${BLUE}📦 Found resource group: $rg${NC}"
        
        # List all resources
        echo "   Resources in $rg:"
        az resource list --resource-group $rg --query "[].{Name:name, Type:type}" -o table
        
        echo "   Deleting $rg..."
        az group delete --name $rg --yes --no-wait
        echo -e "   ${GREEN}✅ Deletion initiated for $rg${NC}"
    else
        echo -e "   ${YELLOW}ℹ️  Resource group $rg not found (already deleted or never created)${NC}"
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
echo ""
echo "Container Instances:"
az container list --query "[?starts_with(name, 'jenkins-llmops') || starts_with(name, 'llmops-app')].{Name:name, ResourceGroup:resourceGroup, Status:containers[0].instanceView.currentState.state}" -o table 2>/dev/null || echo "None found"

# Check for any ACRs
echo ""
echo "Container Registries:"
az acr list --query "[?starts_with(name, 'llmops')].{Name:name, ResourceGroup:resourceGroup, LoginServer:loginServer}" -o table 2>/dev/null || echo "None found"

# Check for any container apps
echo ""
echo "Container Apps:"
az containerapp list --query "[?starts_with(name, 'llmops')].{Name:name, ResourceGroup:resourceGroup, Fqdn:properties.configuration.ingress.fqdn}" -o table 2>/dev/null || echo "None found"

# Check for any storage accounts
echo ""
echo "Storage Accounts:"
az storage account list --query "[?starts_with(name, 'llmops')].{Name:name, ResourceGroup:resourceGroup}" -o table 2>/dev/null || echo "None found"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ Cleanup Complete!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${YELLOW}Note: Resource group deletions are running in the background.${NC}"
echo "It may take 5-10 minutes for all resources to be fully deleted."
echo ""
echo "To verify everything is gone, run:"
echo -e "  ${BLUE}az group list --query \"[?starts_with(name, 'llmops')].name\" -o table${NC}"
echo ""
echo -e "${GREEN}💰 Expected charges: \$0.00/month${NC}"


