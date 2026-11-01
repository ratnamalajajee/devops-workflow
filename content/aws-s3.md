# Amazon S3: Object Storage

Amazon S3 (Simple Storage Service) stores files, which S3 calls **objects**, in containers called **buckets**, with practically unlimited space and very high durability. DevOps teams use it for backups, logs, build artifacts, Terraform state, static websites and data lakes. This guide covers buckets, uploads, storage classes, versioning, security, encryption, sharing, website hosting and costs.

> **Cost:** Small experiments cost cents. Standard storage is about **$0.023 per GB-month** in us-east-1, plus small per-request charges and data transfer **out** to the internet. See [S3 pricing](https://aws.amazon.com/s3/pricing/), and delete test buckets at the end.

## Start here: S3 in simple words

> **In simple words:** S3 is like **Google Drive for applications**. You create a **bucket** (a top-level folder with a globally unique name) and put **objects** (files) in it. Programs read and write them over HTTPS.

### A real-life comparison

Think of a **huge self-storage warehouse**:

| Warehouse | S3 |
|---|---|
| Your rented unit, with a unique number | A **bucket**, with a globally unique name |
| A labelled box in the unit | An **object** (any file, up to 5 TB) |
| The label on the box | The **key**, such as `logs/2026/11/app.log` |
| The warehouse's guarantee not to lose boxes | **Durability**: 99.999999999% ("11 nines") |
| Cheaper storage in the basement, slower to fetch | **Storage classes** such as Glacier |
| The unit's access list | **Bucket policy** and IAM permissions |

### Key words

| Word | Simple meaning |
|---|---|
| **Bucket** | A container for objects. Names are unique across *all* AWS accounts worldwide |
| **Object** | A file plus its metadata (content type, tags…) |
| **Key** | The object's full name inside the bucket. `logs/app.log` looks like a folder path, but S3 has no real folders, just names with `/` in them |
| **Prefix** | The start of a key, such as `logs/`, used like a folder |
| **Region** | Where the bucket's data lives |
| **Storage class** | Price and speed tier: Standard, Infrequent Access, Glacier… |
| **Versioning** | Keeps every old version of an object, so deletes and overwrites can be undone |
| **Bucket policy** | Rules attached to the bucket itself about who can do what |

### Check yourself

1. Can two AWS accounts have a bucket with the same name?
2. Is `photos/2026/beach.jpg` stored in real folders?
3. What does versioning protect you from?

> **Tip:** Answers: 1) No, bucket names are globally unique. 2) No, it's one object whose key contains slashes. 3) Accidental deletes and overwrites, because old versions are kept.

## Create a bucket and upload files

> **In simple words:** Make a bucket in your Region, then copy files in and out of it, much like `cp` on Linux.

```bash
export AWS_REGION=us-east-1
BUCKET=devops-s3-lab-$(aws sts get-caller-identity --query Account --output text)-$RANDOM
aws s3 mb s3://$BUCKET --region $AWS_REGION
aws s3 ls                                   # all your buckets
```

Bucket names: 3–63 characters, lowercase letters, numbers, `-` and `.`, globally unique.

```bash
echo "hello s3" > hello.txt
mkdir -p site && echo "<h1>Hi</h1>" > site/index.html

aws s3 cp hello.txt s3://$BUCKET/                     # upload one file
aws s3 cp hello.txt s3://$BUCKET/notes/hello.txt      # "folder" = key prefix
aws s3 sync ./site s3://$BUCKET/site/                 # upload changed files only
aws s3 ls s3://$BUCKET/ --recursive --human-readable --summarize

aws s3 cp s3://$BUCKET/hello.txt ./downloaded.txt     # download
aws s3 mv s3://$BUCKET/hello.txt s3://$BUCKET/archive/hello.txt
aws s3 rm s3://$BUCKET/notes/hello.txt
aws s3 rm s3://$BUCKET/site/ --recursive              # delete a whole prefix

aws s3api head-object --bucket $BUCKET --key archive/hello.txt   # size, type, encryption, version
```

| Command family | Use it for |
|---|---|
| `aws s3 …` (high level) | Everyday copy, sync, list, remove |
| `aws s3api …` (low level) | Every S3 setting: versioning, policies, encryption, lifecycle |

> **Tip:** `aws s3 sync --delete` also removes files from the bucket that no longer exist locally. That's great for deploying a static site, and dangerous if you point it at the wrong folder. Try `--dryrun` first.

AWS docs: [What is Amazon S3?](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html)

## Storage classes and lifecycle rules

> **In simple words:** Data you rarely read can live in cheaper "basement" storage. **Lifecycle rules** move it there automatically, and can delete it when it's no longer needed.

| Storage class | Good for | Retrieval |
|---|---|---|
| **S3 Standard** | Frequently used data | Instant |
| **S3 Intelligent-Tiering** | Unknown or changing access patterns: S3 moves objects between tiers for you | Instant (for the frequent and infrequent tiers) |
| **S3 Standard-IA** | Read rarely, but needed quickly (backups) | Instant, with a per-GB retrieval fee |
| **S3 One Zone-IA** | Re-creatable data stored in one AZ only | Instant |
| **S3 Glacier Instant Retrieval** | Archives read about once a quarter | Instant |
| **S3 Glacier Flexible Retrieval** | Archives | Minutes to hours |
| **S3 Glacier Deep Archive** | Long-term compliance archives | Within hours (cheapest) |

Upload straight into a class with `aws s3 cp big.log s3://$BUCKET/logs/ --storage-class STANDARD_IA`.

A lifecycle rule for logs: move them to Standard-IA after 30 days, to Glacier after 90, delete after 365, and clean up unfinished uploads. Save as `lifecycle.json`:

```json
{
  "Rules": [
    {
      "ID": "logs-tiering",
      "Status": "Enabled",
      "Filter": { "Prefix": "logs/" },
      "Transitions": [
        { "Days": 30, "StorageClass": "STANDARD_IA" },
        { "Days": 90, "StorageClass": "GLACIER" }
      ],
      "Expiration": { "Days": 365 }
    },
    {
      "ID": "abort-incomplete-uploads",
      "Status": "Enabled",
      "Filter": {},
      "AbortIncompleteMultipartUpload": { "DaysAfterInitiation": 7 }
    }
  ]
}
```

```bash
aws s3api put-bucket-lifecycle-configuration --bucket $BUCKET --lifecycle-configuration file://lifecycle.json
aws s3api get-bucket-lifecycle-configuration --bucket $BUCKET
```

AWS docs: [Storage classes](https://docs.aws.amazon.com/AmazonS3/latest/userguide/storage-class-intro.html) · [Managing the lifecycle of objects](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html)

## Versioning: undo deletes and overwrites

> **In simple words:** With versioning on, S3 keeps every version of an object. Deleting only adds a "delete marker", so the file can be brought back.

```bash
aws s3api put-bucket-versioning --bucket $BUCKET --versioning-configuration Status=Enabled

echo "version 1" > config.txt && aws s3 cp config.txt s3://$BUCKET/config.txt
echo "version 2" > config.txt && aws s3 cp config.txt s3://$BUCKET/config.txt
aws s3 rm s3://$BUCKET/config.txt                       # "deleted"…

aws s3api list-object-versions --bucket $BUCKET --prefix config.txt \
  --query '{Versions:Versions[].[VersionId,IsLatest,LastModified],DeleteMarkers:DeleteMarkers[].[VersionId,IsLatest]}'

# Restore: delete the delete marker
MARKER=$(aws s3api list-object-versions --bucket $BUCKET --prefix config.txt \
  --query 'DeleteMarkers[?IsLatest].VersionId' --output text)
aws s3api delete-object --bucket $BUCKET --key config.txt --version-id $MARKER
aws s3 cp s3://$BUCKET/config.txt - # prints "version 2"

# Fetch an older version
aws s3api get-object --bucket $BUCKET --key config.txt --version-id <OLD_VERSION_ID> old.txt
```

- Old versions cost storage. Add a lifecycle rule with `NoncurrentVersionExpiration` (for example after 30 days).
- **S3 Object Lock** goes further: objects can't be deleted or changed for a set time (WORM), which helps against ransomware and for compliance.

> **Note:** Terraform state buckets should **always** have versioning on (see the Terraform guide).

AWS docs: [S3 Versioning](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html)

## Security: Block Public Access and bucket policies

> **In simple words:** New buckets are **private** by default. **Block Public Access** is a master switch that stops anyone making data public by mistake. **Bucket policies** decide exactly who else can read or write.

Defaults for new buckets today:
- **Block Public Access**: all four settings on.
- **Object Ownership: Bucket owner enforced.** ACLs (the old permission system) are disabled, so permissions come only from IAM and bucket policies.
- **Default encryption: SSE-S3**, so every object is encrypted at rest.

Check them:

```bash
aws s3api get-public-access-block --bucket $BUCKET
aws s3api get-bucket-ownership-controls --bucket $BUCKET
aws s3control get-public-access-block --account-id $(aws sts get-caller-identity --query Account --output text)   # account-wide switch
```

### Who can access what

| Mechanism | Attached to | Use for |
|---|---|---|
| **IAM policy** | A user, group or role | "This role may read bucket X" (same account) |
| **Bucket policy** | The bucket | Other accounts, AWS services, or rules for *everyone* (such as "HTTPS only") |

Bucket policy example: deny any request not using HTTPS, and let a role from **another account** read objects. Save as `bucket-policy.json`, replacing `BUCKET_NAME`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyInsecureTransport",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": ["arn:aws:s3:::BUCKET_NAME", "arn:aws:s3:::BUCKET_NAME/*"],
      "Condition": { "Bool": { "aws:SecureTransport": "false" } }
    },
    {
      "Sid": "PartnerReadOnly",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::444455556666:role/partner-reader" },
      "Action": ["s3:GetObject"],
      "Resource": "arn:aws:s3:::BUCKET_NAME/*"
    }
  ]
}
```

```bash
sed -i "s/BUCKET_NAME/$BUCKET/g" bucket-policy.json
aws s3api put-bucket-policy --bucket $BUCKET --policy file://bucket-policy.json
aws s3api get-bucket-policy --bucket $BUCKET --query Policy --output text | jq .
```

AWS docs: [Blocking public access](https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html) · [Bucket policies](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucket-policies.html)

## Encryption: SSE-S3 and SSE-KMS

> **In simple words:** S3 encrypts every object automatically. Choose **SSE-KMS** when you want your own key, with its own access rules and an audit log of every use.

| Option | Who manages the key | When to use |
|---|---|---|
| **SSE-S3** (default) | AWS, invisibly | Most data |
| **SSE-KMS** | AWS KMS: your **customer managed key** | Sensitive data, separate key permissions, CloudTrail audit of key use |
| **DSSE-KMS** | KMS, two layers | Strict compliance requirements |
| **Client-side** | You, before uploading | You must never let AWS see plaintext |

Make SSE-KMS the default, with an **S3 Bucket Key** to cut KMS request costs. Create the key first in the [KMS guide](#/tool/aws-kms).

```bash
aws s3api put-bucket-encryption --bucket $BUCKET --server-side-encryption-configuration '{
  "Rules": [{
    "ApplyServerSideEncryptionByDefault": { "SSEAlgorithm": "aws:kms", "KMSMasterKeyID": "alias/app-data" },
    "BucketKeyEnabled": true
  }]
}'
aws s3 cp hello.txt s3://$BUCKET/secret/hello.txt
aws s3api head-object --bucket $BUCKET --key secret/hello.txt --query '[ServerSideEncryption,SSEKMSKeyId]'
```

With SSE-KMS, readers need **both** `s3:GetObject` on the object **and** `kms:Decrypt` on the key.

AWS docs: [Protecting data with encryption](https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingEncryption.html) · [SSE-KMS](https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingKMSEncryption.html) · [S3 Bucket Keys](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucket-key.html)

## Share files safely with presigned URLs

> **In simple words:** A presigned URL is a **temporary link** to one private object. Anyone with the link can download (or upload) it until it expires. No bucket policy changes needed.

```bash
aws s3 presign s3://$BUCKET/archive/hello.txt --expires-in 600     # valid for 10 minutes
curl -s "$(aws s3 presign s3://$BUCKET/archive/hello.txt --expires-in 60)"
```

Presigned **upload** links are created from code, for example Python with boto3:

```python
import boto3

s3 = boto3.client("s3")
url = s3.generate_presigned_url(
    "put_object",
    Params={"Bucket": "my-bucket", "Key": "uploads/report.csv"},
    ExpiresIn=900,
)
print(url)   # client uploads with: curl -X PUT --upload-file report.csv "<url>"
```

The link only works while the identity that created it still has permission, and it never lasts longer than that identity's credentials.

AWS docs: [Sharing objects with presigned URLs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/ShareObjectPreSignedURL.html)

## Host a static website

> **In simple words:** S3 can serve HTML, CSS and JS files directly as a website. That's cheap and simple, but HTTP only. For HTTPS and a custom domain, put **CloudFront** in front.

```bash
SITE=devops-site-$RANDOM-$(date +%s)
aws s3 mb s3://$SITE
cat > index.html <<'EOF'
<!doctype html><html><body style="font-family:sans-serif"><h1>Hosted on S3 🎉</h1></body></html>
EOF
echo "<h1>Not found</h1>" > error.html
aws s3 cp index.html s3://$SITE/ && aws s3 cp error.html s3://$SITE/

# 1. Allow public bucket policies on THIS bucket only
aws s3api put-public-access-block --bucket $SITE --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=false,RestrictPublicBuckets=false

# 2. Turn on website hosting
aws s3 website s3://$SITE/ --index-document index.html --error-document error.html

# 3. Public read for objects
aws s3api put-bucket-policy --bucket $SITE --policy "{
  \"Version\": \"2012-10-17\",
  \"Statement\": [{\"Sid\": \"PublicRead\", \"Effect\": \"Allow\", \"Principal\": \"*\",
                   \"Action\": \"s3:GetObject\", \"Resource\": \"arn:aws:s3:::$SITE/*\"}]
}"

echo "http://$SITE.s3-website-$AWS_REGION.amazonaws.com"
```

Open the URL. (Some Regions use `s3-website.<region>`; the exact endpoint is shown under the bucket's **Properties → Static website hosting**.)

> **Warning:** If the **account-level** Block Public Access is on (common in company accounts), step 3 fails, and that's intentional. The production pattern is a **private** bucket behind **CloudFront with Origin Access Control (OAC)**, which also gives you HTTPS and caching.

AWS docs: [Hosting a static website](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteHosting.html)

## Replication and event notifications

> **In simple words:** S3 can **copy** new objects to another bucket automatically (for disaster recovery), and can **notify** other services when objects arrive (for example, "start processing this upload").

| Feature | What it does | Typical use |
|---|---|---|
| **Cross-Region Replication (CRR)** | Copies new objects to a bucket in another Region | Disaster recovery, lower latency for far-away users |
| **Same-Region Replication (SRR)** | Copies within the Region | Log aggregation, prod → test copies |
| **Event notifications** | Sends a message to Lambda, SQS, SNS or EventBridge on create or delete | Thumbnail generation, virus scanning, data pipelines |

Replication needs **versioning on both buckets** and an IAM role that S3 assumes. Event notifications to EventBridge are the easiest to start with:

```bash
aws s3api put-bucket-notification-configuration --bucket $BUCKET \
  --notification-configuration '{"EventBridgeConfiguration": {}}'
```

AWS docs: [Replicating objects](https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication.html) · [Event notifications](https://docs.aws.amazon.com/AmazonS3/latest/userguide/EventNotifications.html)

## Troubleshooting

> **In simple words:** Most S3 problems are permissions (IAM, bucket policy, KMS key) or a wrong name, Region or key.

| Problem | Likely cause / fix |
|---|---|
| `BucketAlreadyExists` | Someone else in the world owns that name; pick another |
| `AccessDenied` on GetObject | Missing `s3:GetObject` on `bucket/*`, a bucket policy Deny, or `kms:Decrypt` missing for SSE-KMS objects |
| `AccessDenied` on put-bucket-policy (public) | Block Public Access, on the bucket or the whole account |
| `NoSuchKey` | Wrong key; keys are case-sensitive and include the full "path" |
| `PermanentRedirect` / wrong Region | Add `--region` matching the bucket's Region |
| Website shows 403 | Objects aren't publicly readable, or the index document is missing |
| `BucketNotEmpty` when deleting | Remove objects **and all versions** first (`aws s3 rb --force` handles unversioned buckets) |
| Unexpected bill | Old versions, incomplete multipart uploads, or data transfer out. Check lifecycle rules |

## Clean up

> **In simple words:** A bucket must be empty, including every old version, before it can be deleted.

```bash
# Unversioned bucket
aws s3 rb s3://$SITE --force

# Versioned bucket: delete all versions and delete markers, then the bucket
aws s3api delete-objects --bucket $BUCKET --delete "$(aws s3api list-object-versions --bucket $BUCKET \
  --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output json)" 2>/dev/null
aws s3api delete-objects --bucket $BUCKET --delete "$(aws s3api list-object-versions --bucket $BUCKET \
  --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' --output json)" 2>/dev/null
aws s3 rb s3://$BUCKET --force
```

The console's **Empty** button on a bucket does the same thing.

## Lab: a secure, cost-aware bucket

> **In simple words:** Practice time: set up a bucket the way a production team would, then prove each setting works.

1. Create bucket `app-artifacts-<name>` with **versioning** on.
2. Add a lifecycle rule: `builds/` objects go to Standard-IA after 30 days and expire after 180; old versions expire after 30 days.
3. Add a bucket policy that **denies non-HTTPS** requests. Test with `aws s3 ls s3://… --endpoint-url http://s3.amazonaws.com`, which should be denied.
4. Switch default encryption to **SSE-KMS** with your own key and a Bucket Key. Upload a file and confirm with `head-object`.
5. Delete a file, then restore it using versions.
6. Share one file with a 5-minute presigned URL and confirm it stops working afterwards.
7. Host a tiny static site in a **separate** bucket, then clean up both.

### Cheat sheet

| Task | Command |
|---|---|
| Make bucket | `aws s3 mb s3://name` |
| Upload / sync | `aws s3 cp f s3://b/` / `aws s3 sync dir s3://b/dir/` |
| List with sizes | `aws s3 ls s3://b --recursive --human-readable --summarize` |
| Versioning on | `aws s3api put-bucket-versioning --bucket b --versioning-configuration Status=Enabled` |
| Temporary link | `aws s3 presign s3://b/key --expires-in 600` |
| Bucket policy | `aws s3api put-bucket-policy --bucket b --policy file://p.json` |
| Delete bucket | `aws s3 rb s3://b --force` |
