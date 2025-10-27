#!/bin/bash

# Script to set up ECR authentication for Kubernetes
# This creates a docker-registry secret in Kubernetes for pulling images from ECR
# Useful as a fallback if IAM role-based authentication is not working

set -e

# Configuration
REGION="${AWS_REGION:-us-east-1}"
ECR_REGISTRY="${ECR_REGISTRY:-}"
SECRET_NAME="ecr-registry-secret"
NAMESPACE="${NAMESPACE:-default}"

echo "=================================================="
echo "ECR Authentication Setup for Kubernetes"
echo "=================================================="
echo ""

# Check prerequisites
if [ -z "${ECR_REGISTRY}" ]; then
    echo "❌ ECR_REGISTRY environment variable not set"
    echo "Usage: ECR_REGISTRY=<account-id>.dkr.ecr.<region>.amazonaws.com $0"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Please install AWS CLI first."
    exit 1
fi

echo "Configuration:"
echo "  Region: ${REGION}"
echo "  Registry: ${ECR_REGISTRY}"
echo "  Secret Name: ${SECRET_NAME}"
echo "  Namespace: ${NAMESPACE}"
echo ""

# Test AWS credentials
echo "Testing AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured or invalid"
    exit 1
fi
echo "✅ AWS credentials valid"
echo ""

# Get ECR authorization token
echo "Getting ECR authorization token..."
ECR_TOKEN=$(aws ecr get-login-password --region ${REGION})

if [ -z "${ECR_TOKEN}" ]; then
    echo "❌ Failed to get ECR token"
    exit 1
fi
echo "✅ ECR token retrieved"
echo ""

# Check if secret already exists
echo "Checking for existing secret..."
if kubectl get secret ${SECRET_NAME} -n ${NAMESPACE} &> /dev/null; then
    echo "⚠️  Secret '${SECRET_NAME}' already exists in namespace '${NAMESPACE}'"
    read -p "Do you want to delete and recreate it? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl delete secret ${SECRET_NAME} -n ${NAMESPACE}
        echo "✅ Old secret deleted"
    else
        echo "Updating existing secret..."
        kubectl delete secret ${SECRET_NAME} -n ${NAMESPACE}
    fi
fi
echo ""

# Create docker-registry secret
echo "Creating Kubernetes secret for ECR..."
kubectl create secret docker-registry ${SECRET_NAME} \
    --docker-server=${ECR_REGISTRY} \
    --docker-username=AWS \
    --docker-password=${ECR_TOKEN} \
    --namespace=${NAMESPACE}

if [ $? -eq 0 ]; then
    echo "✅ Secret created successfully"
else
    echo "❌ Failed to create secret"
    exit 1
fi
echo ""

# Verify secret
echo "Verifying secret..."
kubectl get secret ${SECRET_NAME} -n ${NAMESPACE}
echo ""

# Show how to use the secret
echo "=================================================="
echo "Secret created successfully!"
echo "=================================================="
echo ""
echo "To use this secret in your deployment, add the following to your pod spec:"
echo ""
echo "  spec:"
echo "    imagePullSecrets:"
echo "    - name: ${SECRET_NAME}"
echo ""
echo "Example:"
echo ""
cat << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      imagePullSecrets:
      - name: ecr-registry-secret
      containers:
      - name: my-container
        image: <ECR_REGISTRY>/my-app:latest
EOF
echo ""
echo "=================================================="
echo ""
echo "⚠️  Note: ECR tokens expire after 12 hours."
echo "   For production, consider using IAM roles for service accounts (IRSA)"
echo "   or renew the secret periodically using a cron job."
echo ""
echo "To renew the secret, run this script again."
echo ""

