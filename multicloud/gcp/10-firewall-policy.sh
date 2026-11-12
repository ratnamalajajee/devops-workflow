#!/usr/bin/env bash
# NextGen runbook - step 10 - GCP: Global network firewall policy with a deny rule
# Replaces AWS: NACL   |   Page: /multicloud/#nacl
# Run from the multicloud folder:  bash run-step.sh gcp 10
# Set your values once in gcp/nextgen-gcp.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-gcp.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/gcp}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
gcloud compute network-firewall-policies create "fwp-$PREFIX-$ENV" --global \
  --description="NextGen subnet-level guardrails"

# Block a known-bad range for the whole VPC (NACL-style deny)
gcloud compute network-firewall-policies rules create 1000 \
  --firewall-policy="fwp-$PREFIX-$ENV" --global-firewall-policy \
  --direction=INGRESS --action=deny \
  --src-ip-ranges=198.51.100.0/24 --layer4-configs=all

gcloud compute network-firewall-policies associations create \
  --firewall-policy="fwp-$PREFIX-$ENV" --global-firewall-policy \
  --network="$NETWORK" --name="assoc-$NETWORK"

gcloud compute network-firewall-policies describe "fwp-$PREFIX-$ENV" --global
