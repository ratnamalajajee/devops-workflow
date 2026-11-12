#!/usr/bin/env bash
# NextGen runbook - step 14 - GCP: Cloud Run function, authenticated HTTP
# Replaces AWS: AWS Lambda   |   Page: /multicloud/#lambda
# Run from the multicloud folder:  bash run-step.sh gcp 14
# Set your values once in gcp/nextgen-gcp.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-gcp.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/gcp}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
mkdir -p hello-fn && cd hello-fn
cat > main.py <<'EOF'
import functions_framework

@functions_framework.http
def hello(request):
    name = request.args.get("name", "world")
    return f"Hello, {name}, from NextGen"
EOF
echo "functions-framework==3.*" > requirements.txt

gcloud functions deploy "fn-$PREFIX-hello" \
  --gen2 --region="$REGION" --runtime=python312 \
  --source=. --entry-point=hello --trigger-http \
  --no-allow-unauthenticated --service-account="$SA_FN"

URL=$(gcloud functions describe "fn-$PREFIX-hello" --region="$REGION" \
  --format="value(serviceConfig.uri)")
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" "$URL?name=nextgen"
