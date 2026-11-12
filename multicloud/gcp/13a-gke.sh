#!/usr/bin/env bash
# NextGen runbook - step 13 - GCP: GKE Standard: regional, private nodes, Workload Identity
# Replaces AWS: Amazon EKS   |   Page: /multicloud/#eks
# Run from the multicloud folder:  bash run-step.sh gcp 13
# Set your values once in gcp/nextgen-gcp.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-gcp.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/gcp}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
gcloud container clusters create "$GKE" \
  --region="$REGION" --release-channel=regular \
  --network="$NETWORK" --subnetwork=snet-gke \
  --enable-ip-alias \
  --cluster-secondary-range-name=pods --services-secondary-range-name=services \
  --enable-private-nodes \
  --enable-master-authorized-networks --master-authorized-networks="$MY_IP/32" \
  --workload-pool="$PROJECT_ID.svc.id.goog" \
  --service-account="$SA_GKE" \
  --machine-type=e2-standard-4 --num-nodes=1 \
  --enable-autoscaling --min-nodes=1 --max-nodes=3 \
  --enable-shielded-nodes --shielded-secure-boot \
  --logging=SYSTEM,WORKLOAD --monitoring=SYSTEM

gcloud container clusters get-credentials "$GKE" --region="$REGION"
kubectl get nodes -o wide
