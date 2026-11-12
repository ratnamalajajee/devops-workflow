#!/usr/bin/env bash
# Multi-cloud runbook - step 20 - AWS: Aurora PostgreSQL cluster, writer + reader
# Replaces AWS: Aurora   |   Page: /multicloud/#aurora
# Run from the multicloud folder:  bash run-step.sh aws 20
# Set your values once in aws/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/aws}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
PG_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "$PREFIX/$ENV/db-password" \
  --query SecretString --output text)

# Add --engine-version to pin (list: aws rds describe-db-engine-versions --engine aurora-postgresql)
aws rds create-db-cluster --db-cluster-identifier "aurora-$PREFIX-$ENV" \
  --engine aurora-postgresql \
  --master-username pgadmin --master-user-password "$PG_PASSWORD" \
  --db-subnet-group-name "dbsg-$PREFIX-$ENV" --vpc-security-group-ids "$(sg_id sg-$PREFIX-db)" \
  --storage-encrypted --kms-key-id "alias/$PREFIX-data" \
  --backup-retention-period 14 --deletion-protection

# Instance 1 becomes the writer, instance 2 a reader in another AZ
for i in 1 2; do
  aws rds create-db-instance --db-instance-identifier "aurora-$PREFIX-$ENV-$i" \
    --db-cluster-identifier "aurora-$PREFIX-$ENV" --engine aurora-postgresql \
    --db-instance-class db.r6g.large
done
aws rds wait db-instance-available --db-instance-identifier "aurora-$PREFIX-$ENV-2"

aws rds describe-db-clusters --db-cluster-identifier "aurora-$PREFIX-$ENV" \
  --query "DBClusters[0].{writer:Endpoint, reader:ReaderEndpoint}" --output table
