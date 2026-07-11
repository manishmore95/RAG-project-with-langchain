#!/bin/bash

# Script to refresh ECR authentication secret in Kubernetes
# ECR tokens expire after 12 hours, so this needs to be run periodically

set -e

REGION="${AWS_REGION:-us-east-1}"
ECR_REGISTRY="${ECR_REGISTRY:-}"
SECRET_NAME="ecr-registry-secret"
NAMESPACE="${NAMESPACE:-default}"

echo "Refreshing ECR authentication secret..."
echo ""

# Get ECR registry from deployment if not set
if [ -z "${ECR_REGISTRY}" ]; then
    if command -v kubectl &>/dev/null; then
        ECR_REGISTRY=$(kubectl get deployment multi-doc-chat -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null | cut -d'/' -f1)
    fi
fi

if [ -z "${ECR_REGISTRY}" ]; then
    echo "❌ ECR_REGISTRY not set and could not determine from deployment"
    echo "Usage: ECR_REGISTRY=<account-id>.dkr.ecr.<region>.amazonaws.com $0"
    exit 1
fi

echo "Registry: ${ECR_REGISTRY}"
echo "Region: ${REGION}"
echo ""

# Get new token
echo "Getting new ECR token..."
ECR_TOKEN=$(aws ecr get-login-password --region ${REGION})

# Update secret
echo "Updating Kubernetes secret..."
kubectl create secret docker-registry ${SECRET_NAME} \
    --docker-server=${ECR_REGISTRY} \
    --docker-username=AWS \
    --docker-password="${ECR_TOKEN}" \
    --namespace=${NAMESPACE} \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Secret refreshed successfully"
echo ""
echo "To apply to running pods, restart the deployment:"
echo "  kubectl rollout restart deployment/multi-doc-chat"

