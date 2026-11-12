#!/usr/bin/env bash
# Multi-cloud runbook - step 18 - AWS: On-demand DynamoDB table (+ legacy lock table)
# Replaces AWS: DynamoDB   |   Page: /multicloud/#dynamodb
# Run from the multicloud folder:  bash run-step.sh aws 18
# Set your values once in aws/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/aws}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
aws dynamodb create-table --table-name "$PREFIX-$ENV-items" \
  --attribute-definitions AttributeName=tenantId,AttributeType=S AttributeName=itemId,AttributeType=S \
  --key-schema AttributeName=tenantId,KeyType=HASH AttributeName=itemId,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST --deletion-protection-enabled \
  --sse-specification Enabled=true,SSEType=KMS,KMSMasterKeyId="alias/$PREFIX-data"
aws dynamodb wait table-exists --table-name "$PREFIX-$ENV-items"
aws dynamodb update-continuous-backups --table-name "$PREFIX-$ENV-items" \
  --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true

# Legacy Terraform lock table (not needed with use_lockfile = true)
aws dynamodb create-table --table-name "$PREFIX-$ENV-tflock" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST

aws dynamodb describe-table --table-name "$PREFIX-$ENV-items" \
  --query "Table.{status:TableStatus, mode:BillingModeSummary.BillingMode}" --output table
