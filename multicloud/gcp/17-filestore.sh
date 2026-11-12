#!/usr/bin/env bash
# Multi-cloud runbook - step 17 - GCP: Filestore instance on Private Services Access
# Replaces AWS: Amazon EFS   |   Page: /multicloud/#efs
# Run from the multicloud folder:  bash run-step.sh gcp 17
# Set your values once in gcp/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/gcp}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
gcloud filestore instances create "fs-$PREFIX-$ENV" \
  --zone="$ZONE" --tier=BASIC_HDD \
  --file-share=name=shared,capacity=1TB \
  --network=name="$NETWORK",connect-mode=PRIVATE_SERVICE_ACCESS

FS_IP=$(gcloud filestore instances describe "fs-$PREFIX-$ENV" --zone="$ZONE" \
  --format="value(networks[0].ipAddresses[0])")

gcloud compute ssh "vm-$PREFIX-01" --zone="$ZONE" --tunnel-through-iap --command \
  "sudo apt-get install -y nfs-common && sudo mkdir -p /mnt/shared && sudo mount -t nfs $FS_IP:/shared /mnt/shared && df -h /mnt/shared"
