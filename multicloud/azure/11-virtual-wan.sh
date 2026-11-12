#!/usr/bin/env bash
# NextGen runbook - step 11 - Azure: Virtual WAN + hub + VNet connection
# Replaces AWS: Transit Gateway   |   Page: /multicloud/#transit-gateway
# Run from the multicloud folder:  bash run-step.sh azure 11
# Set your values once in azure/nextgen-azure.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-azure.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/azure}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
az network vwan create -g "$RG" -n "vwan-$PREFIX" -l "$LOCATION" --type Standard

# Hub creation takes about 30 minutes
az network vhub create -g "$RG" -n "vhub-$PREFIX-$LOCATION" -l "$LOCATION" \
  --vwan "vwan-$PREFIX" --address-prefix 10.100.0.0/23 --sku Standard

az network vhub connection create -g "$RG" --vhub-name "vhub-$PREFIX-$LOCATION" \
  -n "conn-$VNET" --remote-vnet "$VNET"

az network vhub connection list -g "$RG" --vhub-name "vhub-$PREFIX-$LOCATION" -o table
