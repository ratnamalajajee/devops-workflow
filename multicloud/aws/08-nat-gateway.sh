#!/usr/bin/env bash
# Multi-cloud runbook - step 08 - AWS: NAT gateway + private route table
# Replaces AWS: NAT Gateway   |   Page: /multicloud/#nat-gateway
# Run from the multicloud folder:  bash run-step.sh aws 08
# Set your values once in aws/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/aws}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
VPC_ID=$(vpc_id)
EIP_ALLOC=$(aws ec2 allocate-address --domain vpc \
  --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=eip-$PREFIX-natgw}]" \
  --query AllocationId --output text)
NAT_ID=$(aws ec2 create-nat-gateway --subnet-id "$(subnet_id snet-public-a)" \
  --allocation-id "$EIP_ALLOC" \
  --tag-specifications "ResourceType=natgateway,Tags=[{Key=Name,Value=natgw-$PREFIX-$ENV}]" \
  --query NatGateway.NatGatewayId --output text)
aws ec2 wait nat-gateway-available --nat-gateway-ids "$NAT_ID"

RT_PRIVATE=$(aws ec2 create-route-table --vpc-id "$VPC_ID" \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=rt-$PREFIX-private}]" \
  --query RouteTable.RouteTableId --output text)
aws ec2 create-route --route-table-id "$RT_PRIVATE" \
  --destination-cidr-block 0.0.0.0/0 --nat-gateway-id "$NAT_ID"
for s in snet-private-a snet-private-b snet-db-a snet-db-b; do
  aws ec2 associate-route-table --route-table-id "$RT_PRIVATE" --subnet-id "$(subnet_id $s)"
done

# The egress IP to allow-list
aws ec2 describe-addresses --allocation-ids "$EIP_ALLOC" --query "Addresses[0].PublicIp" --output text
