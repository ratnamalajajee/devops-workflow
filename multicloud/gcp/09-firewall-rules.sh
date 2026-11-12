#!/usr/bin/env bash
# Multi-cloud runbook - step 09 - GCP: Firewall rules by tag and service account
# Replaces AWS: Security Groups   |   Page: /multicloud/#security-groups
# Run from the multicloud folder:  bash run-step.sh gcp 09
# Set your values once in gcp/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/gcp}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
# SSH only through Identity-Aware Proxy (no public IPs needed)
gcloud compute firewall-rules create fw-allow-iap-ssh --network="$NETWORK" \
  --direction=INGRESS --action=ALLOW --rules=tcp:22 \
  --source-ranges=35.235.240.0/20 --target-tags=ssh

# Google load balancer health checks and proxies to web servers
gcloud compute firewall-rules create fw-allow-lb-health --network="$NETWORK" \
  --direction=INGRESS --action=ALLOW --rules=tcp:80,tcp:443 \
  --source-ranges=130.211.0.0/22,35.191.0.0/16 --target-tags=web

# East-west traffic inside the VPC (VMs, nodes, pods)
gcloud compute firewall-rules create fw-allow-internal --network="$NETWORK" \
  --direction=INGRESS --action=ALLOW --rules=tcp,udp,icmp \
  --source-ranges=10.20.0.0/16,10.24.0.0/14

# Identity-based rule: app tier to VM tier on 8080
gcloud compute firewall-rules create fw-allow-app-to-vm --network="$NETWORK" \
  --direction=INGRESS --action=ALLOW --rules=tcp:8080 \
  --source-service-accounts="$SA_APP" --target-service-accounts="$SA_VM"

gcloud compute firewall-rules list --filter="network~$NETWORK"
