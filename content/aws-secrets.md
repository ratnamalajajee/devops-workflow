# AWS Secrets Manager: Store, Share and Rotate Secrets

AWS Secrets Manager keeps passwords, API keys, tokens and certificates **encrypted in one safe place**, so they never live in your code, Git, images or config files. Your apps fetch them at run time with their IAM role, every read is logged, and Secrets Manager can **change (rotate) passwords automatically**. This guide creates and reads secrets, explains versions, encryption and permissions, turns on rotation and replication, and connects secrets to ECS, Lambda, EC2 and Kubernetes.

> **Cost:** Each secret costs **$0.40 per month** (prorated by the hour) plus **$0.05 per 10,000 API calls** (us-east-1). Each **replica** in another Region is billed as a separate secret, and secrets scheduled for deletion are free. The AWS managed key `aws/secretsmanager` is free; a customer managed KMS key adds about $1 per month. New accounts can use AWS Free Tier credits. See [Secrets Manager pricing](https://aws.amazon.com/secrets-manager/pricing/) and [KMS pricing](https://aws.amazon.com/kms/pricing/).

## Start here: Secrets Manager in simple words

> **In simple words:** A **secret** is any value that would let someone in if it leaked: a database password, an API key, a private key. Secrets Manager is a **locker** for those values. Your app shows its ID badge (its IAM role), the locker checks the list of who may open it, hands over the value, and writes the visit in a logbook.

### Why not just put it in the code?

```compare
❌ Hard-coded secret | ✅ Secret in Secrets Manager
Anyone who can read the repo can read the password | Only IAM roles you allow can read it
It stays in Git history forever, even after you delete it | Nothing secret is ever committed
Changing it means a code change and a redeploy | Change it in one place; apps pick it up
The same value is copied to many places | One source of truth, with versions
No record of who used it | Every read is logged in CloudTrail
Rotating it is manual, so it rarely happens | Rotation can run on a schedule
```

### The bank locker comparison

| Bank locker | Secrets Manager |
|---|---|
| A locker with your valuables inside | A **secret** (one value, or a small JSON document) |
| The locker's number and label | The secret **name** (`my-app/dev/db`) and its **ARN** |
| The list of people allowed to open it | **IAM policies** and the secret's **resource policy** |
| The bank's master lock | **AWS KMS** encryption key |
| Replacing the contents and keeping the last one | **Versions** with labels `AWSCURRENT` and `AWSPREVIOUS` |
| The bank changing the lock code every month | **Rotation** |
| A copy of the locker in another city | **Replication** to another Region |
| The visitor logbook | **CloudTrail** |

### Key words

| Word | Simple meaning |
|---|---|
| **Secret** | The stored item: name, description, encryption key, tags and one or more versions of the value |
| **Secret value** | The actual text (or binary) inside, up to **64 KB** (65,536 bytes) |
| **Key/value secret** | A value stored as JSON, such as `{"username":"app","password":"..."}` |
| **Version** | One saved copy of the value. Changing the value creates a new version |
| **Staging label** | A sticker on a version: `AWSCURRENT` (in use), `AWSPREVIOUS` (last one), `AWSPENDING` (being rotated) |
| **Rotation** | Replacing the value on a schedule, and also changing it where it's used (for example in the database) |
| **Resource policy** | A permission document attached to the secret itself, used mainly for **cross-account** access |
| **Replica** | A read-only copy of the secret in another Region, kept in sync automatically |
| **Recovery window** | 7 to 30 days after you delete a secret during which you can still restore it |

### How an app gets a secret

```flow
🪪 | App asks with its role | The app (or ECS, Lambda, a pod) calls GetSecretValue using its IAM role.
🛂 | Permission check | Secrets Manager checks the IAM policy, the secret's resource policy and any SCPs.
🔑 | Decrypt with KMS | Secrets Manager asks KMS to decrypt the value. The caller needs permission on that key too.
📦 | Value returned | The plain value goes back over TLS. The app keeps it in memory, never on disk or in logs.
📝 | Logged | CloudTrail records who read which secret, and when.
```

### Check yourself

1. Why is deleting a password from your code not enough after it was committed to Git?
2. Which label marks the version that apps read by default?
3. What two permissions does an app need to read a secret encrypted with your own KMS key?

> **Tip:** Answers: 1) It's still in the Git history, so anyone with the repo can find it. Rotate the password. 2) `AWSCURRENT`. 3) `secretsmanager:GetSecretValue` on the secret and `kms:Decrypt` on the key.

## Secrets Manager or Parameter Store?

> **In simple words:** AWS has two places to keep values. **Systems Manager Parameter Store** is a free, simple shelf for settings (and it can encrypt values too). **Secrets Manager** costs a little, but adds rotation, cross-account sharing with a policy, and replication. Use Parameter Store for config, Secrets Manager for real secrets.

```compare
🔐 Secrets Manager | 🗂️ Parameter Store
Built for secrets: passwords, API keys, certificates | Built for config; secrets go in a SecureString parameter
Built-in rotation (managed, or with a Lambda function) | No built-in rotation
$0.40 per secret per month, plus API calls | Standard parameters are free; advanced cost $0.05 per month
Up to 64 KB per secret | 4 KB (standard) or 8 KB (advanced)
Other accounts can read it through a resource policy | Only advanced parameters can be shared, with AWS RAM
Built-in replication to other Regions | No built-in replication
```

| | Secrets Manager | Parameter Store |
|---|---|---|
| Encryption | Always encrypted with KMS | Optional: `String` is plain text, `SecureString` uses KMS |
| Max items per Region | 500,000 secrets | 10,000 standard, 100,000 advanced parameters |
| Versions | Versions with staging labels | Version history and labels |
| Password generator | Yes (`get-random-password`) | No |
| ECS, Lambda, EKS support | Yes | Yes |
| Typical use | DB passwords, third-party API keys, tokens | Feature flags, URLs, AMI IDs, non-secret settings |

**Use both together:** Parameter Store can read a Secrets Manager secret through a special path, so code that already uses Parameter Store doesn't need to change:

```bash
aws ssm get-parameter --name /aws/reference/secretsmanager/my-app/dev/db \
  --with-decryption --query Parameter.Value --output text
```

AWS docs: [Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html) · [Systems Manager pricing](https://aws.amazon.com/systems-manager/pricing/) · [Referencing secrets from Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/integration-ps-secretsmanager.html) · More in the [Systems Manager guide](#/tool/aws-ssm)

## Step 1: Create a secret

> **In simple words:** Create two secrets: a **plaintext** API key (one value) and a **key/value** database login (a small JSON document). Pick names with a clear pattern, because names drive permissions later.

**Console:** **Secrets Manager** → **Store a new secret** → **Secret type: Other type of secret** → in **Key/value pairs**, add `username` and `password` rows (or choose the **Plaintext** tab for a single value) → **Encryption key:** keep `aws/secretsmanager` → **Next** → **Secret name** `my-app/dev/db`, a description → **Next** → leave rotation off → **Next** → **Store**.

For an RDS, Aurora, Redshift or DocumentDB login, the console also offers a database **Secret type** that adds the host, port and engine for you. For the **admin (master) user** of RDS, Aurora and Redshift, AWS recommends letting the database service create the secret instead (see Step 6).

**CLI:** set your variables once, then create both secrets. The values come from a hidden prompt and the built-in password generator, so they never appear in your shell history.

```bash
export AWS_REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# 1) plaintext secret: one value
read -rsp "Paste the API key: " API_KEY; echo
aws secretsmanager create-secret --name my-app/dev/api-key \
  --description "Partner API key for my-app (dev)" \
  --secret-string "$API_KEY" \
  --tags Key=app,Value=my-app Key=env,Value=dev
unset API_KEY

# 2) key/value secret: a JSON document with a generated password
DB_PASS=$(aws secretsmanager get-random-password --password-length 32 \
  --exclude-punctuation --query RandomPassword --output text)

cat > db-secret.json <<EOF
{"engine":"postgres","host":"db.example.com","port":5432,"username":"app_user","password":"$DB_PASS","dbname":"appdb"}
EOF

aws secretsmanager create-secret --name my-app/dev/db \
  --description "Database login for my-app (dev)" \
  --secret-string file://db-secret.json \
  --tags Key=app,Value=my-app Key=env,Value=dev

rm -f db-secret.json; unset DB_PASS

DB_SECRET_ARN=$(aws secretsmanager describe-secret --secret-id my-app/dev/db --query ARN --output text)
echo "$DB_SECRET_ARN"
```

The ARN ends with a **hyphen and 6 random characters**, for example `...:secret:my-app/dev/db-AbCdEf`. If you delete a secret and create a new one with the same name, it gets a different suffix.

### Naming tips

| Rule | Example |
|---|---|
| Use a path: app, then environment, then purpose. One prefix per environment lets one IAM policy cover `my-app/dev/*` | `my-app/prod/db`, `my-app/dev/stripe-key` |
| Letters, digits and `/_+=.@-` only, up to 512 characters | No spaces |
| Don't end a name with a hyphen and 6 characters | Avoid `my-app-db-abcdef`: it looks like an ARN suffix |
| One secret per credential set, not one giant secret | Smaller blast radius, simpler rotation |

> **Warning:** Never paste a real secret on the command line as `--secret-string "abc123"`: it lands in your shell history and process list. Use a prompt, a generated value, or `file://` with a file you delete straight away.

AWS docs: [Create a secret](https://docs.aws.amazon.com/secretsmanager/latest/userguide/create_secret.html) · [Quotas](https://docs.aws.amazon.com/secretsmanager/latest/userguide/reference_limits.html)

## Step 2: Read a secret

> **In simple words:** Reading is one call, `GetSecretValue`. For a key/value secret you get the JSON as a string, then pick the field you need. In apps, read the secret once and **cache** it instead of calling Secrets Manager on every request.

**Console:** open the secret → **Overview** tab → **Retrieve secret value**.

**CLI:**

```bash
# plaintext secret
aws secretsmanager get-secret-value --secret-id my-app/dev/api-key \
  --query SecretString --output text

# one field from a key/value secret (needs jq)
aws secretsmanager get-secret-value --secret-id my-app/dev/db \
  --query SecretString --output text | jq -r .username

# list the JSON keys, without showing the values
aws secretsmanager get-secret-value --secret-id my-app/dev/db \
  --query SecretString --output text | jq -r 'keys[]'

# metadata only (no value): ARN, KMS key, rotation, versions
aws secretsmanager describe-secret --secret-id my-app/dev/db

# find secrets by name prefix, and read several at once
aws secretsmanager list-secrets --filters Key=name,Values=my-app/ --query 'SecretList[].Name'
aws secretsmanager batch-get-secret-value --secret-id-list my-app/dev/api-key my-app/dev/db \
  --query 'SecretValues[].Name'
```

**Python (boto3):**

```python
import json

import boto3

client = boto3.client("secretsmanager", region_name="us-east-1")


def get_secret(name):
    """Return a key/value secret as a Python dict."""
    resp = client.get_secret_value(SecretId=name)
    return json.loads(resp["SecretString"])


db = get_secret("my-app/dev/db")
print("Connecting as", db["username"], "to", db["host"])  # never print the password
```

**Good habits:** cache the value for a few minutes (faster, cheaper, survives short API errors), never log the value or the whole response, and on a login failure fetch the secret again, because it may have just been rotated. For caching in Python, AWS publishes the `aws-secretsmanager-caching` library.

AWS docs: [Get a secret with Python](https://docs.aws.amazon.com/secretsmanager/latest/userguide/retrieving-secrets-python-sdk.html) · [Python client-side caching](https://docs.aws.amazon.com/secretsmanager/latest/userguide/retrieving-secrets_cache-python.html)

## Step 3: Versions and staging labels

> **In simple words:** Every time the value changes, Secrets Manager keeps the old copy as a new **version** and moves the stickers: `AWSCURRENT` goes to the new value and `AWSPREVIOUS` to the one before. Apps read `AWSCURRENT` unless they ask for something else, so you can roll back by moving a sticker.

```text
  put-secret-value (new value)
            │
            ▼
  ┌───────────────┐   ┌───────────────┐   ┌───────────────┐
  │ version v3    │   │ version v2    │   │ version v1    │
  │ AWSCURRENT    │   │ AWSPREVIOUS   │   │ (no label)    │
  └───────────────┘   └───────────────┘   └───────────────┘
   apps read this      one step back       cleaned up later
```

| Label | Meaning | Set by |
|---|---|---|
| `AWSCURRENT` | The value apps should use now | Moved automatically on every new value |
| `AWSPREVIOUS` | The value just before the current one | Moved automatically with `AWSCURRENT` |
| `AWSPENDING` | A new value being prepared during rotation | The rotation function |
| Your own label | Any label you add, for example `release-42` | You, with `update-secret-version-stage` |

Versions without a label are "deprecated", and Secrets Manager deletes them in the background when there are more than 100 (it keeps any created in the last 24 hours). New versions are **free**.

**Console:** open the secret → **Retrieve secret value** → **Edit** → change the value → **Save**. The **Versions** tab shows the labels.

**CLI:**

```bash
# store a new value: becomes AWSCURRENT, the old one becomes AWSPREVIOUS
aws secretsmanager put-secret-value --secret-id my-app/dev/api-key \
  --secret-string "$(openssl rand -hex 24)"

aws secretsmanager list-secret-version-ids --secret-id my-app/dev/api-key \
  --query 'Versions[].[VersionId,join(`,`,VersionStages)]' --output table

# read the previous value
aws secretsmanager get-secret-value --secret-id my-app/dev/api-key \
  --version-stage AWSPREVIOUS --query SecretString --output text

# roll back: move AWSCURRENT back to the previous version
CURRENT=$(aws secretsmanager list-secret-version-ids --secret-id my-app/dev/api-key \
  --query "Versions[?contains(VersionStages, 'AWSCURRENT')].VersionId | [0]" --output text)
PREVIOUS=$(aws secretsmanager list-secret-version-ids --secret-id my-app/dev/api-key \
  --query "Versions[?contains(VersionStages, 'AWSPREVIOUS')].VersionId | [0]" --output text)

aws secretsmanager update-secret-version-stage --secret-id my-app/dev/api-key \
  --version-stage AWSCURRENT --move-to-version-id "$PREVIOUS" --remove-from-version-id "$CURRENT"
```

> **Note:** AWS recommends not updating a secret's value more often than about **once every 10 minutes**. Faster updates create versions quicker than Secrets Manager cleans them up, and you can hit the 100-version quota.

## Step 4: Encryption with KMS

> **In simple words:** Every secret is encrypted with a **KMS key**. The default, `aws/secretsmanager`, is free and works for most cases. Use **your own (customer managed) key** when another account must read the secret, or when you want a key policy and separate audit trail for a group of secrets.

| | `aws/secretsmanager` (AWS managed) | Customer managed key |
|---|---|---|
| Cost | Free | About $1 per month, plus requests |
| Who controls the key policy | AWS | You |
| Cross-account access | **Not possible** | Possible |
| Separate keys per app or team | No, one per account and Region | Yes |
| Extra permission for readers | None (works through Secrets Manager) | `kms:Decrypt` on the key |

**Console:** when you create a secret, change **Encryption key** to your key. For an existing secret: open it → **Actions** → **Edit encryption key**.

**CLI:**

```bash
KEY_ID=$(aws kms create-key --description "Secrets for my-app" \
  --query KeyMetadata.KeyId --output text)
aws kms create-alias --alias-name alias/my-app-secrets --target-key-id "$KEY_ID"
aws kms enable-key-rotation --key-id "$KEY_ID"
KEY_ARN=$(aws kms describe-key --key-id alias/my-app-secrets --query KeyMetadata.Arn --output text)

# a new secret encrypted with your key
aws secretsmanager create-secret --name my-app/dev/partner-token \
  --kms-key-id alias/my-app-secrets --secret-string "$(openssl rand -hex 24)"

# move an existing secret to your key
aws secretsmanager update-secret --secret-id my-app/dev/db --kms-key-id alias/my-app-secrets
aws secretsmanager describe-secret --secret-id my-app/dev/db --query KmsKeyId --output text
```

When you change the key, Secrets Manager re-encrypts the `AWSCURRENT`, `AWSPENDING` and `AWSPREVIOUS` versions with the new key (older versions stay on the old key). Secrets Manager supports **symmetric** KMS keys only.

The [KMS guide](#/tool/aws-kms) explains keys, aliases and [key policies](#/tool/aws-kms/key-policies-iam-policies-and-grants) in depth.

AWS docs: [Secret encryption and decryption](https://docs.aws.amazon.com/secretsmanager/latest/userguide/security-encryption.html) · [Change the encryption key](https://docs.aws.amazon.com/secretsmanager/latest/userguide/manage_update-encryption-key.html)

## Step 5: Who can read it: IAM and resource policies

> **In simple words:** By default **nobody** except admins can read a secret. Give each app a role that can read **only its own secrets**. To let another AWS account read a secret, you need **three** things: a resource policy on the secret, a customer managed KMS key that allows that account, and an IAM policy in the other account.

### Least-privilege policy for your app

This policy lets a role read the `my-app/dev/*` secrets and nothing else. The `kms:ViaService` condition means the key can only be used **through** Secrets Manager.

```bash
cat > read-secrets.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadMyAppDevSecrets",
      "Effect": "Allow",
      "Action": ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"],
      "Resource": "arn:aws:secretsmanager:${AWS_REGION}:${ACCOUNT_ID}:secret:my-app/dev/*"
    },
    {
      "Sid": "DecryptOnlyThroughSecretsManager",
      "Effect": "Allow",
      "Action": "kms:Decrypt",
      "Resource": "${KEY_ARN}",
      "Condition": { "StringEquals": { "kms:ViaService": "secretsmanager.${AWS_REGION}.amazonaws.com" } }
    }
  ]
}
EOF

POLICY_ARN=$(aws iam create-policy --policy-name my-app-dev-secrets-read \
  --policy-document file://read-secrets.json --query Policy.Arn --output text)

APP_ROLE=my-app-role      # the role your app runs as (see the IAM guide)
aws iam attach-role-policy --role-name "$APP_ROLE" --policy-arn "$POLICY_ARN"
```

| Resource pattern | Matches |
|---|---|
| `...:secret:my-app/dev/db-??????` | Exactly the secret `my-app/dev/db` (each `?` is one of the 6 random characters) |
| `...:secret:my-app/dev/*` | Every secret whose name starts with `my-app/dev/` |
| `...:secret:my-app/dev/db-*` | Avoid: also matches names like `my-app/dev/db-old-AbCdEf` |
| `*` | Every secret in the account: only for admins |

If the secret uses `aws/secretsmanager`, drop the KMS statement: that key already allows anyone in the account who can call Secrets Manager. For people, AWS has the managed policy `SecretsManagerReadWrite`, which is broad, so keep it for admins.

### Cross-account access

```text
 Owner 111111111111              Reader 222222222222
 ┌──────────────────────────┐    ┌───────────────────────┐
 │ Secret + resource policy │◀───│ my-app-role           │
 │ KMS key + key policy     │◀───│ IAM policy: get secret│
 │ (both allow my-app-role) │    │ + decrypt, FULL ARN   │
 └──────────────────────────┘    └───────────────────────┘
```

**1) In the owner account, attach a resource policy to the secret.** It must use a customer managed key, so use `my-app/dev/partner-token` from Step 4.

**Console:** open the secret → **Overview** tab → **Resource permissions** → **Edit permissions** → paste the policy → **Save**.

**CLI:**

```bash
OTHER_ACCOUNT=222222222222

cat > secret-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::${OTHER_ACCOUNT}:role/my-app-role" },
      "Action": "secretsmanager:GetSecretValue",
      "Resource": "*"
    }
  ]
}
EOF

aws secretsmanager validate-resource-policy --secret-id my-app/dev/partner-token \
  --resource-policy file://secret-policy.json
aws secretsmanager put-resource-policy --secret-id my-app/dev/partner-token \
  --resource-policy file://secret-policy.json --block-public-policy
aws secretsmanager get-resource-policy --secret-id my-app/dev/partner-token
```

In a secret's resource policy, `"Resource": "*"` means "this secret". `--block-public-policy` refuses any policy that would make the secret public.

**2) In the owner account, add a statement to the KMS key policy** so the other role can decrypt:

```json
{
  "Sid": "AllowOtherAccountToDecryptSecrets",
  "Effect": "Allow",
  "Principal": { "AWS": "arn:aws:iam::222222222222:role/my-app-role" },
  "Action": ["kms:Decrypt", "kms:DescribeKey"],
  "Resource": "*",
  "Condition": { "StringEquals": { "kms:ViaService": "secretsmanager.us-east-1.amazonaws.com" } }
}
```

**3) In the reader account,** give `my-app-role` an IAM policy allowing `secretsmanager:GetSecretValue` on the secret's **full ARN** and `kms:Decrypt` on the key ARN. The reader must always use the **full ARN**, not the name, because names only work inside the owner's account.

AWS docs: [Identity-based policies](https://docs.aws.amazon.com/secretsmanager/latest/userguide/auth-and-access_iam-policies.html) · [Resource-based policies](https://docs.aws.amazon.com/secretsmanager/latest/userguide/auth-and-access_resource-policies.html) · [Cross-account access](https://docs.aws.amazon.com/secretsmanager/latest/userguide/auth-and-access_examples_cross.html) · More in the [IAM guide](#/tool/aws-iam)

## Step 6: Turn on rotation

> **In simple words:** Rotation means **changing the password on a schedule** without anyone touching it. Secrets Manager prepares a new value, sets it in the database or service, tests it, and only then makes it current. For RDS and Aurora admin passwords the database service does all of this for you (**managed rotation**); for everything else a **Lambda function** does the work.

```flow
⏰ | Schedule fires | Secrets Manager starts a rotation inside the rotation window.
🆕 | create_secret | A new value is generated and saved as a new version labelled AWSPENDING.
🔧 | set_secret | The same new password is set in the database or service.
🧪 | test_secret | The function logs in with the AWSPENDING value to prove it works.
✅ | finish_secret | AWSCURRENT moves to the new version; the old one becomes AWSPREVIOUS.
```

### Two kinds of rotation

| | Managed rotation | Rotation by Lambda function |
|---|---|---|
| Used for | RDS, Aurora, Redshift and DocumentDB admin passwords; some other AWS services and partners | Every other secret: app database users, API keys, tokens |
| Who creates the secret | The service (for example RDS) | You |
| Lambda function in your account | None | Yes: from an AWS template (databases) or written by you |
| Cost | Only the secret | The secret plus Lambda runs |

### Managed rotation for RDS and Aurora

Ask RDS to create and manage the admin password. RDS stores it in a secret (named with an `rds!` prefix) and **rotates it every 7 days by default**:

```bash
DB_ID=my-app-db      # an existing RDS instance

aws rds modify-db-instance --db-instance-identifier "$DB_ID" \
  --manage-master-user-password --master-user-secret-kms-key-id alias/my-app-secrets \
  --apply-immediately

aws rds describe-db-instances --db-instance-identifier "$DB_ID" \
  --query 'DBInstances[0].MasterUserSecret'
```

For an Aurora cluster use `aws rds modify-db-cluster --db-cluster-identifier ... --manage-master-user-password`. To change the schedule, open the `rds!...` secret in the Secrets Manager console → **Rotation** → **Edit rotation**. Read more in the [RDS guide](#/tool/aws-rds).

### Lambda rotation for other secrets

**Console:** open the secret → **Rotation** tab → **Edit rotation** → turn on **Automatic rotation** → set the schedule → choose the **Lambda rotation function** → **Save**. For a database secret (a "Credentials for ... database" type), the console can create the rotation function for you from an AWS template.

**CLI:** if you already have a rotation function, allow Secrets Manager to call it, then attach it with a schedule. The `aws:SourceAccount` check stops other accounts from using your function.

```bash
ROTATION_FN=my-app-token-rotation      # your rotation Lambda function
ROTATION_FN_ARN=arn:aws:lambda:${AWS_REGION}:${ACCOUNT_ID}:function:${ROTATION_FN}

aws lambda add-permission --function-name "$ROTATION_FN" \
  --statement-id SecretsManagerInvoke --action lambda:InvokeFunction \
  --principal secretsmanager.amazonaws.com --source-account "$ACCOUNT_ID"

# rotates once now, then every 30 days within a 4-hour window (UTC)
aws secretsmanager rotate-secret --secret-id my-app/dev/partner-token \
  --rotation-lambda-arn "$ROTATION_FN_ARN" \
  --rotation-rules '{"ScheduleExpression":"rate(30 days)","Duration":"4h"}'

aws secretsmanager describe-secret --secret-id my-app/dev/partner-token \
  --query '{Enabled:RotationEnabled,Rules:RotationRules,Last:LastRotatedDate,Next:NextRotationDate}'

# rotate right now (on demand)
aws secretsmanager rotate-secret --secret-id my-app/dev/partner-token
```

| Schedule expression | Meaning |
|---|---|
| `rate(30 days)` | Every 30 days; the window starts at midnight UTC |
| `rate(12 hours)` | Every 12 hours. **4 hours** is the most often you can rotate |
| `cron(0 16 1,15 * ? *)` | 16:00 UTC on the 1st and 15th of each month |
| `"Duration": "2h"` | The rotation window length; rotation happens any time inside it |

For database users there are two **rotation strategies**: **single user** changes the one user's password (simple; apps should retry a failed login), and **alternating users** keeps two users (`user` and `user_clone`) and changes them in turns, so one is always valid (higher availability, but it needs an admin secret that can create the clone).

> **Warning:** The rotation function must reach **both** the Secrets Manager API and the database. A function in a private subnet with no NAT gateway needs a **Secrets Manager VPC endpoint** (see the [PrivateLink guide](#/tool/aws-privatelink)), and the database's security group must allow the function in.

AWS docs: [Managed rotation](https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotate-secrets_managed.html) · [Rotation by Lambda function](https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotate-secrets_lambda.html) · [Rotation strategies](https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotation-strategy.html) · [Rotation for non-database secrets](https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotate-secrets_turn-on-for-other.html) · [RDS password management](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-secrets-manager.html)

## Step 7: Replicate to another Region

> **In simple words:** For disaster recovery, keep a **read-only copy** of the secret in a second Region. Every change to the primary (including rotation) is copied automatically. If the main Region fails, you **promote** the copy into a normal, independent secret.

**Console:** open the secret → **Replicate secret** → **Add Region** → choose `us-west-2` and an encryption key → **Replicate**.

**CLI:**

```bash
DR_REGION=us-west-2

aws secretsmanager replicate-secret-to-regions --secret-id my-app/dev/api-key \
  --add-replica-regions Region=$DR_REGION

aws secretsmanager describe-secret --secret-id my-app/dev/api-key \
  --query 'ReplicationStatus[].[Region,Status,KmsKeyId]' --output table

# the replica has the same name and the same ARN, except for the Region
aws secretsmanager get-secret-value --secret-id my-app/dev/api-key \
  --region $DR_REGION --query Name --output text
```

| Task | Command |
|---|---|
| Replica with your own key | `--add-replica-regions Region=us-west-2,KmsKeyId=alias/my-key-in-us-west-2` |
| Promote a replica (disaster) | `aws secretsmanager stop-replication-to-replica --secret-id my-app/dev/api-key --region us-west-2` |
| Remove a replica | `aws secretsmanager remove-regions-from-replication --secret-id my-app/dev/api-key --remove-replica-regions us-west-2` |

A replica uses a KMS key **in its own Region**. Without `KmsKeyId` it uses that Region's `aws/secretsmanager`. Each replica is billed as a separate secret, and you can't delete a primary secret until its replicas are removed.

AWS docs: [Replicate secrets across Regions](https://docs.aws.amazon.com/secretsmanager/latest/userguide/create-manage-multi-region-secrets.html)

## Step 8: Use secrets from ECS, Lambda, EC2 and Kubernetes

> **In simple words:** Don't copy secret values into task definitions, environment files or Helm values. Point the platform at the secret's **ARN** and let it fetch the value with its own IAM role at start-up or run time.

### ECS: the `secrets` section of a task definition

ECS reads each secret when the container **starts** and passes it in as an environment variable. The **task execution role** needs `secretsmanager:GetSecretValue` on those secrets (and `kms:Decrypt` for a customer managed key).

```json
{
  "family": "my-app",
  "executionRoleArn": "arn:aws:iam::111111111111:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "web",
      "image": "111111111111.dkr.ecr.us-east-1.amazonaws.com/my-app:1.0",
      "essential": true,
      "secrets": [
        { "name": "API_KEY", "valueFrom": "arn:aws:secretsmanager:us-east-1:111111111111:secret:my-app/dev/api-key-AbCdEf" },
        { "name": "DB_USER", "valueFrom": "arn:aws:secretsmanager:us-east-1:111111111111:secret:my-app/dev/db-AbCdEf:username::" },
        { "name": "DB_PASSWORD", "valueFrom": "arn:aws:secretsmanager:us-east-1:111111111111:secret:my-app/dev/db-AbCdEf:password::" }
      ]
    }
  ]
}
```

The full `valueFrom` format is `secret-arn:json-key:version-stage:version-id`. Leave a part empty to use the default (the whole value, `AWSCURRENT`). In the console, add an environment variable and set its value type to **ValueFrom**.

After a rotation, running tasks keep the old value. Start new tasks to pick it up: `aws ecs update-service --cluster my-cluster --service my-app --force-new-deployment`. More in the [ECS guide](#/tool/aws-ecs). AWS docs: [Pass Secrets Manager secrets to ECS](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/secrets-envvar-secrets-manager.html)

### Lambda: the Parameters and Secrets extension

Calling Secrets Manager on every invocation is slow and costs API calls. Add the **AWS Parameters and Secrets Lambda Extension** layer (**Layers** → **Add a layer** → **AWS layers**). It caches secrets (300 seconds by default) and serves them on `localhost:2773`. The function's execution role needs `secretsmanager:GetSecretValue`.

```python
import json
import os
import urllib.parse
import urllib.request

PORT = os.environ.get("PARAMETERS_SECRETS_EXTENSION_HTTP_PORT", "2773")


def get_secret(name):
    url = f"http://localhost:{PORT}/secretsmanager/get?secretId={urllib.parse.quote(name, safe='')}"
    headers = {"X-Aws-Parameters-Secrets-Token": os.environ["AWS_SESSION_TOKEN"]}
    with urllib.request.urlopen(urllib.request.Request(url, headers=headers)) as resp:
        return json.loads(json.loads(resp.read())["SecretString"])


def lambda_handler(event, context):
    db = get_secret("my-app/dev/db")
    return {"connected_as": db["username"]}
```

A Lambda function inside a VPC without a NAT gateway needs a Secrets Manager VPC endpoint. More in the [Lambda guide](#/tool/aws-lambda). AWS docs: [Use Secrets Manager secrets in Lambda](https://docs.aws.amazon.com/lambda/latest/dg/with-secrets-manager.html)

### EC2: the instance role

Attach an **instance profile** whose role has the read policy from Step 5. On the server, the AWS CLI and SDKs (like the boto3 snippet in Step 2) pick up the role automatically, so no keys are stored on the machine. For a local cache that any language can call over HTTP, AWS offers the open-source **AWS Workload Credentials Provider** (formerly the AWS Secrets Manager Agent). It also runs as a sidecar on ECS and EKS. See [Workload Credentials Provider](https://docs.aws.amazon.com/secretsmanager/latest/userguide/workload-credentials-provider.html).

### Kubernetes (EKS): mount secrets as files

Two popular options:

| Option | How it works |
|---|---|
| **AWS Secrets and Configuration Provider (ASCP)** for the Secrets Store CSI Driver | Mounts secrets as **files** in the pod. Install it as the EKS add-on `aws-secrets-store-csi-driver-provider` or with Helm; the pod's service account gets AWS access through **Pod Identity** or IRSA |
| **External Secrets Operator** (open source) | Copies secrets into normal **Kubernetes Secrets** and keeps them in sync, so apps can use `env` or `envFrom` |

An ASCP `SecretProviderClass` that mounts two fields of `my-app/dev/db` as files:

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: my-app-secrets
  namespace: my-app
spec:
  provider: aws
  parameters:
    usePodIdentity: "true"
    objects: |
      - objectName: "my-app/dev/db"
        objectType: "secretsmanager"
        objectAlias: "dbsecret"
        jmesPath:
          - path: "username"
            objectAlias: "dbusername"
          - path: "password"
            objectAlias: "dbpassword"
```

In the pod, add a `csi` volume with driver `secrets-store.csi.k8s.io` and `secretProviderClass: my-app-secrets`, mount it at `/mnt/secrets-store`, and the app reads `/mnt/secrets-store/dbpassword`. See the [EKS guide](#/tool/eks-cluster) and [Pod Identity](#/tool/aws-iam/eks-aws-permissions-for-pods-pod-identity-and-irsa) for the IAM side.

AWS docs: [Install ASCP for Amazon EKS](https://docs.aws.amazon.com/secretsmanager/latest/userguide/ascp-eks-installation.html) · [ASCP on GitHub](https://github.com/aws/secrets-store-csi-driver-provider-aws) · [External Secrets Operator](https://external-secrets.io/latest/)

## Secrets in Terraform

> **In simple words:** Let Terraform create the **empty locker** (name, KMS key, policy, recovery window), but keep the **real value** out of your code and, if possible, out of the Terraform state file. Anything in `secret_string` is saved in the state in plain text.

A common pattern: Terraform creates the secret with a **placeholder**, a person or a rotation function sets the real value, and `ignore_changes` stops Terraform from putting the placeholder back.

```hcl
resource "aws_secretsmanager_secret" "db" {
  name                    = "my-app/dev/db"
  description             = "Database login for my-app (dev)"
  kms_key_id              = var.secrets_kms_key_arn
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = "app_user"
    password = "CHANGE_ME"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}
```

With Terraform 1.11 or later and a recent AWS provider, you can use the **write-only** argument `secret_string_wo` (with `secret_string_wo_version`) so the value is sent to AWS but never stored in state. Either way, keep the state in an encrypted, access-controlled backend. See the [Terraform guide](#/tool/terraform).

## Step 9: Delete and restore safely

> **In simple words:** Deleting a secret is **not immediate**. It's scheduled for deletion after a **recovery window** of 7 to 30 days (30 by default), and you can undo it until then. Only a **force delete** removes it at once, with no way back.

```compare
🗓️ Delete with a recovery window | 💥 Force delete
Secret is scheduled for deletion in 7 to 30 days | Secret is gone immediately
Can be restored with restore-secret | Can never be restored
Apps reading it get an error, which shows you who still uses it | Apps break with "not found"
The name stays reserved until the window ends | The name can be reused (after a short delay)
Use in production (not billed while waiting) | Use in labs and tests only
```

**Console:** open the secret → **Actions** → **Delete secret** → choose the waiting period → **Schedule deletion**. To undo, open it again and choose **Cancel deletion**.

**CLI:**

```bash
aws secretsmanager delete-secret --secret-id my-app/dev/db --recovery-window-in-days 7
aws secretsmanager describe-secret --secret-id my-app/dev/db --query DeletedDate --output text

# changed your mind? cancel the deletion
aws secretsmanager restore-secret --secret-id my-app/dev/db

# lab only: delete at once, no recovery
aws secretsmanager delete-secret --secret-id my-app/dev/db --force-delete-without-recovery
```

While a secret is scheduled for deletion you can't read its value. A **CloudWatch alarm** on attempts to read it is a good early warning that something still depends on it (see the [CloudWatch guide](#/tool/aws-cloudwatch)).

AWS docs: [Delete a secret](https://docs.aws.amazon.com/secretsmanager/latest/userguide/manage_delete-restore-secret.html)

## Troubleshooting

> **In simple words:** Most errors are one of four things: the **IAM policy** doesn't match the secret's ARN, the **KMS key** doesn't allow the caller, you're in the **wrong Region or account**, or the secret is **scheduled for deletion**.

| Problem | Likely cause | Fix |
|---|---|---|
| `AccessDeniedException` on `GetSecretValue` | The role's policy doesn't cover this ARN; a pattern like `my-app/dev/db` without `-??????` or `*`; an SCP or the resource policy denies it | Run `aws sts get-caller-identity`, then fix the `Resource` in the policy. Check the resource policy and SCPs |
| Access denied mentioning **KMS** or `kms:Decrypt` | The secret uses a customer managed key that doesn't allow the caller | Add `kms:Decrypt` to the role's policy **and** allow the role in the key policy |
| Another account can't read the secret | The secret uses `aws/secretsmanager`; resource policy missing; reader used the name | Switch to a customer managed key, add the resource policy, use the **full ARN** |
| `InvalidRequestException`: secret marked for deletion | Someone deleted it; the recovery window is still running | `aws secretsmanager restore-secret --secret-id ...` |
| Can't create a secret: name already exists | An old secret with that name is scheduled for deletion | Restore it, or (labs only) force-delete it, then create again |
| `ResourceNotFoundException` | Wrong Region or account, or a typo in the name | Add `--region`, check `aws secretsmanager list-secrets` |
| App gets `None` or a `KeyError` | Wrong JSON key (`Password` vs `password`), or the secret is plaintext, not JSON | List keys with `jq -r 'keys[]'`; match the exact key name |
| ECS task stops with `ResourceInitializationError` | Execution role can't read the secret or key; no route to Secrets Manager; wrong JSON key in `valueFrom` | Fix the execution role; add a NAT gateway or VPC endpoint; check the key name |
| App still uses the old password after rotation | The value was read at start-up or cached | Restart tasks or pods; on a login failure, fetch the secret again |
| Rotation failed | The function can't reach Secrets Manager or the database; Secrets Manager can't invoke the function | Check the function's logs in CloudWatch; add a VPC endpoint; fix security groups and `add-permission` |
| "This secret is managed by an AWS service" | It's a managed secret (for example `rds!...`) | Change it through the owning service (RDS, Redshift...) |
| Throttling or version quota errors | Reading on every request, or updating the value very often | Cache values; update at most about once every 10 minutes |

Every API call to Secrets Manager is in **CloudTrail**: filter by event source `secretsmanager.amazonaws.com` to see who called what and the exact error.

AWS docs: [Troubleshooting Secrets Manager](https://docs.aws.amazon.com/secretsmanager/latest/userguide/troubleshoot.html)

## Clean up

> **In simple words:** Remove the replica first, then force-delete the lab secrets (they're only test values), detach and delete the IAM policy, and schedule the KMS key for deletion. Don't force-delete real secrets: use a recovery window for those.

```bash
export AWS_REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# replica first (a primary with replicas can't be deleted)
aws secretsmanager remove-regions-from-replication --secret-id my-app/dev/api-key \
  --remove-replica-regions us-west-2 || true

for S in my-app/dev/api-key my-app/dev/db my-app/dev/partner-token; do
  aws secretsmanager delete-secret --secret-id "$S" --force-delete-without-recovery || true
done

# IAM policy: detach from every role, then delete
POLICY_ARN=arn:aws:iam::${ACCOUNT_ID}:policy/my-app-dev-secrets-read
for R in $(aws iam list-entities-for-policy --policy-arn "$POLICY_ARN" \
  --query 'PolicyRoles[].RoleName' --output text); do
  aws iam detach-role-policy --role-name "$R" --policy-arn "$POLICY_ARN"
done
aws iam delete-policy --policy-arn "$POLICY_ARN"

# Lambda permission (only if you added it in Step 6)
aws lambda remove-permission --function-name my-app-token-rotation \
  --statement-id SecretsManagerInvoke || true

# KMS key: the alias goes now, the key after 7 days
KEY_ID=$(aws kms describe-key --key-id alias/my-app-secrets --query KeyMetadata.KeyId --output text)
aws kms delete-alias --alias-name alias/my-app-secrets
aws kms schedule-key-deletion --key-id "$KEY_ID" --pending-window-in-days 7

rm -f db-secret.json read-secrets.json secret-policy.json
aws secretsmanager list-secrets --filters Key=name,Values=my-app/ --query 'SecretList[].Name'
```

If you promoted a replica in Step 7, it's now a normal secret in `us-west-2`: delete it there with `--region us-west-2`. If you turned on managed rotation for a lab RDS instance, deleting the instance also deletes its `rds!` secret.

## Lab and cheat sheet

> **In simple words:** Practice the full life of a secret: create it, read it, change it, roll it back, lock it down, share it, copy it to another Region, and delete it safely.

1. Create `my-app/dev/api-key` (plaintext) and `my-app/dev/db` (key/value with a generated password) using the CLI, without the values ever appearing in your shell history.
2. Read the `username` field with `jq`, and then with the Python snippet.
3. Change the API key twice with `put-secret-value`. List the versions and their labels, read `AWSPREVIOUS`, then roll back with `update-secret-version-stage`.
4. Create a customer managed KMS key and move `my-app/dev/db` to it. Check the new `KmsKeyId`.
5. Create the least-privilege policy, attach it to a test role, and prove the role can read `my-app/dev/db` but **not** a secret named `other-app/dev/db`.
6. Write a resource policy for a second account, check it with `validate-resource-policy`, and attach it with `--block-public-policy`.
7. Replicate `my-app/dev/api-key` to `us-west-2` and read it there. Then remove the replica.
8. Schedule a deletion with a 7-day window, try to read the secret (it fails), restore it, then clean everything up.
9. Bonus: add a `secrets` entry to an ECS task definition (from the [ECS guide](#/tool/aws-ecs)) and print the variable's length (never the value) in the container logs.

### Cheat sheet

| Task | Command |
|---|---|
| Create (plaintext) | `aws secretsmanager create-secret --name N --secret-string "$VALUE"` |
| Create (JSON from file) | `aws secretsmanager create-secret --name N --secret-string file://secret.json` |
| Generate a password | `aws secretsmanager get-random-password --password-length 32 --exclude-punctuation` |
| Read the value | `aws secretsmanager get-secret-value --secret-id N --query SecretString --output text` |
| Read one JSON field | `... get-secret-value --secret-id N --query SecretString --output text \| jq -r .password` |
| Metadata only | `aws secretsmanager describe-secret --secret-id N` |
| New value | `aws secretsmanager put-secret-value --secret-id N --secret-string "$VALUE"` |
| Versions and labels | `aws secretsmanager list-secret-version-ids --secret-id N` |
| Roll back | `aws secretsmanager update-secret-version-stage --secret-id N --version-stage AWSCURRENT --move-to-version-id OLD --remove-from-version-id NEW` |
| Change the KMS key | `aws secretsmanager update-secret --secret-id N --kms-key-id alias/K` |
| Resource policy | `aws secretsmanager put-resource-policy --secret-id N --resource-policy file://p.json --block-public-policy` |
| Turn on rotation | `aws secretsmanager rotate-secret --secret-id N --rotation-lambda-arn FN --rotation-rules '{"ScheduleExpression":"rate(30 days)"}'` |
| Replicate | `aws secretsmanager replicate-secret-to-regions --secret-id N --add-replica-regions Region=us-west-2` |
| Delete (with recovery) | `aws secretsmanager delete-secret --secret-id N --recovery-window-in-days 7` |
| Restore | `aws secretsmanager restore-secret --secret-id N` |
| Delete now (labs only) | `aws secretsmanager delete-secret --secret-id N --force-delete-without-recovery` |
| Via Parameter Store | `aws ssm get-parameter --name /aws/reference/secretsmanager/N --with-decryption` |
