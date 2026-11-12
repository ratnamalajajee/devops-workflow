#!/usr/bin/env bash
# Multi-cloud runbook - step 14 - AWS: Lambda function in the VPC with an IAM-auth URL
# Replaces AWS: AWS Lambda   |   Page: /multicloud/#lambda
# Run from the multicloud folder:  bash run-step.sh aws 14
# Set your values once in aws/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/aws}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
mkdir -p hello-fn && cd hello-fn
cat > app.py <<'EOF'
def handler(event, context):
    params = event.get("queryStringParameters") or {}
    name = params.get("name", "world")
    return {"statusCode": 200, "body": f"Hello, {name}, from ShopNow"}
EOF
zip function.zip app.py

aws lambda create-function --function-name "fn-$PREFIX-hello" \
  --runtime python3.12 --handler app.handler --zip-file fileb://function.zip \
  --role "arn:aws:iam::$ACCOUNT_ID:role/role-$PREFIX-lambda" \
  --vpc-config "SubnetIds=$(subnet_id snet-private-a),$(subnet_id snet-private-b),SecurityGroupIds=$(sg_id sg-$PREFIX-web)"
aws lambda wait function-active-v2 --function-name "fn-$PREFIX-hello"

# HTTPS endpoint that needs IAM-signed requests
aws lambda create-function-url-config --function-name "fn-$PREFIX-hello" --auth-type AWS_IAM

aws lambda invoke --function-name "fn-$PREFIX-hello" --cli-binary-format raw-in-base64-out \
  --payload '{"queryStringParameters":{"name":"shopnow"}}' out.json && cat out.json
