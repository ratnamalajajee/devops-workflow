#!/usr/bin/env bash
# Multi-cloud runbook - step 07 - AWS: Internet gateway + public route table
# Replaces AWS: Internet Gateway   |   Page: /multicloud/#internet-gateway
# Run from the multicloud folder:  bash run-step.sh aws 07
# Set your values once in aws/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/aws}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
VPC_ID=$(vpc_id)
IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=igw-$PREFIX-$ENV}]" \
  --query InternetGateway.InternetGatewayId --output text)
aws ec2 attach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"

RT_PUBLIC=$(aws ec2 create-route-table --vpc-id "$VPC_ID" \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=rt-$PREFIX-public}]" \
  --query RouteTable.RouteTableId --output text)
aws ec2 create-route --route-table-id "$RT_PUBLIC" \
  --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID"
for s in snet-public-a snet-public-b; do
  aws ec2 associate-route-table --route-table-id "$RT_PUBLIC" --subnet-id "$(subnet_id $s)"
done

aws ec2 describe-route-tables --route-table-ids "$RT_PUBLIC" \
  --query "RouteTables[0].Routes" --output table
