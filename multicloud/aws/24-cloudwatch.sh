#!/usr/bin/env bash
# NextGen runbook - step 24 - AWS: SNS topic, CloudWatch alarm, Container Insights, Logs Insights
# Replaces AWS: CloudWatch   |   Page: /multicloud/#cloudwatch
# Run from the multicloud folder:  bash run-step.sh aws 24
# Set your values once in aws/nextgen-aws.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-aws.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/aws}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
# Who gets notified
TOPIC_ARN=$(aws sns create-topic --name "sns-$PREFIX-sre" --query TopicArn --output text)
aws sns subscribe --topic-arn "$TOPIC_ARN" --protocol email --notification-endpoint sre-team@example.com

# Alarm: CPU above 80% for 5 minutes
aws cloudwatch put-metric-alarm --alarm-name alarm-vm-cpu-high \
  --namespace AWS/EC2 --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value="$(vm_id)" \
  --statistic Average --period 60 --evaluation-periods 5 \
  --threshold 80 --comparison-operator GreaterThanThreshold \
  --alarm-actions "$TOPIC_ARN"

# Container Insights for EKS (node role needs the agent policy)
aws iam attach-role-policy --role-name "role-$PREFIX-eks-node" \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
aws eks create-addon --cluster-name "$EKS" --addon-name amazon-cloudwatch-observability

# Metric filter: count ERROR lines in the platform log group
aws logs put-metric-filter --log-group-name "/$PREFIX/$ENV/platform" --filter-name errors \
  --filter-pattern "ERROR" \
  --metric-transformations metricName=PlatformErrors,metricNamespace=NextGen,metricValue=1

# Logs Insights: last hour of EKS audit and API logs
QID=$(aws logs start-query --log-group-name "/aws/eks/$EKS/cluster" \
  --start-time "$(date -d '-1 hour' +%s)" --end-time "$(date +%s)" \
  --query-string 'fields @timestamp, @message | sort @timestamp desc | limit 20' \
  --query queryId --output text)
sleep 5; aws logs get-query-results --query-id "$QID"
