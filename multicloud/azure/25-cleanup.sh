#!/usr/bin/env bash
# NextGen runbook - step 25 - Azure: Resource group + tenant-level objects
# Replaces AWS: Clean up   |   Page: /multicloud/#cleanup
# Run from the multicloud folder:  bash run-step.sh azure 25
# Set your values once in azure/nextgen-azure.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-azure.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/azure}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
az group delete -n "$RG" --yes --no-wait

az ad group delete --group "grp-$PREFIX-platform-admins"
az role definition delete --name "NextGen VM Operator"

# Purge protection keeps the vault name reserved for the retention period
az keyvault list-deleted -o table
