#!/usr/bin/env bash
# NextGen runbook - step 20 - GCP: AlloyDB cluster, primary + read pool
# Replaces AWS: Aurora   |   Page: /multicloud/#aurora
# Run from the multicloud folder:  bash run-step.sh gcp 20
# Set your values once in gcp/nextgen-gcp.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-gcp.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/gcp}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
gcloud alloydb clusters create "alloydb-$PREFIX-$ENV" \
  --region="$REGION" --network="$NETWORK" \
  --password="$(gcloud secrets versions access latest --secret=db-password)"

gcloud alloydb instances create primary \
  --cluster="alloydb-$PREFIX-$ENV" --region="$REGION" \
  --instance-type=PRIMARY --cpu-count=2 --availability-type=REGIONAL

gcloud alloydb instances create read-pool-1 \
  --cluster="alloydb-$PREFIX-$ENV" --region="$REGION" \
  --instance-type=READ_POOL --cpu-count=2 --read-pool-node-count=1

gcloud alloydb instances list --cluster="alloydb-$PREFIX-$ENV" --region="$REGION"
