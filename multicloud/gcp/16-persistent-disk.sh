#!/usr/bin/env bash
# NextGen runbook - step 16 - GCP: Balanced persistent disk + snapshot schedule
# Replaces AWS: Amazon EBS   |   Page: /multicloud/#ebs
# Run from the multicloud folder:  bash run-step.sh gcp 16
# Set your values once in gcp/nextgen-gcp.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-gcp.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/gcp}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
gcloud compute disks create "disk-$PREFIX-data01" \
  --zone="$ZONE" --size=128GB --type=pd-balanced

gcloud compute instances attach-disk "vm-$PREFIX-01" --zone="$ZONE" \
  --disk="disk-$PREFIX-data01" --device-name=data01

gcloud compute ssh "vm-$PREFIX-01" --zone="$ZONE" --tunnel-through-iap --command \
  "sudo mkfs.ext4 -F /dev/disk/by-id/google-data01 && sudo mkdir -p /data && sudo mount /dev/disk/by-id/google-data01 /data && df -h /data"

# Daily snapshots kept for 14 days
gcloud compute resource-policies create snapshot-schedule "sched-$PREFIX-daily" \
  --region="$REGION" --daily-schedule --start-time=02:00 --max-retention-days=14
gcloud compute disks add-resource-policies "disk-$PREFIX-data01" --zone="$ZONE" \
  --resource-policies="sched-$PREFIX-daily"
gcloud compute snapshots create "snap-$PREFIX-data01" \
  --source-disk="disk-$PREFIX-data01" --source-disk-zone="$ZONE"
