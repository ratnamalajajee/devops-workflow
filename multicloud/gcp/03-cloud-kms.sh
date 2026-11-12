#!/usr/bin/env bash
# NextGen runbook - step 03 - GCP: Key ring + HSM key with rotation
# Replaces AWS: KMS   |   Page: /multicloud/#kms
# Run from the multicloud folder:  bash run-step.sh gcp 03
# Set your values once in gcp/nextgen-gcp.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-gcp.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/gcp}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
gcloud kms keyrings create "kr-$PREFIX-$ENV" --location="$REGION"

gcloud kms keys create "key-$PREFIX-data" \
  --keyring="kr-$PREFIX-$ENV" --location="$REGION" \
  --purpose=encryption --protection-level=hsm \
  --rotation-period=90d \
  --next-rotation-time="$(date -u -d '+90 days' +%Y-%m-%dT%H:%M:%SZ)"

# Round-trip test
echo -n "hello nextgen" > plain.txt
gcloud kms encrypt --key="key-$PREFIX-data" --keyring="kr-$PREFIX-$ENV" --location="$REGION" \
  --plaintext-file=plain.txt --ciphertext-file=cipher.bin
gcloud kms decrypt --key="key-$PREFIX-data" --keyring="kr-$PREFIX-$ENV" --location="$REGION" \
  --ciphertext-file=cipher.bin --plaintext-file=-

# Let the app service account use the key
gcloud kms keys add-iam-policy-binding "key-$PREFIX-data" \
  --keyring="kr-$PREFIX-$ENV" --location="$REGION" \
  --member="serviceAccount:$SA_APP" --role=roles/cloudkms.cryptoKeyEncrypterDecrypter
