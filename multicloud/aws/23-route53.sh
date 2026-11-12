#!/usr/bin/env bash
# NextGen runbook - step 23 - AWS: Public hosted zone with alias record + private zone
# Replaces AWS: Route 53   |   Page: /multicloud/#route53
# Run from the multicloud folder:  bash run-step.sh aws 23
# Set your values once in aws/nextgen-aws.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-aws.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/aws}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
ZONE_ID=$(aws route53 create-hosted-zone --name "$DOMAIN" --caller-reference "pub-$(date +%s)" \
  --query HostedZone.Id --output text)
aws route53 get-hosted-zone --id "$ZONE_ID" --query DelegationSet.NameServers --output text   # set at the registrar

# Alias A record to the ALB, plus a CNAME
read -r ALB_DNS ALB_ZONE <<< "$(aws elbv2 describe-load-balancers --names "alb-$PREFIX-$ENV" \
  --query 'LoadBalancers[0].[DNSName,CanonicalHostedZoneId]' --output text)"
cat > records.json <<EOF
{"Changes":[
 {"Action":"UPSERT","ResourceRecordSet":{"Name":"app.$DOMAIN","Type":"A",
   "AliasTarget":{"HostedZoneId":"$ALB_ZONE","DNSName":"$ALB_DNS","EvaluateTargetHealth":true}}},
 {"Action":"UPSERT","ResourceRecordSet":{"Name":"www.$DOMAIN","Type":"CNAME","TTL":300,
   "ResourceRecords":[{"Value":"app.$DOMAIN"}]}}]}
EOF
aws route53 change-resource-record-sets --hosted-zone-id "$ZONE_ID" --change-batch file://records.json

# Private hosted zone visible only inside the VPC
aws route53 create-hosted-zone --name "internal.$DOMAIN" --caller-reference "priv-$(date +%s)" \
  --vpc VPCRegion="$AWS_REGION",VPCId="$(vpc_id)" --hosted-zone-config PrivateZone=true

NS1=$(aws route53 get-hosted-zone --id "$ZONE_ID" --query "DelegationSet.NameServers[0]" --output text)
dig +short "app.$DOMAIN" @"$NS1"
