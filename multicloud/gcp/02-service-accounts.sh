#!/usr/bin/env bash
# Multi-cloud runbook - step 02 - GCP: Service accounts with least-privilege roles
# Replaces AWS: IAM roles   |   Page: /multicloud/#managed-identity
# Run from the multicloud folder:  bash run-step.sh gcp 02
# Set your values once in gcp/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/gcp}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
for sa in vm gke fn app; do
  gcloud iam service-accounts create "sa-$PREFIX-$sa" --display-name="ShopNow $sa"
done

# GKE node service account
for role in roles/logging.logWriter roles/monitoring.metricWriter roles/monitoring.viewer \
            roles/stackdriver.resourceMetadata.writer roles/artifactregistry.reader; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SA_GKE" --role="$role"
done

# VM and function service accounts only write logs and metrics
for sa in "$SA_VM" "$SA_FN"; do
  for role in roles/logging.logWriter roles/monitoring.metricWriter; do
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
      --member="serviceAccount:$sa" --role="$role"
  done
done

gcloud iam service-accounts list
