#!/usr/bin/env bash
# NextGen runbook - step 07 - GCP: Default route + global external IP
# Replaces AWS: Internet Gateway   |   Page: /multicloud/#internet-gateway
# Run from the multicloud folder:  bash run-step.sh gcp 07
# Set your values once in gcp/nextgen-gcp.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-gcp.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/gcp}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
# The default internet route is created with the VPC
gcloud compute routes list --filter="network~$NETWORK"

# Only if someone deleted it:
# gcloud compute routes create "rt-$PREFIX-default-internet" \
#   --network="$NETWORK" --destination-range=0.0.0.0/0 \
#   --next-hop-gateway=default-internet-gateway --priority=1000

# Inbound internet = an external IP on a VM or a load balancer frontend
gcloud compute addresses create "ip-$PREFIX-lb" --global --ip-version=IPV4
gcloud compute addresses describe "ip-$PREFIX-lb" --global --format="value(address)"
