#!/usr/bin/env bash
# NextGen runbook - step 18 - Azure: Cosmos DB for NoSQL, serverless, data-plane RBAC
# Replaces AWS: DynamoDB   |   Page: /multicloud/#dynamodb
# Run from the multicloud folder:  bash run-step.sh azure 18
# Set your values once in azure/nextgen-azure.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-azure.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/azure}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
az cosmosdb create -g "$RG" -n "$COSMOS" \
  --locations regionName="$LOCATION" failoverPriority=0 isZoneRedundant=False \
  --default-consistency-level Session \
  --capabilities EnableServerless

az cosmosdb sql database create -g "$RG" -a "$COSMOS" -n appdb
az cosmosdb sql container create -g "$RG" -a "$COSMOS" -d appdb -n items \
  --partition-key-path "/tenantId"

# Let the app identity read and write data (no account keys)
APP_PRINCIPAL_ID=$(az identity show -g "$RG" -n "id-$PREFIX-app" --query principalId -o tsv)
az cosmosdb sql role assignment create -g "$RG" -a "$COSMOS" \
  --role-definition-name "Cosmos DB Built-in Data Contributor" \
  --principal-id "$APP_PRINCIPAL_ID" --scope "/"

az cosmosdb show -g "$RG" -n "$COSMOS" --query documentEndpoint -o tsv
