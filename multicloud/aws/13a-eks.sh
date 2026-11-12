#!/usr/bin/env bash
# Multi-cloud runbook - step 13 - AWS: EKS cluster, managed node group, Pod Identity
# Replaces AWS: Amazon EKS   |   Page: /multicloud/#eks
# Run from the multicloud folder:  bash run-step.sh aws 13
# Set your values once in aws/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/aws}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
CLUSTER_ROLE_ARN=$(aws iam get-role --role-name "role-$PREFIX-eks-cluster" --query Role.Arn --output text)
NODE_ROLE_ARN=$(aws iam get-role --role-name "role-$PREFIX-eks-node" --query Role.Arn --output text)
SUB_A=$(subnet_id snet-private-a); SUB_B=$(subnet_id snet-private-b)

aws eks create-cluster --name "$EKS" --role-arn "$CLUSTER_ROLE_ARN" \
  --resources-vpc-config "subnetIds=$SUB_A,$SUB_B,endpointPublicAccess=true,endpointPrivateAccess=true,publicAccessCidrs=$MY_IP/32" \
  --access-config authenticationMode=API \
  --logging '{"clusterLogging":[{"types":["api","audit","authenticator"],"enabled":true}]}'
aws eks wait cluster-active --name "$EKS"

aws eks create-nodegroup --cluster-name "$EKS" --nodegroup-name ng-default \
  --node-role "$NODE_ROLE_ARN" --subnets "$SUB_A" "$SUB_B" \
  --instance-types m6i.xlarge --scaling-config minSize=3,maxSize=6,desiredSize=3
aws eks create-addon --cluster-name "$EKS" --addon-name eks-pod-identity-agent
aws eks wait nodegroup-active --cluster-name "$EKS" --nodegroup-name ng-default

# Cluster admin for the team's IAM role (replace PlatformAdmins)
aws eks create-access-entry --cluster-name "$EKS" \
  --principal-arn "arn:aws:iam::$ACCOUNT_ID:role/PlatformAdmins"
aws eks associate-access-policy --cluster-name "$EKS" \
  --principal-arn "arn:aws:iam::$ACCOUNT_ID:role/PlatformAdmins" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster

aws eks update-kubeconfig --name "$EKS"
kubectl get nodes -o wide
