#!/usr/bin/env bash
# Multi-cloud runbook - step 19 - Azure: PostgreSQL flexible server in snet-db
# Replaces AWS: Amazon RDS   |   Page: /multicloud/#rds
# Run from the multicloud folder:  bash run-step.sh azure 19
# Set your values once in azure/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/azure}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
PG_PASSWORD=$(az keyvault secret show --vault-name "$KV" -n db-password --query value -o tsv)

az postgres flexible-server create -g "$RG" -n "$PG" -l "$LOCATION" \
  --version 16 --tier GeneralPurpose --sku-name Standard_D2ds_v5 \
  --storage-size 128 --storage-auto-grow Enabled \
  --high-availability ZoneRedundant \
  --vnet "$VNET" --subnet snet-db \
  --private-dns-zone "$PREFIX-$ENV.private.postgres.database.azure.com" \
  --admin-user pgadmin --admin-password "$PG_PASSWORD" \
  --backup-retention 14 --yes

az postgres flexible-server db create -g "$RG" -s "$PG" -d appdb

# Connect from the VM (step 12)
az vm run-command invoke -g "$RG" -n "vm-$PREFIX-01" --command-id RunShellScript --scripts \
  "apt-get install -y postgresql-client && PGPASSWORD='$PG_PASSWORD' psql 'host=$PG.postgres.database.azure.com dbname=appdb user=pgadmin sslmode=require' -c 'select version();'"
