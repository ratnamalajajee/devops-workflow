#!/usr/bin/env bash
# Multi-cloud runbook - step 01 - Azure: Entra ID group + RBAC role assignment
# Replaces AWS: IAM   |   Page: /multicloud/#iam
# Run from the multicloud folder:  bash run-step.sh azure 01
# Set your values once in azure/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/azure}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
# Group for platform engineers (IAM group)
az ad group create --display-name "grp-$PREFIX-platform-admins" \
  --mail-nickname "grp-$PREFIX-platform-admins"
GROUP_ID=$(az ad group show --group "grp-$PREFIX-platform-admins" --query id -o tsv)

# Add a member (use a real user principal name from your tenant)
USER_ID=$(az ad user show --id "jane.doe@contoso.com" --query id -o tsv)
az ad group member add --group "$GROUP_ID" --member-id "$USER_ID"

# Grant a role on the resource group (attach a policy)
RG_ID=$(az group show -n "$RG" --query id -o tsv)
az role assignment create --assignee-object-id "$GROUP_ID" \
  --assignee-principal-type Group --role "Contributor" --scope "$RG_ID"

# Optional least-privilege custom role
cat > vm-operator.json <<EOF
{
  "Name": "ShopNow VM Operator",
  "Description": "Start, stop and restart VMs only",
  "Actions": [
    "Microsoft.Compute/virtualMachines/read",
    "Microsoft.Compute/virtualMachines/start/action",
    "Microsoft.Compute/virtualMachines/powerOff/action",
    "Microsoft.Compute/virtualMachines/restart/action"
  ],
  "AssignableScopes": ["/subscriptions/$SUB_ID"]
}
EOF
az role definition create --role-definition @vm-operator.json

az role assignment list --resource-group "$RG" -o table
