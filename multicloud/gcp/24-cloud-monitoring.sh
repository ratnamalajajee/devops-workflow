#!/usr/bin/env bash
# Multi-cloud runbook - step 24 - GCP: Notification channel, alert policy, log metric, Ops Agent
# Replaces AWS: CloudWatch   |   Page: /multicloud/#cloudwatch
# Run from the multicloud folder:  bash run-step.sh gcp 24
# Set your values once in gcp/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/gcp}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
# Who gets notified
gcloud beta monitoring channels create --display-name="SRE on-call" \
  --type=email --channel-labels=email_address=sre-team@example.com
CHANNEL=$(gcloud beta monitoring channels list \
  --filter='displayName="SRE on-call"' --format="value(name)")

# Alert: VM CPU above 80% for 5 minutes (unquoted EOF so $CHANNEL expands)
cat > cpu-policy.json <<EOF
{
  "displayName": "VM CPU above 80%",
  "combiner": "OR",
  "conditions": [{
    "displayName": "CPU utilization",
    "conditionThreshold": {
      "filter": "resource.type=\"gce_instance\" AND metric.type=\"compute.googleapis.com/instance/cpu/utilization\"",
      "comparison": "COMPARISON_GT",
      "thresholdValue": 0.8,
      "duration": "300s",
      "aggregations": [{ "alignmentPeriod": "60s", "perSeriesAligner": "ALIGN_MEAN" }]
    }
  }],
  "notificationChannels": ["$CHANNEL"]
}
EOF
gcloud monitoring policies create --policy-from-file=cpu-policy.json

# Log-based metric: 5xx responses at the load balancer
gcloud logging metrics create lb-5xx --description="5xx at the external LB" \
  --log-filter='resource.type="http_load_balancer" AND httpRequest.status>=500'

# Ops Agent on the VM
gcloud compute ssh "vm-$PREFIX-01" --zone="$ZONE" --tunnel-through-iap --command \
  "curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh && sudo bash add-google-cloud-ops-agent-repo.sh --also-install"

# Logs Insights equivalent
gcloud logging read 'severity>=ERROR' --freshness=1h --limit=20
