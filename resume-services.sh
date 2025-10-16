#!/bin/bash

echo "🔄 Resuming Jenkins..."

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

echo "✅ Jenkins resumed!"

JENKINS_URL=$(az container show \
  --resource-group llmops-jenkins-rg \
  --name jenkins-llmops \
  --query ipAddress.fqdn -o tsv)

echo "🌐 Jenkins URL: http://${JENKINS_URL}:8080"

echo ""
echo "🔄 Checking LLM App..."

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
    
    echo "✅ App resumed!"
    echo "🌐 App URL: https://${APP_URL}"
else
    echo "⚠️  App doesn't exist. Deploy it using Jenkins pipeline."
fi