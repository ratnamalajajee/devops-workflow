#!/usr/bin/env bash
# Multi-cloud runbook - step 12 - Azure: Ubuntu VM in snet-vm
# Replaces AWS: Amazon EC2   |   Page: /multicloud/#ec2
# Run from the multicloud folder:  bash run-step.sh azure 12
# Set your values once in azure/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/azure}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
cat > cloud-init.yaml <<'EOF'
#cloud-config
package_update: true
packages: [nginx]
EOF

az vm create -g "$RG" -n "vm-$PREFIX-01" \
  --image Ubuntu2404 --size Standard_D2s_v5 --zone 1 \
  --vnet-name "$VNET" --subnet snet-vm \
  --public-ip-address "" --nsg "" --asgs "asg-$PREFIX-web" \
  --admin-username azureuser --generate-ssh-keys \
  --assign-identity --os-disk-size-gb 64 \
  --custom-data cloud-init.yaml

# Private IP (backend for step 21) and a quick health check
az vm show -d -g "$RG" -n "vm-$PREFIX-01" --query privateIps -o tsv
az vm run-command invoke -g "$RG" -n "vm-$PREFIX-01" --command-id RunShellScript \
  --scripts "systemctl is-active nginx; hostname -I"
