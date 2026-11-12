#!/usr/bin/env bash
# NextGen runbook - step 02 - Azure: User-assigned managed identities
# Replaces AWS: IAM roles   |   Page: /multicloud/#managed-identity
# Run from the multicloud folder:  bash run-step.sh azure 02
# Set your values once in azure/nextgen-azure.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-azure.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/azure}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
# User-assigned identities are reusable and outlive the resources using them
az identity create -g "$RG" -n "id-$PREFIX-aks"   # AKS control plane
az identity create -g "$RG" -n "id-$PREFIX-app"   # application pods

az identity show -g "$RG" -n "id-$PREFIX-app" \
  --query "{clientId:clientId, principalId:principalId}" -o table
az identity list -g "$RG" -o table
