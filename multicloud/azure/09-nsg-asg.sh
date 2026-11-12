#!/usr/bin/env bash
# NextGen runbook - step 09 - Azure: NSG for the VM tier + application security group
# Replaces AWS: Security Groups   |   Page: /multicloud/#security-groups
# Run from the multicloud folder:  bash run-step.sh azure 09
# Set your values once in azure/nextgen-azure.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-azure.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/azure}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
az network asg create -g "$RG" -n "asg-$PREFIX-web"
az network nsg create -g "$RG" -n "nsg-$PREFIX-vm"

# HTTP(S) from the App Gateway subnet to members of asg-web
az network nsg rule create -g "$RG" --nsg-name "nsg-$PREFIX-vm" -n allow-web-from-appgw \
  --priority 100 --direction Inbound --access Allow --protocol Tcp \
  --source-address-prefixes 10.10.16.0/24 \
  --destination-asgs "asg-$PREFIX-web" --destination-port-ranges 80 443

# SSH only from the corporate range (replace 203.0.113.0/24)
az network nsg rule create -g "$RG" --nsg-name "nsg-$PREFIX-vm" -n allow-ssh-corp \
  --priority 110 --direction Inbound --access Allow --protocol Tcp \
  --source-address-prefixes 203.0.113.0/24 --destination-port-ranges 22

az network vnet subnet update -g "$RG" --vnet-name "$VNET" -n snet-vm \
  --network-security-group "nsg-$PREFIX-vm"
az network nsg rule list -g "$RG" --nsg-name "nsg-$PREFIX-vm" -o table
