# Jenkins GitHub Webhook Troubleshooting Guide

## Problem: Jenkins Pipeline Not Triggering on Git Push

### Your Setup
- **Jenkins URL:** http://jenkins-llmops-31002.eastus.azurecontainer.io:8080
- **Branch:** AddingJenkins
- **Trigger Type:** GitHub hook trigger for GITScm polling

---

## Solution Steps

### 1. ✅ Configure GitHub Webhook (MOST IMPORTANT)

This is the most common issue - the webhook is usually not configured or misconfigured.

**Steps:**
1. Go to your GitHub repository
2. Click **Settings** → **Webhooks** → **Add webhook**
3. Configure:
   ```
   Payload URL: http://jenkins-llmops-31002.eastus.azurecontainer.io:8080/github-webhook/
   Content type: application/json
   Secret: (leave empty for now, or set one and configure in Jenkins)
   SSL verification: Enable SSL verification (if using HTTPS)
   Events: Just the push event
   Active: ✅ Checked
   ```
4. Click **Add webhook**
5. GitHub will send a test ping - check for ✅ green checkmark

**Important Notes:**
- The URL **MUST** end with `/github-webhook/` (note the trailing slash)
- If you see a red ❌, click the webhook to see error details
- Common error: `Connection refused` means Jenkins is not accessible from GitHub

---

### 2. ✅ Verify Jenkins is Publicly Accessible

Test if GitHub can reach your Jenkins:

```bash
# From your local machine (simulating GitHub's connection)
curl -I http://jenkins-llmops-31002.eastus.azurecontainer.io:8080/github-webhook/
```

**Expected response:**
```
HTTP/1.1 405 Method Not Allowed
```
(405 is OK - it means Jenkins received the request but needs a POST, not GET)

**If you get connection errors:**
```bash
# Check if Jenkins is running
az container show -g llmops-jenkins-rg -n jenkins-llmops \
  --query "containers[0].instanceView.currentState.state" -o tsv

# Check Jenkins logs
az container logs -g llmops-jenkins-rg -n jenkins-llmops --tail 50
```

---

### 3. ✅ Verify Jenkins Configuration

#### A. Check GitHub Plugin is Installed

1. In Jenkins: **Manage Jenkins** → **Manage Plugins**
2. Go to **Installed** tab
3. Search for: `GitHub Plugin`
4. If not found, go to **Available** tab and install:
   - GitHub Plugin
   - GitHub API Plugin
   - Plain Credentials Plugin

#### B. Check Your Pipeline Job Configuration

1. Go to your pipeline job
2. Click **Configure**
3. Under **Build Triggers**:
   - ✅ Check **GitHub hook trigger for GITScm polling**
4. Under **Pipeline** → **Pipeline script from SCM**:
   - SCM: `Git`
   - Repository URL: `https://github.com/yourusername/your-repo.git`
   - Credentials: (add if private repo)
   - **Branches to build:**
     - For specific branch: `*/AddingJenkins`
     - For all branches: `**`
     - For main/master only: `*/main` or `*/master`
5. Click **Save**

---

### 4. ✅ Test the Webhook Connection

#### From GitHub:
1. Go to your webhook in GitHub
2. Click on it to see **Recent Deliveries**
3. Click on a delivery to see:
   - Request headers
   - Request payload
   - Response from Jenkins
4. If you see errors, note the HTTP status code

#### From Jenkins:
1. Go to **Manage Jenkins** → **System Log**
2. Add a new log recorder:
   - Name: `GitHub Webhook`
   - Add logger: `com.cloudbees.jenkins.GitHubWebHook` → Level: `ALL`
3. Make a test push
4. Check this log for details

---

### 5. 🧪 Manual Test

#### Test 1: Trigger Build Manually
1. Go to your pipeline job
2. Click **Build Now**
3. If this works, the issue is with the webhook, not the pipeline

#### Test 2: Use GitHub's "Redeliver" Feature
1. Go to your webhook in GitHub
2. Click on a recent delivery
3. Click **Redeliver**
4. Check if Jenkins receives it

#### Test 3: Test with curl
```bash
# Simulate GitHub webhook (replace with your Jenkins URL)
curl -X POST http://jenkins-llmops-31002.eastus.azurecontainer.io:8080/github-webhook/ \
  -H "Content-Type: application/json" \
  -H "X-GitHub-Event: push" \
  -d '{
    "ref": "refs/heads/AddingJenkins",
    "repository": {
      "url": "https://github.com/yourusername/your-repo"
    }
  }'
```

---

## Common Issues & Solutions

### Issue 1: Webhook shows ❌ in GitHub
**Cause:** Jenkins is not accessible from GitHub
**Solution:**
- Verify Jenkins URL is correct
- Check Azure Container Instance is running
- Verify port 8080 is open
- Test with curl from your machine

### Issue 2: Webhook shows ✅ but Jenkins doesn't build
**Cause 1:** Branch mismatch
- **Solution:** Check "Branches to build" in job configuration
- Make sure it matches the branch you're pushing to
- Use `**` to build all branches

**Cause 2:** GitHub plugin not configured
- **Solution:** Install GitHub Plugin and restart Jenkins

**Cause 3:** Webhook payload not recognized
- **Solution:** Check Jenkins logs for webhook parsing errors

### Issue 3: Error 403 - No valid crumb
**Cause:** CSRF protection
**Solution:**
1. Go to **Manage Jenkins** → **Configure Global Security**
2. Find **CSRF Protection**
3. Check **Enable proxy compatibility**
4. Or add GitHub webhook to exceptions

### Issue 4: SSL Verification Failed
**Cause:** Using HTTP instead of HTTPS
**Solution:**
- Either use HTTPS for Jenkins (recommended for production)
- Or in GitHub webhook settings, disable SSL verification (not recommended for production)

### Issue 5: Multiple branches but only one triggers
**Cause:** Job configured for specific branch only
**Solution:** Change "Branches to build" to `**` or add multiple branch patterns

---

## Quick Diagnostics Checklist

Run these commands to diagnose issues:

```bash
# 1. Check Jenkins is running
az container show -g llmops-jenkins-rg -n jenkins-llmops \
  --query "{State:containers[0].instanceView.currentState.state, URL:ipAddress.fqdn}" -o json

# 2. Test Jenkins endpoint
curl -I http://jenkins-llmops-31002.eastus.azurecontainer.io:8080/github-webhook/

# 3. Check Jenkins logs
az container logs -g llmops-jenkins-rg -n jenkins-llmops --tail 100

# 4. List recent Jenkins builds
# (Do this from Jenkins web UI: Your Pipeline → Build History)
```

---

## Recommended Configuration

### For Production:
1. **Use HTTPS** for Jenkins (set up SSL/TLS)
2. **Set webhook secret** in GitHub and configure in Jenkins
3. **Restrict branches** to only build specific branches
4. **Enable security** in Jenkins (user authentication)

### For Development/Testing:
Current setup is fine:
- HTTP endpoint
- No webhook secret
- Build all branches

---

## Verification Steps After Setup

1. **Make a test commit:**
   ```bash
   git checkout AddingJenkins
   echo "# Test webhook" >> test-webhook.txt
   git add test-webhook.txt
   git commit -m "Test: Jenkins webhook trigger"
   git push origin AddingJenkins
   ```

2. **Check GitHub webhook:**
   - Go to Settings → Webhooks
   - Click your webhook
   - Check "Recent Deliveries"
   - Should show a green ✅ and HTTP 200 response

3. **Check Jenkins:**
   - Go to your pipeline job
   - Should see a new build started
   - Build history should show the commit message

---

## Still Not Working?

### Debug Mode:

1. **Enable detailed logging in Jenkins:**
   ```
   Manage Jenkins → System Log → Add new log recorder
   Name: GitHub-Webhook-Debug
   Add loggers:
   - com.cloudbees.jenkins.GitHubWebHook → ALL
   - com.cloudbees.jenkins.GitHubPushTrigger → ALL
   - org.jenkinsci.plugins.github → ALL
   ```

2. **Check GitHub webhook delivery details:**
   - Each delivery shows:
     - Request headers
     - Request body (JSON payload)
     - Response from Jenkins
     - Response headers
     - Response body

3. **Check Jenkins system log:**
   ```
   Manage Jenkins → System Log → All Jenkins Logs
   ```
   Look for lines containing "GitHub" or "webhook"

---

## Alternative: Poll SCM (Not Recommended)

If webhooks are not working and you need a temporary solution:

1. In your pipeline job configuration
2. Under **Build Triggers**
3. Check **Poll SCM**
4. Set schedule (using cron syntax):
   ```
   H/5 * * * *  # Check every 5 minutes
   ```

**Note:** This is less efficient than webhooks but will work as a fallback.

---

## Security Best Practices

1. **Use HTTPS** (set up reverse proxy with Nginx + Let's Encrypt)
2. **Configure webhook secret:**
   ```
   # In GitHub webhook
   Secret: your-random-secret-string
   
   # In Jenkins: Manage Jenkins → Configure System → GitHub
   Add shared secret
   ```
3. **Restrict IP access** (allow only GitHub webhook IPs)
4. **Enable authentication** in Jenkins
5. **Use GitHub App** instead of personal access tokens (for private repos)

---

## Need More Help?

**Check these logs:**
```bash
# Jenkins container logs
az container logs -g llmops-jenkins-rg -n jenkins-llmops --tail 200

# Jenkins system info
# In Jenkins UI: Manage Jenkins → System Information
```

**Useful Jenkins URLs:**
- System Log: http://jenkins-llmops-31002.eastus.azurecontainer.io:8080/log/all
- Plugin Manager: http://jenkins-llmops-31002.eastus.azurecontainer.io:8080/pluginManager/
- System Info: http://jenkins-llmops-31002.eastus.azurecontainer.io:8080/systemInfo

---

## Summary

**Most common solution (90% of cases):**
1. Add webhook in GitHub: http://jenkins-llmops-31002.eastus.azurecontainer.io:8080/github-webhook/
2. Check ✅ "GitHub hook trigger for GITScm polling" in Jenkins job
3. Push a commit
4. Should trigger automatically! 🎉

**If still not working:**
- Check webhook shows ✅ in GitHub
- Verify branch name matches in job configuration
- Check Jenkins logs for errors
- Test with manual "Build Now" first

Good luck! 🚀

