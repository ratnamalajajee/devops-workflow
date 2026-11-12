#!/usr/bin/env bash
# NextGen runbook - step 08 - GCP: Cloud Router + Cloud NAT
# Replaces AWS: NAT Gateway   |   Page: /multicloud/#nat-gateway
# Run from the multicloud folder:  bash run-step.sh gcp 08
# Set your values once in gcp/nextgen-gcp.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-gcp.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/gcp}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
gcloud compute routers create "cr-$PREFIX-$ENV" \
  --network="$NETWORK" --region="$REGION"

gcloud compute routers nats create "nat-$PREFIX-$ENV" \
  --router="cr-$PREFIX-$ENV" --region="$REGION" \
  --auto-allocate-nat-external-ips \
  --nat-all-subnet-ip-ranges \
  --enable-logging

gcloud compute routers nats describe "nat-$PREFIX-$ENV" \
  --router="cr-$PREFIX-$ENV" --region="$REGION"
