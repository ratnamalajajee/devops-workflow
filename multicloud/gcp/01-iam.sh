#!/usr/bin/env bash
# Multi-cloud runbook - step 01 - GCP: Google group + IAM role bindings
# Replaces AWS: IAM   |   Page: /multicloud/#iam
# Run from the multicloud folder:  bash run-step.sh gcp 01
# Set your values once in gcp/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/gcp}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
# Group in Cloud Identity (or create it in admin.google.com)
gcloud identity groups create "platform-admins@$ORG_DOMAIN" \
  --organization="$ORG_DOMAIN" --display-name="Platform Admins"
gcloud identity groups memberships add \
  --group-email="platform-admins@$ORG_DOMAIN" --member-email="jane.doe@$ORG_DOMAIN"

# Bind roles on the project
for role in roles/container.admin roles/compute.networkAdmin roles/iam.serviceAccountUser; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="group:platform-admins@$ORG_DOMAIN" --role="$role"
done

# Optional least-privilege custom role
gcloud iam roles create shopnowVmOperator --project="$PROJECT_ID" \
  --title="ShopNow VM Operator" --stage=GA \
  --permissions=compute.instances.get,compute.instances.list,compute.instances.start,compute.instances.stop,compute.instances.reset

gcloud projects get-iam-policy "$PROJECT_ID" \
  --flatten="bindings[].members" --format="table(bindings.role, bindings.members)"
