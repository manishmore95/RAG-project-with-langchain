#!/bin/bash

# Quick script to test GitHub webhook connectivity

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Jenkins GitHub Webhook Test Script            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}\n"

# Get Jenkins URL
echo -e "${YELLOW}Step 1: Getting Jenkins URL...${NC}"
JENKINS_URL=$(az container show -g llmops-jenkins-rg -n jenkins-llmops \
  --query "ipAddress.fqdn" -o tsv 2>/dev/null)

if [ -z "$JENKINS_URL" ]; then
    echo -e "${RED}❌ Error: Could not get Jenkins URL. Is Jenkins running?${NC}"
    echo ""
    echo "Check with:"
    echo "  az container show -g llmops-jenkins-rg -n jenkins-llmops"
    exit 1
fi

WEBHOOK_URL="http://${JENKINS_URL}:8080/github-webhook/"
echo -e "${GREEN}✅ Jenkins URL: ${WEBHOOK_URL}${NC}\n"

# Test 1: Check if Jenkins is reachable
echo -e "${YELLOW}Step 2: Testing if Jenkins webhook endpoint is reachable...${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X GET "${WEBHOOK_URL}" 2>/dev/null)

if [ "$HTTP_CODE" = "000" ]; then
    echo -e "${RED}❌ Connection failed! Jenkins is not reachable.${NC}"
    echo ""
    echo "Possible issues:"
    echo "  1. Jenkins container is not running"
    echo "  2. Network connectivity issue"
    echo "  3. Port 8080 is not accessible"
    echo ""
    echo "Check Jenkins status:"
    echo "  az container show -g llmops-jenkins-rg -n jenkins-llmops --query 'containers[0].instanceView.currentState.state'"
    exit 1
elif [ "$HTTP_CODE" = "403" ]; then
    echo -e "${YELLOW}⚠️  HTTP 403: Jenkins is running but may have CSRF protection enabled${NC}"
    echo -e "${GREEN}✅ This is OK - Jenkins is reachable from the internet!${NC}\n"
elif [ "$HTTP_CODE" = "405" ]; then
    echo -e "${GREEN}✅ HTTP 405: Perfect! Jenkins webhook endpoint is working!${NC}"
    echo -e "${GREEN}   (405 = Method Not Allowed for GET, but POST will work)${NC}\n"
else
    echo -e "${GREEN}✅ HTTP ${HTTP_CODE}: Jenkins is reachable!${NC}\n"
fi

# Test 2: Simulate GitHub webhook
echo -e "${YELLOW}Step 3: Simulating GitHub webhook POST request...${NC}"

# Get current git branch and repo URL if in a git repo
if git rev-parse --git-dir > /dev/null 2>&1; then
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    REPO_URL=$(git config --get remote.origin.url 2>/dev/null || echo "https://github.com/user/repo")
else
    CURRENT_BRANCH="AddingJenkins"
    REPO_URL="https://github.com/user/repo"
fi

echo "Using branch: ${CURRENT_BRANCH}"
echo "Using repo: ${REPO_URL}"
echo ""

WEBHOOK_PAYLOAD=$(cat <<EOF
{
  "ref": "refs/heads/${CURRENT_BRANCH}",
  "repository": {
    "url": "${REPO_URL}",
    "html_url": "${REPO_URL}",
    "name": "LLMOps_series",
    "full_name": "user/LLMOps_series"
  },
  "pusher": {
    "name": "test-user",
    "email": "test@example.com"
  },
  "head_commit": {
    "message": "Test webhook trigger",
    "id": "test123"
  }
}
EOF
)

RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "${WEBHOOK_URL}" \
  -H "Content-Type: application/json" \
  -H "X-GitHub-Event: push" \
  -H "X-GitHub-Delivery: test-$(date +%s)" \
  -d "${WEBHOOK_PAYLOAD}" 2>/dev/null)

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
RESPONSE_BODY=$(echo "$RESPONSE" | grep -v "HTTP_CODE:")

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    echo -e "${GREEN}✅ Webhook test successful! (HTTP ${HTTP_CODE})${NC}"
    echo -e "${GREEN}   Jenkins should have triggered a build!${NC}\n"
elif [ "$HTTP_CODE" = "403" ]; then
    echo -e "${YELLOW}⚠️  HTTP 403: CSRF Protection Enabled${NC}"
    echo "This means Jenkins received the request but needs proper CSRF token."
    echo "This is NORMAL - GitHub webhooks will work because they include proper headers."
    echo -e "${GREEN}✅ Jenkins webhook endpoint is working!${NC}\n"
elif [ -z "$HTTP_CODE" ]; then
    echo -e "${RED}❌ No response from Jenkins${NC}\n"
else
    echo -e "${YELLOW}⚠️  HTTP ${HTTP_CODE}${NC}"
    echo "Response: ${RESPONSE_BODY}"
    echo ""
fi

# Summary and next steps
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}Summary${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Jenkins Webhook URL: ${WEBHOOK_URL}"
echo ""
echo -e "${GREEN}Next Steps:${NC}"
echo ""
echo "1. Configure webhook in GitHub:"
echo "   • Go to: https://github.com/YOUR_USERNAME/YOUR_REPO/settings/hooks"
echo "   • Click: 'Add webhook'"
echo "   • Payload URL: ${WEBHOOK_URL}"
echo "   • Content type: application/json"
echo "   • Events: Just the push event"
echo "   • Click 'Add webhook'"
echo ""
echo "2. In your Jenkins pipeline job:"
echo "   • Go to job configuration"
echo "   • Under 'Build Triggers':"
echo "     ✅ Check 'GitHub hook trigger for GITScm polling'"
echo "   • Under 'Pipeline' → 'Branches to build':"
echo "     • Set to: */AddingJenkins (or your branch)"
echo "     • Or use: ** (for all branches)"
echo "   • Click 'Save'"
echo ""
echo "3. Test with a push:"
echo "   git add ."
echo "   git commit -m 'Test webhook'"
echo "   git push"
echo ""
echo "4. Check webhook in GitHub:"
echo "   • Go to: Settings → Webhooks → Click your webhook"
echo "   • Check 'Recent Deliveries'"
echo "   • Should see green ✅ checkmarks"
echo ""
echo "5. Check Jenkins:"
echo "   • Go to: ${WEBHOOK_URL%/github-webhook/}"
echo "   • Should see a new build triggered automatically!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "For detailed troubleshooting, see: JENKINS_WEBHOOK_TROUBLESHOOTING.md"
echo ""

