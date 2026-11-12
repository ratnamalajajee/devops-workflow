#!/usr/bin/env bash
# NextGen runbook - step 16 - AWS: gp3 volume, attach, mount, snapshot
# Replaces AWS: Amazon EBS   |   Page: /multicloud/#ebs
# Run from the multicloud folder:  bash run-step.sh aws 16
# Set your values once in aws/nextgen-aws.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-aws.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/aws}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
INSTANCE_ID=$(vm_id)
VOL_ID=$(aws ec2 create-volume --availability-zone "$AZ1" --size 128 --volume-type gp3 \
  --encrypted --kms-key-id "alias/$PREFIX-data" \
  --tag-specifications "ResourceType=volume,Tags=[{Key=Name,Value=disk-$PREFIX-data01}]" \
  --query VolumeId --output text)
aws ec2 wait volume-available --volume-ids "$VOL_ID"
aws ec2 attach-volume --volume-id "$VOL_ID" --instance-id "$INSTANCE_ID" --device /dev/sdf

# On Nitro the NVMe serial is the volume ID without the dash
DEV="/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_${VOL_ID/-/}"
cat > mount.json <<EOF
{"commands":["mkfs.ext4 -F $DEV","mkdir -p /data","mount $DEV /data","df -h /data"]}
EOF
aws ssm send-command --instance-ids "$INSTANCE_ID" --document-name AWS-RunShellScript \
  --parameters file://mount.json

aws ec2 create-snapshot --volume-id "$VOL_ID" --description "disk-$PREFIX-data01" \
  --tag-specifications "ResourceType=snapshot,Tags=[{Key=Name,Value=snap-$PREFIX-data01}]"
