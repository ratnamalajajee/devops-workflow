#!/usr/bin/env bash
# NextGen runbook - step 21 - AWS: Application Load Balancer + AWS WAF
# Replaces AWS: ALB   |   Page: /multicloud/#alb
# Run from the multicloud folder:  bash run-step.sh aws 21
# Set your values once in aws/nextgen-aws.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-aws.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/aws}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
VPC_ID=$(vpc_id)
TG_ARN=$(aws elbv2 create-target-group --name "tg-$PREFIX-web" --protocol HTTP --port 80 \
  --vpc-id "$VPC_ID" --target-type instance --health-check-path / \
  --query "TargetGroups[0].TargetGroupArn" --output text)
aws elbv2 register-targets --target-group-arn "$TG_ARN" --targets Id="$(vm_id)"

ALB_ARN=$(aws elbv2 create-load-balancer --name "alb-$PREFIX-$ENV" \
  --type application --scheme internet-facing \
  --subnets "$(subnet_id snet-public-a)" "$(subnet_id snet-public-b)" \
  --security-groups "$(sg_id sg-$PREFIX-alb)" \
  --query "LoadBalancers[0].LoadBalancerArn" --output text)
aws elbv2 wait load-balancer-available --load-balancer-arns "$ALB_ARN"
aws elbv2 create-listener --load-balancer-arn "$ALB_ARN" --protocol HTTP --port 80 \
  --default-actions Type=forward,TargetGroupArn="$TG_ARN"

# WAF: AWS managed rule groups (common + SQL injection)
cat > waf-rules.json <<'EOF'
[{"Name":"common","Priority":0,"OverrideAction":{"None":{}},
  "Statement":{"ManagedRuleGroupStatement":{"VendorName":"AWS","Name":"AWSManagedRulesCommonRuleSet"}},
  "VisibilityConfig":{"SampledRequestsEnabled":true,"CloudWatchMetricsEnabled":true,"MetricName":"common"}},
 {"Name":"sqli","Priority":1,"OverrideAction":{"None":{}},
  "Statement":{"ManagedRuleGroupStatement":{"VendorName":"AWS","Name":"AWSManagedRulesSQLiRuleSet"}},
  "VisibilityConfig":{"SampledRequestsEnabled":true,"CloudWatchMetricsEnabled":true,"MetricName":"sqli"}}]
EOF
WACL_ARN=$(aws wafv2 create-web-acl --name "waf-$PREFIX-$ENV" --scope REGIONAL \
  --default-action Allow={} --rules file://waf-rules.json \
  --visibility-config SampledRequestsEnabled=true,CloudWatchMetricsEnabled=true,MetricName="waf-$PREFIX" \
  --query Summary.ARN --output text)
aws wafv2 associate-web-acl --web-acl-arn "$WACL_ARN" --resource-arn "$ALB_ARN"

# HTTPS: request a certificate now, add the 443 listener after DNS validation (step 23)
CERT_ARN=$(aws acm request-certificate --domain-name "app.$DOMAIN" --validation-method DNS \
  --query CertificateArn --output text)
# aws elbv2 create-listener --load-balancer-arn "$ALB_ARN" --protocol HTTPS --port 443 \
#   --certificates CertificateArn="$CERT_ARN" --default-actions Type=forward,TargetGroupArn="$TG_ARN"

aws elbv2 describe-target-health --target-group-arn "$TG_ARN" --output table
curl -I "http://$(aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN" \
  --query 'LoadBalancers[0].DNSName' --output text)"
