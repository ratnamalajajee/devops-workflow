#!/usr/bin/env bash
# NextGen runbook - step 24 - Azure: Action group, metric alert, diagnostic settings, agent
# Replaces AWS: CloudWatch   |   Page: /multicloud/#cloudwatch
# Run from the multicloud folder:  bash run-step.sh azure 24
# Set your values once in azure/nextgen-azure.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-azure.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/azure}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
LAW_ID=$(az monitor log-analytics workspace show -g "$RG" -n "$LAW" --query id -o tsv)
LAW_GUID=$(az monitor log-analytics workspace show -g "$RG" -n "$LAW" --query customerId -o tsv)
KV_ID=$(az keyvault show -n "$KV" --query id -o tsv)
VM_ID=$(az vm show -g "$RG" -n "vm-$PREFIX-01" --query id -o tsv)

# Who gets notified (SNS topic + subscription)
az monitor action-group create -g "$RG" -n "ag-$PREFIX-sre" --short-name sre \
  --action email sre-oncall sre-team@example.com

# CloudWatch alarm: CPU above 80% for 5 minutes
az monitor metrics alert create -g "$RG" -n alert-vm-cpu-high \
  --scopes "$VM_ID" --condition "avg Percentage CPU > 80" \
  --window-size 5m --evaluation-frequency 1m --severity 2 \
  --action "ag-$PREFIX-sre"

# Resource logs to Log Analytics (CloudWatch Logs)
az monitor diagnostic-settings create -n diag-kv --resource "$KV_ID" \
  --workspace "$LAW_ID" \
  --logs '[{"categoryGroup":"audit","enabled":true}]' \
  --metrics '[{"category":"AllMetrics","enabled":true}]'

# Azure Monitor Agent on the VM (CloudWatch agent); add a DCR in the portal
az vm extension set -g "$RG" --vm-name "vm-$PREFIX-01" \
  --name AzureMonitorLinuxAgent --publisher Microsoft.Azure.Monitor \
  --enable-auto-upgrade true

# Logs Insights equivalent: KQL
az monitor log-analytics query -w "$LAW_GUID" \
  --analytics-query "ContainerLogV2 | where TimeGenerated > ago(1h) | take 20" -o table
