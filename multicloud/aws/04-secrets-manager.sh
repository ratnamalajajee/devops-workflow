#!/usr/bin/env bash
# NextGen runbook - step 04 - AWS: Secrets Manager secret + read policy
# Replaces AWS: Secrets Manager   |   Page: /multicloud/#secrets
# Run from the multicloud folder:  bash run-step.sh aws 04
# Set your values once in aws/nextgen-aws.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-aws.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/aws}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
aws secretsmanager create-secret --name "$PREFIX/$ENV/db-password" \
  --kms-key-id "alias/$PREFIX-data" \
  --secret-string "$(aws secretsmanager get-random-password --password-length 32 \
                      --exclude-punctuation --query RandomPassword --output text)"
aws secretsmanager get-secret-value --secret-id "$PREFIX/$ENV/db-password" \
  --query SecretString --output text

# Read access for the app role
SECRET_ARN=$(aws secretsmanager describe-secret --secret-id "$PREFIX/$ENV/db-password" --query ARN --output text)
cat > read-secret.json <<EOF
{"Version":"2012-10-17","Statement":[
  {"Effect":"Allow","Action":"secretsmanager:GetSecretValue","Resource":"$SECRET_ARN"},
  {"Effect":"Allow","Action":"kms:Decrypt","Resource":"arn:aws:kms:$AWS_REGION:$ACCOUNT_ID:key/*"}]}
EOF
aws iam put-role-policy --role-name "role-$PREFIX-app" --policy-name read-db-password \
  --policy-document file://read-secret.json

aws secretsmanager list-secrets --query "SecretList[].Name" --output table
