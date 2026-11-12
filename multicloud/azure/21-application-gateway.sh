#!/usr/bin/env bash
# NextGen runbook - step 21 - Azure: Application Gateway WAF_v2, zone-redundant, autoscaling
# Replaces AWS: ALB   |   Page: /multicloud/#alb
# Run from the multicloud folder:  bash run-step.sh azure 21
# Set your values once in azure/nextgen-azure.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-azure.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/azure}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
az network application-gateway waf-policy create -g "$RG" -n "wafp-$PREFIX-$ENV" \
  --type Microsoft_DefaultRuleSet --version 2.1

# Public IP from step 07 (this re-run is a no-op if it exists)
az network public-ip create -g "$RG" -n "pip-$PREFIX-appgw" \
  --sku Standard --allocation-method Static --zone 1 2 3

VM_IP=$(az vm show -d -g "$RG" -n "vm-$PREFIX-01" --query privateIps -o tsv)

az network application-gateway create -g "$RG" -n "$APPGW" -l "$LOCATION" \
  --sku WAF_v2 --min-capacity 1 --max-capacity 5 --zones 1 2 3 \
  --vnet-name "$VNET" --subnet snet-appgw \
  --public-ip-address "pip-$PREFIX-appgw" \
  --waf-policy "wafp-$PREFIX-$ENV" \
  --frontend-port 80 --http-settings-port 80 --http-settings-protocol Http \
  --servers "$VM_IP" --priority 100

az network application-gateway show-backend-health -g "$RG" -n "$APPGW" -o table
curl -I "http://$(az network public-ip show -g "$RG" -n "pip-$PREFIX-appgw" --query ipAddress -o tsv)"
