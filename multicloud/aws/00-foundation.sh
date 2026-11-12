#!/usr/bin/env bash
# NextGen runbook - step 00 - AWS: Account, region, profile, tags
# Replaces AWS: Foundation   |   Page: /multicloud/#foundation
# Run from the multicloud folder:  bash run-step.sh aws 00
# Set your values once in aws/nextgen-aws.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-aws.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/aws}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
aws configure sso --profile nextgen-dev     # one time
aws sso login --profile nextgen-dev
aws sts get-caller-identity

# Tag-based resource group (closest thing to an Azure resource group)
aws resource-groups create-group --name "rg-$PREFIX-$ENV" \
  --resource-query '{"Type":"TAG_FILTERS_1_0","Query":"{\"ResourceTypeFilters\":[\"AWS::AllSupported\"],\"TagFilters\":[{\"Key\":\"app\",\"Values\":[\"nextgen\"]}]}"}'

# Platform log group (counterpart of the Log Analytics workspace)
aws logs create-log-group --log-group-name "/$PREFIX/$ENV/platform"
aws logs put-retention-policy --log-group-name "/$PREFIX/$ENV/platform" --retention-in-days 30
