#!/usr/bin/env bash
# Multi-cloud runbook - step 22 - Azure: AGIC add-on + sample app
# Replaces AWS: ALB Ingress Controller   |   Page: /multicloud/#alb-ingress
# Run from the multicloud folder:  bash run-step.sh azure 22
# Set your values once in azure/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/azure}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
APPGW_ID=$(az network application-gateway show -g "$RG" -n "$APPGW" --query id -o tsv)
az aks enable-addons -g "$RG" -n "$AKS" --addons ingress-appgw --appgw-id "$APPGW_ID"

# Add-on identity needs rights on a gateway and subnet it didn't create
AGIC_OBJ=$(az aks show -g "$RG" -n "$AKS" \
  --query addonProfiles.ingressApplicationGateway.identity.objectId -o tsv)
APPGW_SUBNET_ID=$(az network vnet subnet show -g "$RG" --vnet-name "$VNET" -n snet-appgw --query id -o tsv)
RG_ID=$(az group show -n "$RG" --query id -o tsv)
az role assignment create --assignee-object-id "$AGIC_OBJ" --assignee-principal-type ServicePrincipal \
  --role "Contributor" --scope "$APPGW_ID"
az role assignment create --assignee-object-id "$AGIC_OBJ" --assignee-principal-type ServicePrincipal \
  --role "Network Contributor" --scope "$APPGW_SUBNET_ID"
az role assignment create --assignee-object-id "$AGIC_OBJ" --assignee-principal-type ServicePrincipal \
  --role "Reader" --scope "$RG_ID"

kubectl get deployment ingress-appgw-deployment -n kube-system
