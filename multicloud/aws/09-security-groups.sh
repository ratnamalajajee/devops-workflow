#!/usr/bin/env bash
# Multi-cloud runbook - step 09 - AWS: Security groups that reference each other
# Replaces AWS: Security Groups   |   Page: /multicloud/#security-groups
# Run from the multicloud folder:  bash run-step.sh aws 09
# Set your values once in aws/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/aws}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
VPC_ID=$(vpc_id)
for g in alb web db; do
  aws ec2 create-security-group --group-name "sg-$PREFIX-$g" --description "ShopNow $g" \
    --vpc-id "$VPC_ID" --query GroupId --output text
done

aws ec2 authorize-security-group-ingress --group-id "$(sg_id sg-$PREFIX-alb)" \
  --ip-permissions 'IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges=[{CidrIp=0.0.0.0/0}]' \
                   'IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges=[{CidrIp=0.0.0.0/0}]'

# Security group referencing another (Azure: ASG, GCP: service account)
aws ec2 authorize-security-group-ingress --group-id "$(sg_id sg-$PREFIX-web)" \
  --protocol tcp --port 80 --source-group "$(sg_id sg-$PREFIX-alb)"

aws ec2 authorize-security-group-ingress --group-id "$(sg_id sg-$PREFIX-db)" \
  --protocol tcp --port 5432 --source-group "$(sg_id sg-$PREFIX-web)"
for cidr in 10.40.16.0/20 10.40.32.0/20; do
  aws ec2 authorize-security-group-ingress --group-id "$(sg_id sg-$PREFIX-db)" \
    --protocol tcp --port 5432 --cidr "$cidr"
done

aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "SecurityGroups[].{name:GroupName, id:GroupId}" --output table
