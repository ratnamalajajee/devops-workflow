#!/usr/bin/env bash
# NextGen runbook - step 14 - Azure: Function App on the Flex Consumption plan
# Replaces AWS: AWS Lambda   |   Page: /multicloud/#lambda
# Run from the multicloud folder:  bash run-step.sh azure 14
# Set your values once in azure/nextgen-azure.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-azure.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/azure}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
az storage account create -g "$RG" -n "$FUNC_SA" -l "$LOCATION" \
  --sku Standard_LRS --min-tls-version TLS1_2 --allow-blob-public-access false

az functionapp create -g "$RG" -n "$FUNC_APP" \
  --storage-account "$FUNC_SA" \
  --flexconsumption-location "$LOCATION" \
  --runtime python --runtime-version 3.11

az functionapp identity assign -g "$RG" -n "$FUNC_APP"
# Optional: reach private resources through the VNet
az functionapp vnet-integration add -g "$RG" -n "$FUNC_APP" --vnet "$VNET" --subnet snet-func

# Code (Core Tools v4, Python v2 programming model)
func init nextgen-fn --worker-runtime python --model V2
cd nextgen-fn
func new --name hello --template "HTTP trigger" --authlevel function
func azure functionapp publish "$FUNC_APP"

HOST=$(az functionapp show -g "$RG" -n "$FUNC_APP" --query defaultHostName -o tsv)
KEY=$(az functionapp function keys list -g "$RG" -n "$FUNC_APP" \
  --function-name hello --query default -o tsv)
curl "https://$HOST/api/hello?name=nextgen&code=$KEY"
