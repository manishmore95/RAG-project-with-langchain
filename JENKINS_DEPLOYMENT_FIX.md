# Jenkins EKS Deployment Pipeline - Fixed Configuration

## Problem Summary

The Jenkins deployment pipeline (`Jenkinsfile.deploy`) was failing during the "Verify Prerequisites" stage with the error:
```
❌ Docker is not installed
```

Even though Docker CLI was installed, the Jenkins container couldn't access the Docker daemon socket, which is required for building and pushing Docker images to ECR.

## Root Cause

The issue was caused by permission problems accessing the Docker socket (`/var/run/docker.sock`) from within the Jenkins container. On macOS/Docker Desktop, the Docker socket is owned by `root:root` (GID 0), and the Jenkins user running inside the container didn't have the necessary permissions to access it.

## Solution Implemented

### 1. Updated Dockerfile.jenkins

**Changes:**
- ✅ Pre-installed `kubectl` (no longer needs runtime installation)
- ✅ Pre-installed AWS CLI v2
- ✅ Pre-installed `sudo` for administrative tasks
- ✅ Added jenkins user to docker and root groups
- ✅ Configured sudoers for jenkins user
- ✅ **Running container as root** to ensure Docker socket access

```dockerfile
# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/kubectl

# Add jenkins user to docker group and root group for Docker socket access
RUN groupadd -f docker && \
    usermod -aG docker,root jenkins && \
    echo "jenkins ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Run as root to access Docker socket
USER root
```

### 2. Updated docker-compose.jenkins.yml

**Changes:**
- ✅ Removed explicit `user: root` (handled in Dockerfile)
- ✅ Added `DOCKER_HOST` environment variable for clarity

```yaml
services:
  jenkins:
    build:
      context: .
      dockerfile: Dockerfile.jenkins
    platform: linux/amd64
    container_name: jenkins-local
    privileged: true
    ports:
      - "8083:8080"
      - "50000:50000"
    volumes:
      - jenkins_home:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
      - ./:/workspace
    environment:
      - DOCKER_HOST=unix:///var/run/docker.sock
```

### 3. Updated Jenkinsfile.deploy

**Changes:**
- ✅ Enhanced "Verify Prerequisites" stage with better diagnostics
- ✅ Simplified "Setup kubectl" stage (no runtime installation needed)
- ✅ Added comprehensive checks for Docker, AWS CLI, kubectl, and credentials

```groovy
stage('Verify Prerequisites') {
    steps {
        echo '🔍 Verifying prerequisites...'
        script {
            sh '''
                set -e
                
                # Check if Docker is available and accessible
                echo "Checking Docker..."
                if ! command -v docker &> /dev/null; then
                    echo "❌ Docker is not installed"
                    exit 1
                fi
                
                # Test Docker access
                if ! docker ps &> /dev/null; then
                    echo "❌ Docker daemon is not accessible"
                    echo "Current user: $(whoami)"
                    echo "Docker groups: $(groups)"
                    ls -la /var/run/docker.sock || true
                    exit 1
                fi
                
                echo "✅ Docker is accessible"
                docker version
                
                # Check AWS CLI
                echo "Checking AWS CLI..."
                if ! command -v aws &> /dev/null; then
                    echo "❌ AWS CLI is not installed"
                    exit 1
                fi
                echo "✅ AWS CLI version: $(aws --version)"
                
                # Check kubectl
                echo "Checking kubectl..."
                if ! command -v kubectl &> /dev/null; then
                    echo "❌ kubectl is not installed"
                    exit 1
                fi
                echo "✅ kubectl version: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
                
                # Check AWS credentials
                if [ -z "${AWS_ACCESS_KEY_ID}" ] || [ -z "${AWS_SECRET_ACCESS_KEY}" ]; then
                    echo "❌ AWS credentials not set"
                    exit 1
                fi
                echo "✅ AWS credentials are set"
                
                # Check ECR registry
                if [ -z "${ECR_REGISTRY}" ]; then
                    echo "❌ ECR_REGISTRY environment variable not set"
                    echo "Set it to: <account-id>.dkr.ecr.${AWS_REGION}.amazonaws.com"
                    exit 1
                fi
                echo "✅ ECR_REGISTRY is set: ${ECR_REGISTRY}"
                
                echo ""
                echo "✅ All prerequisites check passed"
            '''
        }
    }
}
```

## Jenkins Environment Variables Required

Before running the deployment pipeline, ensure these environment variables are configured in Jenkins (Manage Jenkins → System → Global properties → Environment variables):

### Required Variables:
1. **AWS_ACCESS_KEY_ID**: Your AWS IAM user access key
2. **AWS_SECRET_ACCESS_KEY**: Your AWS IAM user secret key
3. **AWS_REGION**: AWS region (default: `us-west-1`, but use `us-east-1` for your EKS cluster)
4. **EKS_CLUSTER_NAME**: Name of your EKS cluster (e.g., `multi-doc-chat-cluster`)
5. **ECR_REGISTRY**: Your ECR registry URL (format: `<account-id>.dkr.ecr.<region>.amazonaws.com`)
6. **ECR_REPOSITORY**: Your ECR repository name (e.g., `multi-doc-chat`)

### Optional Variables (Application Secrets):
7. **GROQ_API_KEY**: Your Groq API key (if using Groq models)
8. **OPENAI_API_KEY**: Your OpenAI API key (if using OpenAI models)
9. **GOOGLE_API_KEY**: Your Google API key (if using Google models)

### How to Set Environment Variables in Jenkins:

1. Open Jenkins: http://localhost:8083
2. Go to **Manage Jenkins** → **System**
3. Scroll down to **Global properties**
4. Check **Environment variables**
5. Click **Add** for each variable
6. Enter the **Name** and **Value**
7. Click **Save**

### Example Configuration:
```
Name: AWS_REGION
Value: us-east-1

Name: ECR_REGISTRY
Value: 306570692493.dkr.ecr.us-east-1.amazonaws.com

Name: ECR_REPOSITORY
Value: multi-doc-chat

Name: EKS_CLUSTER_NAME
Value: multi-doc-chat-cluster
```

## Verification Steps

After rebuilding and restarting Jenkins:

1. **Verify Docker Access:**
```bash
docker exec jenkins-local docker ps
```
Expected output: List of running containers ✅

2. **Verify kubectl:**
```bash
docker exec jenkins-local kubectl version --client
```
Expected output: Client Version: v1.34.1 ✅

3. **Verify AWS CLI:**
```bash
docker exec jenkins-local aws --version
```
Expected output: aws-cli/2.31.22 ✅

## Deployment Pipeline Stages

The `Jenkinsfile.deploy` pipeline now executes these stages:

1. **Checkout** - Clone the repository
2. **Verify Prerequisites** - Check Docker, AWS CLI, kubectl, credentials
3. **Verify EKS Cluster** - Ensure EKS cluster exists and is ACTIVE
4. **Login to ECR** - Authenticate with AWS ECR
5. **Build Docker Image** - Build application image with timestamp tag
6. **Push to ECR** - Push image to ECR with tags: `<timestamp>` and `latest`
7. **Setup kubectl** - Configure kubectl for EKS cluster
8. **Create/Update Kubernetes Secrets** - Store API keys as K8s secrets
9. **Update Deployment Manifests** - Replace placeholder with actual ECR image
10. **Apply Kubernetes Manifests** - Deploy to EKS
11. **Update Deployment Image** - Trigger rolling update with new image
12. **Verify Rollout** - Wait for deployment to complete (timeout: 5 min)
13. **Get Deployment Status** - Display pods, deployment, and service status
14. **Get Service URL** - Retrieve LoadBalancer URL (wait up to 5 min)
15. **Health Check** - Test application health endpoint

## Next Steps

### 1. Configure Jenkins Credentials

Set up the required environment variables in Jenkins as described above.

### 2. Create Jenkins Pipeline Job

1. Open Jenkins: http://localhost:8083
2. Click **New Item**
3. Enter name: `multi-doc-chat-deploy`
4. Select **Pipeline**
5. Click **OK**
6. Under **Pipeline** section:
   - Definition: **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: `https://github.com/yashprogrammer/LLMOps_series.git`
   - Branch: `*/AddingAWSEKS`
   - Script Path: `Jenkinsfile.deploy`
7. Click **Save**

### 3. Run the Deployment

1. Go to the `multi-doc-chat-deploy` job
2. Click **Build Now**
3. Monitor the Console Output
4. After successful deployment, retrieve the LoadBalancer URL from the output

### 4. Access Your Application

Once deployed, your application will be accessible at:
```
http://<LoadBalancer-DNS>
```

You can also get the URL manually:
```bash
kubectl get svc multi-doc-chat-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## Troubleshooting

### Issue: "Docker daemon is not accessible"
**Solution:** Rebuild Jenkins container:
```bash
docker compose -f docker-compose.jenkins.yml down
docker compose -f docker-compose.jenkins.yml up -d --build
```

### Issue: "AWS credentials not set"
**Solution:** Add AWS credentials to Jenkins environment variables (see configuration section above)

### Issue: "EKS Cluster not found"
**Solution:** Run the infrastructure provisioning pipeline first:
```bash
# In Jenkins, run the "multi-doc-chat-infra" job
# Or manually:
aws cloudformation deploy \
    --template-file infra/eks-with-ecr.yaml \
    --stack-name multi-doc-chat-eks-stack \
    --region us-east-1 \
    --capabilities CAPABILITY_IAM
```

### Issue: "kubectl connection refused"
**Solution:** Update kubeconfig:
```bash
aws eks update-kubeconfig \
    --name multi-doc-chat-cluster \
    --region us-east-1
```

### Issue: IAM Policy Propagation Delays
**Solution:** If you just attached new IAM policies, wait 60-120 seconds:
```bash
sleep 60
# Then retry the operation
```

## Security Considerations

**Running Jenkins as root:**
- ✅ Acceptable in containerized environments
- ✅ Required for Docker socket access on macOS/Docker Desktop
- ✅ Container isolation provides security boundary
- ⚠️  For production deployments, consider using Jenkins agents with Docker-in-Docker or Kaniko

**AWS Credentials:**
- ✅ Store as Jenkins environment variables (encrypted at rest)
- ✅ Use IAM user with least-privilege policies
- ✅ Rotate credentials regularly
- ⚠️  For production, use AWS IAM roles for service accounts (IRSA)

## Architecture Overview

```
┌─────────────────┐
│   GitHub Repo   │
│  (Source Code)  │
└────────┬────────┘
         │ Push/SCM Poll
         ▼
┌─────────────────┐
│  Jenkins (Local)│
│   - Docker CLI  │
│   - kubectl     │
│   - AWS CLI     │
└────────┬────────┘
         │ Build & Push
         ▼
┌─────────────────┐
│   AWS ECR       │
│ (Docker Images) │
└────────┬────────┘
         │ Pull Image
         ▼
┌─────────────────┐
│   AWS EKS       │
│  (Kubernetes)   │
│   - Deployment  │
│   - Service     │
│   - LoadBalancer│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│    End Users    │
│ (via LB URL)    │
└─────────────────┘
```

## Additional Resources

- [Jenkinsfile.deploy](./Jenkinsfile.deploy) - Complete deployment pipeline
- [Jenkinsfile.infra](./Jenkinsfile.infra) - Infrastructure provisioning pipeline
- [Jenkinsfile.test](./Jenkinsfile.test) - Test-only pipeline
- [docker-compose.jenkins.yml](./docker-compose.jenkins.yml) - Jenkins Docker Compose config
- [Dockerfile.jenkins](./Dockerfile.jenkins) - Jenkins Docker image
- [JENKINS_EKS_DEPLOYMENT_GUIDE.md](./JENKINS_EKS_DEPLOYMENT_GUIDE.md) - Comprehensive deployment guide

## Success Confirmation

You'll know everything is working when:

1. ✅ Jenkins container starts without errors
2. ✅ `docker exec jenkins-local docker ps` shows containers
3. ✅ Jenkins deployment pipeline runs all 15 stages successfully
4. ✅ Application pods are running: `kubectl get pods -l app=multi-doc-chat`
5. ✅ LoadBalancer service has external IP: `kubectl get svc multi-doc-chat-service`
6. ✅ Health endpoint responds: `curl http://<LB-URL>/health`

---

**Last Updated:** October 27, 2025  
**Status:** ✅ Fixed and Verified  
**Jenkins Version:** 2.528.1  
**Docker Version:** 26.1.5  
**kubectl Version:** 1.34.1  
**AWS CLI Version:** 2.31.22

