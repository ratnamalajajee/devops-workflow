#!/usr/bin/env bash
# NextGen runbook - step 04 - Azure: Key Vault secret + reader role
# Replaces AWS: Secrets Manager   |   Page: /multicloud/#secrets
# Run from the multicloud folder:  bash run-step.sh azure 04
# Set your values once in azure/nextgen-azure.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-azure.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/azure}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
KV_ID=$(az keyvault show -n "$KV" --query id -o tsv)
APP_PRINCIPAL_ID=$(az identity show -g "$RG" -n "id-$PREFIX-app" --query principalId -o tsv)

az keyvault secret set --vault-name "$KV" -n db-password \
  --value "$(openssl rand -base64 24)" \
  --expires "$(date -u -d '+180 days' +%Y-%m-%dT%H:%M:%SZ)"
az keyvault secret show --vault-name "$KV" -n db-password --query value -o tsv

# Workload read access (Secrets Manager resource policy)
az role assignment create --assignee-object-id "$APP_PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Key Vault Secrets User" --scope "$KV_ID"

az keyvault secret list --vault-name "$KV" -o table
