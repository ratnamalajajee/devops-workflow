#!/usr/bin/env bash
# NextGen runbook - step 10 - AWS: Stateless network ACL for the DB subnets
# Replaces AWS: NACL   |   Page: /multicloud/#nacl
# Run from the multicloud folder:  bash run-step.sh aws 10
# Set your values once in aws/nextgen-aws.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-aws.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/aws}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
VPC_ID=$(vpc_id)
NACL_ID=$(aws ec2 create-network-acl --vpc-id "$VPC_ID" \
  --tag-specifications "ResourceType=network-acl,Tags=[{Key=Name,Value=nacl-$PREFIX-db}]" \
  --query NetworkAcl.NetworkAclId --output text)

# Inbound: PostgreSQL from the private subnets, anything from the DB subnets
aws ec2 create-network-acl-entry --network-acl-id "$NACL_ID" --ingress --rule-number 100 \
  --protocol tcp --port-range From=5432,To=5432 --cidr-block 10.40.16.0/20 --rule-action allow
aws ec2 create-network-acl-entry --network-acl-id "$NACL_ID" --ingress --rule-number 110 \
  --protocol tcp --port-range From=5432,To=5432 --cidr-block 10.40.32.0/20 --rule-action allow
aws ec2 create-network-acl-entry --network-acl-id "$NACL_ID" --ingress --rule-number 120 \
  --protocol -1 --cidr-block 10.40.48.0/23 --rule-action allow

# Outbound: stateless, so return traffic needs the ephemeral port range
aws ec2 create-network-acl-entry --network-acl-id "$NACL_ID" --egress --rule-number 100 \
  --protocol tcp --port-range From=1024,To=65535 --cidr-block 10.40.0.0/16 --rule-action allow
aws ec2 create-network-acl-entry --network-acl-id "$NACL_ID" --egress --rule-number 110 \
  --protocol -1 --cidr-block 10.40.48.0/23 --rule-action allow

# Move the DB subnets from the default NACL to this one
for s in snet-db-a snet-db-b; do
  SUBNET=$(subnet_id $s)
  ASSOC=$(aws ec2 describe-network-acls --filters "Name=association.subnet-id,Values=$SUBNET" \
    --query "NetworkAcls[0].Associations[?SubnetId=='$SUBNET'].NetworkAclAssociationId" --output text)
  aws ec2 replace-network-acl-association --association-id "$ASSOC" --network-acl-id "$NACL_ID"
done
