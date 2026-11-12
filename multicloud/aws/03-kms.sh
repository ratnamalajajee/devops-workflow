#!/usr/bin/env bash
# Multi-cloud runbook - step 03 - AWS: Customer managed KMS key with rotation
# Replaces AWS: KMS   |   Page: /multicloud/#kms
# Run from the multicloud folder:  bash run-step.sh aws 03
# Set your values once in aws/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/aws}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
KEY_ID=$(aws kms create-key --description "ShopNow data key" \
  --key-usage ENCRYPT_DECRYPT --key-spec SYMMETRIC_DEFAULT \
  --tags TagKey=app,TagValue=$PREFIX --query KeyMetadata.KeyId --output text)
aws kms create-alias --alias-name "alias/$PREFIX-data" --target-key-id "$KEY_ID"
aws kms enable-key-rotation --key-id "$KEY_ID" --rotation-period-in-days 90

# Round-trip test
echo -n "hello shopnow" > plain.txt
aws kms encrypt --key-id "alias/$PREFIX-data" --plaintext fileb://plain.txt \
  --query CiphertextBlob --output text | base64 -d > cipher.bin
aws kms decrypt --ciphertext-blob fileb://cipher.bin --query Plaintext --output text | base64 -d

# Let the app role use the key
aws kms create-grant --key-id "$KEY_ID" \
  --grantee-principal "arn:aws:iam::$ACCOUNT_ID:role/role-$PREFIX-app" \
  --operations Encrypt Decrypt GenerateDataKey
