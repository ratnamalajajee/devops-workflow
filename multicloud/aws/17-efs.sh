#!/usr/bin/env bash
# NextGen runbook - step 17 - AWS: EFS file system with mount targets in both AZs
# Replaces AWS: Amazon EFS   |   Page: /multicloud/#efs
# Run from the multicloud folder:  bash run-step.sh aws 17
# Set your values once in aws/nextgen-aws.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-aws.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/aws}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
EFS_SG=$(aws ec2 create-security-group --group-name "sg-$PREFIX-efs" --description "NextGen EFS" \
  --vpc-id "$(vpc_id)" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id "$EFS_SG" --protocol tcp --port 2049 --cidr 10.40.0.0/16

FS_ID=$(aws efs create-file-system --performance-mode generalPurpose --throughput-mode elastic \
  --encrypted --kms-key-id "alias/$PREFIX-data" \
  --tags Key=Name,Value="fs-$PREFIX-$ENV" --query FileSystemId --output text)
# Wait until LifeCycleState is "available" (under a minute)
aws efs describe-file-systems --file-system-id "$FS_ID" --query "FileSystems[0].LifeCycleState"

for s in snet-private-a snet-private-b; do
  aws efs create-mount-target --file-system-id "$FS_ID" \
    --subnet-id "$(subnet_id $s)" --security-groups "$EFS_SG"
done

# Mount on the instance once the mount targets are available
cat > mount-efs.json <<EOF
{"commands":["apt-get install -y nfs-common","mkdir -p /mnt/shared",
  "mount -t nfs4 -o nfsvers=4.1 $FS_ID.efs.$AWS_REGION.amazonaws.com:/ /mnt/shared","df -h /mnt/shared"]}
EOF
aws ssm send-command --instance-ids "$(vm_id)" --document-name AWS-RunShellScript \
  --parameters file://mount-efs.json
