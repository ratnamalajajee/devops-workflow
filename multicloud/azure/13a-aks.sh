#!/usr/bin/env bash
# Multi-cloud runbook - step 13 - Azure: AKS: Azure CNI Overlay, NAT egress, Entra ID + Azure RBAC
# Replaces AWS: Amazon EKS   |   Page: /multicloud/#eks
# Run from the multicloud folder:  bash run-step.sh azure 13
# Set your values once in azure/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/azure}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
LAW_ID=$(az monitor log-analytics workspace show -g "$RG" -n "$LAW" --query id -o tsv)
VNET_ID=$(az network vnet show -g "$RG" -n "$VNET" --query id -o tsv)
AKS_SUBNET_ID=$(az network vnet subnet show -g "$RG" --vnet-name "$VNET" -n snet-aks --query id -o tsv)
AKS_MI_ID=$(az identity show -g "$RG" -n "id-$PREFIX-aks" --query id -o tsv)
AKS_MI_PRINCIPAL=$(az identity show -g "$RG" -n "id-$PREFIX-aks" --query principalId -o tsv)

# Control-plane identity manages the BYO subnet and NAT gateway
az role assignment create --assignee-object-id "$AKS_MI_PRINCIPAL" \
  --assignee-principal-type ServicePrincipal --role "Network Contributor" --scope "$VNET_ID"

az aks create -g "$RG" -n "$AKS" -l "$LOCATION" --tier standard \
  --node-count 3 --node-vm-size Standard_D4s_v5 --zones 1 2 3 \
  --enable-cluster-autoscaler --min-count 3 --max-count 6 \
  --network-plugin azure --network-plugin-mode overlay --pod-cidr 192.168.0.0/16 \
  --vnet-subnet-id "$AKS_SUBNET_ID" --outbound-type userAssignedNATGateway \
  --assign-identity "$AKS_MI_ID" \
  --enable-aad --enable-azure-rbac \
  --enable-oidc-issuer --enable-workload-identity \
  --enable-addons monitoring,azure-keyvault-secrets-provider \
  --workspace-resource-id "$LAW_ID" \
  --api-server-authorized-ip-ranges "$MY_IP/32" \
  --generate-ssh-keys

# Cluster-admin for the platform group, then connect
GROUP_ID=$(az ad group show --group "grp-$PREFIX-platform-admins" --query id -o tsv)
AKS_ID=$(az aks show -g "$RG" -n "$AKS" --query id -o tsv)
az role assignment create --assignee-object-id "$GROUP_ID" --assignee-principal-type Group \
  --role "Azure Kubernetes Service RBAC Cluster Admin" --scope "$AKS_ID"

az aks get-credentials -g "$RG" -n "$AKS"
kubectl get nodes -o wide
