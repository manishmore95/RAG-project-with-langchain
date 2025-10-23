# ⚡ Quick Reference & Cheat Sheet

Essential commands and troubleshooting for daily operations.

**Note:** This guide covers both GitHub Actions and Jenkins-based deployments.

---

## 🔧 Jenkins Operations (For Jenkins Users)

### **Start/Stop Jenkins**
```bash
# Start Jenkins (local Docker)
docker compose -f docker-compose.jenkins.yml up -d

# Stop Jenkins
docker compose -f docker-compose.jenkins.yml stop

# Restart Jenkins
docker restart jenkins-local

# View Jenkins logs
docker logs -f jenkins-local

# Access Jenkins UI
open http://localhost:8083
```

### **Jenkins Pipeline Operations**
```bash
# Trigger infrastructure provisioning
# Go to: Jenkins → multi-doc-chat-infra → Build Now

# Trigger application deployment
# Go to: Jenkins → multi-doc-chat-deploy → Build Now

# View build console output
# Click on build number → Console Output

# Check build status
# Jenkins Dashboard shows status of all jobs
```

### **Jenkins Troubleshooting**
```bash
# Check if Jenkins container is running
docker ps | grep jenkins

# Get initial admin password
docker exec jenkins-local cat /var/jenkins_home/secrets/initialAdminPassword

# Access Jenkins shell
docker exec -it jenkins-local bash

# Check Jenkins system log
# Manage Jenkins → System Log

# Backup Jenkins configuration
docker exec jenkins-local tar czf /tmp/jenkins-backup.tar.gz /var/jenkins_home
docker cp jenkins-local:/tmp/jenkins-backup.tar.gz ./

# Restore Jenkins configuration
docker cp jenkins-backup.tar.gz jenkins-local:/tmp/
docker exec jenkins-local tar xzf /tmp/jenkins-backup.tar.gz -C /
docker restart jenkins-local
```

---

## 🔧 Setup Commands (One-time)

### **Configure kubectl for EKS**
```bash
# Connect to your EKS cluster
aws eks update-kubeconfig \
  --name product-assistant-cluster-latest \
  --region us-west-1

# Verify connection
kubectl cluster-info
kubectl get nodes
```

### **Verify AWS CLI**
```bash
# Check AWS identity
aws sts get-caller-identity

# Check EKS cluster
aws eks describe-cluster \
  --name product-assistant-cluster-latest \
  --region us-west-1

# Check ECR repository
aws ecr describe-repositories --region us-west-1
```

---

## 📊 Daily Monitoring Commands

### **Check Application Health**
```bash
# Get all resources
kubectl get all

# Check pods status
kubectl get pods -l app=product-assistant

# Check pods with more details
kubectl get pods -l app=product-assistant -o wide

# Check if service has external IP
kubectl get svc product-assistant-service

# Expected output:
# NAME                        TYPE           EXTERNAL-IP
# product-assistant-service   LoadBalancer   a1b2c3.elb.amazonaws.com
```

### **View Logs**
```bash
# Tail logs from all pods
kubectl logs -l app=product-assistant -f --tail=50

# Logs from specific pod
kubectl logs <pod-name> -f

# Logs from previous crashed pod
kubectl logs <pod-name> --previous

# Logs from specific container in pod
kubectl logs <pod-name> -c <container-name>

# Logs with timestamps
kubectl logs -l app=product-assistant --timestamps=true

# Export logs to file
kubectl logs -l app=product-assistant > app-logs.txt
```

### **Check Resource Usage**
```bash
# Node resource usage (requires metrics-server)
kubectl top nodes

# Pod resource usage
kubectl top pods -l app=product-assistant

# If metrics-server not installed:
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

---

## 🔍 Debugging Commands

### **Inspect Resources**
```bash
# Detailed info about deployment
kubectl describe deployment product-assistant

# Detailed info about pods
kubectl describe pod <pod-name>

# Detailed info about service
kubectl describe svc product-assistant-service

# Check events (recent issues)
kubectl get events --sort-by='.lastTimestamp' | head -20

# Events for specific pod
kubectl describe pod <pod-name> | grep -A 10 Events

# Check deployment rollout status
kubectl rollout status deployment/product-assistant

# Check deployment history
kubectl rollout history deployment/product-assistant
```

### **Access Pod Shell**
```bash
# Interactive shell in pod
kubectl exec -it <pod-name> -- /bin/bash

# Or if bash not available
kubectl exec -it <pod-name> -- /bin/sh

# Run single command
kubectl exec <pod-name> -- env

# Check if API keys loaded
kubectl exec <pod-name> -- env | grep OPENAI
```

### **Network Debugging**
```bash
# Test service from within cluster
kubectl run test --rm -it --image=busybox -- wget -O- http://product-assistant-service

# Port forward to local machine
kubectl port-forward svc/product-assistant-service 8000:80

# Access at: http://localhost:8000

# Check service endpoints
kubectl get endpoints product-assistant-service

# DNS test
kubectl run test --rm -it --image=busybox -- nslookup product-assistant-service
```

---

## 🚀 Deployment Commands

### **Manual Deployment**
```bash
# Apply changes to deployment
kubectl apply -f k8/deployment.yaml

# Apply changes to service
kubectl apply -f k8/service.yaml

# Apply all manifests in directory
kubectl apply -f k8/

# Update image (triggers rolling update)
kubectl set image deployment/product-assistant \
  product-assistant=<registry>/<repo>:<new-tag>
```

### **Scaling**
```bash
# Scale manually
kubectl scale deployment product-assistant --replicas=4

# Check scaling status
kubectl get deployment product-assistant

# Auto-scaling
kubectl autoscale deployment product-assistant \
  --min=2 --max=10 --cpu-percent=70

# Check autoscaler
kubectl get hpa
```

### **Rollback**
```bash
# Rollback to previous version
kubectl rollout undo deployment/product-assistant

# Rollback to specific revision
kubectl rollout undo deployment/product-assistant --to-revision=2

# Check rollback status
kubectl rollout status deployment/product-assistant

# Pause rollout (for debugging)
kubectl rollout pause deployment/product-assistant

# Resume rollout
kubectl rollout resume deployment/product-assistant
```

---

## 🔐 Secrets Management

### **View Secrets**
```bash
# List secrets
kubectl get secrets

# View secret details (base64 encoded)
kubectl get secret product-assistant-secrets -o yaml

# Decode secret value
kubectl get secret product-assistant-secrets -o jsonpath='{.data.OPENAI_API_KEY}' | base64 -d

# View all secret keys
kubectl get secret product-assistant-secrets -o jsonpath='{.data}'
```

### **Update Secrets**
```bash
# Delete and recreate (easiest)
kubectl delete secret product-assistant-secrets

# Then re-run deploy workflow, or manually:
kubectl create secret generic product-assistant-secrets \
  --from-literal=OPENAI_API_KEY=sk-new-key \
  --from-literal=GOOGLE_API_KEY=new-google-key

# After updating secrets, restart pods
kubectl rollout restart deployment/product-assistant
```

---

## 🧹 Cleanup Commands

### **Delete Application**
```bash
# Delete deployment
kubectl delete deployment product-assistant

# Delete service
kubectl delete svc product-assistant-service

# Delete secrets
kubectl delete secret product-assistant-secrets

# Delete everything with label
kubectl delete all -l app=product-assistant
```

### **Delete Infrastructure**
```bash
# Delete CloudFormation stack (CAUTION: Destroys everything)
aws cloudformation delete-stack \
  --stack-name product-assistant-cluster \
  --region us-west-1

# Wait for deletion to complete
aws cloudformation wait stack-delete-complete \
  --stack-name product-assistant-cluster \
  --region us-west-1

# Check stack status
aws cloudformation describe-stacks \
  --stack-name product-assistant-cluster \
  --region us-west-1
```

### **Delete ECR Images**
```bash
# List images
aws ecr list-images \
  --repository-name product-assistant \
  --region us-west-1

# Delete specific image
aws ecr batch-delete-image \
  --repository-name product-assistant \
  --image-ids imageTag=1729756800 \
  --region us-west-1

# Delete all images (careful!)
aws ecr batch-delete-image \
  --repository-name product-assistant \
  --image-ids "$(aws ecr list-images --repository-name product-assistant --query 'imageIds[*]' --output json)" \
  --region us-west-1
```

---

## 🐛 Troubleshooting Quick Fixes

### **Problem: Pods in ImagePullBackOff**
```bash
# Check image name is correct
kubectl describe pod <pod-name> | grep Image

# Verify image exists in ECR
aws ecr describe-images \
  --repository-name product-assistant \
  --region us-west-1

# Check IAM role permissions
kubectl describe pod <pod-name> | grep "Failed to pull image"

# Solution: Verify deployment.yaml has correct ECR URL
```

### **Problem: Pods in CrashLoopBackOff**
```bash
# Check application logs
kubectl logs <pod-name> --previous

# Check if secrets loaded
kubectl exec <pod-name> -- env | grep API

# Check if port is correct
kubectl describe pod <pod-name> | grep Port

# Solution: Usually missing env vars or application error
```

### **Problem: Service has no EXTERNAL-IP**
```bash
# Check service type
kubectl get svc product-assistant-service -o yaml | grep type

# Should be: LoadBalancer

# Check events
kubectl describe svc product-assistant-service

# Wait (LoadBalancer creation takes 2-5 minutes)
kubectl get svc -w

# If stuck in <pending>:
# - Check AWS service limits
# - Check CloudFormation events
# - Check subnet configuration
```

### **Problem: Cannot access application via LoadBalancer**
```bash
# Check if pods are running
kubectl get pods -l app=product-assistant

# Check if service has endpoints
kubectl get endpoints product-assistant-service

# Should show pod IPs, not empty

# Check security group
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=EKS-*" \
  --region us-west-1

# Test from inside cluster
kubectl run test --rm -it --image=busybox -- wget -O- http://product-assistant-service

# If works inside cluster but not outside:
# - Security group issue
# - LoadBalancer not fully provisioned
```

### **Problem: Deployment rollout stuck**
```bash
# Check rollout status
kubectl rollout status deployment/product-assistant

# Check if pods starting
kubectl get pods -l app=product-assistant -w

# Check events
kubectl describe deployment product-assistant

# Force restart
kubectl rollout restart deployment/product-assistant

# If still stuck, delete pods manually
kubectl delete pod <pod-name>
```

### **Problem: Out of resources**
```bash
# Check node capacity
kubectl describe nodes

# Look for:
# - Allocatable vs Allocated resources
# - Disk pressure, Memory pressure

# Solution options:
# 1. Reduce resource requests in deployment
# 2. Scale up node group
# 3. Use larger instance types
```

---

## 📝 Useful kubectl Snippets

### **Get Pod Names**
```bash
# Get pod names only
kubectl get pods -l app=product-assistant -o name

# Store first pod name in variable
POD=$(kubectl get pods -l app=product-assistant -o jsonpath='{.items[0].metadata.name}')
echo $POD
```

### **Batch Operations**
```bash
# Delete all pods (will be recreated)
kubectl delete pods -l app=product-assistant

# Restart all pods
kubectl rollout restart deployment/product-assistant

# View logs from all pods
for pod in $(kubectl get pods -l app=product-assistant -o name); do
  echo "=== $pod ==="
  kubectl logs $pod --tail=20
done
```

### **JSON/YAML Queries**
```bash
# Get deployment image
kubectl get deployment product-assistant -o jsonpath='{.spec.template.spec.containers[0].image}'

# Get all environment variables
kubectl get deployment product-assistant -o jsonpath='{.spec.template.spec.containers[0].env[*].name}'

# Get service external IP
kubectl get svc product-assistant-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Export deployment as YAML
kubectl get deployment product-assistant -o yaml > deployment-backup.yaml
```

---

## 🔄 CI/CD Management

### **GitHub Actions**
```bash
# View workflow runs (via GitHub CLI)
gh run list --workflow=deploy.yml

# View specific run logs
gh run view <run-id> --log

# Trigger workflow manually
gh workflow run deploy.yml

# Cancel running workflow
gh run cancel <run-id>
```

### **Jenkins**
```bash
# Check Jenkins job status via CLI (requires jenkins-cli.jar)
java -jar jenkins-cli.jar -s http://localhost:8083/ -auth admin:password list-jobs

# Trigger build via CLI
java -jar jenkins-cli.jar -s http://localhost:8083/ -auth admin:password build multi-doc-chat-deploy

# Get build log
java -jar jenkins-cli.jar -s http://localhost:8083/ -auth admin:password console multi-doc-chat-deploy

# Or use Jenkins UI:
# 1. Open http://localhost:8083
# 2. Click on job name
# 3. Click "Build Now"
# 4. View progress in Stage View
```

### **Docker Operations (Local Testing)**
```bash
# Build image locally
docker build -t product-assistant:test .

# Run container locally
docker run -p 8000:8000 \
  -e OPENAI_API_KEY=sk-test \
  -e GOOGLE_API_KEY=test \
  product-assistant:test

# Tag for ECR
docker tag product-assistant:test \
  <account-id>.dkr.ecr.us-west-1.amazonaws.com/product-assistant:test

# Push to ECR (after login)
aws ecr get-login-password --region us-west-1 | \
  docker login --username AWS --password-stdin \
  <account-id>.dkr.ecr.us-west-1.amazonaws.com

docker push <account-id>.dkr.ecr.us-west-1.amazonaws.com/product-assistant:test
```

---

## 📊 Cost Monitoring

### **Check AWS Costs**
```bash
# Get current month costs
aws ce get-cost-and-usage \
  --time-period Start=2025-10-01,End=2025-10-31 \
  --granularity MONTHLY \
  --metrics "UnblendedCost" \
  --group-by Type=DIMENSION,Key=SERVICE

# Or via AWS Console:
# https://console.aws.amazon.com/cost-management/
```

### **Resource Inventory**
```bash
# List EKS clusters
aws eks list-clusters --region us-west-1

# List ECR repositories
aws ecr describe-repositories --region us-west-1

# List EC2 instances (worker nodes)
aws ec2 describe-instances \
  --filters "Name=tag:eks:cluster-name,Values=product-assistant-cluster-latest" \
  --region us-west-1

# List CloudFormation stacks
aws cloudformation list-stacks \
  --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
  --region us-west-1
```

---

## 🎯 Performance Testing

### **Load Testing**
```bash
# Install Apache Bench (if not installed)
# macOS: brew install httpd
# Ubuntu: apt-get install apache2-utils

# Simple load test
ab -n 1000 -c 10 http://<loadbalancer-url>/

# Explanation:
# -n 1000: Total 1000 requests
# -c 10: 10 concurrent requests

# While load testing, monitor:
kubectl top pods -l app=product-assistant
kubectl top nodes
```

### **Watch Resources**
```bash
# Watch pods (auto-refresh every 2s)
watch kubectl get pods -l app=product-assistant

# Watch with custom interval
watch -n 5 kubectl top pods

# Watch logs (follow mode)
kubectl logs -l app=product-assistant -f
```

---

## 🔐 Security Commands

### **Scan for Vulnerabilities**
```bash
# ECR image scan results
aws ecr describe-image-scan-findings \
  --repository-name product-assistant \
  --image-id imageTag=latest \
  --region us-west-1

# Audit kubernetes resources
kubectl auth can-i --list

# Check pod security
kubectl get pod <pod-name> -o jsonpath='{.spec.securityContext}'
```

### **Rotate Secrets**
```bash
# Step 1: Update in GitHub Secrets
# (via GitHub UI)

# Step 2: Re-run deploy workflow
# (will update Kubernetes secrets)

# Step 3: Restart pods to pick up new secrets
kubectl rollout restart deployment/product-assistant

# Verify new secrets loaded
kubectl exec <pod-name> -- env | grep API
```

---

## 📚 Documentation Links

### **Official Documentation**
- AWS EKS: https://docs.aws.amazon.com/eks/
- Kubernetes: https://kubernetes.io/docs/
- kubectl: https://kubernetes.io/docs/reference/kubectl/
- Docker: https://docs.docker.com/
- GitHub Actions: https://docs.github.com/en/actions

### **Troubleshooting Guides**
- EKS Troubleshooting: https://aws.amazon.com/premiumsupport/knowledge-center/eks-pod-status-troubleshooting/
- Kubernetes Debugging: https://kubernetes.io/docs/tasks/debug/
- Common Issues: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/

---

## 🎨 Useful Aliases (Add to ~/.bashrc or ~/.zshrc)

```bash
# Kubectl shortcuts
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgd='kubectl get deployments'
alias kl='kubectl logs'
alias kd='kubectl describe'
alias ke='kubectl exec -it'
alias kpf='kubectl port-forward'

# Project-specific (MultiDocChat)
alias kgpa='kubectl get pods -l app=multi-doc-chat'
alias kla='kubectl logs -l app=multi-doc-chat -f --tail=50'
alias kda='kubectl describe deployment multi-doc-chat'
alias kgs-app='kubectl get svc multi-doc-chat-service'

# AWS shortcuts
alias eks-connect='aws eks update-kubeconfig --name multi-doc-chat-cluster --region us-west-1'
alias ecr-login='aws ecr get-login-password --region us-west-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-west-1.amazonaws.com'

# Jenkins shortcuts (for local Docker setup)
alias jenkins-start='docker compose -f docker-compose.jenkins.yml up -d'
alias jenkins-stop='docker compose -f docker-compose.jenkins.yml stop'
alias jenkins-logs='docker logs -f jenkins-local'
alias jenkins-ui='open http://localhost:8083'

# Usage:
# kgpa  # Get MultiDocChat pods
# kla   # View MultiDocChat logs
# jenkins-start  # Start Jenkins
# jenkins-ui  # Open Jenkins in browser
```

---

## 🚨 Emergency Procedures

### **Application Down - Quick Recovery**
```bash
# 1. Check if pods are running
kubectl get pods -l app=product-assistant

# 2. If no pods, check deployment
kubectl get deployment product-assistant

# 3. If deployment exists but no pods, check events
kubectl describe deployment product-assistant

# 4. If image issue, rollback
kubectl rollout undo deployment/product-assistant

# 5. If still down, restart
kubectl rollout restart deployment/product-assistant

# 6. Monitor recovery
kubectl get pods -w
```

### **High CPU/Memory - Scale Quickly**
```bash
# 1. Check resource usage
kubectl top pods -l app=product-assistant

# 2. Scale up immediately
kubectl scale deployment product-assistant --replicas=4

# 3. Monitor
watch kubectl top pods

# 4. If nodes out of capacity
aws eks update-nodegroup-config \
  --cluster-name product-assistant-cluster-latest \
  --nodegroup-name <nodegroup-name> \
  --scaling-config minSize=2,maxSize=4,desiredSize=3
```

### **Bad Deployment - Immediate Rollback**
```bash
# Rollback to previous version
kubectl rollout undo deployment/product-assistant

# Check status
kubectl rollout status deployment/product-assistant

# Verify working
curl http://<loadbalancer-url>/
```

---

## 💡 Pro Tips

1. **Use `-w` flag for live updates:**
   ```bash
   kubectl get pods -w
   kubectl get svc -w
   ```

2. **Use `--dry-run` to test before applying:**
   ```bash
   kubectl apply -f deployment.yaml --dry-run=client
   ```

3. **Save frequently used commands:**
   ```bash
   # Create a scripts/ directory
   mkdir ~/eks-scripts
   
   # Save useful commands
   echo 'kubectl get pods -l app=product-assistant' > ~/eks-scripts/check-pods.sh
   chmod +x ~/eks-scripts/check-pods.sh
   ```

4. **Set default namespace (if using namespaces):**
   ```bash
   kubectl config set-context --current --namespace=production
   ```

5. **Use kubectl explain for inline help:**
   ```bash
   kubectl explain deployment.spec
   kubectl explain pod.spec.containers
   ```

---

**Bookmark this page for quick reference during operations!** 🚀

