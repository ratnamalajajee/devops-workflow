#!/usr/bin/env bash
# Multi-cloud runbook - step 25 - AWS: Delete in reverse dependency order
# Replaces AWS: Clean up   |   Page: /multicloud/#cleanup
# Run from the multicloud folder:  bash run-step.sh aws 25
# Set your values once in aws/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/aws}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
# Kubernetes first: the Ingress owns an ALB
kubectl delete ingress web -n app
helm uninstall aws-load-balancer-controller -n kube-system
aws eks delete-nodegroup --cluster-name "$EKS" --nodegroup-name ng-default
aws eks wait nodegroup-deleted --cluster-name "$EKS" --nodegroup-name ng-default
aws eks delete-cluster --name "$EKS"

# Databases (turn off deletion protection first)
for i in 1 2; do aws rds delete-db-instance --db-instance-identifier "aurora-$PREFIX-$ENV-$i"; done
aws rds modify-db-cluster --db-cluster-identifier "aurora-$PREFIX-$ENV" --no-deletion-protection --apply-immediately
aws rds delete-db-cluster --db-cluster-identifier "aurora-$PREFIX-$ENV" --skip-final-snapshot
aws rds modify-db-instance --db-instance-identifier "rds-$PREFIX-$ENV" --no-deletion-protection --apply-immediately
aws rds delete-db-instance --db-instance-identifier "rds-$PREFIX-$ENV" --skip-final-snapshot
aws dynamodb update-table --table-name "$PREFIX-$ENV-items" --no-deletion-protection-enabled
aws dynamodb delete-table --table-name "$PREFIX-$ENV-items"

# Compute and load balancing
aws elbv2 delete-load-balancer --load-balancer-arn "$(aws elbv2 describe-load-balancers \
  --names "alb-$PREFIX-$ENV" --query 'LoadBalancers[0].LoadBalancerArn' --output text)"
aws lambda delete-function --function-name "fn-$PREFIX-hello"
aws ec2 terminate-instances --instance-ids "$(vm_id)"

# Then by hand or with Terraform: EFS, buckets (delete all versions), NAT gateway,
# Elastic IP, transit gateway, subnets, route tables, IGW, security groups, VPC.
aws kms schedule-key-deletion --pending-window-in-days 7 \
  --key-id "$(aws kms describe-key --key-id "alias/$PREFIX-data" --query KeyMetadata.KeyId --output text)"
