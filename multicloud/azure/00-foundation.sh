#!/usr/bin/env bash
# NextGen runbook - step 00 - Azure: Subscription, resource group, Log Analytics workspace
# Replaces AWS: Foundation   |   Page: /multicloud/#foundation
# Run from the multicloud folder:  bash run-step.sh azure 00
# Set your values once in azure/nextgen-azure.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-azure.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/azure}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
az login
az account set --subscription "$SUB_ID"
az account show -o table

az group create -n "$RG" -l "$LOCATION" --tags env=$ENV app=$PREFIX owner=sre

for ns in Microsoft.Network Microsoft.Compute Microsoft.ContainerService \
          Microsoft.Storage Microsoft.KeyVault Microsoft.ManagedIdentity \
          Microsoft.DBforPostgreSQL Microsoft.Sql Microsoft.DocumentDB \
          Microsoft.Web Microsoft.App Microsoft.OperationalInsights Microsoft.Insights; do
  az provider register --namespace "$ns"
done

az monitor log-analytics workspace create -g "$RG" -n "$LAW" -l "$LOCATION" --retention-time 30
az monitor log-analytics workspace show -g "$RG" -n "$LAW" --query id -o tsv
