#!/usr/bin/env bash
# Multi-cloud runbook - step 19 - AWS: RDS for PostgreSQL, Multi-AZ, private
# Replaces AWS: Amazon RDS   |   Page: /multicloud/#rds
# Run from the multicloud folder:  bash run-step.sh aws 19
# Set your values once in aws/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/aws}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
PG_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "$PREFIX/$ENV/db-password" \
  --query SecretString --output text)

aws rds create-db-instance --db-instance-identifier "rds-$PREFIX-$ENV" \
  --engine postgres --engine-version 16 --db-instance-class db.m6g.large \
  --allocated-storage 128 --max-allocated-storage 512 --storage-type gp3 \
  --multi-az --db-subnet-group-name "dbsg-$PREFIX-$ENV" \
  --vpc-security-group-ids "$(sg_id sg-$PREFIX-db)" --no-publicly-accessible \
  --master-username pgadmin --master-user-password "$PG_PASSWORD" \
  --db-name appdb --backup-retention-period 14 \
  --storage-encrypted --kms-key-id "alias/$PREFIX-data" --deletion-protection
aws rds wait db-instance-available --db-instance-identifier "rds-$PREFIX-$ENV"

aws rds describe-db-instances --db-instance-identifier "rds-$PREFIX-$ENV" \
  --query "DBInstances[0].{endpoint:Endpoint.Address, status:DBInstanceStatus, multiAZ:MultiAZ}" --output table
