#!/usr/bin/env bash
# NextGen runbook - step 13 - AWS: EKS cluster, managed node group, Pod Identity
# Replaces AWS: Amazon EKS   |   Page: /multicloud/#eks
# Run from the multicloud folder:  bash run-step.sh aws 13
# Set your values once in aws/nextgen-aws.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-aws.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/aws}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
kubectl create namespace app
kubectl create serviceaccount app-sa -n app

aws eks create-pod-identity-association --cluster-name "$EKS" \
  --namespace app --service-account app-sa \
  --role-arn "arn:aws:iam::$ACCOUNT_ID:role/role-$PREFIX-app"
