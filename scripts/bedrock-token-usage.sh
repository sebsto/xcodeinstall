#!/bin/bash
#
# Report Claude token usage on AWS Bedrock for the current month.
# Usage: ./bedrock-token-usage.sh [profile] [region]
#

PROFILE="${1:-pro-login}"
REGION="${2:-eu-central-1}"
START="$(date -u +%Y-%m-01T00:00:00Z)"
END="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
PERIOD=2592000

echo "Bedrock Claude token usage"
echo "Profile: $PROFILE | Region: $REGION"
echo "Period:  $START -> $END"
echo ""

# Discover all Claude models with token metrics
MODELS=$(aws cloudwatch list-metrics \
  --profile "$PROFILE" \
  --region "$REGION" \
  --namespace AWS/Bedrock \
  --metric-name InputTokenCount \
  --output json | python3 -c "
import json, sys
data = json.load(sys.stdin)
for m in data.get('Metrics', []):
    for d in m.get('Dimensions', []):
        if d['Name'] == 'ModelId' and 'claude' in d['Value'].lower():
            print(d['Value'])
" | sort -u)

if [ -z "$MODELS" ]; then
  echo "No Claude models found with token metrics."
  exit 0
fi

GRAND_INPUT=0
GRAND_OUTPUT=0

printf "%-55s %15s %15s %15s\n" "Model" "Input" "Output" "Total"
printf "%-55s %15s %15s %15s\n" "-----" "-----" "------" "-----"

for model in $MODELS; do
  input=$(aws cloudwatch get-metric-statistics \
    --profile "$PROFILE" \
    --region "$REGION" \
    --namespace AWS/Bedrock \
    --metric-name InputTokenCount \
    --start-time "$START" \
    --end-time "$END" \
    --period "$PERIOD" \
    --statistics Sum \
    --dimensions Name=ModelId,Value="$model" \
    --output json | python3 -c "
import json, sys
data = json.load(sys.stdin)
pts = data.get('Datapoints', [])
print(int(pts[0]['Sum']) if pts else 0)
")

  output=$(aws cloudwatch get-metric-statistics \
    --profile "$PROFILE" \
    --region "$REGION" \
    --namespace AWS/Bedrock \
    --metric-name OutputTokenCount \
    --start-time "$START" \
    --end-time "$END" \
    --period "$PERIOD" \
    --statistics Sum \
    --dimensions Name=ModelId,Value="$model" \
    --output json | python3 -c "
import json, sys
data = json.load(sys.stdin)
pts = data.get('Datapoints', [])
print(int(pts[0]['Sum']) if pts else 0)
")

  total=$((input + output))
  GRAND_INPUT=$((GRAND_INPUT + input))
  GRAND_OUTPUT=$((GRAND_OUTPUT + output))

  printf "%-55s %'15d %'15d %'15d\n" "$model" "$input" "$output" "$total"
done

GRAND_TOTAL=$((GRAND_INPUT + GRAND_OUTPUT))
echo ""
printf "%-55s %'15d %'15d %'15d\n" "TOTAL" "$GRAND_INPUT" "$GRAND_OUTPUT" "$GRAND_TOTAL"
