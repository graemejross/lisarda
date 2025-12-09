#!/bin/bash
#
# check-mum-activity.sh
# Checks mum's movement activity at Lisarda via Home Assistant motion sensors
#
# Usage: ./check-mum-activity.sh [hours]
#   hours: Optional, defaults to 24. Show activity for last N hours.
#
# Examples:
#   ./check-mum-activity.sh          # Today's activity
#   ./check-mum-activity.sh 2        # Last 2 hours
#   ./check-mum-activity.sh 48       # Last 48 hours
#

set -euo pipefail

# Configuration
LISARDA_HOST="100.113.132.97"
SSH_KEY="$HOME/.ssh/lisarda-ha"
SSH_USER="graeme"
DB_PATH="/config/home-assistant_v2.db"
TIMEOUT=10

# Hours to check (default: 24, or from command line)
HOURS=${1:-24}

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Function to run SQL query on lisarda-ha
run_query() {
    local query="$1"
    timeout "$TIMEOUT" ssh -i "$SSH_KEY" "$SSH_USER@$LISARDA_HOST" \
        "sqlite3 \"$DB_PATH\" \"$query\"" 2>/dev/null || echo "ERROR"
}

# Print header
echo -e "${BOLD}=== Checking on Mum (Last ${HOURS} hours) ===${NC}"
echo -e "Time: $(date '+%Y-%m-%d %H:%M:%S %Z')\n"

# Check system connectivity
echo -e "${BLUE}[1/4] System Status${NC}"
UPTIME=$(timeout "$TIMEOUT" ssh -i "$SSH_KEY" "$SSH_USER@$LISARDA_HOST" "uptime" 2>/dev/null || echo "OFFLINE")
if [[ "$UPTIME" == "OFFLINE" ]]; then
    echo -e "${RED}✗ Cannot connect to Lisarda Home Assistant${NC}"
    exit 1
fi
echo -e "${GREEN}✓ System online${NC} - $UPTIME"

# Check Zigbee coordinator
ZIGBEE_USB=$(run_query "SELECT 1 FROM states_meta WHERE entity_id LIKE '%zha%' OR entity_id LIKE '%zigbee%' LIMIT 1;")
if [[ "$ZIGBEE_USB" == "1" ]]; then
    echo -e "${GREEN}✓ Zigbee coordinator operational${NC}"
else
    echo -e "${YELLOW}⚠ Zigbee coordinator status unknown${NC}"
fi
echo ""

# Check sensor status
echo -e "${BLUE}[2/4] Sensor Status${NC}"

# Count unavailable motion sensors
UNAVAILABLE=$(run_query "
SELECT COUNT(DISTINCT sm.entity_id)
FROM states s
JOIN states_meta sm ON s.metadata_id = sm.metadata_id
WHERE sm.entity_id LIKE '%movement_occupancy%'
  AND s.last_updated_ts = (
    SELECT MAX(last_updated_ts)
    FROM states
    WHERE metadata_id = sm.metadata_id
  )
  AND s.state = 'unavailable';
")

TOTAL_SENSORS=6
if [[ "$UNAVAILABLE" == "0" ]]; then
    echo -e "${GREEN}✓ All $TOTAL_SENSORS motion sensors online${NC}"
elif [[ "$UNAVAILABLE" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}✗ $UNAVAILABLE of $TOTAL_SENSORS motion sensors offline${NC}"
else
    echo -e "${YELLOW}⚠ Cannot determine sensor status${NC}"
fi
echo ""

# Get activity summary by room
echo -e "${BLUE}[3/4] Activity Summary (Last ${HOURS}h)${NC}"

ACTIVITY=$(run_query "
SELECT
  CASE
    WHEN sm.entity_id LIKE '%kitchen%' THEN 'Kitchen'
    WHEN sm.entity_id LIKE '%lounge%' THEN 'Lounge'
    WHEN sm.entity_id LIKE '%bedroom%' THEN 'Bedroom'
    WHEN sm.entity_id LIKE '%hallway%' THEN 'Hallway'
    WHEN sm.entity_id LIKE '%study%' THEN 'Study'
    WHEN sm.entity_id LIKE '%upstairs%' THEN 'Upstairs'
  END as room,
  COUNT(*) as detections,
  strftime('%H:%M', MIN(datetime(s.last_updated_ts, 'unixepoch', 'localtime'))) as first_seen,
  strftime('%H:%M', MAX(datetime(s.last_updated_ts, 'unixepoch', 'localtime'))) as last_seen
FROM states s
JOIN states_meta sm ON s.metadata_id = sm.metadata_id
WHERE sm.entity_id LIKE '%movement_occupancy%'
  AND s.state = 'on'
  AND s.last_updated_ts > strftime('%s', 'now', '-${HOURS} hours')
GROUP BY room
ORDER BY MAX(s.last_updated_ts) DESC;
")

if [[ "$ACTIVITY" == "ERROR" ]] || [[ -z "$ACTIVITY" ]]; then
    echo -e "${YELLOW}⚠ No activity detected in last ${HOURS} hours${NC}"
    TOTAL_DETECTIONS=0
else
    # Print table header
    printf "${BOLD}%-12s %11s %12s %12s${NC}\n" "Room" "Detections" "First Seen" "Last Seen"
    printf "%s\n" "----------------------------------------------------"

    # Print activity data and count total
    TOTAL_DETECTIONS=0
    while IFS='|' read -r room detections first last; do
        printf "%-12s %11s %12s %12s\n" "$room" "$detections" "$first" "$last"
        TOTAL_DETECTIONS=$((TOTAL_DETECTIONS + detections))
    done <<< "$ACTIVITY"

    echo ""
    echo -e "${BOLD}Total motion events: $TOTAL_DETECTIONS${NC}"
fi
echo ""

# Get recent activity (last 10 events)
echo -e "${BLUE}[4/4] Recent Activity (Last 10 Events)${NC}"

RECENT=$(run_query "
SELECT
  CASE
    WHEN sm.entity_id LIKE '%kitchen%' THEN 'Kitchen'
    WHEN sm.entity_id LIKE '%lounge%' THEN 'Lounge'
    WHEN sm.entity_id LIKE '%bedroom%' THEN 'Bedroom'
    WHEN sm.entity_id LIKE '%hallway%' THEN 'Hallway'
    WHEN sm.entity_id LIKE '%study%' THEN 'Study'
    WHEN sm.entity_id LIKE '%upstairs%' THEN 'Upstairs'
  END as room,
  datetime(s.last_updated_ts, 'unixepoch', 'localtime') as timestamp
FROM states s
JOIN states_meta sm ON s.metadata_id = sm.metadata_id
WHERE sm.entity_id LIKE '%movement_occupancy%'
  AND s.state = 'on'
ORDER BY s.last_updated_ts DESC
LIMIT 10;
")

if [[ "$RECENT" == "ERROR" ]] || [[ -z "$RECENT" ]]; then
    echo -e "${YELLOW}⚠ No recent activity${NC}"
else
    printf "${BOLD}%-12s %s${NC}\n" "Room" "Timestamp"
    printf "%s\n" "------------------------------------"
    echo "$RECENT" | while IFS='|' read -r room timestamp; do
        printf "%-12s %s\n" "$room" "$timestamp"
    done
fi
echo ""

# Alert assessment
echo -e "${BLUE}[Assessment]${NC}"

# Calculate time since last motion
LAST_MOTION=$(run_query "
SELECT
  CAST((strftime('%s', 'now') - MAX(s.last_updated_ts)) / 60.0 AS INTEGER) as minutes_ago
FROM states s
JOIN states_meta sm ON s.metadata_id = sm.metadata_id
WHERE sm.entity_id LIKE '%movement_occupancy%'
  AND s.state = 'on';
")

if [[ "$LAST_MOTION" =~ ^[0-9]+$ ]]; then
    if [[ "$LAST_MOTION" -lt 30 ]]; then
        echo -e "${GREEN}✓ Recent activity detected ($LAST_MOTION minutes ago)${NC}"
        echo -e "${GREEN}✓ Everything appears normal${NC}"
    elif [[ "$LAST_MOTION" -lt 120 ]]; then
        echo -e "${YELLOW}⚠ Last motion was $LAST_MOTION minutes ago${NC}"
        echo -e "${YELLOW}  (Might be resting/sleeping/out)${NC}"
    elif [[ "$LAST_MOTION" -lt 360 ]]; then
        HOURS_AGO=$((LAST_MOTION / 60))
        echo -e "${YELLOW}⚠ Last motion was $HOURS_AGO hours ago${NC}"
        echo -e "${YELLOW}  (Could be out, sleeping, or sensor issue)${NC}"
    else
        HOURS_AGO=$((LAST_MOTION / 60))
        echo -e "${RED}✗ WARNING: No motion for $HOURS_AGO hours${NC}"
        echo -e "${RED}  (Check if she's okay or if sensors are offline)${NC}"
    fi

    # Activity level assessment
    if [[ "$TOTAL_DETECTIONS" -gt 100 ]] && [[ "$LAST_MOTION" -lt 60 ]]; then
        echo -e "${GREEN}✓ Activity level: Normal${NC}"
    elif [[ "$TOTAL_DETECTIONS" -gt 50 ]]; then
        echo -e "${GREEN}✓ Activity level: Moderate${NC}"
    elif [[ "$TOTAL_DETECTIONS" -gt 10 ]]; then
        echo -e "${YELLOW}⚠ Activity level: Low${NC}"
    elif [[ "$TOTAL_DETECTIONS" -eq 0 ]]; then
        echo -e "${RED}✗ Activity level: None detected${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Cannot determine last motion time${NC}"
fi

echo ""
echo -e "${BOLD}=== End of Report ===${NC}"
