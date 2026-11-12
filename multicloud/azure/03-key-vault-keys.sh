#!/usr/bin/env bash
# Multi-cloud runbook - step 03 - Azure: Key Vault (RBAC mode) + HSM-backed key
# Replaces AWS: KMS   |   Page: /multicloud/#kms
# Run from the multicloud folder:  bash run-step.sh azure 03
# Set your values once in azure/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/azure}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
az keyvault create -g "$RG" -n "$KV" -l "$LOCATION" \
  --sku premium \
  --enable-rbac-authorization true \
  --enable-purge-protection true --retention-days 90

KV_ID=$(az keyvault show -n "$KV" --query id -o tsv)
ME_ID=$(az ad signed-in-user show --query id -o tsv)
az role assignment create --assignee-object-id "$ME_ID" --assignee-principal-type User \
  --role "Key Vault Administrator" --scope "$KV_ID"
# Role assignments can take 1-2 minutes to apply

az keyvault key create --vault-name "$KV" -n "key-$PREFIX-data" \
  --kty RSA-HSM --size 3072 --ops wrapKey unwrapKey encrypt decrypt

cat > rotation.json <<'EOF'
{
  "lifetimeActions": [
    { "trigger": { "timeAfterCreate": "P90D" },  "action": { "type": "Rotate" } },
    { "trigger": { "timeBeforeExpiry": "P30D" }, "action": { "type": "Notify" } }
  ],
  "attributes": { "expiryTime": "P1Y" }
}
EOF
az keyvault key rotation-policy update --vault-name "$KV" -n "key-$PREFIX-data" --value @rotation.json
az keyvault key list --vault-name "$KV" -o table
