# Check Mum Activity Script

## Overview

**Script:** `/home/graeme/check-mum-activity.sh`

A comprehensive monitoring script that checks mum's activity at Lisarda by analyzing motion sensor data from her Home Assistant installation via Zigbee motion sensors.

## Purpose

Provides a quick health check to ensure mum is moving around the house normally, with automatic alerts for unusual patterns or sensor issues.

## Features

- ✅ Real-time system connectivity check
- ✅ Zigbee coordinator status verification
- ✅ All 6 motion sensor status monitoring
- ✅ Activity summary by room with timestamps
- ✅ Recent activity timeline (last 10 events)
- ✅ Intelligent assessment with color-coded alerts
- ✅ Configurable time window (default: 24 hours)

## Usage

### Basic Usage
```bash
~/check-mum-activity.sh
```
Shows activity for the last 24 hours (default).

### Custom Time Window
```bash
~/check-mum-activity.sh 2    # Last 2 hours
~/check-mum-activity.sh 48   # Last 48 hours
~/check-mum-activity.sh 168  # Last week
```

## Output Explanation

### Section 1: System Status
- **Green ✓**: System online and reachable
- **Red ✗**: Cannot connect (investigate immediately)
- Shows system uptime

### Section 2: Sensor Status
- **Green ✓**: All 6 motion sensors online
- **Red ✗**: Some sensors offline (number shown)
- **Yellow ⚠**: Status unknown (rare)

### Section 3: Activity Summary
Table showing activity by room:
- **Room**: Which room detected motion
- **Detections**: Number of motion events
- **First Seen**: First motion in time window
- **Last Seen**: Most recent motion
- **Total**: Sum of all motion events

### Section 4: Recent Activity
Last 10 motion events with timestamps, most recent first.

### Section 5: Assessment
Intelligent analysis with color-coded alerts:

**Green ✓ Everything appears normal**
- Last motion < 30 minutes ago
- Activity level normal (100+ events/day)

**Yellow ⚠ Caution**
- Last motion 30 minutes - 2 hours ago (might be resting)
- Last motion 2-6 hours ago (could be out/sleeping)
- Activity level: Low (10-50 events) or Moderate (50-100 events)

**Red ✗ Warning**
- No motion for 6+ hours (check on her!)
- Zero activity detected
- Sensors offline

## Monitored Rooms

1. **Kitchen** - Most active area (cooking, eating)
2. **Hallway** - High traffic (connects all rooms)
3. **Bedroom** - Morning/evening/rest periods
4. **Lounge** - TV watching, relaxing
5. **Study** - Computer use, activities
6. **Upstairs** (Landing) - Bathroom access, storage

## Technical Details

### Connection
- **Host**: 100.113.132.97 (lisarda-ha via Tailscale)
- **SSH Key**: `~/.ssh/lisarda-ha`
- **User**: graeme
- **Database**: `/config/home-assistant_v2.db` (SQLite)
- **Timeout**: 10 seconds per query

### Sensors
- **Type**: eWeLink SNZB-03P Motion Sensors (Zigbee)
- **Battery**: CR2450 (lasts ~1 year)
- **Detection**: PIR (passive infrared)
- **Entities**: `binary_sensor.*_movement_occupancy`

### Data Source
Queries Home Assistant's SQLite database directly:
- `states` table: Current and historical sensor states
- `states_meta` table: Entity metadata
- Timezone: Converted to local time (GMT)

## Troubleshooting

### "Cannot connect to Lisarda Home Assistant"
1. Check Tailscale connection: `tailscale status | grep lisarda`
2. Ping the host: `ping 100.113.132.97`
3. Check SSH key: `ls -la ~/.ssh/lisarda-ha`
4. Check if HA is running: `ssh -i ~/.ssh/lisarda-ha graeme@100.113.132.97 uptime`

### "All sensors offline"
1. Run the script again (might be temporary)
2. Check if coordinator disconnected: `ssh ... "ls -l /dev/ttyUSB*"`
3. Reboot HA if needed: `ssh ... "sudo reboot"`
4. Wait 5 minutes for battery sensors to reconnect

### "No activity detected"
- **Time of day**: Check if it's nighttime (sleeping)
- **Out**: She might be out shopping/visiting
- **Holiday**: Check if she's away
- **Sensor batteries**: Check battery levels in HA
- **Call her**: If unusual pattern, call to verify she's okay

### "Activity level: Low"
- Normal for:
  - Early morning (still sleeping)
  - Evening (sitting watching TV)
  - Away from home
- Investigate if:
  - Low activity all day
  - Combined with no recent motion

## Maintenance

### Battery Replacement
Motion sensors use CR2450 batteries:
- **Lifespan**: ~12 months
- **Warning**: Battery level < 20% in Home Assistant
- **Replacement**: Have spare batteries ready

### Script Updates
Script location: `/home/graeme/check-mum-activity.sh`

To modify:
```bash
nano ~/check-mum-activity.sh
```

### Testing
Test with different time windows:
```bash
~/check-mum-activity.sh 1    # Last hour (should show recent activity)
~/check-mum-activity.sh 168  # Last week (should show 1000+ events)
```

## Integration with Claude Code

### When User Says "Check on Mum"
Claude should:
1. Run: `/home/graeme/check-mum-activity.sh`
2. Interpret the results
3. Provide summary in natural language
4. Highlight any concerns

### Example Responses

**Normal Activity:**
> "Mum is doing well! She's been active throughout the day with 233 motion events. Most recent activity was in the kitchen 23 minutes ago. Everything appears normal."

**Low Activity:**
> "Mum's activity is a bit lower than usual today (45 events). Last motion was in the bedroom 2 hours ago. She might be resting or out. Everything seems okay, but worth noting."

**No Recent Motion:**
> "⚠️ No motion detected for 8 hours. Last activity was in the bedroom at 09:30. This is unusual - she might be out, sleeping late, or there could be a sensor issue. Consider calling to check in."

**Sensors Offline:**
> "⚠️ System alert: 3 motion sensors are offline. This happened after the system reboot. Sensors need to reconnect. I can restart the system if needed."

## Examples

### Example 1: Normal Day
```bash
$ ~/check-mum-activity.sh

=== Checking on Mum (Last 24 hours) ===
Time: 2025-12-09 17:31:46 GMT

[1/4] System Status
✓ System online - 17:31:46 up 1:20, 0 user, load average: 0.15, 0.13, 0.10

[2/4] Sensor Status
✓ All 6 motion sensors online

[3/4] Activity Summary (Last 24h)
Room          Detections   First Seen    Last Seen
----------------------------------------------------
Kitchen               78        17:42        17:08
Hallway               82        19:24        17:03
Bedroom               28        19:26        17:04
Lounge                36        18:03        16:54
Study                  9        08:55        14:53

Total motion events: 233

[4/4] Recent Activity (Last 10 Events)
Room         Timestamp
------------------------------------
Kitchen      2025-12-09 17:08:33
Bedroom      2025-12-09 17:04:10
Hallway      2025-12-09 17:03:57

[Assessment]
✓ Recent activity detected (23 minutes ago)
✓ Everything appears normal
✓ Activity level: Normal
```

### Example 2: Last 2 Hours Only
```bash
$ ~/check-mum-activity.sh 2

=== Checking on Mum (Last 2 hours) ===
[Shows only last 2 hours of activity...]
```

### Example 3: Week Overview
```bash
$ ~/check-mum-activity.sh 168

=== Checking on Mum (Last 168 hours) ===
[Shows full week of activity...]
```

## Related Documentation

- **Main Project**: `~/projects.md` (Project #4: Lisarda Home Assistant)
- **System Audit**: `~/projects/lisarda-ha/system-audit-2025-12-01.md`
- **Zigbee Setup**: `~/projects/sonoff-zigbee/sonoff-zigbee-setup-guide.md`
- **Session History**: `~/claude-history/2025-11-27-lisarda-ha.md`

## Quick Reference

| Command | Purpose |
|---------|---------|
| `~/check-mum-activity.sh` | Check last 24 hours |
| `~/check-mum-activity.sh 2` | Check last 2 hours |
| `~/check-mum-activity.sh 168` | Check last week |
| `ssh -i ~/.ssh/lisarda-ha graeme@100.113.132.97` | SSH to Lisarda HA |
| `tailscale status \| grep lisarda` | Check Tailscale connection |

## Support

- **Script Issues**: Check permissions (`chmod +x`), SSH key access
- **No Data**: Check database path, query syntax
- **False Alarms**: Adjust threshold in Assessment section
- **Network Issues**: Check Tailscale, SSH connectivity

---

**Last Updated**: 2025-12-09
**Version**: 1.0
**Author**: Claude Code
**Location**: `/home/graeme/check-mum-activity.sh`
