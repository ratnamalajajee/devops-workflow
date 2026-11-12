#!/usr/bin/env bash
# NextGen runbook - step 21 - GCP: Global external Application LB + managed cert + Cloud Armor
# Replaces AWS: ALB   |   Page: /multicloud/#alb
# Run from the multicloud folder:  bash run-step.sh gcp 21
# Set your values once in gcp/nextgen-gcp.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-gcp.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/gcp}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
# Backend: unmanaged instance group with the VM
gcloud compute instance-groups unmanaged create "ig-$PREFIX-web" --zone="$ZONE"
gcloud compute instance-groups unmanaged add-instances "ig-$PREFIX-web" --zone="$ZONE" \
  --instances="vm-$PREFIX-01"
gcloud compute instance-groups unmanaged set-named-ports "ig-$PREFIX-web" --zone="$ZONE" \
  --named-ports=http:80

gcloud compute health-checks create http "hc-$PREFIX-http" --port=80 --request-path=/
gcloud compute backend-services create "bes-$PREFIX-web" --global \
  --load-balancing-scheme=EXTERNAL_MANAGED --protocol=HTTP --port-name=http \
  --health-checks="hc-$PREFIX-http" --enable-logging
gcloud compute backend-services add-backend "bes-$PREFIX-web" --global \
  --instance-group="ig-$PREFIX-web" --instance-group-zone="$ZONE"

# Frontend: URL map -> HTTP proxy -> forwarding rule on the IP from step 07
gcloud compute url-maps create "um-$PREFIX-web" --default-service="bes-$PREFIX-web"
gcloud compute target-http-proxies create "thp-$PREFIX-web" --url-map="um-$PREFIX-web"
gcloud compute forwarding-rules create "fr-$PREFIX-http" --global \
  --load-balancing-scheme=EXTERNAL_MANAGED --address="ip-$PREFIX-lb" \
  --target-http-proxy="thp-$PREFIX-web" --ports=80

# WAF: Cloud Armor preconfigured rules
gcloud compute security-policies create "armor-$PREFIX-$ENV" --description="NextGen WAF"
gcloud compute security-policies rules create 1000 --security-policy="armor-$PREFIX-$ENV" \
  --expression="evaluatePreconfiguredWaf('sqli-v33-stable')" --action=deny-403
gcloud compute security-policies rules create 1001 --security-policy="armor-$PREFIX-$ENV" \
  --expression="evaluatePreconfiguredWaf('xss-v33-stable')" --action=deny-403
gcloud compute backend-services update "bes-$PREFIX-web" --global \
  --security-policy="armor-$PREFIX-$ENV"

# HTTPS after step 23 points app.$DOMAIN at the IP
gcloud compute ssl-certificates create "cert-$PREFIX-app" --domains="app.$DOMAIN" --global
gcloud compute target-https-proxies create "thps-$PREFIX-web" \
  --url-map="um-$PREFIX-web" --ssl-certificates="cert-$PREFIX-app"
gcloud compute forwarding-rules create "fr-$PREFIX-https" --global \
  --load-balancing-scheme=EXTERNAL_MANAGED --address="ip-$PREFIX-lb" \
  --target-https-proxy="thps-$PREFIX-web" --ports=443

curl -I "http://$(gcloud compute addresses describe "ip-$PREFIX-lb" --global --format='value(address)')"
