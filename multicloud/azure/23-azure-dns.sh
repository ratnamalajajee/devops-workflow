#!/usr/bin/env bash
# Multi-cloud runbook - step 23 - Azure: Public zone with alias record + private zone
# Replaces AWS: Route 53   |   Page: /multicloud/#route53
# Run from the multicloud folder:  bash run-step.sh azure 23
# Set your values once in azure/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/azure}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
az network dns zone create -g "$RG" -n "$DOMAIN"
az network dns zone show -g "$RG" -n "$DOMAIN" --query nameServers -o tsv   # set these at the registrar

# Alias A record follows the public IP if it ever changes
PIP_ID=$(az network public-ip show -g "$RG" -n "pip-$PREFIX-appgw" --query id -o tsv)
az network dns record-set a create -g "$RG" -z "$DOMAIN" -n app --target-resource "$PIP_ID"
az network dns record-set cname set-record -g "$RG" -z "$DOMAIN" -n www --cname "app.$DOMAIN"

# Private zone (Route 53 private hosted zone), VMs auto-register
az network private-dns zone create -g "$RG" -n "internal.$DOMAIN"
az network private-dns link vnet create -g "$RG" -z "internal.$DOMAIN" \
  -n "link-$VNET" -v "$VNET" -e true

NS1=$(az network dns zone show -g "$RG" -n "$DOMAIN" --query "nameServers[0]" -o tsv)
nslookup "app.$DOMAIN" "$NS1"
