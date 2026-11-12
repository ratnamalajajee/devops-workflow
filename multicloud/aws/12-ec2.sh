#!/usr/bin/env bash
# Multi-cloud runbook - step 12 - AWS: Private Ubuntu instance with Session Manager
# Replaces AWS: Amazon EC2   |   Page: /multicloud/#ec2
# Run from the multicloud folder:  bash run-step.sh aws 12
# Set your values once in aws/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/aws}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
AMI_ID=$(aws ssm get-parameter \
  --name /aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id \
  --query Parameter.Value --output text)

cat > cloud-init.yaml <<'EOF'
#cloud-config
package_update: true
packages: [nginx]
EOF

INSTANCE_ID=$(aws ec2 run-instances --image-id "$AMI_ID" --instance-type m6i.large \
  --subnet-id "$(subnet_id snet-private-a)" --security-group-ids "$(sg_id sg-$PREFIX-web)" \
  --iam-instance-profile Name="ip-$PREFIX-ec2" --metadata-options HttpTokens=required \
  --block-device-mappings 'DeviceName=/dev/sda1,Ebs={VolumeSize=64,VolumeType=gp3,Encrypted=true}' \
  --user-data file://cloud-init.yaml \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=vm-$PREFIX-01},{Key=app,Value=$PREFIX}]" \
  --query "Instances[0].InstanceId" --output text)
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

# Private IP (ALB target in step 21) and a health check through Systems Manager
aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].PrivateIpAddress" --output text
# Wait for the SSM agent to register (1-2 minutes after boot)
until [ "$(aws ssm describe-instance-information --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
  --query "length(InstanceInformationList)" --output text)" = "1" ]; do sleep 10; done
CMD_ID=$(aws ssm send-command --instance-ids "$INSTANCE_ID" --document-name AWS-RunShellScript \
  --parameters 'commands=["systemctl is-active nginx","hostname -I"]' --query Command.CommandId --output text)
aws ssm wait command-executed --command-id "$CMD_ID" --instance-id "$INSTANCE_ID"
aws ssm get-command-invocation --command-id "$CMD_ID" --instance-id "$INSTANCE_ID" \
  --query StandardOutputContent --output text
# Interactive shell:  aws ssm start-session --target "$INSTANCE_ID"
