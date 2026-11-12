#!/usr/bin/env bash
# Multi-cloud runbook - step 18 - GCP: Firestore database in Native mode
# Replaces AWS: DynamoDB   |   Page: /multicloud/#dynamodb
# Run from the multicloud folder:  bash run-step.sh gcp 18
# Set your values once in gcp/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/gcp}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
gcloud firestore databases create --database=appdb \
  --location="$REGION" --type=firestore-native

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$SA_APP" --role=roles/datastore.user

gcloud firestore databases describe --database=appdb
