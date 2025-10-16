#!/bin/bash

RESOURCE_GROUP="llmops-jenkins-rg"

echo "WARNING: This will delete all Jenkins resources in Azure!"
read -p "Are you sure? (yes/no): " confirm

if [ "$confirm" == "yes" ]; then
  echo "Deleting resource group: $RESOURCE_GROUP"
  az group delete --name $RESOURCE_GROUP --yes --no-wait
  echo "Cleanup initiated. Resources will be deleted in a few minutes."
else
  echo "Cleanup cancelled."
fi