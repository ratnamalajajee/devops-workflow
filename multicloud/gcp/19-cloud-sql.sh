#!/usr/bin/env bash
# Multi-cloud runbook - step 19 - GCP: Cloud SQL for PostgreSQL, private IP, regional HA
# Replaces AWS: Amazon RDS   |   Page: /multicloud/#rds
# Run from the multicloud folder:  bash run-step.sh gcp 19
# Set your values once in gcp/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/gcp}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
gcloud sql instances create "sql-$PREFIX-$ENV" \
  --database-version=POSTGRES_16 --edition=ENTERPRISE \
  --tier=db-custom-2-8192 --region="$REGION" --availability-type=REGIONAL \
  --storage-type=SSD --storage-size=100GB --storage-auto-increase \
  --network="projects/$PROJECT_ID/global/networks/$NETWORK" --no-assign-ip \
  --backup-start-time=02:00 --enable-point-in-time-recovery \
  --deletion-protection

gcloud sql users set-password postgres --instance="sql-$PREFIX-$ENV" \
  --password="$(gcloud secrets versions access latest --secret=db-password)"
gcloud sql databases create appdb --instance="sql-$PREFIX-$ENV"

gcloud sql instances describe "sql-$PREFIX-$ENV" \
  --format="value(ipAddresses[0].ipAddress, state)"
