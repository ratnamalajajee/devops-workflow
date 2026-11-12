#!/usr/bin/env bash
# NextGen runbook - step 23 - GCP: Public zone with DNSSEC + private zone
# Replaces AWS: Route 53   |   Page: /multicloud/#route53
# Run from the multicloud folder:  bash run-step.sh gcp 23
# Set your values once in gcp/nextgen-gcp.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-gcp.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/gcp}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
gcloud dns managed-zones create "zone-$PREFIX-public" \
  --dns-name="$DOMAIN." --description="NextGen public zone" \
  --visibility=public --dnssec-state=on
gcloud dns managed-zones describe "zone-$PREFIX-public" --format="value(nameServers)"   # set at the registrar

LB_IP=$(gcloud compute addresses describe "ip-$PREFIX-lb" --global --format="value(address)")
GKE_IP=$(gcloud compute addresses describe "ip-$PREFIX-gke" --global --format="value(address)")
gcloud dns record-sets create "app.$DOMAIN." --zone="zone-$PREFIX-public" --type=A --ttl=300 --rrdatas="$LB_IP"
gcloud dns record-sets create "k8s.$DOMAIN." --zone="zone-$PREFIX-public" --type=A --ttl=300 --rrdatas="$GKE_IP"
gcloud dns record-sets create "www.$DOMAIN." --zone="zone-$PREFIX-public" --type=CNAME --ttl=300 --rrdatas="app.$DOMAIN."

# Private zone visible only inside the VPC
gcloud dns managed-zones create "zone-$PREFIX-private" \
  --dns-name="internal.$DOMAIN." --description="NextGen private zone" \
  --visibility=private --networks="$NETWORK"

gcloud dns record-sets list --zone="zone-$PREFIX-public"
