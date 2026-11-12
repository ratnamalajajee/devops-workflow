#!/usr/bin/env bash
# NextGen runbook - step 17 - Azure: Premium FileStorage account + NFS share
# Replaces AWS: Amazon EFS   |   Page: /multicloud/#efs
# Run from the multicloud folder:  bash run-step.sh azure 17
# Set your values once in azure/nextgen-azure.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-azure.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/azure}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
# NFS needs Premium FileStorage with secure transfer off
az storage account create -g "$RG" -n "$FILES_SA" -l "$LOCATION" \
  --sku Premium_ZRS --kind FileStorage --https-only false --default-action Deny

# Only snet-vm may reach the account (service endpoint + network rule)
az network vnet subnet update -g "$RG" --vnet-name "$VNET" -n snet-vm \
  --service-endpoints Microsoft.Storage
az storage account network-rule add -g "$RG" --account-name "$FILES_SA" \
  --vnet-name "$VNET" --subnet snet-vm

az storage share-rm create -g "$RG" --storage-account "$FILES_SA" -n shared \
  --quota 100 --enabled-protocols NFS --root-squash RootSquash

# Mount on the VM
az vm run-command invoke -g "$RG" -n "vm-$PREFIX-01" --command-id RunShellScript --scripts \
  "apt-get install -y nfs-common && mkdir -p /mnt/shared && mount -t nfs -o vers=4,minorversion=1,sec=sys,nconnect=4 $FILES_SA.file.core.windows.net:/$FILES_SA/shared /mnt/shared && df -h /mnt/shared"
