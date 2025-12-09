# n8n Mum Activity Monitor - Setup Guide

## Overview

Automated workflow that:
- Runs at 9 AM and 6 PM daily
- Executes the monitoring script on Lisarda HA
- Uses Claude AI to interpret results
- Sends alerts if concerns detected
- Logs all checks

## Quick Start

### 1. Import Workflow

**n8n URL:** http://100.68.66.20:5678

1. Open n8n in browser
2. Click **"Add workflow"** → **"Import from File"**
3. Select: `/tmp/mum-activity-monitor.json` (already uploaded to n8nserver)
   - Or import from: `~/lisarda-repo/n8n-workflows/mum-activity-monitor.json`
4. Click **"Import"**

### 2. Configure Credentials

The workflow requires 3 credentials:

#### A) Claude SSH Key

1. In workflow, click **"SSH: Run Monitoring Script"** node
2. Click **"Create New Credential"** for **"SSH Private Key"**
3. Configure:
   - **Name:** `Claude SSH Key`
   - **Host:** `100.83.146.108`
   - **Port:** `22`
   - **Username:** `graeme`
   - **Private Key:** Paste contents of `~/.ssh/id_rsa` or `~/.ssh/id_ed25519` from n8nserver
   - **Passphrase:** (leave empty if no passphrase)
4. Click **"Save"**

**To get the private key from n8nserver:**
```bash
ssh graeme@n8nserver "cat ~/.ssh/id_rsa"
```

**Note:** The workflow SSHs to the claude VM (100.83.146.108) to run the monitoring script. The script then SSHs from claude to Lisarda HA (100.113.132.97) to query the database.

#### B) Anthropic API Key

1. Click **"Claude AI: Interpret Results"** node
2. Click **"Create New Credential"** for **"HTTP Header Auth"**
3. Configure:
   - **Name:** `Anthropic API Key`
   - **Name:** `x-api-key`
   - **Value:** Your Anthropic API key (get from: https://console.anthropic.com/settings/keys)
4. Click **"Save"**

**To use existing key:**
```bash
# If you have an Anthropic API key stored:
ssh graeme@claude "cat ~/.anthropic-key" 2>/dev/null
```

#### C) Slack Webhook (Optional - for alerts)

1. Click **"Slack: Send Alert"** node
2. Click **"Create New Credential"** for **"Slack Webhook"**
3. Configure:
   - **Name:** `Slack Webhook`
   - **Webhook URL:** Your Slack Incoming Webhook URL
4. Click **"Save"**

**To create Slack Webhook:**
- Go to: https://api.slack.com/messaging/webhooks
- Create new webhook for your workspace/channel
- Copy the webhook URL

**Alternative:** If you don't want Slack alerts, you can:
- Delete the "Slack: Send Alert" node
- Alerts will still be logged to `/home/graeme/logs/mum-activity-alerts.log`

### 3. Create Log Directory

SSH to claude VM:
```bash
ssh graeme@claude "mkdir -p ~/logs"
```

### 4. Activate Workflow

1. In n8n, click the **toggle switch** at top right to activate
2. Click **"Save"**

## Workflow Structure

```
┌─────────────────────┐
│ Schedule Trigger    │ ← Runs at 9 AM & 6 PM daily
│ (9 AM & 6 PM)       │
└──────────┬──────────┘
           │
           ↓
┌─────────────────────┐
│ SSH: Run Script     │ ← Connects to claude VM (100.83.146.108)
│ (Claude VM)         │   Runs ~/check-mum-activity.sh
└──────────┬──────────┘   (Script SSHs to Lisarda HA internally)
           │
           ↓
┌─────────────────────┐
│ Set: Script Output  │ ← Captures script output
└──────────┬──────────┘
           │
           ↓
┌─────────────────────┐
│ Claude AI:          │ ← Interprets results
│ Interpret Results   │   Natural language summary
└──────────┬──────────┘
           │
           ↓
┌─────────────────────┐
│ Set: AI             │ ← Prepares interpretation
│ Interpretation      │
└──────────┬──────────┘
           │
           ↓
┌─────────────────────┐
│ IF: Needs Alert?    │ ← Checks for warnings
└─────┬─────────┬─────┘
      │         │
   FALSE      TRUE
      │         │
      ↓         ↓
┌─────────┐ ┌─────────────┐
│ Log     │ │ Send Alert  │
│ Normal  │ │ (Slack/Log) │
└─────────┘ └─────────────┘
```

### Additional Trigger: Manual Check

The workflow also has a **"Manual Trigger"** that you can use to check on mum anytime:

1. Open workflow in n8n
2. Click **"Execute Workflow"** button
3. View results in execution log

## Alert Conditions

Alerts are triggered if ANY of these conditions are met:

- ✗ No motion detected for 6+ hours
- ✗ Motion sensors offline
- ⚠ Claude's interpretation contains: "warning", "concern", "unusual", "alert"
- ⚠ Script output contains: "✗ WARNING" or "sensors offline"

## Logs

All activity is logged:

**Normal checks:**
- **Location:** `/home/graeme/logs/mum-activity-monitor.log`
- **Content:** Timestamp + brief summary
- **Example:** `2025-12-09 09:00:15: Normal activity - Mum active, 156 events, last seen kitchen 12 min ago`

**Alerts:**
- **Location:** `/home/graeme/logs/mum-activity-alerts.log`
- **Content:** Timestamp + full AI interpretation
- **Example:** `2025-12-09 18:00:23: ALERT - No motion detected for 8 hours...`

**View logs:**
```bash
ssh graeme@claude "tail -50 ~/logs/mum-activity-monitor.log"
ssh graeme@claude "tail -50 ~/logs/mum-activity-alerts.log"
```

## Testing

### Test Manual Execution

1. Open workflow in n8n
2. Click **"Execute Workflow"**
3. Watch each node execute
4. Check the output of "Set: AI Interpretation" node
5. Verify alert/log path taken

### Test SSH Connection

From n8n UI:
1. Click **"SSH: Run Monitoring Script"** node
2. Click **"Test step"**
3. Should see script output

### Test Schedule

The workflow will automatically run at:
- **9:00 AM GMT** (morning check)
- **6:00 PM GMT** (evening check)

Check execution history:
1. Go to **"Executions"** tab in n8n
2. View past runs and their results

## Customization

### Change Schedule

Edit **"Schedule: 9 AM & 6 PM"** node:
- Current: `0 9,18 * * *` (9 AM and 6 PM)
- Examples:
  - `0 8,12,18 * * *` (8 AM, noon, 6 PM)
  - `0 * * * *` (every hour)
  - `0 */2 * * *` (every 2 hours)

### Change Alert Threshold

Edit **"IF: Needs Alert?"** node conditions to add/remove trigger words.

### Add Email Alerts

1. Add new **"Send Email"** node after "Prepare Alert Message"
2. Configure SMTP credentials
3. Connect to alert path

### Add More Notification Channels

Supported options:
- **SMS:** Twilio node
- **Discord:** Discord webhook
- **Telegram:** Telegram bot
- **PagerDuty:** For urgent alerts
- **IFTTT:** For smart home integration

## Troubleshooting

### Workflow not running on schedule

1. Check workflow is **Active** (toggle at top right)
2. Check n8n container is running:
   ```bash
   ssh graeme@n8nserver "sudo docker ps | grep n8n"
   ```
3. Check executions tab for errors

### SSH connection fails

1. Verify claude VM is online:
   ```bash
   ssh graeme@claude uptime
   ```
2. Check SSH key in n8n credentials allows access from n8nserver to claude VM
3. Test SSH from n8n server:
   ```bash
   ssh graeme@n8nserver
   ssh graeme@100.83.146.108 "echo test"
   ```
4. Verify the monitoring script exists on claude VM:
   ```bash
   ssh graeme@claude "ls -l ~/check-mum-activity.sh"
   ```

### Claude API errors

1. Check API key is valid: https://console.anthropic.com/settings/keys
2. Check API quota/billing
3. View error in execution log

### Slack alerts not working

1. Check webhook URL is correct
2. Test webhook manually:
   ```bash
   curl -X POST -H 'Content-type: application/json' \
     --data '{"text":"Test alert"}' \
     YOUR_WEBHOOK_URL
   ```
3. Note: Slack node has "Continue on fail" enabled, so workflow won't stop if Slack fails

### Logs not being written

1. Check log directory exists:
   ```bash
   ssh graeme@claude "ls -la ~/logs/"
   ```
2. Check permissions:
   ```bash
   ssh graeme@claude "touch ~/logs/test.log && rm ~/logs/test.log"
   ```

## Advanced Configuration

### Environment Variables

n8n is configured via environment variables. To modify:

```bash
ssh graeme@n8nserver
sudo docker inspect n8n | grep -A30 Env
```

Common variables:
- `N8N_BASIC_AUTH_ACTIVE=true` - Enable authentication
- `N8N_BASIC_AUTH_USER` - Username
- `N8N_BASIC_AUTH_PASSWORD` - Password
- `WEBHOOK_URL` - For external webhooks
- `N8N_ENCRYPTION_KEY` - For credential encryption

### Backup Workflow

Export workflow regularly:

1. In n8n UI: **Workflow → Export**
2. Save to: `~/lisarda-repo/n8n-workflows/backups/`
3. Commit to git

Or via CLI:
```bash
ssh graeme@n8nserver "sudo docker exec n8n n8n export:workflow --all --output=/tmp/workflows.json"
```

### API Access

n8n also provides REST API access:

**Example: Trigger workflow via API**
```bash
curl -X POST http://100.68.66.20:5678/webhook/manual-check-mum
```

## Monitoring n8n Health

### Check n8n is running
```bash
ssh graeme@n8nserver "sudo docker ps | grep n8n"
```

### View n8n logs
```bash
ssh graeme@n8nserver "sudo docker logs -f n8n"
```

### Restart n8n
```bash
ssh graeme@n8nserver "sudo docker restart n8n"
```

### Check disk space
```bash
ssh graeme@n8nserver "df -h"
```

## Cost Estimate

**Anthropic API Costs:**
- Model: Claude Sonnet 4.5
- Input: ~500 tokens per check (script output)
- Output: ~200 tokens per check (interpretation)
- Cost: ~$0.01 per check
- **Daily:** 2 checks × $0.01 = **$0.02/day**
- **Monthly:** ~**$0.60/month**

**Optimization:**
- Use Claude Haiku for cheaper alternative (~$0.001 per check)
- Reduce to 1 check per day

## Integration with Claude Code

When you ask "check on mum" in Claude Code, you can now:

1. **Manual CLI:** `ssh graeme@claude '~/check-mum-activity.sh'` (instant)
2. **n8n Manual Trigger:** View latest automated check in n8n UI
3. **View Logs:** `ssh graeme@claude "tail ~/logs/mum-activity-monitor.log"`

## Maintenance

### Weekly
- Check execution history in n8n UI
- Review alert logs

### Monthly
- Verify credentials still valid
- Check disk space on n8nserver
- Review and adjust schedule if needed
- Export workflow backup

### As Needed
- Update alert thresholds based on patterns
- Add new notification channels
- Adjust schedule for seasonal changes

## Related Documentation

- **Main script:** `/home/graeme/check-mum-activity.sh`
- **Script docs:** `~/lisarda-repo/docs/check-mum-activity-guide.md`
- **GitHub repo:** https://github.com/graemejross/lisarda
- **n8n docs:** https://docs.n8n.io

## Support

**n8n Issues:**
- n8n Community: https://community.n8n.io
- n8n Docs: https://docs.n8n.io

**Workflow Issues:**
- Check execution logs in n8n
- Review this documentation
- Test each node individually

---

**Created:** 2025-12-09
**Version:** 1.0
**Workflow File:** `/home/graeme/lisarda-repo/n8n-workflows/mum-activity-monitor.json`
**n8n Server:** n8nserver (100.68.66.20:5678)
