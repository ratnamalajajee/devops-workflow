#!/usr/bin/env bash
# Multi-cloud runbook - step 06 - Azure: Subnets, delegations, private subnets
# Replaces AWS: Subnets   |   Page: /multicloud/#subnets
# Run from the multicloud folder:  bash run-step.sh azure 06
# Set your values once in azure/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/azure}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
# AKS nodes (pods use the overlay range, not VNet IPs)
az network vnet subnet create -g "$RG" --vnet-name "$VNET" -n snet-aks \
  --address-prefixes 10.10.0.0/20 --default-outbound false
# Application Gateway: dedicated subnet, nothing else in it
az network vnet subnet create -g "$RG" --vnet-name "$VNET" -n snet-appgw \
  --address-prefixes 10.10.16.0/24
az network vnet subnet create -g "$RG" --vnet-name "$VNET" -n snet-vm \
  --address-prefixes 10.10.17.0/24 --default-outbound false
# PostgreSQL flexible server (delegated)
az network vnet subnet create -g "$RG" --vnet-name "$VNET" -n snet-db \
  --address-prefixes 10.10.18.0/24 \
  --delegations Microsoft.DBforPostgreSQL/flexibleServers
# Private endpoints (Azure SQL, Storage, Key Vault)
az network vnet subnet create -g "$RG" --vnet-name "$VNET" -n snet-pe \
  --address-prefixes 10.10.19.0/24
# Functions Flex Consumption VNet integration (delegated)
az network vnet subnet create -g "$RG" --vnet-name "$VNET" -n snet-func \
  --address-prefixes 10.10.20.0/24 --delegations Microsoft.App/environments

az network vnet subnet list -g "$RG" --vnet-name "$VNET" \
  --query "[].{name:name, prefix:addressPrefix}" -o table
