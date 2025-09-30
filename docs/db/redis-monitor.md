# Redis OOM Monitor - Quick Start Guide

## Overview

This monitoring system automatically discovers and tracks your Redis pod in the `portalappv6-chart` namespace, even after pod restarts.

## Features

✅ **Auto-Discovery** - Automatically finds Redis pod by label or name pattern
 ✅ **Restart Detection** - Detects pod restarts and reconnects automatically
 ✅ **Pre-OOM Snapshots** - Captures diagnostics at 85% and 95% thresholds
 ✅ **Multi-Level Alerts** - WARNING (70%), CRITICAL (85%), EMERGENCY (95%)
 ✅ **Continuous Monitoring** - Tracks both Redis maxmemory and container cgroup limits

------

```bash
#!/bin/bash
#
# Redis OOM Prevention Monitor (Auto-Discovery Version)
# Automatically detects Redis pod and handles pod restarts
#
# Usage: ./redis-monitor.sh [-n namespace] [-l label-selector] [-i interval] [-d logdir]
#

set -e

# Default configuration
NAMESPACE="portalappv6-chart"
LABEL_SELECTOR="app.kubernetes.io/name=portal-v6-redis"  # Adjust if your Redis pod has different labels
POD_NAME_PATTERN="redis"    # Pattern to match in pod name
INTERVAL=60                 # Check every 60 seconds
LOG_DIR="/var/log/redis-monitor"
ALERT_LOG="$LOG_DIR/alerts.log"
METRICS_LOG="$LOG_DIR/metrics.log"
SNAPSHOT_DIR="$LOG_DIR/snapshots"

# Thresholds (percentage)
WARN_THRESHOLD=70      # Warning at 70% of maxmemory
CRITICAL_THRESHOLD=85  # Critical at 85%
EMERGENCY_THRESHOLD=95 # Emergency at 95%

# Cgroup thresholds
CGROUP_WARN=60         # Warning at 60% of container limit
CGROUP_CRITICAL=75     # Critical at 75%
CGROUP_EMERGENCY=85    # Emergency at 85%

# Alert cooldown (seconds) - prevent alert spam
ALERT_COOLDOWN=300
LAST_ALERT_TIME=0

# Current pod tracking
CURRENT_POD=""
POD_START_TIME=""

# Color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
while getopts "n:l:i:d:p:h" opt; do
  case $opt in
    n) NAMESPACE="$OPTARG" ;;
    l) LABEL_SELECTOR="$OPTARG" ;;
    i) INTERVAL="$OPTARG" ;;
    d) LOG_DIR="$OPTARG" ;;
    p) POD_NAME_PATTERN="$OPTARG" ;;
    h) cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -n <namespace>       Kubernetes namespace (default: portalappv6-chart)
  -l <label-selector>  Label selector for Redis pod (default: app=redis)
  -p <pattern>         Pod name pattern to match (default: redis)
  -i <interval>        Check interval in seconds (default: 60)
  -d <logdir>          Log directory (default: /var/log/redis-monitor)
  -h                   Show this help message

Examples:
  $0                                    # Use all defaults
  $0 -n mynamespace -p portal-redis     # Custom namespace and pattern
  $0 -l app.kubernetes.io/name=redis    # Custom label selector
EOF
       exit 0 ;;
    *) echo "Invalid option. Use -h for help."; exit 1 ;;
  esac
done

# Update log paths
ALERT_LOG="$LOG_DIR/alerts.log"
METRICS_LOG="$LOG_DIR/metrics.log"
SNAPSHOT_DIR="$LOG_DIR/snapshots"

# Create log directories
mkdir -p "$LOG_DIR" "$SNAPSHOT_DIR"

# Function: Discover Redis pod
discover_redis_pod() {
  local pod=""
  
  # Method 1: Try label selector first
  if [[ -n "$LABEL_SELECTOR" ]]; then
    pod=$(kubectl get pods -n "$NAMESPACE" -l "$LABEL_SELECTOR" \
      --field-selector=status.phase=Running \
      -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  fi
  
  # Method 2: Fall back to name pattern matching
  if [[ -z "$pod" ]]; then
    pod=$(kubectl get pods -n "$NAMESPACE" \
      --field-selector=status.phase=Running \
      -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | \
      tr ' ' '\n' | grep -i "$POD_NAME_PATTERN" | head -1 || echo "")
  fi
  
  echo "$pod"
}

# Function: Get pod start time
get_pod_start_time() {
  local pod=$1
  kubectl get pod "$pod" -n "$NAMESPACE" \
    -o jsonpath='{.status.startTime}' 2>/dev/null || echo ""
}

# Function: Check if pod is still valid
is_pod_valid() {
  local pod=$1
  kubectl get pod "$pod" -n "$NAMESPACE" &>/dev/null
}

# Function: Execute redis-cli command
redis_cli() {
  if [[ -z "$CURRENT_POD" ]]; then
    return 1
  fi
  kubectl exec -n "$NAMESPACE" "$CURRENT_POD" -- redis-cli "$@" 2>/dev/null
}

# Function: Get memory info
get_memory_stats() {
  redis_cli INFO memory | grep -E "(used_memory:|used_memory_rss:|used_memory_peak:|mem_fragmentation_ratio:|maxmemory:)"
}

# Function: Get stats
get_stats() {
  redis_cli INFO stats | grep -E "(keyspace_hits:|keyspace_misses:|evicted_keys:|expired_keys:|rejected_connections:)"
}

# Function: Get keyspace info
get_keyspace() {
  redis_cli INFO keyspace
  redis_cli DBSIZE
}

# Function: Get client info
get_clients() {
  redis_cli INFO clients
  redis_cli CLIENT LIST | head -20
}

# Function: Get cgroup memory usage
get_cgroup_memory() {
  kubectl exec -n "$NAMESPACE" "$CURRENT_POD" -- cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null || echo "0"
  kubectl exec -n "$NAMESPACE" "$CURRENT_POD" -- cat /sys/fs/cgroup/memory/memory.usage_in_bytes 2>/dev/null || echo "0"
}

# Function: Parse bytes to human readable
bytes_to_human() {
  local bytes=$1
  if (( bytes > 1073741824 )); then
    echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1073741824}")GB"
  elif (( bytes > 1048576 )); then
    echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1048576}")MB"
  else
    echo "${bytes}B"
  fi
}

# Function: Extract value from INFO output
extract_value() {
  local key=$1
  local data=$2
  echo "$data" | grep "^$key:" | cut -d: -f2 | tr -d '\r'
}

# Function: Calculate percentage
calc_percent() {
  local used=$1
  local total=$2
  if [[ $total -eq 0 ]]; then
    echo "0"
  else
    awk "BEGIN {printf \"%.2f\", ($used/$total)*100}"
  fi
}

# Function: Send alert
send_alert() {
  local level=$1
  local message=$2
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  
  # Check cooldown
  local current_time=$(date +%s)
  if (( current_time - LAST_ALERT_TIME < ALERT_COOLDOWN )); then
    return
  fi
  LAST_ALERT_TIME=$current_time
  
  # Log alert
  echo "[$timestamp] [$level] [Pod: $CURRENT_POD] $message" | tee -a "$ALERT_LOG"
  
  # You can add webhook/email notifications here
  # Example: curl -X POST webhook_url -d "{\"level\":\"$level\",\"message\":\"$message\",\"pod\":\"$CURRENT_POD\"}"
}

# Function: Capture detailed snapshot
capture_snapshot() {
  local reason=$1
  local timestamp=$(date '+%Y%m%d_%H%M%S')
  local snapshot_file="$SNAPSHOT_DIR/snapshot_${timestamp}_${reason}_${CURRENT_POD}.log"
  
  echo "=== REDIS EMERGENCY SNAPSHOT ===" > "$snapshot_file"
  echo "Timestamp: $(date)" >> "$snapshot_file"
  echo "Pod: $CURRENT_POD" >> "$snapshot_file"
  echo "Namespace: $NAMESPACE" >> "$snapshot_file"
  echo "Reason: $reason" >> "$snapshot_file"
  echo "" >> "$snapshot_file"
  
  echo "=== MEMORY INFO ===" >> "$snapshot_file"
  redis_cli INFO memory >> "$snapshot_file" 2>&1
  echo "" >> "$snapshot_file"
  
  echo "=== STATS ===" >> "$snapshot_file"
  redis_cli INFO stats >> "$snapshot_file" 2>&1
  echo "" >> "$snapshot_file"
  
  echo "=== KEYSPACE ===" >> "$snapshot_file"
  redis_cli INFO keyspace >> "$snapshot_file" 2>&1
  redis_cli DBSIZE >> "$snapshot_file" 2>&1
  echo "" >> "$snapshot_file"
  
  echo "=== CLIENTS (top 50) ===" >> "$snapshot_file"
  redis_cli CLIENT LIST | head -50 >> "$snapshot_file" 2>&1
  echo "" >> "$snapshot_file"
  
  echo "=== SLOWLOG (last 20) ===" >> "$snapshot_file"
  redis_cli SLOWLOG GET 20 >> "$snapshot_file" 2>&1
  echo "" >> "$snapshot_file"
  
  echo "=== CONFIG ===" >> "$snapshot_file"
  redis_cli CONFIG GET maxmemory* >> "$snapshot_file" 2>&1
  echo "" >> "$snapshot_file"
  
  echo "=== TOP KEYS BY MEMORY (sample) ===" >> "$snapshot_file"
  redis_cli --bigkeys >> "$snapshot_file" 2>&1
  echo "" >> "$snapshot_file"
  
  echo "=== POD STATUS ===" >> "$snapshot_file"
  kubectl describe pod "$CURRENT_POD" -n "$NAMESPACE" >> "$snapshot_file" 2>&1
  
  echo "Snapshot saved: $snapshot_file"
  send_alert "INFO" "Diagnostic snapshot captured: $snapshot_file"
}

# Function: Update current pod
update_pod() {
  local new_pod=$(discover_redis_pod)
  
  if [[ -z "$new_pod" ]]; then
    if [[ -n "$CURRENT_POD" ]]; then
      echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] Redis pod disappeared. Waiting for new pod...${NC}"
      CURRENT_POD=""
      POD_START_TIME=""
    fi
    return 1
  fi
  
  if [[ "$new_pod" != "$CURRENT_POD" ]]; then
    local new_start_time=$(get_pod_start_time "$new_pod")
    
    if [[ -n "$CURRENT_POD" ]]; then
      echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] Pod changed: $CURRENT_POD -> $new_pod${NC}"
      send_alert "WARNING" "Redis pod restarted: $CURRENT_POD -> $new_pod"
      
      # Log pod change to metrics
      echo "$(date '+%Y-%m-%d %H:%M:%S'),POD_RESTART,$CURRENT_POD,$new_pod,$new_start_time" >> "$METRICS_LOG"
    else
      echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] Discovered Redis pod: $new_pod${NC}"
      send_alert "INFO" "Monitoring started for Redis pod: $new_pod"
    fi
    
    CURRENT_POD="$new_pod"
    POD_START_TIME="$new_start_time"
    return 0
  fi
  
  return 0
}

# Function: Monitor loop
monitor() {
  echo "=========================================="
  echo "Redis OOM Prevention Monitor"
  echo "=========================================="
  echo "Namespace: $NAMESPACE"
  echo "Label Selector: $LABEL_SELECTOR"
  echo "Pod Pattern: $POD_NAME_PATTERN"
  echo "Check Interval: $INTERVAL seconds"
  echo "Log Directory: $LOG_DIR"
  echo "=========================================="
  echo ""
  echo "Discovering Redis pod..."
  echo ""
  
  # Initial pod discovery
  while ! update_pod; do
    echo "Waiting for Redis pod... (retrying in 10s)"
    sleep 10
  done
  
  echo "Monitoring started. Press Ctrl+C to stop."
  echo ""
  
  while true; do
    # Check if pod is still valid, update if changed
    if ! is_pod_valid "$CURRENT_POD"; then
      echo -e "${YELLOW}Pod $CURRENT_POD is no longer valid. Discovering new pod...${NC}"
      while ! update_pod; do
        echo "Waiting for Redis pod... (retrying in 10s)"
        sleep 10
      done
      # Give new pod time to fully start
      sleep 5
      continue
    fi
    
    # Check for pod changes (restart with same name)
    local current_start_time=$(get_pod_start_time "$CURRENT_POD")
    if [[ -n "$current_start_time" && "$current_start_time" != "$POD_START_TIME" ]]; then
      echo -e "${YELLOW}Pod $CURRENT_POD restarted (start time changed)${NC}"
      send_alert "WARNING" "Redis pod restarted: $CURRENT_POD (new start time: $current_start_time)"
      POD_START_TIME="$current_start_time"
      echo "$(date '+%Y-%m-%d %H:%M:%S'),POD_RESTART,$CURRENT_POD,$CURRENT_POD,$current_start_time" >> "$METRICS_LOG"
      sleep 5
      continue
    fi
    
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Get memory stats
    mem_info=$(get_memory_stats)
    stats_info=$(get_stats)
    
    if [[ -z "$mem_info" ]]; then
      echo -e "${RED}[$timestamp] Failed to get Redis stats. Pod may be restarting...${NC}"
      sleep 5
      continue
    fi
    
    # Parse key metrics
    used_memory=$(extract_value "used_memory" "$mem_info")
    used_memory_rss=$(extract_value "used_memory_rss" "$mem_info")
    maxmemory=$(extract_value "maxmemory" "$mem_info")
    mem_frag=$(extract_value "mem_fragmentation_ratio" "$mem_info")
    
    evicted_keys=$(extract_value "evicted_keys" "$stats_info")
    expired_keys=$(extract_value "expired_keys" "$stats_info")
    keyspace_hits=$(extract_value "keyspace_hits" "$stats_info")
    keyspace_misses=$(extract_value "keyspace_misses" "$stats_info")
    
    # Get cgroup limits
    cgroup_limit=$(get_cgroup_memory | head -1)
    cgroup_usage=$(get_cgroup_memory | tail -1)
    
    # Calculate percentages
    if [[ $maxmemory -gt 0 ]]; then
      mem_percent=$(calc_percent "$used_memory" "$maxmemory")
    else
      mem_percent="N/A"
      maxmemory="unlimited"
    fi
    
    if [[ $cgroup_limit -gt 0 ]]; then
      cgroup_percent=$(calc_percent "$cgroup_usage" "$cgroup_limit")
    else
      cgroup_percent="N/A"
    fi
    
    # Calculate hit rate
    total_requests=$((keyspace_hits + keyspace_misses))
    if [[ $total_requests -gt 0 ]]; then
      hit_rate=$(calc_percent "$keyspace_hits" "$total_requests")
    else
      hit_rate="N/A"
    fi
    
    # Log metrics
    echo "$timestamp,$CURRENT_POD,$(bytes_to_human $used_memory),$(bytes_to_human $used_memory_rss),$(bytes_to_human $maxmemory),$mem_percent%,$mem_frag,$(bytes_to_human $cgroup_usage),$(bytes_to_human $cgroup_limit),$cgroup_percent%,$evicted_keys,$hit_rate%" >> "$METRICS_LOG"
    
    # Determine status and alert
    status="${GREEN}OK${NC}"
    alert_needed=false
    alert_level="INFO"
    
    # Check maxmemory threshold
    if [[ "$mem_percent" != "N/A" ]]; then
      mem_percent_int=$(echo "$mem_percent" | cut -d. -f1)
      
      if (( mem_percent_int >= EMERGENCY_THRESHOLD )); then
        status="${RED}EMERGENCY${NC}"
        alert_needed=true
        alert_level="EMERGENCY"
        capture_snapshot "memory_emergency_${mem_percent}pct"
      elif (( mem_percent_int >= CRITICAL_THRESHOLD )); then
        status="${RED}CRITICAL${NC}"
        alert_needed=true
        alert_level="CRITICAL"
        capture_snapshot "memory_critical_${mem_percent}pct"
      elif (( mem_percent_int >= WARN_THRESHOLD )); then
        status="${YELLOW}WARNING${NC}"
        alert_needed=true
        alert_level="WARNING"
      fi
    fi
    
    # Check cgroup threshold
    if [[ "$cgroup_percent" != "N/A" ]]; then
      cgroup_percent_int=$(echo "$cgroup_percent" | cut -d. -f1)
      
      if (( cgroup_percent_int >= CGROUP_EMERGENCY )); then
        status="${RED}CGROUP_EMERGENCY${NC}"
        alert_needed=true
        alert_level="EMERGENCY"
        capture_snapshot "cgroup_emergency_${cgroup_percent}pct"
      elif (( cgroup_percent_int >= CGROUP_CRITICAL )); then
        if [[ "$alert_level" != "EMERGENCY" ]]; then
          status="${RED}CGROUP_CRITICAL${NC}"
          alert_needed=true
          alert_level="CRITICAL"
          capture_snapshot "cgroup_critical_${cgroup_percent}pct"
        fi
      elif (( cgroup_percent_int >= CGROUP_WARN )); then
        if [[ "$alert_level" == "INFO" ]]; then
          status="${YELLOW}CGROUP_WARNING${NC}"
          alert_needed=true
          alert_level="WARNING"
        fi
      fi
    fi
    
    # Send alert if needed
    if $alert_needed; then
      msg="Redis memory: $(bytes_to_human $used_memory) / $(bytes_to_human $maxmemory) (${mem_percent}%) | Cgroup: $(bytes_to_human $cgroup_usage) / $(bytes_to_human $cgroup_limit) (${cgroup_percent}%) | Evicted: $evicted_keys | Hit rate: ${hit_rate}%"
      send_alert "$alert_level" "$msg"
    fi
    
    # Console output
    printf "[%s] ${BLUE}Pod: %-50s${NC} Status: %b | Memory: %s/%s (%s%%) | RSS: %s | Cgroup: %s/%s (%s%%) | Frag: %s | Evicted: %s | Hit: %s%%\n" \
      "$timestamp" \
      "$CURRENT_POD" \
      "$status" \
      "$(bytes_to_human $used_memory)" \
      "$(bytes_to_human $maxmemory)" \
      "$mem_percent" \
      "$(bytes_to_human $used_memory_rss)" \
      "$(bytes_to_human $cgroup_usage)" \
      "$(bytes_to_human $cgroup_limit)" \
      "$cgroup_percent" \
      "$mem_frag" \
      "$evicted_keys" \
      "$hit_rate"
    
    sleep "$INTERVAL"
  done
}

# Trap for cleanup
trap 'echo ""; echo "Monitoring stopped."; exit 0' INT TERM

# Start monitoring
monitor
```



## Quick Start

### 1. Basic Usage (Default Settings)

```bash
# Make script executable
chmod +x redis-monitor.sh

# Start monitoring with defaults
# - Namespace: portalappv6-chart
# - Will auto-discover any pod with "redis" in the name
./redis-monitor.sh

# Or run in background
nohup ./redis-monitor.sh > /dev/null 2>&1 &
```

### 2. Custom Configuration

```bash
# Custom label selector
./redis-monitor.sh -l app.kubernetes.io/name=redis

# Custom pod name pattern
./redis-monitor.sh -p "portal.*redis"

# Custom check interval (30 seconds)
./redis-monitor.sh -i 30

# Custom log directory
./redis-monitor.sh -d /opt/redis-logs

# Combine options
./redis-monitor.sh -n portalappv6-chart -l app=redis -i 30 -d /opt/redis-logs
```

------

## Understanding the Output

### Console Output Example

```
[2025-09-30 17:30:15] Pod: portal-v6-chart-redis-64d7c79677-wp28b    Status: OK | Memory: 1.60GB/5.00GB (32.00%) | RSS: 1.91GB | Cgroup: 1.96GB/9.00GB (21.78%) | Frag: 1.20 | Evicted: 0 | Hit: 92.80%
```

**Status Levels:**

- 🟢 **OK** - Memory < 70%
- 🟡 **WARNING** - Memory 70-84%
- 🔴 **CRITICAL** - Memory 85-94% (snapshot captured)
- 🔴 **EMERGENCY** - Memory ≥ 95% (snapshot captured)

### Log Files

All logs are stored in `/var/log/redis-monitor/` (or custom directory):

```
/var/log/redis-monitor/
├── metrics.log              # CSV format metrics
├── alerts.log               # Alert history
└── snapshots/               # Diagnostic snapshots
    └── snapshot_20250930_173015_memory_critical_87pct_portal-v6-chart-redis-xxx.log
```

### Metrics Log Format (CSV)

```csv
timestamp,pod_name,used_memory,used_rss,maxmemory,mem_percent,fragmentation,cgroup_usage,cgroup_limit,cgroup_percent,evicted_keys,hit_rate
2025-09-30 17:30:15,portal-v6-chart-redis-64d7c79677-wp28b,1.60GB,1.91GB,5.00GB,32.00%,1.20,1.96GB,9.00GB,21.78%,0,92.80%
```

------

## Pod Restart Handling

The monitor automatically handles pod restarts:

```
[2025-09-30 14:47:51] Discovered Redis pod: portal-v6-chart-redis-64d7c79677-wp28b
... monitoring ...
[2025-09-30 15:30:22] Pod changed: portal-v6-chart-redis-64d7c79677-wp28b -> portal-v6-chart-redis-84d569ccbd-5cgg9
... continues monitoring new pod ...
```

Pod restart events are logged in `metrics.log` as:

```csv
2025-09-30 15:30:22,POD_RESTART,old-pod-name,new-pod-name,new-start-time
```

------

## Analyzing Logs

```bash
#!/bin/bash
#
# Redis Metrics Log Analyzer
# Analyzes metrics.log to identify patterns and trends
#
# Usage: ./analyze-logs.sh /var/log/redis-monitor/metrics.log
#

LOG_FILE="$1"

if [[ ! -f "$LOG_FILE" ]]; then
  echo "Error: Log file not found: $LOG_FILE"
  echo "Usage: $0 <metrics.log>"
  exit 1
fi

echo "=== REDIS METRICS ANALYSIS ==="
echo "Log file: $LOG_FILE"
echo ""

# Count entries
total_entries=$(wc -l < "$LOG_FILE")
echo "Total entries: $total_entries"
echo ""

# Time range
first_time=$(head -1 "$LOG_FILE" | cut -d, -f1)
last_time=$(tail -1 "$LOG_FILE" | cut -d, -f1)
echo "Time range: $first_time to $last_time"
echo ""

# Pod restarts analysis
echo "=== POD RESTART EVENTS ==="
if grep -q "POD_RESTART" "$LOG_FILE" 2>/dev/null; then
  pod_restarts=$(grep "POD_RESTART" "$LOG_FILE" | wc -l)
  echo "Total pod restarts detected: $pod_restarts"
  echo ""
  echo "Restart events:"
  grep "POD_RESTART" "$LOG_FILE" | while IFS=, read -r time event old_pod new_pod start_time; do
    echo "  $time: $old_pod -> $new_pod"
  done
else
  echo "No pod restarts detected during monitoring period"
fi
echo ""

# Memory analysis
echo "=== MEMORY USAGE ANALYSIS ==="

# Extract memory percentages (field 6 now, since field 2 is pod name)
awk -F, '{print $6}' "$LOG_FILE" | sed 's/%//g' | sort -n > /tmp/mem_pct.tmp

min_mem=$(head -1 /tmp/mem_pct.tmp)
max_mem=$(tail -1 /tmp/mem_pct.tmp)
avg_mem=$(awk '{sum+=$1} END {print sum/NR}' /tmp/mem_pct.tmp)

echo "Memory usage (% of maxmemory):"
echo "  Min: ${min_mem}%"
echo "  Max: ${max_mem}%"
echo "  Avg: $(printf "%.2f" $avg_mem)%"
echo ""

# Times above thresholds
above_70=$(awk -F, '{gsub(/%/,"",$6); if($6>=70) count++} END {print count+0}' "$LOG_FILE")
above_85=$(awk -F, '{gsub(/%/,"",$6); if($6>=85) count++} END {print count+0}' "$LOG_FILE")
above_95=$(awk -F, '{gsub(/%/,"",$6); if($6>=95) count++} END {print count+0}' "$LOG_FILE")

echo "Threshold breaches:"
echo "  Above 70% (warning): $above_70 times ($(awk "BEGIN {printf \"%.1f\", ($above_70/$total_entries)*100}")%)"
echo "  Above 85% (critical): $above_85 times ($(awk "BEGIN {printf \"%.1f\", ($above_85/$total_entries)*100}")%)"
echo "  Above 95% (emergency): $above_95 times ($(awk "BEGIN {printf \"%.1f\", ($above_95/$total_entries)*100}")%)"
echo ""

# Cgroup analysis
echo "=== CGROUP MEMORY ANALYSIS ==="
awk -F, '{print $10}' "$LOG_FILE" | sed 's/%//g' | sort -n > /tmp/cgroup_pct.tmp

min_cgroup=$(head -1 /tmp/cgroup_pct.tmp)
max_cgroup=$(tail -1 /tmp/cgroup_pct.tmp)
avg_cgroup=$(awk '{sum+=$1} END {print sum/NR}' /tmp/cgroup_pct.tmp)

echo "Cgroup usage (% of container limit):"
echo "  Min: ${min_cgroup}%"
echo "  Max: ${max_cgroup}%"
echo "  Avg: $(printf "%.2f" $avg_cgroup)%"
echo ""

# Eviction analysis
echo "=== EVICTION ANALYSIS ==="
start_evicted=$(head -1 "$LOG_FILE" | cut -d, -f11)
end_evicted=$(tail -1 "$LOG_FILE" | cut -d, -f11)
total_evicted=$((end_evicted - start_evicted))

if [[ $total_evicted -gt 0 ]]; then
  echo "Total keys evicted: $total_evicted"
  
  # Calculate eviction rate
  first_ts=$(date -d "$first_time" +%s 2>/dev/null || echo 0)
  last_ts=$(date -d "$last_time" +%s 2>/dev/null || echo 0)
  duration=$((last_ts - first_ts))
  
  if [[ $duration -gt 0 ]]; then
    evict_rate=$(awk "BEGIN {printf \"%.2f\", $total_evicted/$duration}")
    echo "Eviction rate: $evict_rate keys/second"
  fi
else
  echo "No evictions occurred during monitoring period"
fi
echo ""

# Hit rate analysis
echo "=== HIT RATE ANALYSIS ==="
awk -F, '{print $12}' "$LOG_FILE" | sed 's/%//g' | sort -n > /tmp/hitrate.tmp

min_hit=$(head -1 /tmp/hitrate.tmp)
max_hit=$(tail -1 /tmp/hitrate.tmp)
avg_hit=$(awk '{sum+=$1} END {print sum/NR}' /tmp/hitrate.tmp)

echo "Cache hit rate:"
echo "  Min: ${min_hit}%"
echo "  Max: ${max_hit}%"
echo "  Avg: $(printf "%.2f" $avg_hit)%"
echo ""

# Fragmentation analysis
echo "=== FRAGMENTATION ANALYSIS ==="
awk -F, '{print $7}' "$LOG_FILE" | sort -n > /tmp/frag.tmp

min_frag=$(head -1 /tmp/frag.tmp)
max_frag=$(tail -1 /tmp/frag.tmp)
avg_frag=$(awk '{sum+=$1} END {print sum/NR}' /tmp/frag.tmp)

echo "Memory fragmentation ratio:"
echo "  Min: $min_frag"
echo "  Max: $max_frag"
echo "  Avg: $(printf "%.2f" $avg_frag)"

if (( $(echo "$avg_frag > 1.5" | bc -l) )); then
  echo "  WARNING: High fragmentation detected!"
fi
echo ""

# Growth rate analysis
echo "=== GROWTH RATE ANALYSIS ==="
# Get first and last memory values (field 3, pod name is in field 2)
first_mem=$(head -1 "$LOG_FILE" | cut -d, -f3)
last_mem=$(tail -1 "$LOG_FILE" | cut -d, -f3)

echo "Memory change: $first_mem -> $last_mem"

# Identify rapid growth periods (>10% increase in 5 minutes)
echo ""
echo "Rapid growth periods (>10% increase):"
awk -F, '
  NR==1 {prev=$6; gsub(/%/,"",prev); prevtime=$1; next}
  {
    curr=$6; gsub(/%/,"",curr);
    diff=curr-prev;
    if(diff > 10) {
      print "  " prevtime " -> " $1 ": +" diff "%"
    }
    prev=curr;
    prevtime=$1;
  }
' "$LOG_FILE"

# Top 5 highest memory usage moments
echo ""
echo "=== TOP 5 HIGHEST MEMORY USAGE MOMENTS ==="
sort -t, -k6 -rn "$LOG_FILE" | head -5 | while IFS=, read -r time pod mem1 mem2 maxmem pct rest; do
  echo "  $time ($pod): $pct (Used: $mem1 / Max: $maxmem)"
done

# Recommendations
echo ""
echo "=== RECOMMENDATIONS ==="

if (( $(echo "$avg_mem > 80" | bc -l) )); then
  echo "⚠️  Average memory usage is high (${avg_mem}%)"
  echo "   Consider increasing maxmemory or reviewing eviction policy"
fi

if [[ $total_evicted -gt 1000 ]]; then
  echo "⚠️  High eviction count detected ($total_evicted keys)"
  echo "   Consider increasing maxmemory to reduce evictions"
fi

if (( $(echo "$avg_hit < 90" | bc -l) )); then
  echo "⚠️  Cache hit rate is below 90% (${avg_hit}%)"
  echo "   Review application caching strategy or TTL settings"
fi

if (( $(echo "$avg_frag > 1.5" | bc -l) )); then
  echo "⚠️  High memory fragmentation (${avg_frag})"
  echo "   Consider enabling activedefrag or restarting Redis during low-traffic period"
fi

if (( $(echo "$max_cgroup > 80" | bc -l) )); then
  echo "⚠️  Cgroup memory usage reached ${max_cgroup}% of container limit"
  echo "   Risk of OOM kill. Consider increasing container memory limit"
fi

# Cleanup
rm -f /tmp/mem_pct.tmp /tmp/cgroup_pct.tmp /tmp/hitrate.tmp /tmp/frag.tmp

echo ""
echo "=== END OF ANALYSIS ==="
```



Use the analyzer script to get insights:

```bash
chmod +x analyze-logs.sh
./analyze-logs.sh /var/log/redis-monitor/metrics.log
```

**Output includes:**

- Memory usage statistics (min/max/avg)
- Threshold breach counts
- Eviction analysis and rates
- Hit rate analysis
- Fragmentation trends
- Pod restart events
- Growth rate patterns
- Recommendations

------

## Running as a Service

### Option 1: Screen Session

```bash
# Start in screen
screen -S redis-monitor
./redis-monitor.sh
# Detach: Ctrl+A, then D

# Reattach later
screen -r redis-monitor

# List sessions
screen -ls
```

### Option 2: Systemd Service

```bash
# Create service file
sudo tee /etc/systemd/system/redis-monitor.service > /dev/null <<'EOF'
[Unit]
Description=Redis OOM Monitor
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/redis
ExecStart=/root/redis/redis-monitor.sh -d /var/log/redis-monitor
Restart=always
RestartSec=10
StandardOutput=append:/var/log/redis-monitor/monitor.out
StandardError=append:/var/log/redis-monitor/monitor.err

[Install]
WantedBy=multi-user.target
EOF

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable redis-monitor
sudo systemctl start redis-monitor

# Check status
sudo systemctl status redis-monitor

# View logs
sudo journalctl -u redis-monitor -f
```

### Option 3: Kubernetes CronJob

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-monitor-script
  namespace: portalappv6-chart
data:
  monitor.sh: |
    #!/bin/bash
    # Quick health check for CronJob execution with auto-discovery
    
    NAMESPACE="${REDIS_NAMESPACE:-portalappv6-chart}"
    LABEL_SELECTOR="${REDIS_LABEL_SELECTOR:-app=redis}"
    POD_NAME_PATTERN="${REDIS_POD_PATTERN:-redis}"
    SLACK_WEBHOOK="${SLACK_WEBHOOK_URL}"
    
    # Thresholds
    WARN_THRESHOLD=70
    CRITICAL_THRESHOLD=85
    
    # Discover Redis pod
    discover_pod() {
      local pod=""
      
      # Try label selector first
      if [[ -n "$LABEL_SELECTOR" ]]; then
        pod=$(kubectl get pods -n "$NAMESPACE" -l "$LABEL_SELECTOR" \
          --field-selector=status.phase=Running \
          -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
      fi
      
      # Fall back to name pattern
      if [[ -z "$pod" ]]; then
        pod=$(kubectl get pods -n "$NAMESPACE" \
          --field-selector=status.phase=Running \
          -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | \
          tr ' ' '\n' | grep -i "$POD_NAME_PATTERN" | head -1 || echo "")
      fi
      
      echo "$pod"
    }
    
    POD=$(discover_pod)
    
    if [[ -z "$POD" ]]; then
      echo "ERROR: No Redis pod found in namespace $NAMESPACE"
      echo "Label selector: $LABEL_SELECTOR"
      echo "Pod pattern: $POD_NAME_PATTERN"
      exit 1
    fi
    
    echo "Found Redis pod: $POD"
    
    redis_cli() {
      kubectl exec -n "$NAMESPACE" "$POD" -- redis-cli "$@" 2>/dev/null
    }
    
    # Get metrics
    mem_info=$(redis_cli INFO memory)
    if [[ -z "$mem_info" ]]; then
      echo "ERROR: Failed to get memory info from Redis pod $POD"
      exit 1
    fi
    
    used_memory=$(echo "$mem_info" | grep "^used_memory:" | cut -d: -f2 | tr -d '\r')
    used_memory_rss=$(echo "$mem_info" | grep "^used_memory_rss:" | cut -d: -f2 | tr -d '\r')
    maxmemory=$(echo "$mem_info" | grep "^maxmemory:" | cut -d: -f2 | tr -d '\r')
    mem_frag=$(echo "$mem_info" | grep "^mem_fragmentation_ratio:" | cut -d: -f2 | tr -d '\r')
    
    stats_info=$(redis_cli INFO stats)
    evicted_keys=$(echo "$stats_info" | grep "^evicted_keys:" | cut -d: -f2 | tr -d '\r')
    keyspace_hits=$(echo "$stats_info" | grep "^keyspace_hits:" | cut -d: -f2 | tr -d '\r')
    keyspace_misses=$(echo "$stats_info" | grep "^keyspace_misses:" | cut -d: -f2 | tr -d '\r')
    
    # Get cgroup info
    cgroup_limit=$(kubectl exec -n "$NAMESPACE" "$POD" -- cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null || echo "0")
    cgroup_usage=$(kubectl exec -n "$NAMESPACE" "$POD" -- cat /sys/fs/cgroup/memory/memory.usage_in_bytes 2>/dev/null || echo "0")
    
    if [[ $maxmemory -eq 0 ]]; then
      echo "Warning: maxmemory not set for pod $POD"
      mem_percent=0
    else
      mem_percent=$(awk "BEGIN {printf \"%.0f\", ($used_memory/$maxmemory)*100}")
    fi
    
    if [[ $cgroup_limit -gt 0 ]]; then
      cgroup_percent=$(awk "BEGIN {printf \"%.0f\", ($cgroup_usage/$cgroup_limit)*100}")
    else
      cgroup_percent=0
    fi
    
    # Calculate hit rate
    total_requests=$((keyspace_hits + keyspace_misses))
    if [[ $total_requests -gt 0 ]]; then
      hit_rate=$(awk "BEGIN {printf \"%.1f\", ($keyspace_hits/$total_requests)*100}")
    else
      hit_rate="N/A"
    fi
    
    # Convert to human readable
    bytes_to_human() {
      local bytes=$1
      if (( bytes > 1073741824 )); then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1073741824}")GB"
      elif (( bytes > 1048576 )); then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1048576}")MB"
      else
        echo "${bytes}B"
      fi
    }
    
    used_mem_human=$(bytes_to_human $used_memory)
    maxmem_human=$(bytes_to_human $maxmemory)
    rss_human=$(bytes_to_human $used_memory_rss)
    cgroup_usage_human=$(bytes_to_human $cgroup_usage)
    cgroup_limit_human=$(bytes_to_human $cgroup_limit)
    
    # Check threshold
    if (( mem_percent >= CRITICAL_THRESHOLD )); then
      level="CRITICAL"
      color="danger"
      emoji="🔴"
    elif (( mem_percent >= WARN_THRESHOLD )); then
      level="WARNING"
      color="warning"
      emoji="⚠️"
    else
      level="OK"
      color="good"
      emoji="✅"
    fi
    
    # Check cgroup separately
    if (( cgroup_percent >= 80 )); then
      if [[ "$level" == "OK" ]]; then
        level="CGROUP_WARNING"
        color="warning"
        emoji="⚠️"
      fi
    fi
    
    # Log
    echo "$(date) - Pod: $POD | Redis Memory: ${mem_percent}% | Cgroup: ${cgroup_percent}% | Status: $level"
    
    # Send Slack notification if threshold exceeded
    if [[ "$level" != "OK" && -n "$SLACK_WEBHOOK" ]]; then
      curl -X POST "$SLACK_WEBHOOK" -H 'Content-Type: application/json' -d @- <<EOF
    {
      "attachments": [{
        "color": "$color",
        "title": "$emoji Redis Memory Alert - $level",
        "fields": [
          {
            "title": "Pod",
            "value": "$POD",
            "short": true
          },
          {
            "title": "Namespace",
            "value": "$NAMESPACE",
            "short": true
          },
          {
            "title": "Redis Memory",
            "value": "${mem_percent}% (${used_mem_human} / ${maxmem_human})",
            "short": true
          },
          {
            "title": "Container Memory",
            "value": "${cgroup_percent}% (${cgroup_usage_human} / ${cgroup_limit_human})",
            "short": true
          },
          {
            "title": "RSS",
            "value": "$rss_human",
            "short": true
          },
          {
            "title": "Fragmentation",
            "value": "$mem_frag",
            "short": true
          },
          {
            "title": "Evicted Keys",
            "value": "$evicted_keys",
            "short": true
          },
          {
            "title": "Hit Rate",
            "value": "${hit_rate}%",
            "short": true
          }
        ],
        "footer": "Redis Monitor",
        "ts": $(date +%s)
      }]
    }
    EOF
    fi
    
    # Capture snapshot if critical
    if [[ "$level" == "CRITICAL" || "$level" == "CGROUP_WARNING" ]]; then
      echo "=== CRITICAL SNAPSHOT @ $(date) ===" > /tmp/redis-snapshot-${POD}.log
      echo "Pod: $POD" >> /tmp/redis-snapshot-${POD}.log
      echo "Namespace: $NAMESPACE" >> /tmp/redis-snapshot-${POD}.log
      echo "" >> /tmp/redis-snapshot-${POD}.log
      redis_cli INFO memory >> /tmp/redis-snapshot-${POD}.log
      redis_cli INFO stats >> /tmp/redis-snapshot-${POD}.log
      redis_cli CLIENT LIST | head -20 >> /tmp/redis-snapshot-${POD}.log
      redis_cli SLOWLOG GET 10 >> /tmp/redis-snapshot-${POD}.log
      kubectl describe pod "$POD" -n "$NAMESPACE" >> /tmp/redis-snapshot-${POD}.log
      
      echo "Snapshot saved to /tmp/redis-snapshot-${POD}.log"
    fi
    
    # Exit with appropriate code
    if [[ "$level" == "CRITICAL" ]]; then
      exit 2
    elif [[ "$level" =~ "WARNING" ]]; then
      exit 1
    else
      exit 0
    fi
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: redis-monitor
  namespace: portalappv6-chart
spec:
  schedule: "*/5 * * * *"  # Every 5 minutes
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: redis-monitor-sa
          containers:
          - name: monitor
            image: bitnami/kubectl:latest
            command:
            - /bin/bash
            - /scripts/monitor.sh
            env:
            - name: REDIS_NAMESPACE
              value: "portalappv6-chart"
            - name: REDIS_LABEL_SELECTOR
              value: "app=redis"
            - name: REDIS_POD_PATTERN
              value: "redis"
            - name: SLACK_WEBHOOK_URL
              valueFrom:
                secretKeyRef:
                  name: redis-monitor-secrets
                  key: slack-webhook
                  optional: true
            volumeMounts:
            - name: script
              mountPath: /scripts
          volumes:
          - name: script
            configMap:
              name: redis-monitor-script
              defaultMode: 0755
          restartPolicy: OnFailure
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: redis-monitor-sa
  namespace: portalappv6-chart
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: redis-monitor-role
  namespace: portalappv6-chart
rules:
- apiGroups: [""]
  resources: ["pods", "pods/exec"]
  verbs: ["get", "list", "create"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: redis-monitor-binding
  namespace: portalappv6-chart
subjects:
- kind: ServiceAccount
  name: redis-monitor-sa
roleRef:
  kind: Role
  name: redis-monitor-role
  apiGroup: rbac.authorization.k8s.io
```



For periodic checks (every 5 minutes):

```bash
# Deploy the CronJob
kubectl apply -f redis-monitor-cronjob.yaml

# Check CronJob status
kubectl get cronjob -n portalappv6-chart

# View job logs
kubectl logs -n portalappv6-chart -l job-name=redis-monitor-xxxxx
```

------

## Log Rotation

Set up automatic log rotation:

```bash
sudo tee /etc/logrotate.d/redis-monitor > /dev/null <<'EOF'
/var/log/redis-monitor/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}

/var/log/redis-monitor/snapshots/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
}
EOF

# Test rotation
sudo logrotate -d /etc/logrotate.d/redis-monitor
```

------

## Webhook Integration

### Slack Notifications

Edit `redis-monitor.sh` and update the `send_alert()` function:

```bash
send_alert() {
  local level=$1
  local message=$2
  
  # ... existing code ...
  
  # Add Slack webhook
  if [[ -n "$SLACK_WEBHOOK" ]]; then
    local color="warning"
    [[ "$level" == "CRITICAL" || "$level" == "EMERGENCY" ]] && color="danger"
    [[ "$level" == "INFO" ]] && color="good"
    
    curl -X POST "$SLACK_WEBHOOK" \
      -H 'Content-Type: application/json' \
      -d "{
        \"attachments\": [{
          \"color\": \"$color\",
          \"title\": \"Redis Alert - $level\",
          \"text\": \"$message\",
          \"footer\": \"Pod: $CURRENT_POD\",
          \"ts\": $(date +%s)
        }]
      }"
  fi
}
```

Then set the webhook URL:

```bash
export SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
./redis-monitor.sh
```

------

## Troubleshooting

### Pod Not Found

```bash
# Check if pod exists
kubectl get pods -n portalappv6-chart | grep redis

# Check pod labels
kubectl get pods -n portalappv6-chart --show-labels | grep redis

# Try different label selector
./redis-monitor.sh -l app.kubernetes.io/name=redis

# Try different name pattern
./redis-monitor.sh -p "chart-redis"
```

### Permission Errors

```bash
# Ensure you have kubectl access
kubectl auth can-i list pods -n portalappv6-chart
kubectl auth can-i exec pods -n portalappv6-chart

# Check log directory permissions
sudo chown -R $USER:$USER /var/log/redis-monitor
```

### High CPU Usage

If monitoring is using too much CPU:

```bash
# Increase check interval
./redis-monitor.sh -i 120  # Check every 2 minutes
```

------

## What to Do When Alerts Fire

### WARNING (70%)

1. Check if this is expected growth or anomaly
2. Review application behavior
3. Check for memory leaks in application
4. Plan for potential memory increase

### CRITICAL (85%)

1. **Review the snapshot** in `/var/log/redis-monitor/snapshots/`
2. Check SLOWLOG for slow queries
3. Check CLIENT LIST for clients with large buffers
4. Check --bigkeys output for unusually large keys
5. Consider:
   - Increasing maxmemory (if cgroup limit allows)
   - Optimizing application caching patterns
   - Adding more Redis instances

### EMERGENCY (95%)

**Immediate actions:**

1. Check if evictions are working: `redis-cli INFO stats | grep evicted_keys`
2. If evicted_keys is growing, Redis is evicting normally
3. If evicted_keys is 0:
   - Check maxmemory-policy: `redis-cli CONFIG GET maxmemory-policy`
   - Ensure it's not `noeviction`
4. Consider emergency measures:
   - Flush non-critical data: `redis-cli FLUSHDB`
   - Restart pod if necessary (will lose all data without AOF/RDB)

------

## Best Practices

1. **Always run the monitor** - Even when things are stable
2. **Review snapshots** - Learn from critical events
3. **Tune thresholds** - Adjust based on your workload patterns
4. **Set up alerts** - Integrate with your alerting system
5. **Analyze trends** - Run analyzer weekly to spot patterns
6. **Document incidents** - Keep notes on what triggered alerts

------

## Customization

### Adjust Thresholds

Edit the script to change alert thresholds:

```bash
# In redis-monitor.sh
WARN_THRESHOLD=75         # Change from 70
CRITICAL_THRESHOLD=90     # Change from 85
EMERGENCY_THRESHOLD=98    # Change from 95
```

### Change Alert Cooldown

Prevent alert spam by adjusting cooldown:

```bash
ALERT_COOLDOWN=600  # 10 minutes instead of 5
```

### Snapshot Frequency

Snapshots are triggered at CRITICAL and EMERGENCY thresholds. To add more:

```bash
# Add snapshot at WARNING level
if (( mem_percent_int >= WARN_THRESHOLD )); then
  capture_snapshot "memory_warning_${mem_percent}pct"
fi
```

------

## Support

For issues or questions:

1. Check logs: `/var/log/redis-monitor/alerts.log`
2. Review snapshots for diagnostic info
3. Run analyzer for trend analysis
4. Check systemd logs: `journalctl -u redis-monitor`

------

## Summary

**To get started right now:**

```bash
# 1. Start monitoring
./redis-monitor.sh

# 2. In another terminal, watch logs
tail -f /var/log/redis-monitor/metrics.log

# 3. Analyze when needed
./analyze-logs.sh /var/log/redis-monitor/metrics.log
```

That's it! The monitor will automatically track your Redis pod and alert you before OOM occurs. 🎯