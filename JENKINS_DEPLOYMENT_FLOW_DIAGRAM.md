# 📊 Jenkins-Based Deployment Flow Diagrams

Visual representation of the complete Jenkins CI/CD deployment process for MultiDocChat.

---

## 🏗️ Complete Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                      DEVELOPER WORKFLOW                              │
│                                                                      │
│  Developer → Git Push → GitHub Repository (main branch)             │
└────────────────────────┬────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    JENKINS CI/CD SERVER                              │
│                 (Local Docker or EC2 Instance)                       │
│                                                                      │
│  ┌──────────────────────┐         ┌────────────────────┐           │
│  │  Jenkinsfile.infra   │         │  Jenkinsfile.deploy│           │
│  │  (Manual Trigger)    │         │  (Auto/Manual)     │           │
│  │                      │         │                    │           │
│  │  • Checkout Code     │         │  • Checkout Code   │           │
│  │  • Validate CF       │         │  • Verify EKS      │           │
│  │  • Deploy Stack      │         │  • Login ECR       │           │
│  │  • Verify Infra      │         │  • Build Docker    │           │
│  └─────────┬────────────┘         │  • Push to ECR     │           │
│            │                      │  • Setup kubectl   │           │
│            │                      │  • Create Secrets  │           │
│            │                      │  • Apply Manifests │           │
│            │                      │  • Rolling Update  │           │
│            │                      └──────────┬─────────┘           │
└────────────┼─────────────────────────────────┼─────────────────────┘
             │                                 │
             ▼                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          AWS CLOUD                                   │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                 CloudFormation Stack                          │  │
│  │                                                               │  │
│  │  Creates:                                                     │  │
│  │  ├── VPC (10.0.0.0/16)                                       │  │
│  │  ├── Internet Gateway                                        │  │
│  │  ├── 2 Public Subnets (Multi-AZ)                            │  │
│  │  ├── Route Tables                                            │  │
│  │  ├── Security Groups                                         │  │
│  │  ├── IAM Roles (EKS + NodeGroup)                            │  │
│  │  ├── ECR Repository                                          │  │
│  │  ├── EKS Cluster (Control Plane)                            │  │
│  │  └── EKS NodeGroup (EC2 Workers)                            │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                    Amazon ECR                                 │  │
│  │                                                               │  │
│  │  ┌─────────────────────────────────────────────────┐        │  │
│  │  │  multi-doc-chat Repository                      │        │  │
│  │  │  ├── Image: multi-doc-chat:1729756800          │        │  │
│  │  │  ├── Image: multi-doc-chat:1729757400          │        │  │
│  │  │  └── Image: multi-doc-chat:latest              │        │  │
│  │  └─────────────────────────────────────────────────┘        │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │              Amazon EKS Cluster                               │  │
│  │                                                               │  │
│  │  Control Plane (Managed by AWS)                              │  │
│  │  ├── API Server                                              │  │
│  │  ├── Scheduler                                               │  │
│  │  ├── Controller Manager                                      │  │
│  │  └── etcd                                                    │  │
│  │                                                               │  │
│  │  ┌────────────────────────────────────────────────────────┐ │  │
│  │  │            Worker Node Group                           │ │  │
│  │  │                                                        │ │  │
│  │  │  ┌──────────────────┐    ┌──────────────────┐        │ │  │
│  │  │  │   EC2 Instance   │    │   EC2 Instance   │        │ │  │
│  │  │  │   (t3.medium)    │    │   (t3.medium)    │        │ │  │
│  │  │  │                  │    │                  │        │ │  │
│  │  │  │  ┌────────────┐  │    │  ┌────────────┐  │        │ │  │
│  │  │  │  │   Pod 1    │  │    │  │   Pod 2    │  │        │ │  │
│  │  │  │  │            │  │    │  │            │  │        │ │  │
│  │  │  │  │  FastAPI   │  │    │  │  FastAPI   │  │        │ │  │
│  │  │  │  │  Uvicorn   │  │    │  │  Uvicorn   │  │        │ │  │
│  │  │  │  │  RAG App   │  │    │  │  RAG App   │  │        │ │  │
│  │  │  │  │            │  │    │  │            │  │        │ │  │
│  │  │  │  │  Port 8080 │  │    │  │  Port 8080 │  │        │ │  │
│  │  │  │  └────────────┘  │    │  └────────────┘  │        │ │  │
│  │  │  └──────────────────┘    └──────────────────┘        │ │  │
│  │  └────────────────────────────────────────────────────────┘ │  │
│  │                                                               │  │
│  │  ┌────────────────────────────────────────────────────────┐ │  │
│  │  │              Kubernetes Services                       │ │  │
│  │  │                                                        │ │  │
│  │  │  ┌──────────────────────────────────────────┐        │ │  │
│  │  │  │  Service: multi-doc-chat-service         │        │ │  │
│  │  │  │  Type: LoadBalancer                      │        │ │  │
│  │  │  │  Port: 80 → 8080                         │        │ │  │
│  │  │  └──────────────┬───────────────────────────┘        │ │  │
│  │  │                 │                                     │ │  │
│  │  │                 ▼                                     │ │  │
│  │  │  ┌─────────────────────────────────────────┐         │ │  │
│  │  │  │      AWS Elastic Load Balancer          │         │ │  │
│  │  │  │  External IP: a1b2c3.elb.amazonaws.com  │         │ │  │
│  │  │  └──────────────┬──────────────────────────┘         │ │  │
│  │  └─────────────────┼──────────────────────────────────┘ │  │
│  │                    │                                      │  │
│  │  ┌─────────────────┼──────────────────────────────────┐ │  │
│  │  │  Kubernetes Secrets                   │            │ │  │
│  │  │  ├── GROQ_API_KEY                     │            │ │  │
│  │  │  ├── OPENAI_API_KEY                   │            │ │  │
│  │  │  └── GOOGLE_API_KEY                   │            │ │  │
│  │  └────────────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────────────────┘  │
└──────────────────────────┬───────────────────────────────────────────┘
                           │
                           ▼
                  ┌─────────────────┐
                  │   End Users     │
                  │  (via Browser)  │
                  └─────────────────┘
```

---

## 🔄 Workflow 1: Infrastructure Provisioning Flow (Jenkinsfile.infra)

```
START: Developer triggers "Infrastructure Pipeline" job manually in Jenkins
  │
  ├─► Stage 1: Checkout Repository
  │     └─► Actions: Pulls code from Git
  │
  ├─► Stage 2: Validate CloudFormation Template
  │     ├─► Checks: infra/eks-with-ecr.yaml exists
  │     └─► Validates: Template syntax with AWS CLI
  │
  ├─► Stage 3: Check Existing Stack
  │     ├─► Checks: If stack already exists
  │     └─► Decides: Create or Update
  │
  ├─► Stage 4: Deploy CloudFormation Stack
  │     ├─► Action: aws cloudformation deploy
  │     ├─► Template: infra/eks-with-ecr.yaml
  │     ├─► Stack Name: multi-doc-chat-eks-stack
  │     ├─► Parameters: ClusterName, InstanceType, Capacity, etc.
  │     └─► Capabilities: CAPABILITY_IAM
  │
  └─► Stage 5: CloudFormation Creates Resources (20-30 min):
        │
        ├─► Phase 1: Networking (5-10 min)
        │     ├─► VPC (10.0.0.0/16)
        │     ├─► Internet Gateway
        │     ├─► 2 Public Subnets
        │     ├─► Route Tables
        │     └─► Security Groups
        │
        ├─► Phase 2: IAM (2-3 min)
        │     ├─► EKS Cluster Role
        │     └─► NodeGroup Role
        │
        ├─► Phase 3: ECR (1 min)
        │     └─► ECR Repository: multi-doc-chat
        │
        ├─► Phase 4: EKS Cluster (10-15 min)
        │     └─► Control Plane Setup
        │
        └─► Phase 5: NodeGroup (5-10 min)
              ├─► Launch 2 EC2 instances (t3.medium)
              ├─► Join cluster
              └─► Install CNI, kube-proxy
        │
        ▼
  ┌─► Stage 6: Wait for Stack Completion
  │     └─► aws cloudformation wait stack-create-complete
  │
  ├─► Stage 7: Verify Infrastructure
  │     ├─► Check EKS Cluster status (should be ACTIVE)
  │     ├─► Verify ECR Repository exists
  │     └─► Check NodeGroup status (should be ACTIVE)
  │
  └─► Stage 8: Display Stack Outputs
        └─► Outputs:
              ├─► Cluster Name
              ├─► Cluster Endpoint
              ├─► ECR Repository URI
              ├─► VPC ID
              └─► Security Group ID

END: Infrastructure provisioned successfully
     Next: Update ECR_REGISTRY env var and run deployment pipeline
```

---

## 🚀 Workflow 2: Application Deployment Flow (Jenkinsfile.deploy)

```
TRIGGER: Git push to main branch (SCM poll) OR Manual trigger
  │
  ├─► Stage 1: Checkout Code
  │     └─► Pulls latest code from repository
  │
  ├─► Stage 2: Verify Prerequisites
  │     ├─► Check: Docker available
  │     ├─► Check: AWS credentials set
  │     └─► Check: ECR_REGISTRY configured
  │
  ├─► Stage 3: Verify EKS Cluster
  │     ├─► Command: aws eks describe-cluster
  │     └─► If not found: FAIL (run infra pipeline first)
  │
  ├─► Stage 4: Login to ECR
  │     ├─► Gets ECR login token
  │     └─► Configures Docker to use ECR
  │
  ├─► Stage 5: Generate Image Tag
  │     ├─► Creates timestamp: $(date +%s)
  │     └─► Example: 1729756800
  │
  ├─► Stage 6: Build Docker Image
  │     │
  │     ├─► FROM python:3.12-slim
  │     │     └─► Base image (~50MB)
  │     │
  │     ├─► Install system dependencies
  │     │     └─► build-essential, poppler-utils, curl
  │     │
  │     ├─► Install uv (Python package manager)
  │     │     └─► Fast dependency resolution
  │     │
  │     ├─► COPY requirements.txt
  │     │     └─► Dependency file (layer caching)
  │     │
  │     ├─► RUN uv pip install -r requirements.txt
  │     │     ├─► fastapi, langchain, uvicorn
  │     │     ├─► langchain-groq, langchain-openai
  │     │     ├─► faiss-cpu, docx2txt
  │     │     └─► All dependencies
  │     │
  │     ├─► COPY . .
  │     │     └─► Application code
  │     │
  │     ├─► EXPOSE 8080
  │     │     └─► Document port
  │     │
  │     └─► CMD
  │           └─► Start Uvicorn with FastAPI on port 8080
  │
  ├─► Stage 7: Tag Image
  │     ├─► Tag 1: <registry>/<repo>:1729756800 (timestamped)
  │     └─► Tag 2: <registry>/<repo>:latest
  │
  ├─► Stage 8: Push to ECR
  │     ├─► Push timestamped image
  │     └─► Push latest image
  │
  ├─► Stage 9: Setup kubectl
  │     ├─► Install kubectl (if not present)
  │     └─► Update kubeconfig for EKS
  │           └─► Command: aws eks update-kubeconfig
  │
  ├─► Stage 10: Create/Update Kubernetes Secrets
  │     ├─► kubectl create secret generic multi-doc-chat-secrets
  │     ├─► Adds: GROQ_API_KEY
  │     ├─► Adds: OPENAI_API_KEY
  │     ├─► Adds: GOOGLE_API_KEY
  │     └─► Uses: --dry-run=client -o yaml | kubectl apply -f -
  │           └─► Effect: Updates if exists, creates if not
  │
  ├─► Stage 11: Update Deployment Manifests
  │     └─► Replace <ECR_REGISTRY>/<ECR_REPOSITORY> with actual values
  │
  ├─► Stage 12: Apply Kubernetes Manifests
  │     │
  │     ├─► Apply k8/deployment.yaml
  │     │     ├─► Name: multi-doc-chat
  │     │     ├─► Replicas: 2
  │     │     ├─► Image: (will be updated next stage)
  │     │     ├─► Port: 8080
  │     │     └─► Env vars from secrets
  │     │
  │     └─► Apply k8/service.yaml
  │           ├─► Name: multi-doc-chat-service
  │           ├─► Type: LoadBalancer
  │           ├─► External Port: 80
  │           └─► Target Port: 8080
  │                 └─► AWS creates ELB automatically
  │
  ├─► Stage 13: Update Deployment Image
  │     ├─► Command: kubectl set image deployment/multi-doc-chat
  │     ├─► New Image: <registry>/<repo>:1729756800
  │     │
  │     └─► Kubernetes Rolling Update:
  │           │
  │           ├─► Create new pod with new image
  │           │     └─► Wait for pod to be ready (health checks)
  │           │
  │           ├─► Shift traffic to new pod
  │           │     └─► Service routes requests
  │           │
  │           ├─► Create second new pod
  │           │     └─► Wait for pod to be ready
  │           │
  │           ├─► Shift traffic to second new pod
  │           │
  │           └─► Terminate old pods
  │                 └─► Zero downtime!
  │
  ├─► Stage 14: Verify Rollout
  │     ├─► Command: kubectl rollout status deployment/multi-doc-chat
  │     ├─► Timeout: 300 seconds (5 minutes)
  │     │
  │     ├─► If Success: ✅ Continue
  │     │
  │     └─► If Failure:
  │           ├─► Show deployment details
  │           ├─► List pods
  │           ├─► Show pod logs
  │           └─► Exit 1 (pipeline fails)
  │
  ├─► Stage 15: Get Deployment Status
  │     ├─► Display: Deployment status
  │     ├─► Display: Pod list with IPs
  │     └─► Display: Service details
  │
  ├─► Stage 16: Get Service URL
  │     ├─► Command: kubectl get svc multi-doc-chat-service
  │     ├─► Wait: Up to 5 minutes for LoadBalancer IP
  │     │
  │     └─► Output:
  │           ├─► Service Name
  │           ├─► Type: LoadBalancer
  │           ├─► External IP/DNS
  │           └─► Ports: 80:8080
  │
  └─► Stage 17: Health Check
        ├─► Get LoadBalancer URL
        ├─► Test: curl http://<url>/health
        └─► Expected: {"status": "ok"}

END: Application deployed successfully
     └─► Access at: http://<EXTERNAL-IP>
```

---

## 📊 Request Flow: User to Application

```
User Browser
  │
  │  HTTP GET http://a1b2c3.elb.amazonaws.com/
  │
  ▼
┌─────────────────────────────────────┐
│   AWS Elastic Load Balancer         │
│   (Created by K8s Service)          │
│   - Health checks pods              │
│   - Distributes traffic             │
└──────────────┬──────────────────────┘
               │
               │  Forwards to healthy pods
               │
         ┌─────┴─────┐
         │           │
         ▼           ▼
    ┌────────┐  ┌────────┐
    │ Pod 1  │  │ Pod 2  │
    │        │  │        │
    │ Port   │  │ Port   │
    │ 8080   │  │ 8080   │
    └────┬───┘  └───┬────┘
         │          │
         │          │
         ▼          ▼
    ┌──────────────────────┐
    │   Uvicorn Server     │
    │   (ASGI server)      │
    └──────────┬───────────┘
               │
               ▼
    ┌──────────────────────┐
    │   FastAPI App        │
    │   (main.py)          │
    └──────────┬───────────┘
               │
               ▼
    ┌──────────────────────┐
    │  MultiDocChat        │
    │  Application Logic   │
    └──────────┬───────────┘
               │
         ┌─────┴─────┐
         │           │
         ▼           ▼
    ┌─────────┐  ┌──────────┐
    │  FAISS  │  │  LLM     │
    │  Vector │  │  APIs    │
    │  Store  │  │ (Groq/   │
    │ (Local) │  │ OpenAI)  │
    └─────────┘  └──────────┘
         │
         └──► RAG Response
         
               │
               ▼
         Response flows back
               │
               ▼
         HTML rendered in browser
```

---

## 🔄 Rolling Update Process (Detailed)

```
Initial State:
┌────────────────────────────────────────┐
│  LoadBalancer                          │
└──────────┬─────────────────────────────┘
           │
     ┌─────┴─────┐
     │           │
     ▼           ▼
┌─────────┐ ┌─────────┐
│ Pod 1   │ │ Pod 2   │
│ v1.0    │ │ v1.0    │  ← Old version
│ (8080)  │ │ (8080)  │
└─────────┘ └─────────┘


Step 1: Create first new pod (maxSurge: 1)
┌────────────────────────────────────────┐
│  LoadBalancer                          │
└──────────┬─────────────────────────────┘
           │
     ┌─────┼─────┬─────┐
     │     │     │     │
     ▼     ▼     ▼     ▼
┌─────────┐ ┌─────────┐ ┌─────────┐
│ Pod 1   │ │ Pod 2   │ │ Pod 3   │
│ v1.0    │ │ v1.0    │ │ v1.1    │  ← New pod starting
│ (8080)  │ │ (8080)  │ │ (8080)  │
└─────────┘ └─────────┘ └─────────┘
                        (Not ready - health check pending)


Step 2: New pod passes health checks and ready
┌────────────────────────────────────────┐
│  LoadBalancer                          │
└──────────┬─────────────────────────────┘
           │
     ┌─────┼─────┬─────┐
     │     │     │     │
     ▼     ▼     ▼     ▼
┌─────────┐ ┌─────────┐ ┌─────────┐
│ Pod 1   │ │ Pod 2   │ │ Pod 3   │
│ v1.0    │ │ v1.0    │ │ v1.1    │  ← Receiving traffic
│ (8080)  │ │ (8080)  │ │ (8080)  │
└─────────┘ └─────────┘ └─────────┘
                        ✅ Ready!


Step 3: Terminate one old pod (maxUnavailable: 0)
┌────────────────────────────────────────┐
│  LoadBalancer                          │
└──────────┬─────────────────────────────┘
           │
     ┌─────┴─────┬─────┐
     │           │     │
     ▼           ▼     ▼
             ┌─────────┐ ┌─────────┐
             │ Pod 2   │ │ Pod 3   │
             │ v1.0    │ │ v1.1    │
             │ (8080)  │ │ (8080)  │
             └─────────┘ └─────────┘
             Still 2 replicas maintained!


Step 4: Create second new pod
┌────────────────────────────────────────┐
│  LoadBalancer                          │
└──────────┬─────────────────────────────┘
           │
     ┌─────┼─────┬─────┬─────┐
     │     │     │     │     │
     ▼     ▼     ▼     ▼     ▼
         ┌─────────┐ ┌─────────┐ ┌─────────┐
         │ Pod 2   │ │ Pod 3   │ │ Pod 4   │
         │ v1.0    │ │ v1.1    │ │ v1.1    │  ← New pod starting
         │ (8080)  │ │ (8080)  │ │ (8080)  │
         └─────────┘ └─────────┘ └─────────┘
                                 (Not ready - health check pending)


Step 5: Second new pod ready
┌────────────────────────────────────────┐
│  LoadBalancer                          │
└──────────┬─────────────────────────────┘
           │
     ┌─────┼─────┬─────┬─────┐
     │     │     │     │     │
     ▼     ▼     ▼     ▼     ▼
         ┌─────────┐ ┌─────────┐ ┌─────────┐
         │ Pod 2   │ │ Pod 3   │ │ Pod 4   │
         │ v1.0    │ │ v1.1    │ │ v1.1    │  ← Both new receiving traffic
         │ (8080)  │ │ (8080)  │ │ (8080)  │
         └─────────┘ └─────────┘ └─────────┘
                                 ✅ Ready!


Final State: Terminate last old pod
┌────────────────────────────────────────┐
│  LoadBalancer                          │
└──────────┬─────────────────────────────┘
           │
     ┌─────┴─────┐
     │           │
     ▼           ▼
┌─────────┐ ┌─────────┐
│ Pod 3   │ │ Pod 4   │
│ v1.1    │ │ v1.1    │  ← Update complete!
│ (8080)  │ │ (8080)  │
└─────────┘ └─────────┘

✅ Zero downtime achieved
✅ Traffic always routed to healthy pods (health checks passed)
✅ Can rollback: kubectl rollout undo deployment/multi-doc-chat
```

---

## 🎯 Decision Flow: Jenkins Pipeline Troubleshooting

```
Deployment Failed?
  │
  ├─► Is infra provisioned?
  │     ├─ No → Run Jenkinsfile.infra job
  │     └─ Yes → Continue
  │
  ├─► Does EKS cluster exist?
  │     ├─ No → Check CloudFormation stack status
  │     │       └─► View stack events in AWS Console
  │     └─ Yes → Continue
  │
  ├─► Does ECR image exist?
  │     ├─ No → Check Docker build stage logs in Jenkins
  │     │       └─► Check Dockerfile syntax
  │     └─ Yes → Continue
  │
  ├─► Is ECR_REGISTRY env var set?
  │     ├─ No → Set in Jenkins environment variables
  │     │       Format: <account-id>.dkr.ecr.<region>.amazonaws.com
  │     └─ Yes → Continue
  │
  ├─► Are pods running?
  │     ├─ No → Check pod events
  │     │       └─► ImagePullBackOff?
  │     │             ├─ Check image name matches ECR
  │     │             └─ Check IAM permissions
  │     │       └─► CrashLoopBackOff?
  │     │             ├─ Check application logs: kubectl logs
  │     │             └─ Check environment variables/secrets
  │     └─ Yes → Continue
  │
  ├─► Is service created?
  │     ├─ No → Check service manifest
  │     │       └─► Run: kubectl describe svc
  │     └─ Yes → Continue
  │
  ├─► Does LoadBalancer have external IP?
  │     ├─ No (pending) → Wait 2-5 minutes
  │     │                 AWS is provisioning ELB
  │     └─ Yes → Continue
  │
  ├─► Is application accessible?
  │     ├─ No → Check security groups (port 80 open)
  │     │       └─ Check pod health (liveness/readiness probes)
  │     └─ Yes → ✅ Success!
  │
  └─► Are environment variables set?
        ├─ No → Check secrets in Kubernetes
        │       └─ Recreate: kubectl delete secret multi-doc-chat-secrets
        │       └─ Re-run deployment pipeline
        └─ Yes → Check application logs for errors
```

---

## 📅 Typical Timeline

```
Day 1: Initial Setup (One-Time)
├─ Hour 0-1: Setup Jenkins locally, install plugins
├─ Hour 1-2: Configure AWS credentials and environment variables
├─ Hour 2-2.5: Create pipeline jobs (infra + deploy)
├─ Hour 2.5-3: Run Jenkinsfile.infra (30 min build time)
└─ Hour 3-3.5: Run Jenkinsfile.deploy (10 min) and verify

Day 1+: Every Deployment (Automated)
├─ Minute 0: Developer pushes code
├─ Minute 0-5: Jenkins detects change (SCM poll)
├─ Minute 5-8: Docker build stage
├─ Minute 8-10: Push to ECR
├─ Minute 10-12: Kubernetes deployment
├─ Minute 12-15: Rolling update completes
└─ Minute 15: New version live! ✅

Maintenance:
├─ Weekly: Check pod health and logs
├─ Monthly: Review costs in AWS Console
├─ Quarterly: Update dependencies (requirements.txt)
└─ As needed: Scale resources, update cluster version
```

---

## 🔐 Security Flow

```
Jenkins Environment Variables (stored in Jenkins config)
  │
  └─► Jenkins Pipeline reads them
        │
        ├─► AWS Credentials
        │     └─► Used for: CloudFormation, ECR, EKS access
        │
        └─► Application Secrets (API Keys)
              │
              └─► Jenkins creates Kubernetes Secret
                    │
                    ├─► Base64 encoded (in etcd)
                    │
                    └─► Injected into pods as env vars
                          │
                          └─► Application reads at runtime
                                └─► Never logged or exposed in Jenkins output

Security Recommendations:
1. ✅ Use environment variables in Jenkins (current)
2. 🔒 Consider Jenkins Credentials Store for production
3. 🔒 Enable Kubernetes Secrets encryption at rest (KMS)
4. 🔒 Use IAM roles when Jenkins runs on EC2
5. 🔒 Rotate secrets regularly
6. 🔒 Enable CloudTrail for audit logs
```

---

## 💡 Jenkins vs GitHub Actions Flow Comparison

```
┌─────────────────────────────────────────────────────────────────┐
│                    GitHub Actions Approach                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Developer Push → GitHub detects → GitHub Runners execute       │
│                                                                  │
│  Pros:                                                           │
│  ✅ No server to manage                                         │
│  ✅ Native GitHub integration                                    │
│  ✅ Easy setup                                                   │
│                                                                  │
│  Cons:                                                           │
│  ❌ 2000 minutes/month limit (free tier)                        │
│  ❌ Limited to GitHub infrastructure                             │
│  ❌ Less control over build environment                          │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      Jenkins Approach (This)                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Developer Push → Jenkins polls → Jenkins executes (local/EC2)  │
│                                                                  │
│  Pros:                                                           │
│  ✅ Unlimited build minutes                                     │
│  ✅ Full control over environment                                │
│  ✅ Can run on EC2 with IAM roles (more secure)                 │
│  ✅ Industry-standard tool                                       │
│  ✅ More customization options                                   │
│                                                                  │
│  Cons:                                                           │
│  ❌ Need to manage Jenkins server                               │
│  ❌ More initial setup                                           │
│  ❌ Requires Docker/EC2 resources                                │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📈 Scaling Scenarios

### Scenario 1: Horizontal Pod Scaling

```
Normal Load (2 replicas):
┌─────────────┐
│ LoadBalancer│
└──────┬──────┘
   ┌───┴───┐
   ▼       ▼
 Pod 1   Pod 2
 (8080)  (8080)


High Load (4 replicas):
┌─────────────┐
│ LoadBalancer│
└──────┬──────┘
   ┌───┼───┬───┐
   ▼   ▼   ▼   ▼
 Pod1 Pod2 Pod3 Pod4
 (8080)(8080)(8080)(8080)

Command: kubectl scale deployment multi-doc-chat --replicas=4
```

### Scenario 2: Node Auto-Scaling

```
Normal (2 nodes):
┌──────────┐  ┌──────────┐
│  Node 1  │  │  Node 2  │
│ (2 pods) │  │ (2 pods) │
└──────────┘  └──────────┘


High Load (3 nodes):
┌──────────┐  ┌──────────┐  ┌──────────┐
│  Node 1  │  │  Node 2  │  │  Node 3  │
│ (3 pods) │  │ (3 pods) │  │ (2 pods) │
└──────────┘  └──────────┘  └──────────┘

AWS EKS auto-scales nodes based on pod demands
```

---

This visual guide helps you understand the complete Jenkins-based deployment flow for MultiDocChat! 🚀

