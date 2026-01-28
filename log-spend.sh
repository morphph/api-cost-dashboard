#!/bin/bash
# Log API spending: ./log-spend.sh <api_name> <amount>
# Example: ./log-spend.sh twitter 0.0015

API_NAME="${1:?API name required}"
AMOUNT="${2:?Amount required}"
TRACKER="/home/ubuntu/clawd/dashboard/spending-tracker.json"
TODAY=$(date +%Y-%m-%d)

# Reset if new day
SAVED_DATE=$(jq -r '.today.date' "$TRACKER")
if [ "$SAVED_DATE" != "$TODAY" ]; then
  jq --arg today "$TODAY" '
    .history += [.today] |
    .today = {date: $today, spent: 0, breakdown: {}}
  ' "$TRACKER" > "$TRACKER.tmp" && mv "$TRACKER.tmp" "$TRACKER"
fi

# Add spending
jq --arg api "$API_NAME" --argjson amt "$AMOUNT" '
  .today.spent += $amt |
  .today.breakdown[$api] = ((.today.breakdown[$api] // 0) + $amt)
' "$TRACKER" > "$TRACKER.tmp" && mv "$TRACKER.tmp" "$TRACKER"

# Check if alert needed
SPENT=$(jq -r '.today.spent' "$TRACKER")
BUDGET=$(jq -r '.dailyBudget' "$TRACKER")
WARNING=$(jq -r '.warningThreshold' "$TRACKER")
CRITICAL=$(jq -r '.criticalThreshold' "$TRACKER")

WARNING_AMT=$(echo "scale=2; $BUDGET * $WARNING" | bc)
CRITICAL_AMT=$(echo "scale=2; $BUDGET * $CRITICAL" | bc)

if (( $(echo "$SPENT >= $CRITICAL_AMT" | bc -l) )); then
  echo "🚨 CRITICAL: Daily spend \$$SPENT / \$$BUDGET ($(echo "scale=0; $SPENT / $BUDGET * 100" | bc)%)"
  exit 2
elif (( $(echo "$SPENT >= $WARNING_AMT" | bc -l) )); then
  echo "⚠️ WARNING: Daily spend \$$SPENT / \$$BUDGET ($(echo "scale=0; $SPENT / $BUDGET * 100" | bc)%)"
  exit 1
else
  echo "✅ Logged \$$AMOUNT to $API_NAME. Total: \$$SPENT / \$$BUDGET"
  exit 0
fi
