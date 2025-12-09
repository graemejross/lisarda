# Lisarda Monitoring Architecture

## System Overview

The Lisarda activity monitoring system uses a multi-tier architecture to monitor mum's activity through motion sensors at her home.

## Architecture Diagram

```
┌──────────────┐         ┌──────────────┐         ┌──────────────┐
│   n8n        │   SSH   │    claude    │   SSH   │   Lisarda    │
│ n8nserver    │────────>│      VM      │────────>│     HA       │
│              │         │              │         │  (Raspberry  │
│ 100.68.66.20 │         │100.83.146.108│         │   Pi 4)      │
└──────────────┘         └──────────────┘         └──────────────┘
                                │                         │
                                │                    ┌────┴─────┐
                                │                    │ SQLite   │
                                │                    │ Database │
                                │                    └──────────┘
                                │                         │
                                │                    6 Zigbee Motion
                                │                    Sensors (via
                                │                    ZBDongle-P)
                                ↓
                         ┌──────────────┐
                         │ Anthropic    │
                         │ Claude API   │
                         └──────────────┘
```

## Components

### 1. n8n Workflow (n8nserver)

**Location:** Docker container on n8nserver (100.68.66.20:5678)

**Responsibilities:**
- Schedule automation (9 AM & 6 PM daily)
- Trigger manual checks via webhook
- Orchestrate the monitoring workflow
- Send alerts to Slack (optional)
- Write logs to claude VM

**Files:**
- `/home/graeme/lisarda-repo/n8n-workflows/mum-activity-monitor.json` - Workflow definition
- `/home/graeme/lisarda-repo/docs/n8n-workflow-setup.md` - Setup guide

### 2. Claude VM (Monitoring Host)

**Location:** 100.83.146.108 (Tailscale: balinese-butterfly.ts.net)

**Responsibilities:**
- Hosts the monitoring script
- SSHs to Lisarda HA to query database
- Executes monitoring logic
- Stores activity logs

**Files:**
- `/home/graeme/check-mum-activity.sh` - Main monitoring script (262 lines)
- `/home/graeme/logs/mum-activity-monitor.log` - Normal check logs
- `/home/graeme/logs/mum-activity-alerts.log` - Alert logs
- `/home/graeme/.ssh/lisarda-ha` - SSH key for Lisarda HA access

**Key Script Features:**
- Color-coded terminal output
- Intelligent assessment (Normal/Warning/Error)
- Room-by-room activity breakdown
- Configurable time windows
- Connection timeout handling

### 3. Lisarda HA (Data Source)

**Location:** 100.113.132.97 (Raspberry Pi 4)
**OS:** Home Assistant OS 16.2

**Responsibilities:**
- Runs Home Assistant Core
- Manages Zigbee network via ZHA integration
- Stores sensor data in SQLite database
- Provides data via SSH/database queries

**Hardware:**
- Sonoff ZBDongle-P (USB coordinator)
- 6 Sonoff SNZB-03P motion sensors

**Database:**
- Path: `/config/home-assistant_v2.db`
- Tables used: `states`, `states_meta`
- Query method: SQLite over SSH

### 4. Claude AI (Interpretation)

**Service:** Anthropic API (api.anthropic.com)
**Model:** claude-sonnet-4-5-20250929

**Responsibilities:**
- Natural language interpretation of monitoring data
- Pattern analysis
- Risk assessment
- Recommendation generation

**Cost:** ~$0.60/month (2 checks/day × $0.01/check)

## Data Flow

### Scheduled Check Flow

1. **n8n Schedule Trigger** (9 AM / 6 PM GMT)
2. **SSH: n8nserver → claude VM**
   - Executes: `/home/graeme/check-mum-activity.sh`
3. **SSH: claude VM → Lisarda HA**
   - Queries SQLite database
   - Returns sensor data
4. **Script Processing** (on claude VM)
   - Aggregates motion events
   - Calculates time since last activity
   - Formats color-coded output
5. **Claude AI Interpretation** (via n8n HTTP Request)
   - Sends script output to Anthropic API
   - Receives natural language interpretation
6. **Alert Decision** (n8n IF node)
   - Checks for keywords: warning, concern, unusual, alert
   - Checks for script warnings: "✗ WARNING", "sensors offline"
7. **Output Routing**
   - **Normal:** Log to `mum-activity-monitor.log`
   - **Alert:** Send to Slack + log to `mum-activity-alerts.log`

### Manual Check Flow

1. **User Command:** `ssh graeme@claude '~/check-mum-activity.sh'`
2. Same steps 3-4 as above
3. Output directly to terminal (no AI interpretation)

OR

1. **n8n Manual Trigger:** Execute workflow button in UI
2. Same steps 2-7 as scheduled flow

## Authentication & Security

### SSH Keys

**n8nserver → claude:**
- n8n stores SSH private key for graeme@claude
- Allows n8n to execute monitoring script remotely

**claude → Lisarda HA:**
- Key: `/home/graeme/.ssh/lisarda-ha`
- Configured in monitoring script
- Read-only database access

### API Keys

**Anthropic API:**
- Stored in n8n credentials (HTTP Header Auth)
- Header: `x-api-key`
- Required for Claude AI interpretation

**Slack Webhook (Optional):**
- Stored in n8n credentials
- Used for alert notifications
- Webhook format: `https://hooks.slack.com/services/...`

### Network

**Tailscale VPN:**
- All systems on private network: balinese-butterfly.ts.net
- No public internet exposure
- SSH traffic encrypted over Tailscale

## Alert Conditions

Alerts trigger when ANY of these conditions are met:

1. **AI Interpretation contains:**
   - "warning"
   - "concern"
   - "unusual"
   - "alert"

2. **Script Output contains:**
   - "✗ WARNING"
   - "sensors offline"

3. **Time-based:**
   - No motion > 6 hours (flagged by script)
   - Last activity > 8 hours (critical warning)

## Monitoring Points

### System Health
- ✓ Lisarda HA system online/uptime
- ✓ Zigbee coordinator status
- ✓ Motion sensor online status (6 sensors)

### Activity Tracking
- ✓ Motion events per room
- ✓ Time since last motion (per room + overall)
- ✓ First/last seen timestamps
- ✓ Activity level assessment (Low/Moderate/High)

### Historical Data
- ✓ Recent event log (last 10 events)
- ✓ Configurable time windows (default: 24h)
- ✓ Trend analysis via Claude AI

## Failure Modes & Recovery

### Lisarda HA Offline
- **Detection:** SSH timeout (10s)
- **Alert:** "✗ Unable to connect to Lisarda HA"
- **Recovery:** Automatic retry on next scheduled run

### Zigbee Sensors Offline
- **Detection:** Sensor state = "unavailable"
- **Alert:** "✗ Motion sensors offline"
- **Recovery:** System reboot or wait for auto-reconnect

### n8n Service Down
- **Detection:** Manual (no scheduled checks run)
- **Fallback:** Manual CLI checks still work
- **Recovery:** `ssh graeme@n8nserver "sudo docker restart n8n"`

### Claude API Failure
- **Detection:** HTTP error from api.anthropic.com
- **Impact:** No AI interpretation, but script still logs raw data
- **Recovery:** n8n retry logic + check API status

### SSH Key Issues
- **Detection:** Permission denied errors
- **Recovery:** Re-add SSH public key to authorized_keys

## Maintenance

### Daily (Automated)
- 9 AM: Morning activity check
- 6 PM: Evening activity check

### Weekly (Manual)
- Review execution history in n8n
- Check log files for patterns

### Monthly (Manual)
- Verify API credentials valid
- Check disk space on claude VM
- Export workflow backup
- Review alert thresholds

### As Needed
- Update sensor battery (CR2450, ~12 month life)
- Adjust alert keywords based on patterns
- Add notification channels

## Future Enhancements

### Potential Improvements
1. **Battery monitoring** - Track sensor battery levels
2. **Temperature tracking** - Add temperature sensors
3. **Medication reminders** - Time-based notifications
4. **Activity patterns** - ML-based anomaly detection
5. **Multi-channel alerts** - SMS via Twilio, Email via SMTP
6. **Dashboard** - Grafana visualization of historical data
7. **Voice updates** - "Alexa, check on mum"

## Documentation

### Primary Docs
- `check-mum-activity.sh` - Main monitoring script
- `docs/check-mum-activity-guide.md` - Script usage guide (480 lines)
- `docs/n8n-workflow-setup.md` - n8n deployment guide (407 lines)
- `docs/ARCHITECTURE.md` - This document

### Related
- `~/projects.md` - Project tracking
- `~/claude-history/2025-12-09-mum-activity-monitor.md` - Session history

### Repository
- **GitHub:** https://github.com/graemejross/lisarda
- **Structure:**
  - `scripts/` - Monitoring scripts
  - `docs/` - Documentation
  - `n8n-workflows/` - Workflow definitions
  - `.gitignore` - Security (excludes SSH keys, credentials, logs)

## Support

### Common Issues
See `docs/n8n-workflow-setup.md` - Troubleshooting section

### Testing
```bash
# Test monitoring script
ssh graeme@claude '~/check-mum-activity.sh 6'

# Test from Mac (one-liner)
ssh graeme@claude '/home/graeme/check-mum-activity.sh' | tail -20

# View logs
ssh graeme@claude 'tail -50 ~/logs/mum-activity-monitor.log'
ssh graeme@claude 'tail -50 ~/logs/mum-activity-alerts.log'
```

---

**Created:** 2025-12-09
**Version:** 1.0
**Last Updated:** 2025-12-09
