# 📊 Deployment Flow Diagrams

Visual representation of the complete deployment process.

---

## 🏗️ Complete Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         DEVELOPER WORKFLOW                           │
│                                                                      │
│  Developer → Git Push → GitHub Repository (main branch)             │
└────────────────────────┬────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       GITHUB ACTIONS CI/CD                           │
│                                                                      │
│  ┌──────────────────────┐         ┌──────────────────────┐         │
│  │   infra.yml          │         │   deploy.yml         │         │
│  │   (Manual Trigger)   │         │   (Auto on Push)     │         │
│  │                      │         │                      │         │
│  │  • Checkout Code     │         │  • Checkout Code     │         │
│  │  • AWS Auth          │         │  • AWS Auth          │         │
│  │  • CloudFormation    │         │  • Verify EKS        │         │
│  │    Deploy            │         │  • Login ECR         │         │
│  │                      │         │  • Build Docker      │         │
│  └─────────┬────────────┘         │  • Push to ECR       │         │
│            │                      │  • Setup kubectl     │         │
│            │                      │  • Create Secrets    │         │
│            │                      │  • Apply Manifests   │         │
│            │                      │  • Rolling Update    │         │
│            │                      └──────────┬───────────┘         │
└────────────┼─────────────────────────────────┼─────────────────────┘
             │                                 │
             ▼                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          AWS CLOUD                                   │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                    CloudFormation Stack                       │  │
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
│  │  │  product-assistant Repository                   │        │  │
│  │  │  ├── Image: product-assistant:1729756800        │        │  │
│  │  │  ├── Image: product-assistant:1729757400        │        │  │
│  │  │  └── Image: product-assistant:latest            │        │  │
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
│  │  │  │  │  MCP Srv   │  │    │  │  MCP Srv   │  │        │ │  │
│  │  │  │  │            │  │    │  │            │  │        │ │  │
│  │  │  │  │  Port 8000 │  │    │  │  Port 8000 │  │        │ │  │
│  │  │  │  └────────────┘  │    │  └────────────┘  │        │ │  │
│  │  │  └──────────────────┘    └──────────────────┘        │ │  │
│  │  └────────────────────────────────────────────────────────┘ │  │
│  │                                                               │  │
│  │  ┌────────────────────────────────────────────────────────┐ │  │
│  │  │              Kubernetes Services                       │ │  │
│  │  │                                                        │ │  │
│  │  │  ┌──────────────────────────────────────────┐        │ │  │
│  │  │  │  Service: product-assistant-service      │        │ │  │
│  │  │  │  Type: LoadBalancer                      │        │ │  │
│  │  │  │  Port: 80 → 8000                         │        │ │  │
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
│  │  │  ├── OPENAI_API_KEY                   │            │ │  │
│  │  │  ├── GOOGLE_API_KEY                   │            │ │  │
│  │  │  ├── ASTRA_DB_API_ENDPOINT            │            │ │  │
│  │  │  ├── ASTRA_DB_APPLICATION_TOKEN       │            │ │  │
│  │  │  └── ASTRA_DB_KEYSPACE                │            │ │  │
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

## 🔄 Workflow 1: Infrastructure Provisioning Flow

```
START: Developer triggers "infra.yml" workflow manually
  │
  ├─► Step 1: Checkout Repository
  │     └─► Actions: Pulls code from GitHub
  │
  ├─► Step 2: Configure AWS Credentials
  │     ├─► Reads: AWS_ACCESS_KEY_ID (secret)
  │     ├─► Reads: AWS_SECRET_ACCESS_KEY (secret)
  │     └─► Reads: AWS_REGION (secret)
  │
  └─► Step 3: Deploy CloudFormation Stack
        ├─► Action: aws cloudformation deploy
        ├─► Template: infra/eks-with-ecr.yaml
        ├─► Stack Name: product-assistant-cluster
        │
        └─► CloudFormation Creates Resources (20-30 min):
              │
              ├─► Phase 1: Networking (5-10 min)
              │     ├─► VPC
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
              │     └─► ECR Repository
              │
              ├─► Phase 4: EKS Cluster (10-15 min)
              │     └─► Control Plane Setup
              │
              └─► Phase 5: NodeGroup (5-10 min)
                    ├─► Launch 2 EC2 instances
                    ├─► Join cluster
                    └─► Install CNI, kube-proxy
              │
              ▼
        ✅ Infrastructure Ready
              │
              └─► Outputs:
                    ├─► ECR Repository URI
                    └─► EKS Cluster Name

END: Infrastructure provisioned successfully
```

---

## 🚀 Workflow 2: Application Deployment Flow

```
TRIGGER: Push to main branch OR Manual trigger
  │
  ├─► Step 1: Checkout Code
  │     └─► Pulls latest code
  │
  ├─► Step 2: Configure AWS Credentials
  │     └─► Same as infra workflow
  │
  ├─► Step 3: Verify EKS Cluster Exists
  │     ├─► Command: aws eks describe-cluster
  │     └─► If not found: FAIL (run infra.yml first)
  │
  ├─► Step 4: Login to ECR
  │     ├─► Gets ECR login token
  │     └─► Configures Docker to use ECR
  │
  ├─► Step 5: Generate Image Tag
  │     ├─► Creates timestamp: $(date +%s)
  │     └─► Example: 1729756800
  │
  ├─► Step 6: Build Docker Image
  │     │
  │     ├─► FROM python:3.11-slim
  │     │     └─► Base image (~50MB)
  │     │
  │     ├─► Install git
  │     │     └─► For some pip packages
  │     │
  │     ├─► COPY requirements.txt + pyproject.toml
  │     │     └─► Dependency files first (layer caching)
  │     │
  │     ├─► COPY prod_assistant/
  │     │     └─► Application code
  │     │
  │     ├─► RUN pip install -r requirements.txt
  │     │     ├─► fastapi, langchain, uvicorn
  │     │     ├─► langchain-astradb
  │     │     ├─► langchain-mcp-adapters
  │     │     └─► All dependencies
  │     │
  │     ├─► COPY . .
  │     │     └─► Remaining files
  │     │
  │     ├─► EXPOSE 8000
  │     │     └─► Document port
  │     │
  │     └─► CMD
  │           ├─► Start MCP server in background
  │           └─► Start Uvicorn with FastAPI (2 workers)
  │
  ├─► Step 7: Tag Image
  │     ├─► Tag 1: <registry>/<repo>:1729756800
  │     └─► Tag 2: <registry>/<repo>:latest
  │
  ├─► Step 8: Push to ECR
  │     ├─► Push timestamped image
  │     └─► Push latest image
  │
  ├─► Step 9: Setup kubectl
  │     └─► Install latest kubectl CLI
  │
  ├─► Step 10: Install AWS CLI
  │     └─► Ensure latest version
  │
  ├─► Step 11: Update kubeconfig
  │     ├─► Command: aws eks update-kubeconfig
  │     └─► Effect: kubectl now points to EKS cluster
  │
  ├─► Step 12: Create/Update Kubernetes Secrets
  │     ├─► kubectl create secret generic product-assistant-secrets
  │     ├─► Adds: OPENAI_API_KEY
  │     ├─► Adds: GOOGLE_API_KEY
  │     ├─► Adds: ASTRA_DB_API_ENDPOINT
  │     ├─► Adds: ASTRA_DB_APPLICATION_TOKEN
  │     ├─► Adds: ASTRA_DB_KEYSPACE
  │     └─► Uses: --dry-run=client -o yaml | kubectl apply -f -
  │           └─► Effect: Updates if exists, creates if not
  │
  ├─► Step 13: Apply Kubernetes Manifests
  │     │
  │     ├─► Apply deployment.yaml
  │     │     ├─► Name: product-assistant
  │     │     ├─► Replicas: 2
  │     │     ├─► Image: (will be updated next step)
  │     │     ├─► Port: 8000
  │     │     └─► Env vars from secrets
  │     │
  │     └─► Apply service.yaml
  │           ├─► Name: product-assistant-service
  │           ├─► Type: LoadBalancer
  │           ├─► External Port: 80
  │           └─► Target Port: 8000
  │                 └─► AWS creates ELB automatically
  │
  ├─► Step 14: Patch Deployment with New Image
  │     ├─► Command: kubectl set image deployment/product-assistant
  │     ├─► New Image: <registry>/<repo>:1729756800
  │     │
  │     └─► Kubernetes Rolling Update:
  │           │
  │           ├─► Create new pod with new image
  │           │     └─► Wait for pod to be ready
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
  ├─► Step 15: Verify Rollout
  │     ├─► Command: kubectl rollout status deployment/product-assistant
  │     ├─► Timeout: 120 seconds
  │     │
  │     ├─► If Success: ✅ Continue
  │     │
  │     └─► If Failure:
  │           ├─► Show deployment details
  │           ├─► List pods
  │           ├─► Show pod logs
  │           └─► Exit 1 (workflow fails)
  │
  └─► Step 16: Get Service Info
        ├─► Command: kubectl get svc product-assistant-service -o wide
        │
        └─► Output:
              ├─► Service Name
              ├─► Type: LoadBalancer
              ├─► External IP/DNS
              └─► Ports: 80:8000

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
    │ 8000   │  │ 8000   │
    └────┬───┘  └───┬────┘
         │          │
         │          │
         ▼          ▼
    ┌──────────────────────┐
    │   Uvicorn Server     │
    │   (2 workers each)   │
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
    │  AgenticRAG          │
    │  (Workflow)          │
    └──────────┬───────────┘
               │
         ┌─────┴─────┐
         │           │
         ▼           ▼
    ┌─────────┐  ┌──────────┐
    │   MCP   │  │  Astra   │
    │  Server │  │  Vector  │
    │ (Local) │  │  DB      │
    └─────────┘  └──────────┘
         │
         └──► Search Products
         
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
└─────────┘ └─────────┘


Step 1: Create first new pod
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
└─────────┘ └─────────┘ └─────────┘
                        (Not ready yet)


Step 2: New pod ready, shift traffic
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
└─────────┘ └─────────┘ └─────────┘


Step 3: Terminate one old pod
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
             └─────────┘ └─────────┘


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
         └─────────┘ └─────────┘ └─────────┘
                                 (Not ready yet)


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
         └─────────┘ └─────────┘ └─────────┘


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
└─────────┘ └─────────┘

✅ Zero downtime achieved
✅ Traffic always routed to healthy pods
```

---

## 🎯 Decision Flow: Troubleshooting

```
Deployment Failed?
  │
  ├─► Is infra provisioned?
  │     ├─ No → Run infra.yml workflow
  │     └─ Yes → Continue
  │
  ├─► Does EKS cluster exist?
  │     ├─ No → Check CloudFormation stack
  │     └─ Yes → Continue
  │
  ├─► Does ECR image exist?
  │     ├─ No → Check Docker build logs
  │     └─ Yes → Continue
  │
  ├─► Are pods running?
  │     ├─ No → Check pod events
  │     │       └─► ImagePullBackOff?
  │     │             ├─ Check image name
  │     │             └─ Check IAM permissions
  │     │       └─► CrashLoopBackOff?
  │     │             ├─ Check application logs
  │     │             └─ Check environment variables
  │     └─ Yes → Continue
  │
  ├─► Is service created?
  │     ├─ No → Check service manifest
  │     └─ Yes → Continue
  │
  ├─► Does LoadBalancer have external IP?
  │     ├─ No (pending) → Wait 2-5 minutes
  │     └─ Yes → Continue
  │
  ├─► Is application accessible?
  │     ├─ No → Check security groups
  │     │       └─ Check pod health
  │     └─ Yes → ✅ Success!
  │
  └─► Are environment variables set?
        ├─ No → Check secrets
        │       └─ Recreate secrets
        └─ Yes → Check application logs
```

---

## 📅 Typical Timeline

```
Day 1: Initial Setup (Manual Work)
├─ Hour 0-1: AWS account setup, IAM user creation
├─ Hour 1-2: Configure GitHub secrets
├─ Hour 2-3: Customize deployment files
├─ Hour 3-3.5: Run infra.yml (30 min workflow)
└─ Hour 3.5-4: Test and verify

Day 1+: Every Deployment (Automated)
├─ Minute 0: Developer pushes code
├─ Minute 1-5: Docker build and push
├─ Minute 5-8: Kubernetes deployment
├─ Minute 8-10: Rolling update completes
└─ Minute 10: New version live! ✅

Maintenance:
├─ Weekly: Check pod health and logs
├─ Monthly: Review costs
├─ Quarterly: Update dependencies
└─ As needed: Scale resources
```

---

## 🔐 Security Flow

```
GitHub Secrets (Encrypted at rest)
  │
  └─► GitHub Actions Runner
        │
        ├─► AWS Authentication
        │     └─► IAM User with policies
        │           └─► Creates resources
        │
        └─► Kubernetes Secrets
              │
              ├─► Base64 encoded (not encrypted by default)
              │
              └─► Injected into pods as env vars
                    │
                    └─► Application reads at runtime
                          └─► Never logged or exposed
```

**Security Recommendations:**
1. Enable Kubernetes Secrets encryption at rest (KMS)
2. Use IAM Roles for Service Accounts (IRSA) instead of secrets
3. Rotate secrets regularly
4. Use AWS Secrets Manager for highly sensitive data
5. Enable CloudTrail for audit logs

---

## 💡 Best Practices Flow

```
Development
  │
  ├─► Write code
  ├─► Test locally
  ├─► Test Docker build locally
  └─► Push to feature branch
        │
        ▼
  Create Pull Request
        │
        ├─► Code review
        ├─► CI tests (if configured)
        └─► Merge to main
              │
              ▼
  Automatic Deployment
        │
        ├─► Build + Test
        ├─► Deploy to staging (if configured)
        ├─► Run integration tests
        └─► Deploy to production
              │
              └─► Monitor and verify

Rollback if needed:
  kubectl rollout undo deployment/product-assistant
```

---

This visual guide should help you understand the complete flow from code push to production deployment! 🚀

