#!/usr/bin/env bash
# Multi-cloud runbook - step 13 - GCP: GKE Standard: regional, private nodes, Workload Identity
# Replaces AWS: Amazon EKS   |   Page: /multicloud/#eks
# Run from the multicloud folder:  bash run-step.sh gcp 13
# Set your values once in gcp/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/gcp}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
kubectl create namespace app
kubectl create serviceaccount app-sa -n app

gcloud iam service-accounts add-iam-policy-binding "$SA_APP" \
  --role=roles/iam.workloadIdentityUser \
  --member="serviceAccount:$PROJECT_ID.svc.id.goog[app/app-sa]"

kubectl annotate serviceaccount app-sa -n app \
  iam.gke.io/gcp-service-account="$SA_APP"
