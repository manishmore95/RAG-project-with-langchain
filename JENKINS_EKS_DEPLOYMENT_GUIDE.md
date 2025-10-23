# 🚀 Jenkins-Based AWS EKS Deployment Guide

Complete guide for deploying MultiDocChat application to AWS EKS using Jenkins CI/CD.

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Quick Start](#quick-start)
4. [Detailed Setup](#detailed-setup)
5. [Pipeline Configuration](#pipeline-configuration)
6. [Running Deployments](#running-deployments)
7. [Monitoring and Maintenance](#monitoring-and-maintenance)
8. [Troubleshooting](#troubleshooting)
9. [Migration to EC2](#migration-to-ec2)
10. [Cost Optimization](#cost-optimization)

---

## 🎯 Overview

### Architecture

```
Developer → Git Push → Jenkins (Local Docker/EC2)
                           ↓
                    [Jenkinsfile.infra] (One-time)
                           ↓
                    AWS CloudFormation
                           ↓
                 VPC + EKS + ECR + Networking
                           
Developer → Git Push → Jenkins
                           ↓
                    [Jenkinsfile.deploy] (Continuous)
                           ↓
              Docker Build → ECR Push → EKS Deploy
                           ↓
                    2 Pods + LoadBalancer
                           ↓
                        Users
```

### Components

- **Jenkinsfile.infra**: Provisions AWS infrastructure (EKS cluster, ECR, VPC)
- **Jenkinsfile.deploy**: Builds and deploys application with zero-downtime updates
- **CloudFormation**: Infrastructure as Code for AWS resources
- **Kubernetes**: Container orchestration on EKS
- **ECR**: Private Docker registry

---

## ✅ Prerequisites

### Local Environment

1. **Docker Desktop**
   ```bash
   # macOS
   brew install --cask docker
   
   # Or download from: https://www.docker.com/products/docker-desktop
   ```

2. **AWS CLI** (for local testing)
   ```bash
   # macOS
   brew install awscli
   
   # Verify
   aws --version
   ```

3. **kubectl** (for verification)
   ```bash
   # macOS
   brew install kubectl
   
   # Verify
   kubectl version --client
   ```

4. **Git**
   ```bash
   # Should already be installed
   git --version
   ```

### AWS Account Setup

1. **Create IAM User**
   - Go to AWS Console → IAM → Users → Add User
   - User name: `jenkins-deployer`
   - Access type: Programmatic access
   - Attach policies:
     - `AmazonEC2FullAccess`
     - `AmazonEKSClusterPolicy`
     - `AmazonEKSServicePolicy`
     - `AmazonEC2ContainerRegistryFullAccess`
     - `AmazonVPCFullAccess`
     - `IAMFullAccess`
     - `CloudFormationFullAccess`

2. **Generate Access Keys**
   - Click on the user → Security credentials
   - Create access key
   - Save `Access Key ID` and `Secret Access Key`

### GitHub Repository

- Repository must be accessible (public or with credentials)
- Branch: `main` or your working branch

---

## 🚀 Quick Start

### 1. Start Jenkins Locally

```bash
# From project root
cd /Users/yashpatil/Developer/AI/YT/Sunny/LLMOps_series

# Start Jenkins
docker compose -f docker-compose.jenkins.yml up -d

# Check logs
docker logs -f jenkins-local
```

**Jenkins will be available at:** http://localhost:8083

### 2. Initial Jenkins Setup

```bash
# Get initial admin password
docker exec jenkins-local cat /var/jenkins_home/secrets/initialAdminPassword
```

1. Open http://localhost:8083
2. Paste the initial admin password
3. Click "Install suggested plugins"
4. Create admin user:
   - Username: `admin`
   - Password: (choose a secure password)
   - Full name: `Admin`
   - Email: your-email@example.com
5. Click "Save and Continue"
6. Click "Start using Jenkins"

### 3. Install Required Plugins

Go to: **Manage Jenkins → Plugins → Available plugins**

Search and install (if not already installed):
- ✅ Pipeline
- ✅ Git
- ✅ Docker Pipeline (optional, for better Docker integration)
- ✅ AWS Steps (optional, for AWS-specific steps)

Click "Install without restart"

---

## 🔧 Detailed Setup

### Configure Environment Variables in Jenkins

You'll need to set environment variables for both pipelines. You can set them:
1. **Globally** (applies to all jobs)
2. **Per Job** (specific to each pipeline)

#### Option A: Global Environment Variables (Recommended for local setup)

**Manage Jenkins → System → Global properties → Environment variables**

Add the following variables:

**AWS Credentials:**
- Name: `AWS_ACCESS_KEY_ID`, Value: `your-access-key-id`
- Name: `AWS_SECRET_ACCESS_KEY`, Value: `your-secret-access-key`
- Name: `AWS_REGION`, Value: `us-west-1`

**Application Secrets:**
- Name: `GROQ_API_KEY`, Value: `your-groq-api-key` (or leave empty)
- Name: `OPENAI_API_KEY`, Value: `your-openai-api-key` (or leave empty)
- Name: `GOOGLE_API_KEY`, Value: `your-google-api-key` (optional)

**For Deployment Pipeline (will be set after infrastructure is created):**
- Name: `EKS_CLUSTER_NAME`, Value: `multi-doc-chat-cluster`
- Name: `ECR_REPOSITORY`, Value: `multi-doc-chat`
- Name: `ECR_REGISTRY`, Value: `<account-id>.dkr.ecr.us-west-1.amazonaws.com`

**To get your AWS account ID:**
```bash
aws sts get-caller-identity --query Account --output text
```

#### Option B: Per-Job Environment Variables

When creating each pipeline job, go to:
**Configure → Build Environment → Check "Use secret text(s) or file(s)"**

Add environment variables specific to that job.

### Create GitHub Credentials (for private repos)

If your repository is private:

1. **Manage Jenkins → Credentials → System → Global credentials → Add Credentials**
2. Kind: **Username with password**
3. Username: Your GitHub username
4. Password: GitHub Personal Access Token
   - Create PAT at: GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
   - Scope: `repo` (full control of private repositories)
5. ID: `github-pat`
6. Description: "GitHub PAT for repository access"
7. Click "Create"

---

## 📦 Pipeline Configuration

### Create Infrastructure Pipeline Job

1. **New Item**
   - Name: `multi-doc-chat-infra`
   - Type: **Pipeline**
   - Click OK

2. **General Configuration**
   - Description: "Provisions AWS EKS infrastructure (run once)"
   - ✅ Check "Do not allow concurrent builds"

3. **Pipeline Section**
   - Definition: **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: `https://github.com/yashprogrammer/LLMOps_series.git` (or your fork)
   - Credentials: Select `github-pat` (if private repo)
   - Branch Specifier: `*/main` (or your branch)
   - Script Path: `Jenkinsfile.infra`

4. **Save**

### Create Deployment Pipeline Job

1. **New Item**
   - Name: `multi-doc-chat-deploy`
   - Type: **Pipeline**
   - Click OK

2. **General Configuration**
   - Description: "Builds and deploys MultiDocChat application"
   - ✅ Check "Do not allow concurrent builds"

3. **Build Triggers** (Optional)
   - ✅ Poll SCM: `H/5 * * * *` (every 5 minutes)
   - This automatically triggers builds when code changes

4. **Pipeline Section**
   - Definition: **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: `https://github.com/yashprogrammer/LLMOps_series.git`
   - Credentials: Select `github-pat` (if private repo)
   - Branch Specifier: `*/main` (or your branch)
   - Script Path: `Jenkinsfile.deploy`

5. **Save**

---

## 🎬 Running Deployments

### First-Time Deployment (Complete Setup)

#### Step 1: Provision Infrastructure (Run Once)

1. Go to Jenkins → Click `multi-doc-chat-infra`
2. Click **Build Now**
3. **Expected duration: 20-30 minutes**
4. Monitor the build progress in Stage View
5. Check console output for any errors

**What this creates:**
- ✅ VPC with 2 public subnets
- ✅ EKS cluster: `multi-doc-chat-cluster`
- ✅ Node group with 2 × t3.medium instances
- ✅ ECR repository: `multi-doc-chat`
- ✅ Security groups and IAM roles

**After completion:**
- Go to "Display Stack Outputs" stage
- Copy the ECR Repository URI
- Update the `ECR_REGISTRY` environment variable in Jenkins
  - Format: `<account-id>.dkr.ecr.us-west-1.amazonaws.com`
  - Go to: Manage Jenkins → System → Global properties → Environment variables
  - Add/Update: `ECR_REGISTRY` = `<value-from-output>`

#### Step 2: Deploy Application

1. Go to Jenkins → Click `multi-doc-chat-deploy`
2. Click **Build Now**
3. **Expected duration: 5-10 minutes**
4. Monitor the build progress

**What this does:**
- ✅ Builds Docker image
- ✅ Pushes to ECR
- ✅ Creates Kubernetes resources
- ✅ Deploys 2 pod replicas
- ✅ Creates LoadBalancer service

**After completion:**
- Check "Get Service URL" stage for the LoadBalancer URL
- Access your application at: `http://<loadbalancer-url>`

#### Step 3: Verify Deployment

```bash
# Configure kubectl locally (optional)
aws eks update-kubeconfig --name multi-doc-chat-cluster --region us-west-1

# Check pods
kubectl get pods -l app=multi-doc-chat

# Check service
kubectl get svc multi-doc-chat-service

# View logs
kubectl logs -l app=multi-doc-chat -f
```

### Subsequent Deployments (After Code Changes)

**Option A: Automatic (with SCM polling)**
- Simply push your code changes to the repository
- Jenkins will detect changes within 5 minutes
- Automatic build and deployment

**Option B: Manual**
- Go to Jenkins → `multi-doc-chat-deploy`
- Click **Build Now**

---

## 📊 Monitoring and Maintenance

### View Build Status

**Jenkins Dashboard:**
- Green checkmark ✅ = Success
- Red X ❌ = Failed
- Blue ball (animated) = In Progress

### View Console Output

- Click on build number (e.g., #1, #2)
- Click "Console Output"
- Shows complete log of all commands executed

### View Pipeline Stages

- Click on build number
- View "Stage View" for visual representation
- Click on any stage to see its logs

### Monitor Application

```bash
# Get pods status
kubectl get pods -l app=multi-doc-chat -w

# View pod logs
kubectl logs -l app=multi-doc-chat -f --tail=100

# Check deployment status
kubectl rollout status deployment/multi-doc-chat

# Get service info
kubectl get svc multi-doc-chat-service

# Describe pod (for troubleshooting)
kubectl describe pod <pod-name>
```

### Access Application

```bash
# Get LoadBalancer URL
kubectl get svc multi-doc-chat-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Test health endpoint
curl http://<loadbalancer-url>/health
```

### Scaling

```bash
# Scale manually
kubectl scale deployment multi-doc-chat --replicas=4

# Check scaling
kubectl get deployment multi-doc-chat

# Enable autoscaling
kubectl autoscale deployment multi-doc-chat --min=2 --max=10 --cpu-percent=70
```

---

## 🐛 Troubleshooting

### Common Issues

#### 1. Infrastructure Pipeline Fails

**Error: "Stack already exists"**
- Solution: This is normal if re-running. Pipeline will update the existing stack.

**Error: "Insufficient IAM permissions"**
- Solution: Check that IAM user has all required policies attached
- Verify AWS credentials are correct in Jenkins

**Error: "Service quota exceeded"**
- Solution: Check AWS service limits
  - AWS Console → Service Quotas → Amazon EKS
  - Request limit increase if needed

**Error: "No default VPC available"**
- Solution: This is fine, the template creates its own VPC

#### 2. Deployment Pipeline Fails

**Error: "EKS Cluster not found"**
- Solution: Run `Jenkinsfile.infra` first to create infrastructure
- Verify `EKS_CLUSTER_NAME` environment variable is correct

**Error: "Cannot connect to Docker daemon"**
- Solution: Ensure Docker Desktop is running
- Check docker.sock is mounted in docker-compose.jenkins.yml

**Error: "ECR_REGISTRY not set"**
- Solution: Set the `ECR_REGISTRY` environment variable
  - Format: `<account-id>.dkr.ecr.<region>.amazonaws.com`
  - Get from infrastructure pipeline output

**Error: "ImagePullBackOff" in pods**
- Check ECR image exists: `aws ecr describe-images --repository-name multi-doc-chat`
- Verify node IAM role has ECR read permissions
- Check image URL in deployment.yaml matches ECR registry

**Error: "CrashLoopBackOff" in pods**
- Check pod logs: `kubectl logs <pod-name>`
- Verify environment variables (API keys) are set correctly
- Check application errors in logs

#### 3. LoadBalancer Issues

**External IP shows "<pending>"**
- Wait 2-5 minutes for AWS to provision LoadBalancer
- Check: `kubectl get svc multi-doc-chat-service -w`

**Cannot access LoadBalancer URL**
- Check security group allows inbound on port 80
- Verify pods are running: `kubectl get pods`
- Check pod health: `kubectl describe pod <pod-name>`

#### 4. Jenkins Issues

**Cannot access Jenkins at localhost:8083**
- Check Docker container is running: `docker ps | grep jenkins`
- Check logs: `docker logs jenkins-local`
- Restart: `docker restart jenkins-local`

**Pipeline stuck or slow**
- Check Jenkins system resources
- View Jenkins System Log: Manage Jenkins → System Log
- May need more Docker resources in Docker Desktop settings

### Debug Commands

```bash
# Check CloudFormation stack
aws cloudformation describe-stacks --stack-name multi-doc-chat-eks-stack

# Check EKS cluster
aws eks describe-cluster --name multi-doc-chat-cluster --region us-west-1

# Check ECR images
aws ecr describe-images --repository-name multi-doc-chat --region us-west-1

# Check Kubernetes resources
kubectl get all -n default

# Describe deployment
kubectl describe deployment multi-doc-chat

# Get pod events
kubectl get events --sort-by='.lastTimestamp' | head -20

# Test from inside cluster
kubectl run test --rm -it --image=busybox -- wget -O- http://multi-doc-chat-service
```

---

## 🔄 Migration to EC2

### Why Migrate?

**Local Docker (Current):**
- ✅ Good for development and learning
- ✅ Quick setup
- ❌ Jenkins stops when computer is off
- ❌ Not suitable for team collaboration
- ❌ Requires hardcoded AWS credentials

**EC2 Jenkins (Production):**
- ✅ Always available
- ✅ Team can access
- ✅ Uses IAM instance profile (more secure)
- ✅ Can receive GitHub webhooks
- ✅ Better for production workloads

### Migration Steps

#### 1. Backup Jenkins Configuration

```bash
# Create backup
docker exec jenkins-local tar czf /tmp/jenkins-backup.tar.gz /var/jenkins_home

# Copy to host
docker cp jenkins-local:/tmp/jenkins-backup.tar.gz ./jenkins-backup.tar.gz
```

#### 2. Launch EC2 Instance

**Instance Details:**
- AMI: Amazon Linux 2 or Ubuntu 20.04
- Instance Type: t3.medium (minimum)
- Storage: 30 GB GP3
- Security Group:
  - Port 22 (SSH) from your IP
  - Port 8080 (Jenkins UI) from your IP or 0.0.0.0/0
  - Port 443 (HTTPS) optional for secure access

**IAM Role:**
Create an IAM role with these policies:
- AmazonEC2FullAccess
- AmazonEKSClusterPolicy
- AmazonEKSServicePolicy
- AmazonEC2ContainerRegistryFullAccess
- AmazonVPCFullAccess
- IAMFullAccess
- CloudFormationFullAccess

Attach this role to the EC2 instance.

#### 3. Install Jenkins on EC2

```bash
# SSH into EC2
ssh -i your-key.pem ec2-user@<ec2-public-ip>

# Install Docker
sudo yum update -y
sudo yum install -y docker
sudo service docker start
sudo usermod -a -G docker ec2-user

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

#### 4. Deploy Jenkins on EC2

```bash
# Copy docker-compose file
# (Upload jenkins-backup.tar.gz and docker-compose.jenkins.yml)

# Run Jenkins
docker-compose -f docker-compose.jenkins.yml up -d

# Restore backup
docker cp jenkins-backup.tar.gz jenkins-local:/tmp/
docker exec jenkins-local tar xzf /tmp/jenkins-backup.tar.gz -C /
docker restart jenkins-local
```

#### 5. Update Environment Variables

Since EC2 has IAM role, you can:
- Remove `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` from Jenkins
- AWS CLI will automatically use the instance role
- Keep application secrets (API keys)

#### 6. Configure GitHub Webhooks (Optional)

For instant builds instead of polling:

1. **In Jenkins:**
   - Job → Configure → Build Triggers
   - ✅ GitHub hook trigger for GITScm polling

2. **In GitHub:**
   - Repository → Settings → Webhooks → Add webhook
   - Payload URL: `http://<ec2-public-ip>:8080/github-webhook/`
   - Content type: application/json
   - Events: Just the push event
   - ✅ Active

---

## 💰 Cost Optimization

### Monthly Cost Breakdown

**AWS Resources:**
- EKS Control Plane: $73/month (flat fee)
- 2 × t3.medium nodes: $60/month (~$30 each)
- LoadBalancer (Classic ELB): $18/month
- ECR Storage: $1-5/month (depends on images)
- Data Transfer: Variable

**Total: ~$150-160/month**

### Optimization Strategies

#### 1. Use Smaller Instances for Dev/Staging

```yaml
# In infra/eks-with-ecr.yaml, change:
NodeInstanceType: t3.small  # Instead of t3.medium
```

**Savings:** ~$30/month (t3.small is ~$15/month per instance)

#### 2. Scale Down When Not in Use

```bash
# Scale deployment to 0 (keeps infrastructure)
kubectl scale deployment multi-doc-chat --replicas=0

# Scale back up when needed
kubectl scale deployment multi-doc-chat --replicas=2
```

#### 3. Delete Stack When Not Needed

```bash
# Delete entire stack (most cost-effective)
aws cloudformation delete-stack --stack-name multi-doc-chat-eks-stack --region us-west-1

# Recreate when needed using Jenkinsfile.infra
```

**Savings:** All AWS costs (~$150/month)
**Note:** You'll lose all data and need to redeploy

#### 4. Use Spot Instances for Node Group

```yaml
# In CloudFormation template, add to NodeGroup:
CapacityType: SPOT
```

**Savings:** Up to 70% on EC2 costs
**Tradeoff:** Pods may be evicted if spot instances reclaimed

#### 5. Set Up AWS Budget Alerts

```bash
# AWS Console → Billing → Budgets → Create budget
# Set threshold: $200/month
# Get email alerts when approaching limit
```

#### 6. Clean Up Old ECR Images

```bash
# List images
aws ecr list-images --repository-name multi-doc-chat

# Delete old images
aws ecr batch-delete-image \
  --repository-name multi-doc-chat \
  --image-ids imageTag=<old-tag>
```

**Savings:** $0.10/GB/month storage

---

## 🆚 Comparison: Jenkins vs GitHub Actions

| Feature | Jenkins (This Setup) | GitHub Actions |
|---------|---------------------|----------------|
| **Cost** | Free (self-hosted) | 2000 min/month free |
| **Control** | Full control | Limited to GH infrastructure |
| **Setup Complexity** | Moderate (Docker/EC2) | Easy (built-in) |
| **Customization** | Unlimited | Limited by runners |
| **Secret Management** | Environment variables | GitHub Secrets |
| **Build Environment** | Your infrastructure | GitHub runners |
| **Private Runners** | Yes (your machines) | Yes (extra cost) |
| **Integration** | Plugins needed | Native GitHub |
| **Logs Retention** | Forever (your storage) | 90 days (free tier) |
| **Migration** | Can move to any platform | Locked to GitHub |
| **Best For** | Complex builds, on-prem, learning | Quick setup, GitHub-native |

**Why We Use Jenkins:**
- ✅ Learn industry-standard CI/CD tool
- ✅ Full control over build environment
- ✅ No limits on build minutes
- ✅ Can run on EC2 with IAM roles (more secure)
- ✅ Transferable skills to any organization

---

## 📚 Additional Resources

### Official Documentation
- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Docker Documentation](https://docs.docker.com/)

### Tutorials
- [Jenkins Pipeline Tutorial](https://www.jenkins.io/doc/book/pipeline/)
- [EKS Workshop](https://www.eksworkshop.com/)
- [Kubernetes Basics](https://kubernetes.io/docs/tutorials/kubernetes-basics/)

### Community
- [Jenkins Community](https://www.jenkins.io/participate/)
- [Kubernetes Slack](https://slack.k8s.io/)
- [AWS Forums](https://forums.aws.amazon.com/)

---

## 📝 Daily Operations Cheat Sheet

```bash
# Start Jenkins
docker compose -f docker-compose.jenkins.yml up -d

# Stop Jenkins
docker compose -f docker-compose.jenkins.yml stop

# View Jenkins logs
docker logs -f jenkins-local

# Access Jenkins
open http://localhost:8083

# Check deployment
kubectl get pods -l app=multi-doc-chat

# View logs
kubectl logs -l app=multi-doc-chat -f

# Get service URL
kubectl get svc multi-doc-chat-service

# Scale application
kubectl scale deployment multi-doc-chat --replicas=3

# Rollback deployment
kubectl rollout undo deployment/multi-doc-chat

# Delete infrastructure
aws cloudformation delete-stack --stack-name multi-doc-chat-eks-stack
```

---

## ✅ Success Checklist

- [ ] Jenkins running at localhost:8083
- [ ] AWS credentials configured in Jenkins
- [ ] Infrastructure pipeline created
- [ ] Deployment pipeline created
- [ ] Infrastructure provisioned successfully (ran Jenkinsfile.infra)
- [ ] Application deployed successfully (ran Jenkinsfile.deploy)
- [ ] LoadBalancer has external IP
- [ ] Application accessible via browser
- [ ] Health endpoint returns 200 OK
- [ ] Can view pod logs
- [ ] SCM polling working (automatic builds)

---

**Last Updated:** October 23, 2025  
**Version:** 1.0  
**Project:** MultiDocChat  
**Deployment:** Jenkins + AWS EKS + ECR + CloudFormation

**Happy Deploying! 🚀**

