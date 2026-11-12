#!/usr/bin/env bash
# NextGen runbook - step 01 - AWS: IAM group + managed and custom policies
# Replaces AWS: IAM   |   Page: /multicloud/#iam
# Run from the multicloud folder:  bash run-step.sh aws 01
# Set your values once in aws/nextgen-aws.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-aws.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/aws}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
aws iam create-group --group-name "grp-$PREFIX-platform-admins"
aws iam attach-group-policy --group-name "grp-$PREFIX-platform-admins" \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess
aws iam add-user-to-group --group-name "grp-$PREFIX-platform-admins" --user-name jane.doe

# Least-privilege custom policy
cat > vm-operator.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["ec2:DescribeInstances", "ec2:StartInstances",
               "ec2:StopInstances", "ec2:RebootInstances"],
    "Resource": "*"
  }]
}
EOF
aws iam create-policy --policy-name NextGenVmOperator --policy-document file://vm-operator.json
aws iam attach-group-policy --group-name "grp-$PREFIX-platform-admins" \
  --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/NextGenVmOperator"

aws iam list-attached-group-policies --group-name "grp-$PREFIX-platform-admins"
