#!/usr/bin/env bash
# NextGen runbook - step 10 - Azure: Subnet NSGs for the database and App Gateway subnets
# Replaces AWS: NACL   |   Page: /multicloud/#nacl
# Run from the multicloud folder:  bash run-step.sh azure 10
# Set your values once in azure/nextgen-azure.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-azure.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/azure}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
# Database subnet: allow app tiers and intra-subnet HA, deny the rest
az network nsg create -g "$RG" -n "nsg-$PREFIX-snet-db"
az network nsg rule create -g "$RG" --nsg-name "nsg-$PREFIX-snet-db" -n allow-pg-from-apps \
  --priority 100 --direction Inbound --access Allow --protocol Tcp \
  --source-address-prefixes 10.10.0.0/20 10.10.17.0/24 --destination-port-ranges 5432
az network nsg rule create -g "$RG" --nsg-name "nsg-$PREFIX-snet-db" -n allow-intra-subnet \
  --priority 110 --direction Inbound --access Allow --protocol '*' \
  --source-address-prefixes 10.10.18.0/24 --destination-port-ranges '*'
az network nsg rule create -g "$RG" --nsg-name "nsg-$PREFIX-snet-db" -n deny-all-inbound \
  --priority 4000 --direction Inbound --access Deny --protocol '*' \
  --source-address-prefixes '*' --destination-port-ranges '*'
az network vnet subnet update -g "$RG" --vnet-name "$VNET" -n snet-db \
  --network-security-group "nsg-$PREFIX-snet-db"

# App Gateway subnet: required infrastructure ports + web traffic
az network nsg create -g "$RG" -n "nsg-$PREFIX-appgw"
az network nsg rule create -g "$RG" --nsg-name "nsg-$PREFIX-appgw" -n allow-gateway-manager \
  --priority 100 --direction Inbound --access Allow --protocol Tcp \
  --source-address-prefixes GatewayManager --destination-port-ranges 65200-65535
az network nsg rule create -g "$RG" --nsg-name "nsg-$PREFIX-appgw" -n allow-web \
  --priority 110 --direction Inbound --access Allow --protocol Tcp \
  --source-address-prefixes Internet --destination-port-ranges 80 443
az network vnet subnet update -g "$RG" --vnet-name "$VNET" -n snet-appgw \
  --network-security-group "nsg-$PREFIX-appgw"
