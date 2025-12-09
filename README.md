# Lisarda Home Assistant Monitoring

Remote monitoring and management tools for Lisarda Home Assistant installation.

## Overview

This repository contains scripts and documentation for monitoring mum's activity at Lisarda through Home Assistant motion sensors. The system provides automated health checks, activity tracking, and intelligent assessment to ensure wellbeing remotely.

## System Architecture

- **Home Assistant**: Raspberry Pi 4 running Home Assistant OS 16.2
- **Network**: Tailscale VPN (balinese-butterfly.ts.net)
- **Zigbee Coordinator**: Sonoff ZBDongle-P (USB)
- **Sensors**: 11 Zigbee devices across 6 rooms
  - 6x eWeLink SNZB-03P Motion Sensors
  - 4x Sonoff SNZB-02D Temperature/Humidity Sensors
  - 1x Innr SP 222 Smart Plug (mesh router)

## Features

- ✅ Real-time activity monitoring via motion sensors
- ✅ Automated system health checks
- ✅ Intelligent assessment with color-coded alerts
- ✅ Room-by-room activity breakdown
- ✅ Configurable time windows
- ✅ Recent activity timeline

## Repository Structure

```
lisarda/
├── scripts/
│   └── check-mum-activity.sh       # Main monitoring script
├── docs/
│   └── check-mum-activity-guide.md # Complete documentation
└── README.md                        # This file
```

## Quick Start

### Prerequisites

1. **SSH Access**: SSH key authentication to Lisarda Home Assistant
   ```bash
   ssh -i ~/.ssh/lisarda-ha graeme@100.113.132.97
   ```

2. **Tailscale**: Connected to balinese-butterfly.ts.net network

### Installation

```bash
# Clone the repository
git clone https://github.com/graemejross/lisarda.git
cd lisarda

# Make the script executable
chmod +x scripts/check-mum-activity.sh

# Run a test
./scripts/check-mum-activity.sh
```

### Configuration

Edit `scripts/check-mum-activity.sh` and update these variables:

```bash
LISARDA_HOST="100.113.132.97"        # Tailscale IP of Home Assistant
SSH_KEY="$HOME/.ssh/lisarda-ha"      # Path to SSH private key
SSH_USER="graeme"                     # SSH username
DB_PATH="/config/home-assistant_v2.db" # Home Assistant database path
```

## Usage

### Basic Usage

```bash
# Check last 24 hours (default)
./scripts/check-mum-activity.sh

# Check last 2 hours
./scripts/check-mum-activity.sh 2

# Check last week
./scripts/check-mum-activity.sh 168
```

### Output

The script provides:

1. **System Status** - Connectivity and uptime
2. **Sensor Status** - All 6 motion sensors online/offline
3. **Activity Summary** - Motion events by room with timestamps
4. **Recent Activity** - Last 10 motion events
5. **Assessment** - Intelligent health check with color-coded alerts

### Assessment Levels

- **🟢 Green (Normal)**: Recent activity (< 30 min), normal level (100+ events/day)
- **🟡 Yellow (Caution)**: 30min - 6 hours since last motion, or low activity
- **🔴 Red (Warning)**: 6+ hours no motion, sensors offline, or no activity

## Documentation

Complete documentation available in [`docs/check-mum-activity-guide.md`](docs/check-mum-activity-guide.md):

- Detailed usage instructions
- Output interpretation guide
- Troubleshooting steps
- Technical details
- Maintenance procedures
- Example scenarios

## Monitored Rooms

| Room | Sensor Type | Usage Pattern |
|------|-------------|---------------|
| Kitchen | Motion | High activity (cooking, eating) |
| Hallway | Motion | High traffic (connects all rooms) |
| Bedroom | Motion | Morning/evening/rest periods |
| Lounge | Motion | TV watching, relaxing |
| Study | Motion | Computer use, activities |
| Upstairs (Landing) | Motion | Bathroom access, storage |

## Technical Details

### Connection Method

- **Protocol**: SSH with key authentication
- **Network**: Tailscale VPN (no port forwarding)
- **Database**: Direct SQLite queries on Home Assistant database
- **Timeout**: 10 seconds per query

### Sensor Technology

- **Type**: PIR (Passive Infrared) motion detection
- **Protocol**: Zigbee 3.0
- **Battery**: CR2450 (12-month lifespan)
- **Range**: ~5 meters detection radius

### Data Source

Queries Home Assistant's SQLite database:
- `states` table: Current and historical sensor states
- `states_meta` table: Entity metadata
- `zigbee.db`: Zigbee network information

## Troubleshooting

### Connection Issues

```bash
# Check Tailscale connection
tailscale status | grep lisarda

# Test SSH access
ssh -i ~/.ssh/lisarda-ha graeme@100.113.132.97 "uptime"

# Check database access
ssh -i ~/.ssh/lisarda-ha graeme@100.113.132.97 "ls -lh /config/home-assistant_v2.db"
```

### Sensors Offline

If all sensors show unavailable:
1. Reboot Home Assistant: `ssh ... "sudo reboot"`
2. Wait 5 minutes for battery sensors to reconnect
3. Run script again to verify recovery

### No Activity Detected

Consider:
- Time of day (might be sleeping)
- Out of house (shopping/visiting)
- Sensor battery levels
- Call to verify if pattern is unusual

## Maintenance

### Battery Replacement

Motion sensors use CR2450 batteries:
- **Lifespan**: ~12 months
- **Warning**: Battery level < 20% in Home Assistant
- **Action**: Replace battery, press reset button to reconnect

### Script Updates

Pull latest changes:
```bash
cd ~/lisarda
git pull origin main
```

## Security

- **No Credentials**: Script contains no passwords or private keys
- **SSH Key Required**: Must have authorized SSH key for access
- **VPN Only**: System accessible only via Tailscale VPN
- **Read-Only**: Script performs read-only database queries

### Sensitive Files (Not in Repository)

- SSH private key: `~/.ssh/lisarda-ha`
- Home Assistant credentials
- Tailscale authentication

## Contributing

This is a personal monitoring system. For issues or improvements:

1. Create an issue describing the problem
2. Fork the repository
3. Make your changes
4. Submit a pull request

## Related Projects

- **Main Infrastructure**: See `~/projects.md` on claude VM
- **Session History**: `~/claude-history/2025-12-09-mum-activity-monitor.md`
- **System Audit**: `~/projects/lisarda-ha/system-audit-2025-12-01.md`

## Support

For questions or issues:
- Review the [complete documentation](docs/check-mum-activity-guide.md)
- Check the [troubleshooting section](#troubleshooting)
- Open an issue on GitHub

## License

Private repository for personal use.

---

**Last Updated**: 2025-12-09
**Version**: 1.0
**Author**: Graeme Ross
**Status**: Production
