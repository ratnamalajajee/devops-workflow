#!/usr/bin/env bash
# NextGen runbook - step 15 - AWS: Versioned, KMS-encrypted buckets
# Replaces AWS: Amazon S3   |   Page: /multicloud/#s3
# Run from the multicloud folder:  bash run-step.sh aws 15
# Set your values once in aws/nextgen-aws.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/nextgen-aws.env"
WORK_DIR="${WORK_DIR:-$HOME/nextgen-work/aws}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
cat > sse.json <<EOF
{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"aws:kms",
  "KMSMasterKeyID":"alias/$PREFIX-data"},"BucketKeyEnabled":true}]}
EOF
for b in "$BUCKET" "$PREFIX-$ENV-$SUFFIX-tfstate"; do
  aws s3 mb "s3://$b" --region "$AWS_REGION"
  aws s3api put-public-access-block --bucket "$b" --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
  aws s3api put-bucket-versioning --bucket "$b" --versioning-configuration Status=Enabled
  aws s3api put-bucket-encryption --bucket "$b" --server-side-encryption-configuration file://sse.json
done

echo "hello" > hello.txt
aws s3 cp hello.txt "s3://$BUCKET/"
aws s3 ls "s3://$BUCKET/"

# Lifecycle: Standard-IA after 30 days, keep 5 noncurrent versions
cat > lifecycle.json <<'EOF'
{"Rules":[{"ID":"ia-after-30d","Status":"Enabled","Filter":{},
  "Transitions":[{"Days":30,"StorageClass":"STANDARD_IA"}],
  "NoncurrentVersionExpiration":{"NoncurrentDays":30,"NewerNoncurrentVersions":5}}]}
EOF
aws s3api put-bucket-lifecycle-configuration --bucket "$BUCKET" \
  --lifecycle-configuration file://lifecycle.json
