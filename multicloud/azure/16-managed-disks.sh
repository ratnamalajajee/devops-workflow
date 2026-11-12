#!/usr/bin/env bash
# NextGen runbook - step 16 - Azure: Premium SSD data disk + incremental snapshot
# Replaces AWS: Amazon EBS   |   Page: /multicloud/#ebs
# Run from the multicloud folder:  bash run-step.sh azure 16
# Set your values once in azure/nextgen-azure.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-azure.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/azure}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
az disk create -g "$RG" -n "disk-$PREFIX-data01" \
  --size-gb 128 --sku Premium_LRS --zone 1

az vm disk attach -g "$RG" --vm-name "vm-$PREFIX-01" \
  --name "disk-$PREFIX-data01" --lun 0

az vm run-command invoke -g "$RG" -n "vm-$PREFIX-01" --command-id RunShellScript --scripts \
  "mkfs.ext4 -F /dev/disk/azure/scsi1/lun0 && mkdir -p /data && mount /dev/disk/azure/scsi1/lun0 /data && df -h /data"

az snapshot create -g "$RG" -n "snap-$PREFIX-data01" \
  --source "disk-$PREFIX-data01" --incremental true
az disk list -g "$RG" -o table
