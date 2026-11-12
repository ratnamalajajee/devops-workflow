#!/usr/bin/env bash
# NextGen runbook - step 05 - AWS: VPC
# Replaces AWS: Amazon VPC   |   Page: /multicloud/#vpc
# Run from the multicloud folder:  bash run-step.sh aws 05
# Set your values once in aws/nextgen-aws.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-aws.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/aws}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.40.0.0/16 \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=vpc-$PREFIX-$ENV},{Key=app,Value=$PREFIX}]" \
  --query Vpc.VpcId --output text)
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames '{"Value":true}'

aws ec2 describe-vpcs --vpc-ids "$VPC_ID" \
  --query "Vpcs[].{id:VpcId, cidr:CidrBlock}" --output table
