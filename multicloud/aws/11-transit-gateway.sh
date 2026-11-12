#!/usr/bin/env bash
# Multi-cloud runbook - step 11 - AWS: Transit gateway + VPC attachment
# Replaces AWS: Transit Gateway   |   Page: /multicloud/#transit-gateway
# Run from the multicloud folder:  bash run-step.sh aws 11
# Set your values once in aws/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/aws}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
TGW_ID=$(aws ec2 create-transit-gateway --description "ShopNow transit hub" \
  --options AmazonSideAsn=64512,DefaultRouteTableAssociation=enable,DefaultRouteTablePropagation=enable \
  --tag-specifications "ResourceType=transit-gateway,Tags=[{Key=Name,Value=tgw-$PREFIX}]" \
  --query TransitGateway.TransitGatewayId --output text)
# Wait until State is "available" (a few minutes)
aws ec2 describe-transit-gateways --transit-gateway-ids "$TGW_ID" --query "TransitGateways[0].State"

aws ec2 create-transit-gateway-vpc-attachment --transit-gateway-id "$TGW_ID" \
  --vpc-id "$(vpc_id)" --subnet-ids "$(subnet_id snet-private-a)" "$(subnet_id snet-private-b)" \
  --tag-specifications "ResourceType=transit-gateway-attachment,Tags=[{Key=Name,Value=tgwa-$PREFIX-$ENV}]"

# Send traffic for another network through the hub
RT_PRIVATE=$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=rt-$PREFIX-private" \
  --query "RouteTables[0].RouteTableId" --output text)
aws ec2 create-route --route-table-id "$RT_PRIVATE" \
  --destination-cidr-block 10.50.0.0/16 --transit-gateway-id "$TGW_ID"

aws ec2 describe-transit-gateway-attachments \
  --filters "Name=transit-gateway-id,Values=$TGW_ID" --output table
