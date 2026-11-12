#!/usr/bin/env bash
# NextGen runbook - step 20 - Azure: Azure SQL Hyperscale, Entra-only auth, private endpoint
# Replaces AWS: Aurora   |   Page: /multicloud/#aurora
# Run from the multicloud folder:  bash run-step.sh azure 20
# Set your values once in azure/nextgen-azure.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-azure.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/azure}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
GROUP_ID=$(az ad group show --group "grp-$PREFIX-platform-admins" --query id -o tsv)

az sql server create -g "$RG" -n "$SQLSRV" -l "$LOCATION" \
  --enable-ad-only-auth \
  --external-admin-principal-type Group \
  --external-admin-name "grp-$PREFIX-platform-admins" \
  --external-admin-sid "$GROUP_ID"

az sql db create -g "$RG" -s "$SQLSRV" -n appdb \
  --edition Hyperscale --family Gen5 --capacity 2 --ha-replicas 1

# Private endpoint + private DNS, then close the public endpoint
SQL_ID=$(az sql server show -g "$RG" -n "$SQLSRV" --query id -o tsv)
az network private-endpoint create -g "$RG" -n "pe-$SQLSRV" \
  --vnet-name "$VNET" --subnet snet-pe \
  --private-connection-resource-id "$SQL_ID" --group-id sqlServer \
  --connection-name "pec-$SQLSRV"
az network private-dns zone create -g "$RG" -n privatelink.database.windows.net
az network private-dns link vnet create -g "$RG" -z privatelink.database.windows.net \
  -n "link-$VNET" -v "$VNET" -e false
az network private-endpoint dns-zone-group create -g "$RG" --endpoint-name "pe-$SQLSRV" \
  -n default --private-dns-zone privatelink.database.windows.net --zone-name sql
az sql server update -g "$RG" -n "$SQLSRV" --enable-public-network false

az sql db show -g "$RG" -s "$SQLSRV" -n appdb --query "{tier:sku.tier, status:status}" -o table
