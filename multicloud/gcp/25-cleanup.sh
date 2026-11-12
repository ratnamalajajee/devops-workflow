#!/usr/bin/env bash
# Multi-cloud runbook - step 25 - GCP: Project (30-day recovery window)
# Replaces AWS: Clean up   |   Page: /multicloud/#cleanup
# Run from the multicloud folder:  bash run-step.sh gcp 25
# Set your values once in gcp/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/gcp}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
gcloud sql instances patch "sql-$PREFIX-$ENV" --no-deletion-protection
gcloud projects delete "$PROJECT_ID"

gcloud identity groups delete "platform-admins@$ORG_DOMAIN"
