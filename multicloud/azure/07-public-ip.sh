#!/usr/bin/env bash
# Multi-cloud runbook - step 07 - Azure: Standard public IP + effective routes
# Replaces AWS: Internet Gateway   |   Page: /multicloud/#internet-gateway
# Run from the multicloud folder:  bash run-step.sh azure 07
# Set your values once in azure/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/azure}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
# Inbound internet = a Standard public IP on an App Gateway, load balancer or NIC
az network public-ip create -g "$RG" -n "pip-$PREFIX-appgw" \
  --sku Standard --allocation-method Static --zone 1 2 3

# Private subnets: no implicit outbound (NAT gateway in step 08)
az network vnet subnet show -g "$RG" --vnet-name "$VNET" -n snet-vm \
  --query "{name:name, defaultOutbound:defaultOutboundAccess}" -o table

# After step 12, check the VM NIC's effective routes (VM must be running):
# NIC_ID=$(az vm show -g "$RG" -n "vm-$PREFIX-01" \
#   --query "networkProfile.networkInterfaces[0].id" -o tsv)
# az network nic show-effective-route-table --ids "$NIC_ID" -o table
