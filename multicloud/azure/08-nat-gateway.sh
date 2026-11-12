#!/usr/bin/env bash
# Multi-cloud runbook - step 08 - Azure: NAT gateway on the AKS and VM subnets
# Replaces AWS: NAT Gateway   |   Page: /multicloud/#nat-gateway
# Run from the multicloud folder:  bash run-step.sh azure 08
# Set your values once in azure/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/azure}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
az network public-ip create -g "$RG" -n "pip-$PREFIX-natgw" \
  --sku Standard --allocation-method Static

az network nat gateway create -g "$RG" -n "natgw-$PREFIX-$ENV" -l "$LOCATION" \
  --public-ip-addresses "pip-$PREFIX-natgw" --idle-timeout 10

for s in snet-aks snet-vm; do
  az network vnet subnet update -g "$RG" --vnet-name "$VNET" -n "$s" \
    --nat-gateway "natgw-$PREFIX-$ENV"
done

# The egress IP to allow-list
az network public-ip show -g "$RG" -n "pip-$PREFIX-natgw" --query ipAddress -o tsv
