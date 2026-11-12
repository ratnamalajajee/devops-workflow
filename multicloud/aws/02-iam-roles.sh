#!/usr/bin/env bash
# Multi-cloud runbook - step 02 - AWS: IAM roles for EC2, EKS, Lambda and pods
# Replaces AWS: IAM roles   |   Page: /multicloud/#managed-identity
# Run from the multicloud folder:  bash run-step.sh aws 02
# Set your values once in aws/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/aws}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
# Trust policies: who may assume each role
for svc in ec2 lambda eks; do
  cat > "trust-$svc.json" <<EOF
{"Version":"2012-10-17","Statement":[{"Effect":"Allow",
  "Principal":{"Service":"$svc.amazonaws.com"},"Action":"sts:AssumeRole"}]}
EOF
done
cat > trust-pods.json <<'EOF'
{"Version":"2012-10-17","Statement":[{"Effect":"Allow",
  "Principal":{"Service":"pods.eks.amazonaws.com"},"Action":["sts:AssumeRole","sts:TagSession"]}]}
EOF

# VM identity: role + instance profile
aws iam create-role --role-name "role-$PREFIX-ec2" --assume-role-policy-document file://trust-ec2.json
for p in AmazonSSMManagedInstanceCore CloudWatchAgentServerPolicy; do
  aws iam attach-role-policy --role-name "role-$PREFIX-ec2" --policy-arn "arn:aws:iam::aws:policy/$p"
done
aws iam create-instance-profile --instance-profile-name "ip-$PREFIX-ec2"
aws iam add-role-to-instance-profile --instance-profile-name "ip-$PREFIX-ec2" --role-name "role-$PREFIX-ec2"

# EKS node and cluster roles
aws iam create-role --role-name "role-$PREFIX-eks-node" --assume-role-policy-document file://trust-ec2.json
for p in AmazonEKSWorkerNodePolicy AmazonEKS_CNI_Policy AmazonEC2ContainerRegistryReadOnly; do
  aws iam attach-role-policy --role-name "role-$PREFIX-eks-node" --policy-arn "arn:aws:iam::aws:policy/$p"
done
aws iam create-role --role-name "role-$PREFIX-eks-cluster" --assume-role-policy-document file://trust-eks.json
aws iam attach-role-policy --role-name "role-$PREFIX-eks-cluster" \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy

# Lambda execution role and the pod role for the app
aws iam create-role --role-name "role-$PREFIX-lambda" --assume-role-policy-document file://trust-lambda.json
aws iam attach-role-policy --role-name "role-$PREFIX-lambda" \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole
aws iam create-role --role-name "role-$PREFIX-app" --assume-role-policy-document file://trust-pods.json

aws iam list-roles --query "Roles[?starts_with(RoleName, 'role-$PREFIX')].RoleName" --output table
