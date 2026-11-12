#!/usr/bin/env bash
# NextGen runbook - step 13 - Azure: AKS: Azure CNI Overlay, NAT egress, Entra ID + Azure RBAC
# Replaces AWS: Amazon EKS   |   Page: /multicloud/#eks
# Run from the multicloud folder:  bash run-step.sh azure 13
# Set your values once in azure/nextgen-azure.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-azure.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/azure}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
APP_CLIENT_ID=$(az identity show -g "$RG" -n "id-$PREFIX-app" --query clientId -o tsv)
AKS_OIDC=$(az aks show -g "$RG" -n "$AKS" --query oidcIssuerProfile.issuerUrl -o tsv)

az identity federated-credential create -g "$RG" --identity-name "id-$PREFIX-app" \
  -n fic-app-sa --issuer "$AKS_OIDC" \
  --subject system:serviceaccount:app:app-sa --audiences api://AzureADTokenExchange

kubectl create namespace app
kubectl create serviceaccount app-sa -n app
kubectl annotate serviceaccount app-sa -n app \
  azure.workload.identity/client-id="$APP_CLIENT_ID"
# Pods opt in with the label  azure.workload.identity/use: "true"
