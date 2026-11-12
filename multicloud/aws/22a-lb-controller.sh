#!/usr/bin/env bash
# Multi-cloud runbook - step 22 - AWS: AWS Load Balancer Controller (Helm) + Ingress
# Replaces AWS: ALB Ingress Controller   |   Page: /multicloud/#alb-ingress
# Run from the multicloud folder:  bash run-step.sh aws 22
# Set your values once in aws/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/aws}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
# IAM policy published with the controller (pin the URL to your controller version)
curl -sSo lbc-policy.json \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
aws iam create-policy --policy-name ShopNowLBController --policy-document file://lbc-policy.json
aws iam create-role --role-name "role-$PREFIX-lbc" --assume-role-policy-document file://trust-pods.json
aws iam attach-role-policy --role-name "role-$PREFIX-lbc" \
  --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/ShopNowLBController"
aws eks create-pod-identity-association --cluster-name "$EKS" \
  --namespace kube-system --service-account aws-load-balancer-controller \
  --role-arn "arn:aws:iam::$ACCOUNT_ID:role/role-$PREFIX-lbc"

helm repo add eks https://aws.github.io/eks-charts && helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system \
  --set clusterName="$EKS" --set region="$AWS_REGION" --set vpcId="$(vpc_id)" \
  --set serviceAccount.create=true --set serviceAccount.name=aws-load-balancer-controller
kubectl get deployment aws-load-balancer-controller -n kube-system
