# 📋 Quick Replication Checklist for AWS EKS Deployment

Use this checklist to replicate the deployment setup in any new project.

---

## ✅ Pre-Deployment Checklist

### 1. AWS Account Setup
- [ ] AWS Account created
- [ ] IAM user created with admin/EKS permissions
- [ ] Access Key ID and Secret Access Key generated
- [ ] AWS CLI installed locally (optional, for testing)

### 2. GitHub Repository Setup
- [ ] Repository created
- [ ] Code pushed to `main` branch
- [ ] Repository settings accessible (for secrets)

### 3. Application Requirements
- [ ] Application containerizable (Dockerfile works)
- [ ] Application tested locally
- [ ] All dependencies documented
- [ ] Port number identified (e.g., 8000, 3000)

---

## 📁 Files to Create/Copy

### Required Directory Structure
```
your-project/
├── .github/
│   └── workflows/
│       ├── infra.yml
│       └── deploy.yml
├── infra/
│   └── eks-with-ecr.yaml
├── k8/
│   ├── deployment.yaml
│   └── service.yaml
├── Dockerfile
└── requirements.txt (or package.json, etc.)
```

### Checklist
- [ ] `.github/workflows/` directory created
- [ ] `infra/` directory created
- [ ] `k8/` directory created
- [ ] All 5 required files copied from template

---

## ✏️ Customization Checklist

### File 1: `infra/eks-with-ecr.yaml`
- [ ] Line 7: Update `ClusterName` default value
  ```yaml
  Default: your-project-cluster  # Change this
  ```
- [ ] Line 10: Set appropriate instance type
  ```yaml
  Default: t3.medium  # or t3.small, t3.large
  ```
- [ ] Line 13: Set desired node count
  ```yaml
  Default: 2  # Number of EC2 nodes
  ```
- [ ] Line 16: Update ECR repository name
  ```yaml
  Default: your-app-name  # Change this
  ```

### File 2: `.github/workflows/infra.yml`
- [ ] Line 26: Update stack name
  ```yaml
  --stack-name your-project-stack
  ```
- [ ] Verify AWS region reference (uses secret)

### File 3: `.github/workflows/deploy.yml`
- [ ] Line 28: Update cluster name check
  ```yaml
  --name ${{ secrets.EKS_CLUSTER_NAME }}
  ```
- [ ] Line 48: Verify ECR repository secret name
- [ ] Lines 94-100: Customize secrets for your app
  ```yaml
  # Add/remove based on your needs:
  --from-literal=YOUR_API_KEY=${{ secrets.YOUR_API_KEY }} \
  --from-literal=DATABASE_URL=${{ secrets.DATABASE_URL }} \
  ```
- [ ] Line 94: Update secret name
  ```yaml
  kubectl create secret generic your-app-secrets
  ```
- [ ] Lines 105-106: Update manifest paths (if different)
- [ ] Line 114: Update deployment name
  ```yaml
  kubectl set image deployment/your-app ...
  ```
- [ ] Line 121: Update deployment name in verification
  ```yaml
  kubectl rollout status deployment/your-app
  ```
- [ ] Line 125: Update app label
  ```yaml
  kubectl get pods -l app=your-app
  ```
- [ ] Line 134: Update service name
  ```yaml
  kubectl get svc your-app-service
  ```

### File 4: `k8/deployment.yaml`
- [ ] Line 4: Update deployment name
  ```yaml
  name: your-app
  ```
- [ ] Line 6: Update label
  ```yaml
  app: your-app
  ```
- [ ] Line 8: Set replica count
  ```yaml
  replicas: 2  # Adjust as needed
  ```
- [ ] Line 11: Update selector label
  ```yaml
  app: your-app
  ```
- [ ] Line 15: Update pod label
  ```yaml
  app: your-app
  ```
- [ ] Line 18: Update container name
  ```yaml
  - name: your-app
  ```
- [ ] Line 19: Update image URL
  ```yaml
  image: <account-id>.dkr.ecr.<region>.amazonaws.com/your-repo:latest
  ```
- [ ] Line 21: Update container port
  ```yaml
  - containerPort: 8000  # Your app's port
  ```
- [ ] Lines 22-47: Update environment variables
  ```yaml
  # Replace with your app's env vars:
  - name: YOUR_CONFIG
    valueFrom:
      secretKeyRef:
        name: your-app-secrets
        key: YOUR_CONFIG
  ```

### File 5: `k8/service.yaml`
- [ ] Line 4: Update service name
  ```yaml
  name: your-app-service
  ```
- [ ] Line 6: Set service type (LoadBalancer for external, ClusterIP for internal)
  ```yaml
  type: LoadBalancer
  ```
- [ ] Line 8: Update selector
  ```yaml
  app: your-app
  ```
- [ ] Line 12: Set target port (must match containerPort in deployment)
  ```yaml
  targetPort: 8000
  ```

### File 6: `Dockerfile`
- [ ] Base image appropriate for your app
  ```dockerfile
  FROM python:3.11-slim  # or node:18-alpine, openjdk:17, etc.
  ```
- [ ] Dependencies copied and installed
  ```dockerfile
  COPY requirements.txt ./  # or package.json, pom.xml, etc.
  RUN pip install -r requirements.txt  # or npm install, mvn install
  ```
- [ ] Application code copied
  ```dockerfile
  COPY . .
  ```
- [ ] Correct port exposed
  ```dockerfile
  EXPOSE 8000  # Match your app's port
  ```
- [ ] Proper start command
  ```dockerfile
  CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
  # or CMD ["node", "server.js"]
  # or CMD ["java", "-jar", "app.jar"]
  ```

---

## 🔐 GitHub Secrets Configuration

### Navigation
1. Go to your GitHub repository
2. Click `Settings` tab
3. Navigate to `Secrets and variables` → `Actions`
4. Click `New repository secret`

### Required Secrets Checklist

#### AWS Infrastructure Secrets
- [ ] `AWS_ACCESS_KEY_ID`
  - Value: Your AWS access key
  - Get from: AWS Console → IAM → Users → Security credentials
  
- [ ] `AWS_SECRET_ACCESS_KEY`
  - Value: Your AWS secret key
  - Get from: AWS Console → IAM → Users → Security credentials
  
- [ ] `AWS_REGION`
  - Value: `us-west-1` (or your preferred region)
  - Common: us-east-1, us-west-2, eu-west-1, ap-south-1

#### EKS Configuration Secrets
- [ ] `EKS_CLUSTER_NAME`
  - Value: Match the ClusterName in `eks-with-ecr.yaml`
  - Example: `your-project-cluster`
  
- [ ] `ECR_REGISTRY`
  - Value: `<account-id>.dkr.ecr.<region>.amazonaws.com`
  - Get account ID: AWS Console top-right dropdown or `aws sts get-caller-identity`
  - Example: `123456789012.dkr.ecr.us-west-1.amazonaws.com`
  
- [ ] `ECR_REPOSITORY`
  - Value: Match ECRRepositoryName in `eks-with-ecr.yaml`
  - Example: `your-app-name`

#### Application-Specific Secrets
- [ ] Add any API keys your app needs
  - Examples: `OPENAI_API_KEY`, `STRIPE_SECRET_KEY`, `DATABASE_URL`
  - Must reference these in `deploy.yml` (lines 94-100)
  - Must reference these in `deployment.yaml` (env section)

---

## 🚀 Deployment Execution Checklist

### Phase 1: Infrastructure Provisioning (One-time)

1. **Verify All Files Ready**
   - [ ] All 6 files created and customized
   - [ ] All GitHub secrets configured
   - [ ] Code pushed to `main` branch

2. **Run Infrastructure Workflow**
   - [ ] Go to GitHub → Actions tab
   - [ ] Click `Provision Infra (EKS + ECR)`
   - [ ] Click `Run workflow` button
   - [ ] Select `main` branch
   - [ ] Click green `Run workflow` button

3. **Monitor Progress**
   - [ ] Watch workflow in Actions tab
   - [ ] Expected duration: 20-30 minutes
   - [ ] Check for any errors in logs

4. **Verify Infrastructure Created**
   - [ ] AWS Console → EKS → Clusters → Your cluster exists
   - [ ] Status shows `ACTIVE`
   - [ ] AWS Console → ECR → Repositories → Your repository exists
   - [ ] Node group shows `ACTIVE`

### Phase 2: Application Deployment (Every update)

1. **Trigger Deployment**
   - Option A: Automatic
     - [ ] Make code changes
     - [ ] Commit and push to `main` branch
     - [ ] Workflow auto-triggers
   
   - Option B: Manual
     - [ ] Go to Actions → `Deploy App to EKS`
     - [ ] Click `Run workflow`

2. **Monitor Deployment**
   - [ ] Watch workflow progress in Actions tab
   - [ ] Expected duration: 5-10 minutes
   - [ ] Verify all steps complete successfully

3. **Get Application URL**
   - [ ] Scroll to bottom of workflow logs
   - [ ] Find "Get Service Info" step
   - [ ] Copy EXTERNAL-IP or DNS name
   - [ ] Format: `http://<EXTERNAL-IP>` or `http://<DNS-NAME>`

4. **Test Application**
   - [ ] Open browser to application URL
   - [ ] Verify application loads
   - [ ] Test core functionality
   - [ ] Check for any errors

---

## 🧪 Testing Checklist

### Local Testing (Before Deployment)
- [ ] Dockerfile builds successfully
  ```bash
  docker build -t test-app .
  ```
- [ ] Container runs locally
  ```bash
  docker run -p 8000:8000 test-app
  ```
- [ ] Application accessible at `http://localhost:8000`
- [ ] All features work with test data

### Post-Deployment Testing
- [ ] LoadBalancer URL accessible
- [ ] Application responds correctly
- [ ] Environment variables loaded (check logs if needed)
- [ ] API endpoints functional
- [ ] Database connections work (if applicable)

### Kubernetes Health Checks
- [ ] Run commands (requires kubectl configured):
  ```bash
  kubectl get pods -l app=your-app
  # All pods should show Running and 1/1 READY
  
  kubectl get svc your-app-service
  # Should show EXTERNAL-IP (not <pending>)
  
  kubectl logs -l app=your-app --tail=50
  # Check for errors in logs
  ```

---

## 🐛 Troubleshooting Checklist

### If Infrastructure Provisioning Fails

- [ ] Check AWS credentials are correct
  ```bash
  # Verify secrets are set in GitHub
  # Try locally: aws sts get-caller-identity
  ```
- [ ] Verify IAM permissions sufficient
- [ ] Check AWS service limits (EKS, VPC, EC2)
- [ ] Review CloudFormation events in AWS Console
- [ ] Try different region if capacity issues

### If Deployment Fails

- [ ] Verify infrastructure exists (EKS cluster active)
- [ ] Check ECR repository created
- [ ] Verify all GitHub secrets set correctly
- [ ] Check image name format matches ECR registry
- [ ] Review deployment logs in GitHub Actions
- [ ] Check Kubernetes events:
  ```bash
  kubectl get events --sort-by='.lastTimestamp'
  ```

### If Application Not Accessible

- [ ] Verify LoadBalancer created (not pending)
- [ ] Check security group allows inbound traffic
- [ ] Verify pods are running:
  ```bash
  kubectl get pods -l app=your-app
  ```
- [ ] Check pod logs for errors:
  ```bash
  kubectl logs -l app=your-app
  ```
- [ ] Verify service targets correct port

### If Environment Variables Missing

- [ ] Verify secrets created in Kubernetes:
  ```bash
  kubectl get secrets
  kubectl describe secret your-app-secrets
  ```
- [ ] Check secret keys match deployment.yaml
- [ ] Verify GitHub secrets match deploy.yml references
- [ ] Re-run deployment to recreate secrets

---

## 💰 Cost Awareness Checklist

### Understanding Costs
- [ ] EKS Control Plane: ~$73/month (flat)
- [ ] EC2 Nodes: Depends on instance type and count
  - t3.small: ~$15/month each
  - t3.medium: ~$30/month each
  - t3.large: ~$60/month each
- [ ] LoadBalancer: ~$18/month
- [ ] Data transfer: Variable
- [ ] **Estimated total**: $100-200/month for 2 t3.medium nodes

### Cost Optimization
- [ ] Use t3.small for dev/staging
- [ ] Scale down to 1 node when not in use
- [ ] Delete infrastructure when not needed:
  ```bash
  aws cloudformation delete-stack --stack-name your-stack-name
  ```
- [ ] Set up billing alerts in AWS

---

## 📊 Monitoring Setup Checklist

### Enable CloudWatch Logging (Optional)
- [ ] AWS Console → EKS → Your cluster → Configuration → Logging
- [ ] Enable: API server, Audit, Authenticator, Controller manager, Scheduler
- [ ] View logs: CloudWatch → Log groups → `/aws/eks/your-cluster/*`

### Set Up Alerts (Optional)
- [ ] CloudWatch → Alarms → Create alarm
- [ ] Alert on:
  - High CPU usage
  - Pod restarts
  - Failed deployments
  - High error rates

### Regular Health Checks
- [ ] Check pod status weekly
- [ ] Review logs for errors
- [ ] Monitor costs in AWS Cost Explorer
- [ ] Update dependencies regularly

---

## 🔄 Update and Maintenance Checklist

### Regular Updates
- [ ] Update Docker base images (security patches)
- [ ] Update application dependencies
- [ ] Update Kubernetes manifests if needed
- [ ] Test changes locally before pushing

### Deployment Updates
- [ ] Push changes to `main` branch
- [ ] Automatic deployment triggered
- [ ] Monitor rollout status
- [ ] Verify new version deployed
- [ ] Test application functionality

### Rollback if Needed
```bash
kubectl rollout undo deployment/your-app
```

---

## 📝 Documentation Checklist

### For Your Team
- [ ] Document application-specific environment variables
- [ ] Document any manual setup steps
- [ ] Document how to access logs
- [ ] Document emergency contacts/procedures
- [ ] Keep GitHub secrets list updated

### For Future You
- [ ] Note any custom configurations made
- [ ] Document why certain decisions were made
- [ ] Keep this checklist updated for your project
- [ ] Add troubleshooting solutions you discover

---

## ✨ Success Criteria

Your deployment is successful when:

- [ ] ✅ Infrastructure workflow completes without errors
- [ ] ✅ EKS cluster status is ACTIVE
- [ ] ✅ ECR repository exists and contains images
- [ ] ✅ Deployment workflow completes successfully
- [ ] ✅ Pods are running (kubectl get pods shows Running status)
- [ ] ✅ Service has EXTERNAL-IP assigned
- [ ] ✅ Application accessible via LoadBalancer URL
- [ ] ✅ Application functions correctly
- [ ] ✅ Logs show no critical errors
- [ ] ✅ Environment variables loaded correctly

---

## 🎓 Learning Resources

- [ ] Read AWS EKS documentation: https://docs.aws.amazon.com/eks/
- [ ] Learn Kubernetes basics: https://kubernetes.io/docs/tutorials/
- [ ] Understand Docker: https://docs.docker.com/get-started/
- [ ] GitHub Actions: https://docs.github.com/en/actions/learn-github-actions

---

## 📞 Need Help?

If you're stuck:

1. **Check the logs** (most issues show up here)
   - GitHub Actions logs
   - CloudFormation events
   - Kubernetes events
   - Pod logs

2. **Verify configuration**
   - All secrets set correctly
   - File customizations complete
   - Names match across files

3. **Search for error messages**
   - AWS documentation
   - Kubernetes documentation
   - Stack Overflow
   - GitHub Issues

4. **Test components individually**
   - Does Dockerfile build?
   - Does app run locally?
   - Do AWS credentials work?

---

**Remember**: Infrastructure provisioning takes 20-30 minutes. Be patient! ☕

**Tip**: Save this checklist and check off items as you complete them for each new project.

---

**Last Updated**: October 23, 2025

