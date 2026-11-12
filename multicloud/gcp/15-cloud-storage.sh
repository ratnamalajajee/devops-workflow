#!/usr/bin/env bash
# NextGen runbook - step 15 - GCP: Bucket with uniform access and public access prevention
# Replaces AWS: Amazon S3   |   Page: /multicloud/#s3
# Run from the multicloud folder:  bash run-step.sh gcp 15
# Set your values once in gcp/nextgen-gcp.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-gcp.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/gcp}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
for b in "$BUCKET" "$PROJECT_ID-tfstate"; do
  gcloud storage buckets create "gs://$b" \
    --location="$REGION" --default-storage-class=STANDARD \
    --uniform-bucket-level-access --public-access-prevention
  gcloud storage buckets update "gs://$b" --versioning
done

gcloud storage buckets add-iam-policy-binding "gs://$BUCKET" \
  --member="serviceAccount:$SA_APP" --role=roles/storage.objectUser

echo "hello" > hello.txt
gcloud storage cp hello.txt "gs://$BUCKET/"
gcloud storage ls -l "gs://$BUCKET"

# Lifecycle: Nearline after 30 days, keep 5 noncurrent versions
cat > lifecycle.json <<'EOF'
{"rule":[{"action":{"type":"SetStorageClass","storageClass":"NEARLINE"},"condition":{"age":30}},
         {"action":{"type":"Delete"},"condition":{"numNewerVersions":5}}]}
EOF
gcloud storage buckets update "gs://$BUCKET" --lifecycle-file=lifecycle.json
