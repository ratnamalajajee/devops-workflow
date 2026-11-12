#!/usr/bin/env bash
# Multi-cloud runbook - step 11 - GCP: NCC hub + VPC spoke
# Replaces AWS: Transit Gateway   |   Page: /multicloud/#transit-gateway
# Run from the multicloud folder:  bash run-step.sh gcp 11
# Set your values once in gcp/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/gcp}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
gcloud network-connectivity hubs create "hub-$PREFIX" \
  --description="ShopNow transit hub"

gcloud network-connectivity spokes linked-vpc-network create "spoke-$NETWORK" \
  --hub="hub-$PREFIX" --global \
  --vpc-network="projects/$PROJECT_ID/global/networks/$NETWORK"

gcloud network-connectivity hubs describe "hub-$PREFIX"
gcloud network-connectivity spokes list --global
