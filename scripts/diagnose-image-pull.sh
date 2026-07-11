#!/bin/bash

# Quick diagnostic script for ImagePullBackOff issues

set -e

CLUSTER_NAME="${EKS_CLUSTER_NAME:-multi-doc-chat-cluster}"
REGION="${AWS_REGION:-us-east-1}"
NODEGROUP_NAME="${CLUSTER_NAME}-nodegroup"

echo "======================================"
echo "ImagePullBackOff Diagnostic Script"
echo "======================================"
echo ""

# 1. Check kubectl connection
echo "1. Checking kubectl connection..."
if ! kubectl cluster-info &>/dev/null; then
    echo "❌ Cannot connect to cluster. Run:"
    echo "   aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${REGION}"
    exit 1
fi
echo "✅ Connected to cluster"
echo ""

# 2. Check pods
echo "2. Checking pod status..."
kubectl get pods -l app=multi-doc-chat
echo ""

# 3. Get detailed pod info
echo "3. Getting pod events..."
PODS=$(kubectl get pods -l app=multi-doc-chat -o name)
for POD in ${PODS}; do
    echo "Events for ${POD}:"
    kubectl describe ${POD} | grep -A 10 "Events:"
    echo ""
done

# 4. Check node IAM role
echo "4. Checking node IAM role..."
NODE_ROLE=$(aws eks describe-nodegroup \
    --cluster-name ${CLUSTER_NAME} \
    --nodegroup-name ${NODEGROUP_NAME} \
    --region ${REGION} \
    --query 'nodegroup.nodeRole' \
    --output text)
echo "Node Role: ${NODE_ROLE}"

ROLE_NAME=$(echo ${NODE_ROLE} | awk -F'/' '{print $NF}')
echo ""
echo "Attached policies:"
aws iam list-attached-role-policies --role-name ${ROLE_NAME}
echo ""

# 5. Check ECR access from node
echo "5. Verifying ECR policy..."
if aws iam list-attached-role-policies --role-name ${ROLE_NAME} | grep -q "AmazonEC2ContainerRegistryReadOnly"; then
    echo "✅ AmazonEC2ContainerRegistryReadOnly policy attached"
else
    echo "❌ Missing AmazonEC2ContainerRegistryReadOnly policy!"
    echo "   Run: aws iam attach-role-policy --role-name ${ROLE_NAME} --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
fi
echo ""

# 6. Check secrets
echo "6. Checking Kubernetes secrets..."
if kubectl get secret ecr-registry-secret &>/dev/null; then
    echo "✅ ecr-registry-secret exists"
else
    echo "⚠️  ecr-registry-secret not found"
    echo "   This is optional if IAM role has ECR access"
fi
echo ""

# 7. Test ECR login from local machine
echo "7. Testing ECR authentication from this machine..."
ECR_REGISTRY=$(kubectl get deployment multi-doc-chat -o jsonpath='{.spec.template.spec.containers[0].image}' | cut -d'/' -f1)
if [ -n "${ECR_REGISTRY}" ]; then
    echo "ECR Registry: ${ECR_REGISTRY}"
    if aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY} &>/dev/null; then
        echo "✅ ECR authentication successful from this machine"
    else
        echo "❌ ECR authentication failed"
    fi
else
    echo "⚠️  Could not determine ECR registry from deployment"
fi
echo ""

echo "======================================"
echo "Diagnostic complete"
echo "======================================"

