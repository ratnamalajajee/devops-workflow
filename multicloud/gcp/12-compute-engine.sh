#!/usr/bin/env bash
# NextGen runbook - step 12 - GCP: Shielded Ubuntu VM in snet-vm
# Replaces AWS: Amazon EC2   |   Page: /multicloud/#ec2
# Run from the multicloud folder:  bash run-step.sh gcp 12
# Set your values once in gcp/nextgen-gcp.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-gcp.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/gcp}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
cat > startup.sh <<'EOF'
#!/bin/bash
apt-get update && apt-get install -y nginx
EOF

gcloud compute instances create "vm-$PREFIX-01" \
  --zone="$ZONE" --machine-type=e2-standard-2 \
  --subnet=snet-vm --no-address \
  --image-family=ubuntu-2404-lts-amd64 --image-project=ubuntu-os-cloud \
  --boot-disk-size=50GB --boot-disk-type=pd-balanced \
  --tags=ssh,web \
  --service-account="$SA_VM" --scopes=cloud-platform \
  --shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring \
  --metadata-from-file=startup-script=startup.sh

gcloud compute instances describe "vm-$PREFIX-01" --zone="$ZONE" \
  --format="value(networkInterfaces[0].networkIP)"
gcloud compute ssh "vm-$PREFIX-01" --zone="$ZONE" --tunnel-through-iap \
  --command="systemctl is-active nginx"
