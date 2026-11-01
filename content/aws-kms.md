# AWS KMS: Encryption Keys

AWS KMS (Key Management Service) creates and protects the encryption keys used across AWS: S3, EBS disks, RDS databases, Secrets Manager, EKS secrets and your own applications. The keys never leave KMS unencrypted. You ask KMS to encrypt or decrypt, and KMS checks permissions and logs every use. This guide covers key types, creating keys, encrypting data, envelope encryption, key policies, rotation and safe deletion.

> **Cost:** Each **customer managed key** costs about **$1 per month** (prorated), and the first two rotations add a little more. API requests cost a few cents per 10,000, and many requests are free tier. AWS managed keys (`aws/s3`, `aws/ebs`…) have no monthly fee. See [KMS pricing](https://aws.amazon.com/kms/pricing/).

## Start here: KMS in simple words

> **In simple words:** KMS is a **bank vault for encryption keys**. You never take the master key out of the vault. Instead you hand data to the vault clerk, who encrypts or decrypts it for you, but only if you're on the key's permission list, and every visit is written in a logbook.

### A real-life comparison

| Bank | KMS |
|---|---|
| The master key that never leaves the vault | **KMS key** (stored in hardware security modules) |
| The list of people allowed to use it | **Key policy** plus IAM policies |
| A small lockbox key you're allowed to take home, delivered sealed | A **data key**, returned both in plain form and encrypted by the KMS key |
| The visitor logbook | **CloudTrail**: every Encrypt, Decrypt and GenerateDataKey call |
| Changing the lock every year | **Key rotation** |

### Key words

| Word | Simple meaning |
|---|---|
| **KMS key** | The main key inside KMS. It never leaves KMS unencrypted |
| **Customer managed key** | A key **you** create and control: policy, rotation, deletion |
| **AWS managed key** | A key AWS creates for a service in your account, such as `aws/s3` |
| **Alias** | A friendly name, such as `alias/app-data`, pointing to a key ID |
| **Key policy** | The key's own permission document. **Every key has exactly one** |
| **Data key** | A key KMS generates for you to encrypt large data locally |
| **Envelope encryption** | Encrypt data with a data key, then encrypt the data key with the KMS key |
| **Encryption context** | Extra non-secret labels that must match at decrypt time, like a second password |

### Check yourself

1. Can you download a KMS key to your laptop?
2. Why do services use data keys instead of sending all data to KMS?
3. Where can you see who used a key?

> **Tip:** Answers: 1) No. KMS keys never leave KMS unencrypted. 2) KMS encrypts at most 4 KB per call, and sending gigabytes over the network would be slow, so services encrypt locally with a data key. 3) In CloudTrail.

## Key types

> **In simple words:** There are three owners of keys (AWS owns it, AWS manages it in your account, or you manage it) and a few kinds of key (symmetric for encryption, asymmetric for signing, HMAC for message checks).

### Who owns and manages the key

| Type | Example | You can see it? | You control policy, rotation, deletion? | Monthly fee |
|---|---|---|---|---|
| **AWS owned** | Default S3 (SSE-S3) or DynamoDB encryption | No | No | Free |
| **AWS managed** | `aws/s3`, `aws/ebs`, `aws/secretsmanager` | Yes | No (rotated yearly by AWS) | Free |
| **Customer managed** | `alias/app-data` | Yes | **Yes** | ~$1 |

Use a **customer managed key** when you need your own access rules (for example, "only the payments role may decrypt"), cross-account access, your own rotation schedule, or the ability to disable a key in an emergency.

### What kind of key

| Spec | Used for |
|---|---|
| `SYMMETRIC_DEFAULT` (AES-256) | Encrypting data. **What you'll use 95% of the time**; AWS services require it |
| RSA / ECC (asymmetric) | Signing and verifying, or encryption where the public key is shared outside AWS |
| HMAC | Creating and verifying message authentication codes (tamper checks) |

AWS docs: [AWS KMS keys](https://docs.aws.amazon.com/kms/latest/developerguide/concepts.html) · [What is AWS KMS?](https://docs.aws.amazon.com/kms/latest/developerguide/overview.html)

## Create a key and an alias

> **In simple words:** Create one customer managed key, give it a readable name (alias), and say who may administer it and who may use it.

### Console

1. **KMS → Customer managed keys → Create key**.
2. **Symmetric**, **Encrypt and decrypt**, then **Next**.
3. **Alias:** `app-data`. Add a description and tags (`team`, `env`).
4. **Key administrators:** your admin role. Admins manage the key but can't use it to decrypt.
5. **Key users:** the roles that may encrypt and decrypt with it.
6. Review the generated **key policy**, then **Finish**.

### CLI

```bash
KEY_ID=$(aws kms create-key \
  --description "App data encryption key" \
  --tags TagKey=team,TagValue=platform TagKey=env,TagValue=lab \
  --query KeyMetadata.KeyId --output text)

aws kms create-alias --alias-name alias/app-data --target-key-id $KEY_ID

aws kms describe-key --key-id alias/app-data \
  --query 'KeyMetadata.[KeyId,KeyState,KeySpec,KeyManager,Arn]' --output table
aws kms list-aliases --query "Aliases[?starts_with(AliasName,'alias/app')]"
```

Without `--policy`, the key gets the **default key policy**: the account (root) has full access, which means **IAM policies** in this account decide who can use the key.

## Encrypt and decrypt small secrets

> **In simple words:** For small data (up to 4 KB), such as a password or token, send it to KMS and get back an encrypted blob. Only someone allowed to use the key can turn it back into plaintext.

```bash
echo -n "db-password-123" > secret.txt

# Encrypt → binary ciphertext file
aws kms encrypt --key-id alias/app-data \
  --plaintext fileb://secret.txt \
  --encryption-context app=billing \
  --query CiphertextBlob --output text | base64 --decode > secret.enc

xxd secret.enc | head -3        # unreadable bytes; it also records which key was used

# Decrypt → original text (no key ID needed for symmetric keys)
aws kms decrypt --ciphertext-blob fileb://secret.enc \
  --encryption-context app=billing \
  --query Plaintext --output text | base64 --decode; echo
```

Try decrypting **without** `--encryption-context`: it fails with `InvalidCiphertextException`. The context must match exactly, and it appears in CloudTrail, which makes logs much more useful.

> **Tip:** For storing application secrets, use **AWS Secrets Manager** or **SSM Parameter Store (SecureString)**. Both use KMS underneath and add versioning, rotation and an easy API.

## Envelope encryption with data keys

> **In simple words:** To encrypt a big file, KMS gives you a fresh **data key** twice: once in plain form (use it, then throw it away) and once encrypted (store it next to the data). To read the file later, ask KMS to decrypt the small encrypted key. This is how S3, EBS and most AWS services encrypt your data.

```text
            GenerateDataKey
 KMS key ─────────────────────▶  plaintext data key  ──encrypt──▶  big-file.enc
 (never leaves KMS)              encrypted data key  ──store────▶  big-file.key.enc
                                 (forget the plaintext key after use)

 To read:  Decrypt(big-file.key.enc) → plaintext data key → decrypt big-file.enc
```

Try the KMS part:

```bash
aws kms generate-data-key --key-id alias/app-data --key-spec AES_256 \
  --query '{PlaintextKey:Plaintext,EncryptedKey:CiphertextBlob}' > datakey.json
jq -r .EncryptedKey datakey.json | base64 --decode > datakey.enc

# Later: recover the plaintext data key from the stored encrypted copy
aws kms decrypt --ciphertext-blob fileb://datakey.enc --query Plaintext --output text
jq -r .PlaintextKey datakey.json        # same value

rm datakey.json                          # never keep the plaintext data key on disk
```

Why this design matters:
- Large data is encrypted **locally and quickly**. Only a tiny key goes over the network to KMS.
- **Revoking access to the KMS key** makes every encrypted data key, and so all the data, unreadable.
- Real apps use the **AWS Encryption SDK**, which does all of this correctly for you.

## Key policies, IAM policies and grants

> **In simple words:** A KMS key checks **its own key policy first**. The default policy says "trust IAM in this account", so IAM policies then decide. For stricter control, name the allowed roles directly in the key policy.

View the current key policy:

```bash
aws kms get-key-policy --key-id $KEY_ID --policy-name default --output text | jq .
```

A tighter key policy: admins manage it, only the `billing-app` role uses it, and AWS services may use it on that role's behalf. Save as `key-policy.json`, replacing `111122223333`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EnableRootAccountAccess",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::111122223333:root" },
      "Action": "kms:*",
      "Resource": "*"
    },
    {
      "Sid": "AllowKeyAdministration",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::111122223333:role/platform-admin" },
      "Action": ["kms:Describe*", "kms:List*", "kms:Get*", "kms:Put*", "kms:Update*", "kms:Enable*",
                 "kms:Disable*", "kms:TagResource", "kms:UntagResource", "kms:ScheduleKeyDeletion",
                 "kms:CancelKeyDeletion", "kms:RotateKeyOnDemand"],
      "Resource": "*"
    },
    {
      "Sid": "AllowUseByBillingApp",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::111122223333:role/billing-app" },
      "Action": ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"],
      "Resource": "*"
    },
    {
      "Sid": "AllowAwsServicesForBillingApp",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::111122223333:role/billing-app" },
      "Action": ["kms:CreateGrant", "kms:ListGrants", "kms:RevokeGrant"],
      "Resource": "*",
      "Condition": { "Bool": { "kms:GrantIsForAWSResource": "true" } }
    }
  ]
}
```

```bash
aws kms put-key-policy --key-id $KEY_ID --policy-name default --policy file://key-policy.json
```

> **Warning:** Keep the first statement (account root access) unless you really know what you're doing. A key policy that locks out every admin makes the key unmanageable, and only AWS Support can help.

In a key policy, `"Resource": "*"` means "this key".

| Mechanism | Use |
|---|---|
| **Key policy** | The primary control, and required. Needed for cross-account access |
| **IAM policy** | Works only if the key policy trusts the account (as the default policy does) |
| **Grant** | Temporary, narrow permissions. AWS services such as EBS and RDS create them automatically |

AWS docs: [Key policies](https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html) · [Grants](https://docs.aws.amazon.com/kms/latest/developerguide/grants.html)

## Use KMS with AWS services

> **In simple words:** You rarely call KMS directly. Instead you tell S3, EBS, Secrets Manager or EKS "use this key", and they handle the encryption.

### S3: default encryption with your key

```bash
aws s3api put-bucket-encryption --bucket my-bucket --server-side-encryption-configuration '{
  "Rules": [{ "ApplyServerSideEncryptionByDefault": { "SSEAlgorithm": "aws:kms", "KMSMasterKeyID": "alias/app-data" },
              "BucketKeyEnabled": true }]
}'
```

A **Bucket Key** makes S3 call KMS far less often, which cuts cost. More detail is in the [S3 guide](#/tool/aws-s3).

### EBS: encrypt every new disk in the Region

```bash
aws ec2 enable-ebs-encryption-by-default
aws ec2 modify-ebs-default-kms-key-id --kms-key-id alias/app-data
aws ec2 get-ebs-encryption-by-default
```

### Secrets Manager: store a secret with your key

```bash
aws secretsmanager create-secret --name billing/db-password \
  --secret-string 'db-password-123' --kms-key-id alias/app-data
aws secretsmanager get-secret-value --secret-id billing/db-password --query SecretString --output text
```

### EKS

EKS encrypts Kubernetes API data, including Secrets, with KMS envelope encryption by default. You can supply your **own** customer managed key when creating the cluster if you need to control it.

AWS docs: [EKS default envelope encryption](https://docs.aws.amazon.com/eks/latest/userguide/envelope-encryption.html)

## Key rotation

> **In simple words:** Rotation gives the key new cryptographic material on a schedule. Old data still decrypts (KMS keeps every old version), new data uses the new material, and your apps change nothing.

```bash
aws kms enable-key-rotation --key-id $KEY_ID --rotation-period-in-days 365   # 90 to 2560 days
aws kms get-key-rotation-status --key-id $KEY_ID
aws kms rotate-key-on-demand --key-id $KEY_ID           # rotate right now (limited number per key)
aws kms list-key-rotations --key-id $KEY_ID
```

- The key ID, ARN and alias stay the same, so nothing in your apps changes.
- Rotation does **not** re-encrypt existing data. It doesn't need to.
- Automatic rotation is for **symmetric** keys. AWS managed keys rotate every year automatically.

AWS docs: [Rotate KMS keys](https://docs.aws.amazon.com/kms/latest/developerguide/rotate-keys.html)

## Disable and delete keys safely

> **In simple words:** Deleting a KMS key is **permanent**, and everything encrypted with it becomes unreadable forever. So KMS forces a waiting period, and you should disable the key first to see whether anything breaks.

```bash
# 1. Disable (reversible): any use now fails
aws kms disable-key --key-id $KEY_ID
aws kms enable-key --key-id $KEY_ID          # undo

# 2. Schedule deletion: waiting period of 7–30 days (default 30)
aws kms schedule-key-deletion --key-id $KEY_ID --pending-window-in-days 7
aws kms describe-key --key-id $KEY_ID --query 'KeyMetadata.[KeyState,DeletionDate]'

# Changed your mind?
aws kms cancel-key-deletion --key-id $KEY_ID && aws kms enable-key --key-id $KEY_ID
```

> **Tip:** During the waiting period, watch CloudTrail for failed `Decrypt` calls using the key, and set a CloudWatch alarm on them. Any hit means something still needs the key, so cancel the deletion.

**Multi-Region keys** are copies of one key in several Regions, so data encrypted in one Region can be decrypted in another (useful for disaster recovery and global apps).

AWS docs: [Delete a KMS key](https://docs.aws.amazon.com/kms/latest/developerguide/deleting-keys.html) · [Multi-Region keys](https://docs.aws.amazon.com/kms/latest/developerguide/multi-region-keys-overview.html)

## Troubleshooting

> **In simple words:** Most KMS errors mean "you're not on this key's list", "the key is disabled", or "the extra labels (encryption context) don't match".

| Error | Likely cause / fix |
|---|---|
| `AccessDeniedException … kms:Decrypt` | The caller's role isn't allowed by the key policy or IAM. Reading SSE-KMS S3 objects needs `kms:Decrypt` too |
| `KMSInvalidStateException` / `DisabledException` | The key is disabled or pending deletion |
| `InvalidCiphertextException` | Wrong or missing encryption context, a corrupted blob, or the ciphertext isn't binary (decode the base64 first) |
| `NotFoundException` for an alias | Wrong Region: keys and aliases are Regional |
| Cross-account access denied | Needs **both** the key policy in the key's account **and** an IAM policy in the caller's account |
| Throttling (`ThrottlingException`) | Too many requests. Enable S3 Bucket Keys, or cache data keys |

Check who used the key, in **CloudTrail → Event history → Event source `kms.amazonaws.com`**.

## Lab: protect application data with your own key

> **In simple words:** Practice time: create a key, use it to protect a file, a bucket and a secret, then prove that removing access makes the data unreadable.

1. Create a customer managed key `alias/lab-data` with rotation every **180 days**.
2. Encrypt and decrypt a short text with encryption context `env=lab`. Show that decrypting without the context fails.
3. Set it as the default encryption key for a test S3 bucket, with a Bucket Key. Upload a file and confirm with `head-object`.
4. Store a secret in Secrets Manager using the key.
5. **Disable** the key: downloading the S3 object and reading the secret now fail. Re-enable it, and both work again.
6. Find your Encrypt and Decrypt calls in CloudTrail.
7. Clean up: delete the secret (`--force-delete-without-recovery`), empty and delete the bucket, then schedule the key for deletion with a 7-day window.

### Cheat sheet

| Task | Command |
|---|---|
| Create key + alias | `aws kms create-key` / `aws kms create-alias --alias-name alias/x --target-key-id ID` |
| Encrypt file | `aws kms encrypt --key-id alias/x --plaintext fileb://f --query CiphertextBlob --output text \| base64 -d > f.enc` |
| Decrypt file | `aws kms decrypt --ciphertext-blob fileb://f.enc --query Plaintext --output text \| base64 -d` |
| Data key | `aws kms generate-data-key --key-id alias/x --key-spec AES_256` |
| Rotation | `aws kms enable-key-rotation --key-id ID --rotation-period-in-days 365` |
| See policy | `aws kms get-key-policy --key-id ID --policy-name default` |
| Delete (7-day wait) | `aws kms schedule-key-deletion --key-id ID --pending-window-in-days 7` |
