#!/usr/bin/env bash
# NextGen runbook - step 05 - GCP: Custom-mode VPC network
# Replaces AWS: Amazon VPC   |   Page: /multicloud/#vpc
# Run from the multicloud folder:  bash run-step.sh gcp 05
# Set your values once in gcp/nextgen-gcp.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-gcp.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/gcp}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
gcloud compute networks create "$NETWORK" \
  --subnet-mode=custom --bgp-routing-mode=regional --mtu=1460

gcloud compute networks describe "$NETWORK" \
  --format="yaml(name, autoCreateSubnetworks, routingConfig)"
