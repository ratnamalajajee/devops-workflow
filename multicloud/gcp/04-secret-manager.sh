#!/usr/bin/env bash
# NextGen runbook - step 04 - GCP: Secret Manager secret + accessor role
# Replaces AWS: Secrets Manager   |   Page: /multicloud/#secrets
# Run from the multicloud folder:  bash run-step.sh gcp 04
# Set your values once in gcp/nextgen-gcp.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-gcp.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/gcp}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
gcloud secrets create db-password --replication-policy=automatic
openssl rand -base64 24 | tr -d '\n' | gcloud secrets versions add db-password --data-file=-
gcloud secrets versions access latest --secret=db-password

gcloud secrets add-iam-policy-binding db-password \
  --member="serviceAccount:$SA_APP" --role=roles/secretmanager.secretAccessor

gcloud secrets list
