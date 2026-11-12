#!/usr/bin/env bash
# NextGen runbook - step 00 - GCP: Project, billing, APIs
# Replaces AWS: Foundation   |   Page: /multicloud/#foundation
# Run from the multicloud folder:  bash run-step.sh gcp 00
# Set your values once in gcp/nextgen-gcp.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-gcp.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/gcp}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
gcloud auth login
gcloud projects create "$PROJECT_ID" --name="NextGen Dev"     # skip if it exists
gcloud billing projects link "$PROJECT_ID" --billing-account="$BILLING_ACCOUNT"
gcloud config set project "$PROJECT_ID"
gcloud config set compute/region "$REGION"
gcloud config set compute/zone "$ZONE"

gcloud services enable \
  compute.googleapis.com container.googleapis.com iam.googleapis.com \
  cloudkms.googleapis.com secretmanager.googleapis.com \
  servicenetworking.googleapis.com networkconnectivity.googleapis.com \
  dns.googleapis.com file.googleapis.com firestore.googleapis.com \
  sqladmin.googleapis.com alloydb.googleapis.com \
  cloudfunctions.googleapis.com run.googleapis.com cloudbuild.googleapis.com \
  artifactregistry.googleapis.com logging.googleapis.com monitoring.googleapis.com \
  iap.googleapis.com cloudidentity.googleapis.com
