#!/bin/bash
# Check spending and alert if thresholds hit

TRACKER="/home/ubuntu/clawd/dashboard/spending-tracker.json"
TODAY=$(date +%Y-%m-%d)

# Reset if new day
SAVED_DATE=$(jq -r '.today.date' "$TRACKER")
if [ "$SAVED_DATE" != "$TODAY" ]; then
  # Archive yesterday and reset
  jq --arg today "$TODAY" '
    .history += [.today] |
    .today = {date: $today, spent: 0, breakdown: {}}
  ' "$TRACKER" > "$TRACKER.tmp" && mv "$TRACKER.tmp" "$TRACKER"
fi

# Get current values
SPENT=$(jq -r '.today.spent' "$TRACKER")
BUDGET=$(jq -r '.dailyBudget' "$TRACKER")
WARNING=$(jq -r '.warningThreshold' "$TRACKER")
CRITICAL=$(jq -r '.criticalThreshold' "$TRACKER")

# Calculate percentage
PERCENT=$(echo "scale=2; $SPENT / $BUDGET * 100" | bc)
WARNING_AMT=$(echo "scale=2; $BUDGET * $WARNING" | bc)
CRITICAL_AMT=$(echo "scale=2; $BUDGET * $CRITICAL" | bc)

echo "Daily spend: \$$SPENT / \$$BUDGET ($PERCENT%)"

# Check thresholds
if (( $(echo "$SPENT >= $CRITICAL_AMT" | bc -l) )); then
  echo "CRITICAL"
  exit 2
elif (( $(echo "$SPENT >= $WARNING_AMT" | bc -l) )); then
  echo "WARNING"
  exit 1
else
  echo "OK"
  exit 0
fi
