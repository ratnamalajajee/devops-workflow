#!/usr/bin/env bash
# Multi-cloud runbook - step 06 - AWS: Public, private and DB subnets in two AZs
# Replaces AWS: Subnets   |   Page: /multicloud/#subnets
# Run from the multicloud folder:  bash run-step.sh aws 06
# Set your values once in aws/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/aws}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
VPC_ID=$(vpc_id)
while read -r name cidr az; do
  aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block "$cidr" --availability-zone "$az" \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$name},{Key=app,Value=$PREFIX}]" \
    --query Subnet.SubnetId --output text
done <<EOF
snet-public-a  10.40.0.0/24  $AZ1
snet-public-b  10.40.1.0/24  $AZ2
snet-private-a 10.40.16.0/20 $AZ1
snet-private-b 10.40.32.0/20 $AZ2
snet-db-a      10.40.48.0/24 $AZ1
snet-db-b      10.40.49.0/24 $AZ2
EOF

# Tags the AWS Load Balancer Controller uses to pick subnets (step 22)
aws ec2 create-tags --resources "$(subnet_id snet-public-a)" "$(subnet_id snet-public-b)" \
  --tags Key=kubernetes.io/role/elb,Value=1
aws ec2 create-tags --resources "$(subnet_id snet-private-a)" "$(subnet_id snet-private-b)" \
  --tags Key=kubernetes.io/role/internal-elb,Value=1

# DB subnet group for RDS and Aurora (steps 19-20)
aws rds create-db-subnet-group --db-subnet-group-name "dbsg-$PREFIX-$ENV" \
  --db-subnet-group-description "ShopNow databases" \
  --subnet-ids "$(subnet_id snet-db-a)" "$(subnet_id snet-db-b)"

aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "Subnets[].{name:Tags[?Key=='Name']|[0].Value, cidr:CidrBlock, az:AvailabilityZone}" --output table
