#!/usr/bin/env bash
# Multi-cloud runbook - step 15 - Azure: Storage account + containers, Entra ID auth
# Replaces AWS: Amazon S3   |   Page: /multicloud/#s3
# Run from the multicloud folder:  bash run-step.sh azure 15
# Set your values once in azure/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/azure}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
az storage account create -g "$RG" -n "$SA" -l "$LOCATION" \
  --sku Standard_ZRS --kind StorageV2 \
  --min-tls-version TLS1_2 --allow-blob-public-access false --https-only true

az storage account blob-service-properties update -g "$RG" --account-name "$SA" \
  --enable-versioning true \
  --enable-delete-retention true --delete-retention-days 14 \
  --enable-container-delete-retention true --container-delete-retention-days 14

SA_ID=$(az storage account show -g "$RG" -n "$SA" --query id -o tsv)
ME_ID=$(az ad signed-in-user show --query id -o tsv)
az role assignment create --assignee-object-id "$ME_ID" --assignee-principal-type User \
  --role "Storage Blob Data Contributor" --scope "$SA_ID"

az storage container create --account-name "$SA" -n artifacts --auth-mode login
az storage container create --account-name "$SA" -n tfstate --auth-mode login

echo "hello" > hello.txt
az storage blob upload --account-name "$SA" -c artifacts -n hello.txt -f hello.txt --auth-mode login
az storage blob list --account-name "$SA" -c artifacts --auth-mode login -o table

# Lifecycle: tier to Cool after 30 days
cat > policy.json <<'EOF'
{"rules":[{"enabled":true,"name":"cool-after-30d","type":"Lifecycle",
  "definition":{"actions":{"baseBlob":{"tierToCool":{"daysAfterModificationGreaterThan":30}}},
                "filters":{"blobTypes":["blockBlob"]}}}]}
EOF
az storage account management-policy create -g "$RG" --account-name "$SA" --policy @policy.json
