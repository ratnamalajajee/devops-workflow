#!/usr/bin/env bash
# NextGen runbook - step 06 - GCP: Subnets, secondary ranges, Private Services Access
# Replaces AWS: Subnets   |   Page: /multicloud/#subnets
# Run from the multicloud folder:  bash run-step.sh gcp 06
# Set your values once in gcp/nextgen-gcp.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-gcp.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/gcp}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
gcloud compute networks subnets create snet-gke \
  --network="$NETWORK" --region="$REGION" --range=10.20.0.0/20 \
  --secondary-range=pods=10.24.0.0/14,services=10.28.0.0/20 \
  --enable-private-ip-google-access --enable-flow-logs

gcloud compute networks subnets create snet-vm \
  --network="$NETWORK" --region="$REGION" --range=10.20.16.0/24 \
  --enable-private-ip-google-access --enable-flow-logs

# Private Services Access for Cloud SQL, AlloyDB and Filestore
gcloud compute addresses create google-managed-services \
  --global --purpose=VPC_PEERING --addresses=10.30.0.0 --prefix-length=16 \
  --network="$NETWORK"
gcloud services vpc-peerings connect \
  --service=servicenetworking.googleapis.com \
  --ranges=google-managed-services --network="$NETWORK"

gcloud compute networks subnets list --network="$NETWORK"
