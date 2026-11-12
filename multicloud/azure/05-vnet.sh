#!/usr/bin/env bash
# NextGen runbook - step 05 - Azure: Virtual network
# Replaces AWS: Amazon VPC   |   Page: /multicloud/#vpc
# Run from the multicloud folder:  bash run-step.sh azure 05
# Set your values once in azure/nextgen-azure.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-azure.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/azure}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
az network vnet create -g "$RG" -n "$VNET" -l "$LOCATION" \
  --address-prefixes 10.10.0.0/16

az network vnet show -g "$RG" -n "$VNET" \
  --query "{name:name, region:location, space:addressSpace.addressPrefixes}" -o table
