# AWS Backup and DataSync

Two storage services that people often mix up. **AWS Backup** takes scheduled, versioned copies of your servers, disks, databases and file systems, keeps them in a **vault**, and lets you **restore** them when something goes wrong. **AWS DataSync** **moves or syncs** files and objects from one place to another: from an office file server to Amazon EFS, or between S3, EFS and FSx on a schedule. Every step shows the **console clicks** and the matching **AWS CLI v2** commands.

> **Cost:** AWS Backup has no fixed fee. You pay for **backup storage** (about **$0.05 per GB-month** for EBS snapshots and EFS backups in us-east-1, about $0.01 for EFS backups in cold storage), for **restores** of some types (about $0.02 per GB for EFS) and for **copies between Regions**. DataSync charges per GB copied: about **$0.0125/GB in Basic mode**, or about **$0.015/GB plus $0.55 per task run in Enhanced mode**, plus normal S3, EFS and FSx charges. Each customer managed KMS key costs about $1 per month. The lab costs a few cents if you clean up. See [AWS Backup pricing](https://aws.amazon.com/backup/pricing/) and [DataSync pricing](https://aws.amazon.com/datasync/pricing/).

## Start here: Backup and DataSync in simple words

> **In simple words:** **AWS Backup** is your **insurance**: it takes a dated copy of your data every night, keeps each copy as long as you say, and gives it back when you need it. **DataSync** is your **moving company**: it carries your files from the old place to the new place (once, or every night) and checks that nothing broke on the way.

```compare
🛡️ AWS Backup (protection) | 🚚 AWS DataSync (moving and syncing)
Scheduled copies of EBS, EC2, RDS, EFS, FSx, S3, DynamoDB and more | Copies files and objects between storage systems
Keeps many dated versions (recovery points) | Makes the destination match the source (latest state)
You restore a version when something breaks | You use the copied data directly at the destination
Answers "give me yesterday's data back" | Answers "move my data from here to there"
Copies backups to other Regions and accounts | Migrates NFS, SMB, HDFS or other clouds into AWS
Retention, cold storage, Vault Lock (WORM) | Verification, filters, bandwidth limits, schedules
```

| Everyday life | AWS |
|---|---|
| A fireproof safe | **Backup vault**: where the copies are stored, encrypted with a KMS key |
| A dated photocopy of your documents | **Recovery point**: one backup of one resource at one moment |
| "Copy everything every night, keep copies 35 days" | **Backup plan** with one or more **backup rules** |
| A sticker on each folder that says "back me up" | **Resource assignment by tag**, e.g. `backup=daily` |
| A second safe in another city | **Cross-Region copy** |
| A safe with a time lock even the owner can't open early | **Vault Lock** (write once, read many) |
| Movers who pack, drive and unpack your boxes | **DataSync task** (one run is a **task execution**) |
| The old house and the new house | **DataSync locations** (source and destination) |
| A mover working from inside your old house | **DataSync agent**: a VM next to storage AWS can't reach |

### Key words

| Word | Meaning |
|---|---|
| **Backup rule** | Schedule (cron), start and completion windows, lifecycle and copy actions |
| **Lifecycle** | When a recovery point moves to cheaper **cold storage**, and when it's deleted (**retention**) |
| **Restore** | Creating a **new** resource (or a new folder) from a recovery point. The original is never overwritten |
| **RPO / RTO** | How much data you can afford to lose / how fast you must be back |
| **Task mode** | DataSync **Basic** (all location types) or **Enhanced** (parallel and faster) |

```flow
🏷️ | Tag the resource | Add `backup=daily` to a volume, database or file system.
📅 | The rule fires | At 03:00 UTC, AWS Backup starts a **backup job** within the start window.
📦 | Recovery point in the vault | The copy is stored and encrypted.
🌍 | Copy to another Region | A copy action sends it to a vault in another Region or account.
🧊 | Cold storage (optional) | Older backups of supported types move to cheaper storage.
🗑️ | Expire | After the retention period, AWS Backup deletes the recovery point.
♻️ | Restore and test | Restore as a new resource, and check it regularly.
```

### Check yourself

1. What's the difference between a backup **plan** and a backup **vault**?
2. Why is a backup you have never restored not really a backup yet?
3. You must move 20 TB from an office NFS server to Amazon EFS. AWS Backup or DataSync?

> **Tip:** Answers: 1) The **plan** decides **when** and **for how long**; the **vault** is **where** the copies live. 2) Until you restore it, you don't know if it works, how long it takes, or whether the right data is in it. 3) **DataSync**, with an agent next to the NFS server. AWS Backup protects data that's already in AWS.

## What AWS Backup can protect

> **In simple words:** One service, many resource types, but not every feature works for every type. Check this table before you promise "cross-account copies" or "cold storage" to anyone.

| Resource | Copy to other Region / account | Cold storage | Continuous (point-in-time) | Fully managed |
|---|---|---|---|---|
| **EC2 instance** (AMI + EBS snapshots) | Yes | No | No | No |
| **EBS volume** | Yes | Yes (EBS Snapshots Archive) | No | No |
| **S3 bucket** (needs versioning) | Yes | No | Yes | Yes |
| **RDS DB instance**, **Aurora** | Yes | No | Yes | No |
| **DynamoDB** | Only with **advanced features** on | Only with advanced features | No | Only with advanced features |
| **EFS file system** | Yes | Yes | No | Yes |
| **FSx** (Windows, ONTAP, OpenZFS, Lustre) | Yes | No | No | No |

It also covers DocumentDB, Neptune, Redshift, Timestream, Storage Gateway, VMware VMs, SAP HANA on EC2, CloudFormation stacks and EKS clusters: see [Feature availability by resource](https://docs.aws.amazon.com/aws-backup/latest/devguide/backup-feature-availability.html).

**"Fully managed"** types (EFS, S3, ...) are encrypted with the **vault's KMS key**. The others (EBS, EC2, RDS, Aurora) **keep the source's encryption**: an unencrypted volume gives an unencrypted snapshot.

> **Note:** RDS and Aurora also have their **own** automated backups, explained in the [RDS guide](#/tool/aws-rds/step-5-backups-snapshots-and-restore). AWS Backup adds one central plan for everything, cross-account copies, Vault Lock and audit reports. Some types must be switched on per Region first: AWS Backup console → **Settings** → **Service opt-in** (CLI: `aws backup describe-region-settings`).

## Before you start: variables, a KMS key and the backup role

> **In simple words:** Set a few variables, create your own **encryption key** for the vault, create the **role** that AWS Backup uses to take and restore backups, and create a small **test volume** tagged `backup=daily`.

```bash
export AWS_REGION=us-east-1
export DR_REGION=us-west-2
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
VAULT=my-app-vault
AZ=${AWS_REGION}a

# a customer managed KMS key for the vault
KEY_ARN=$(aws kms create-key --description "AWS Backup vault key for my-app" \
  --query KeyMetadata.Arn --output text)
aws kms create-alias --alias-name alias/my-app-backup --target-key-id "$KEY_ARN"

# the IAM role that AWS Backup assumes
cat > backup-trust.json <<'EOF'
{"Version": "2012-10-17",
 "Statement": [{"Effect": "Allow", "Principal": {"Service": "backup.amazonaws.com"},
                "Action": "sts:AssumeRole"}]}
EOF
aws iam create-role --role-name my-app-backup-role --assume-role-policy-document file://backup-trust.json
for P in AWSBackupServiceRolePolicyForBackup AWSBackupServiceRolePolicyForRestores; do
  aws iam attach-role-policy --role-name my-app-backup-role \
    --policy-arn arn:aws:iam::aws:policy/service-role/$P
done
BACKUP_ROLE_ARN=$(aws iam get-role --role-name my-app-backup-role --query Role.Arn --output text)

# a small encrypted test volume, tagged for backup
VOL_ID=$(aws ec2 create-volume --availability-zone "$AZ" --size 1 --volume-type gp3 --encrypted \
  --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=my-app-data},{Key=backup,Value=daily}]' \
  --query VolumeId --output text)
VOL_ARN=arn:aws:ec2:$AWS_REGION:$ACCOUNT_ID:volume/$VOL_ID
```

The console creates a role called **`AWSBackupDefaultServiceRole`** (same two managed policies) the first time you assign resources or run an on-demand backup. In CLI or Terraform setups you create your own, as above. To back up **S3**, also attach `AWSBackupServiceRolePolicyForS3Backup` and `AWSBackupServiceRolePolicyForS3Restore`, and turn on bucket versioning.

AWS docs: [IAM service roles for AWS Backup](https://docs.aws.amazon.com/aws-backup/latest/devguide/iam-service-roles.html) · Related: [KMS guide](#/tool/aws-kms) · [IAM roles](#/tool/aws-iam/create-a-role-and-attach-a-policy)

## Step 1: Create a backup vault

> **In simple words:** Create the **safe** for your backups and lock it with your own KMS key. One vault per application or environment makes access rules, Vault Lock and clean-up simpler than putting everything in `Default`.

**Console:** AWS Backup console → **Backup vaults** → **Create backup vault** → Name `my-app-vault` → **Encryption key** `alias/my-app-backup` → **Create Backup vault**.

**CLI:**

```bash
aws backup create-backup-vault --backup-vault-name "$VAULT" \
  --encryption-key-arn "$KEY_ARN" --backup-vault-tags app=my-app
aws backup describe-backup-vault --backup-vault-name "$VAULT" \
  --query '{Name:BackupVaultName,Key:EncryptionKeyArn,RecoveryPoints:NumberOfRecoveryPoints}'
```

AWS docs: [Backup vault creation and deletion](https://docs.aws.amazon.com/aws-backup/latest/devguide/create-a-vault.html)

## Step 2: Create a backup plan

> **In simple words:** The plan is the **timetable**. Ours has two rules: a **daily** backup kept **35 days**, and a **monthly** backup kept **one year** that moves to cheaper cold storage after 30 days.

| Rule setting | Example | Meaning |
|---|---|---|
| **Schedule** | `cron(0 3 * * ? *)` | Minute, hour, day-of-month, month, day-of-week, year. **UTC** unless you set `ScheduleExpressionTimezone`. Monthly: `cron(0 4 1 * ? *)`; Sundays: `cron(0 5 ? * SUN *)` |
| **Start within** (`StartWindowMinutes`) | `60` | How long the job may wait to start. Minimum **60**; the default is 8 hours |
| **Complete within** (`CompletionWindowMinutes`) | `480` | The job is cancelled if not finished in time. Default 7 days |
| **Cold storage after** (`MoveToColdStorageAfterDays`) | `30` | Only for types that support it; ignored for others |
| **Retention** (`DeleteAfterDays`) | `35` | With cold storage, at least **90 days more** than the cold setting |
| **Copy actions** | DR vault | Copy each new backup to another vault (Step 6) |
| **Continuous backup** | `true` | Point-in-time restore for S3, RDS and Aurora |

**Console:** **Backup plans** → **Create backup plan** → **Build a new plan** → Name `my-app-plan`. Rule `daily-35d`: vault `my-app-vault`, frequency **Daily**, **Customize backup window** (start 03:00 UTC, start within 1 hour, complete within 8 hours), **Total retention period** 35 days. **Add backup rule** `monthly-1y`: **Monthly**, cold storage after 30 days, retention 365 days → **Create plan**.

**CLI:** save as `plan.json`, then create the plan:

```json
{
  "BackupPlanName": "my-app-plan",
  "Rules": [
    {
      "RuleName": "daily-35d",
      "TargetBackupVaultName": "my-app-vault",
      "ScheduleExpression": "cron(0 3 * * ? *)",
      "StartWindowMinutes": 60,
      "CompletionWindowMinutes": 480,
      "Lifecycle": { "DeleteAfterDays": 35 },
      "RecoveryPointTags": { "rule": "daily" }
    },
    {
      "RuleName": "monthly-1y",
      "TargetBackupVaultName": "my-app-vault",
      "ScheduleExpression": "cron(0 4 1 * ? *)",
      "StartWindowMinutes": 60,
      "CompletionWindowMinutes": 1440,
      "Lifecycle": { "MoveToColdStorageAfterDays": 30, "DeleteAfterDays": 365,
                     "OptInToArchiveForSupportedResources": true },
      "RecoveryPointTags": { "rule": "monthly" }
    }
  ]
}
```

```bash
PLAN_ID=$(aws backup create-backup-plan --backup-plan file://plan.json --query BackupPlanId --output text)
aws backup get-backup-plan --backup-plan-id "$PLAN_ID" \
  --query 'BackupPlan.Rules[].[RuleName,ScheduleExpression,Lifecycle.DeleteAfterDays]' --output table
```

`OptInToArchiveForSupportedResources` lets **EBS** snapshots move to the **EBS Snapshots Archive** tier. That's allowed only for **monthly or rarer** backups kept **more than 90 days**; archived snapshots are stored as full copies and can take **up to 72 hours** to restore. EFS cold storage needs no opt-in.

> **Cost:** Cold storage has a **90-day minimum**: a backup deleted earlier is still charged for the remaining days. Use it for long-term backups only.

AWS docs: [Create a backup plan](https://docs.aws.amazon.com/aws-backup/latest/devguide/creating-a-backup-plan.html)

## Step 3: Assign resources by tag

> **In simple words:** Tell the plan **what** to protect. With a **tag**, every resource tagged `backup=daily` is protected automatically, including resources created next month by Terraform. Nobody has to remember to "add it to the backup".

**Console:** open `my-app-plan` → **Assign resources** → Name `tag-backup-daily` → **IAM role** `my-app-backup-role` (or **Default role**) → **Include all resource types** → **Refine selection using tags**: key `backup`, **Equals**, value `daily` → **Assign resources**.

**CLI:**

```bash
cat > selection.json <<EOF
{
  "SelectionName": "tag-backup-daily",
  "IamRoleArn": "$BACKUP_ROLE_ARN",
  "ListOfTags": [{ "ConditionType": "STRINGEQUALS", "ConditionKey": "backup", "ConditionValue": "daily" }]
}
EOF
SELECTION_ID=$(aws backup create-backup-selection --backup-plan-id "$PLAN_ID" \
  --backup-selection file://selection.json --query SelectionId --output text)
aws backup list-backup-selections --backup-plan-id "$PLAN_ID" --output table
```

`ListOfTags` matches a resource with **any** of the listed tags. For stricter rules, use `Resources` (ARNs, wildcards allowed) with `Conditions` (all must match), and `NotResources` to exclude something.

> **Tip:** Agree on **one tag key** for the whole company (for example `backup` = `daily`, `weekly` or `none`) and set it in your Terraform modules. That's how real teams make sure new resources are never forgotten.

## Step 4: Run an on-demand backup

> **In simple words:** Don't wait until 03:00 to find out if it works. Start a backup **now**, watch the job, and find the new recovery point in the vault. Do the same before risky changes, such as an upgrade.

**Console:** **Protected resources** → **Create on-demand backup** → Resource type **EBS**, volume `my-app-data` → vault `my-app-vault` → retention 7 days → role `my-app-backup-role` → **Create on-demand backup**. Watch **Jobs** → **Backup jobs**.

**CLI:**

```bash
JOB_ID=$(aws backup start-backup-job --backup-vault-name "$VAULT" \
  --resource-arn "$VOL_ARN" --iam-role-arn "$BACKUP_ROLE_ARN" \
  --lifecycle DeleteAfterDays=7 --query BackupJobId --output text)

while true; do
  STATE=$(aws backup describe-backup-job --backup-job-id "$JOB_ID" --query State --output text)
  echo "$(date +%T) backup job: $STATE"
  case "$STATE" in COMPLETED|FAILED|ABORTED|EXPIRED|PARTIAL) break ;; esac
  sleep 30
done
aws backup describe-backup-job --backup-job-id "$JOB_ID" --query '{State:State,Message:StatusMessage}'

RP_ARN=$(aws backup describe-backup-job --backup-job-id "$JOB_ID" --query RecoveryPointArn --output text)
aws backup list-recovery-points-by-backup-vault --backup-vault-name "$VAULT" \
  --query 'RecoveryPoints[].[ResourceType,Status,CreationDate]' --output table
```

A job goes `CREATED` (waiting inside the start window, retried if needed) → `RUNNING` → `COMPLETED`. On `FAILED`, read `StatusMessage` (usually IAM, KMS or an unsupported resource). `EXPIRED` means it didn't start or finish within the windows.

## Step 5: Test a restore

> **In simple words:** A restore always creates a **new** resource, so testing never touches the original. Do it now and then regularly: it proves the backup works and tells you how long recovery really takes.

**Console:** **Backup vaults** → `my-app-vault` → select the recovery point → **Actions → Restore** → EBS volume, type `gp3`, size 1 GiB, AZ `us-east-1a` → role `my-app-backup-role` → **Restore backup**. Watch **Jobs** → **Restore jobs**.

**CLI:**

```bash
aws backup get-recovery-point-restore-metadata --backup-vault-name "$VAULT" \
  --recovery-point-arn "$RP_ARN" --query RestoreMetadata

RESTORE_ID=$(aws backup start-restore-job --recovery-point-arn "$RP_ARN" \
  --iam-role-arn "$BACKUP_ROLE_ARN" --resource-type EBS \
  --metadata availabilityZone=$AZ,volumeType=gp3,volumeSize=1,encrypted=true \
  --query RestoreJobId --output text)

while true; do
  STATUS=$(aws backup describe-restore-job --restore-job-id "$RESTORE_ID" --query Status --output text)
  echo "$(date +%T) restore job: $STATUS"
  case "$STATUS" in COMPLETED|FAILED|ABORTED) break ;; esac
  sleep 20
done

NEW_VOL_ARN=$(aws backup describe-restore-job --restore-job-id "$RESTORE_ID" --query CreatedResourceArn --output text)
NEW_VOL_ID=${NEW_VOL_ARN##*/}
aws ec2 describe-volumes --volume-ids "$NEW_VOL_ID" --query 'Volumes[0].[VolumeId,Size,State,Encrypted]' --output table
```

**Check the data, not just the status:** attach the restored volume to a test instance in the same AZ, mount it read-only and compare files or checksums with the original. The minutes the whole thing took are your real **RTO**.

| Resource | What a restore creates |
|---|---|
| EBS | A new volume (or selected files copied to an S3 bucket) |
| EC2 | A new instance from the backed-up AMI |
| RDS / Aurora | A new DB instance or cluster with a new endpoint |
| EFS | A **new file system**, or a **new folder in the source file system**; all files or selected items |
| S3 | The source or another bucket; all objects or selected ones |

**Automate it with restore testing:** AWS Backup console → **Restore testing** → **Create restore testing plan** → frequency, which vaults, latest or random recovery point within a window → **Assign resources** (by type, then all or by tag) → a **validation window** for your own checks. AWS Backup restores on schedule, records success and duration, then **deletes the restored resources**. You pay per tested recovery point plus normal restore charges.

AWS docs: [Restore an EBS volume](https://docs.aws.amazon.com/aws-backup/latest/devguide/restoring-ebs.html) · [Restore testing](https://docs.aws.amazon.com/aws-backup/latest/devguide/restore-testing.html)

## Step 6: Copy backups to another Region and account

> **In simple words:** A backup in the same Region and account doesn't help if the Region has a big outage or the account is compromised. **Copy actions** send each backup to a vault in **another Region** (disaster recovery) or **another account** (safe from someone deleting everything in the first one).

### Cross-Region copy

```bash
DR_KEY_ARN=$(aws kms create-key --region "$DR_REGION" --description "DR backup vault key" \
  --query KeyMetadata.Arn --output text)
aws backup create-backup-vault --region "$DR_REGION" --backup-vault-name my-app-vault-dr \
  --encryption-key-arn "$DR_KEY_ARN"
DR_VAULT_ARN=$(aws backup describe-backup-vault --region "$DR_REGION" \
  --backup-vault-name my-app-vault-dr --query BackupVaultArn --output text)

# copy one recovery point now
COPY_ID=$(aws backup start-copy-job --recovery-point-arn "$RP_ARN" \
  --source-backup-vault-name "$VAULT" --destination-backup-vault-arn "$DR_VAULT_ARN" \
  --iam-role-arn "$BACKUP_ROLE_ARN" --lifecycle DeleteAfterDays=7 --query CopyJobId --output text)
aws backup describe-copy-job --copy-job-id "$COPY_ID" --query 'CopyJob.[State,StatusMessage]'
```

To copy **every** backup, add `CopyActions` to the daily rule in `plan.json` and run `aws backup update-backup-plan --backup-plan-id "$PLAN_ID" --backup-plan file://plan.json`:

```json
{
  "RuleName": "daily-35d",
  "TargetBackupVaultName": "my-app-vault",
  "ScheduleExpression": "cron(0 3 * * ? *)",
  "Lifecycle": { "DeleteAfterDays": 35 },
  "CopyActions": [{
    "DestinationBackupVaultArn": "arn:aws:backup:us-west-2:111111111111:backup-vault:my-app-vault-dr",
    "Lifecycle": { "DeleteAfterDays": 35 }
  }]
}
```

> **Note:** Copies are re-encrypted with the **destination vault's key**. For types that aren't fully managed (EBS, EC2, RDS), that key must be a **customer managed key** (or the service's own key such as `aws/ebs`), not `aws/backup`, or the copy fails. Another reason to always create vaults with your own key.

### Cross-account copy

| Requirement | Where |
|---|---|
| Both accounts in the same **AWS Organization** | Organizations |
| **Cross-account backup** turned on: **Settings → Cross-account management** (CLI: `aws backup update-global-settings --global-settings isCrossAccountBackupEnabled=true`) | Management account |
| A vault with an **access policy** allowing `backup:CopyIntoBackupVault` | Destination account |
| Source resources encrypted with a **customer managed key** shared with the destination (AWS managed keys can't be shared) | Source account |
| Backups in **cold storage** can't be copied across accounts | Plan design |

The access policy on `central-vault` in the destination account `222222222222` (source account `111111111111`), applied with `aws backup put-backup-vault-access-policy --backup-vault-name central-vault --policy file://vault-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "AllowCopyFromWorkloadAccount",
    "Effect": "Allow",
    "Principal": { "AWS": "arn:aws:iam::111111111111:root" },
    "Action": "backup:CopyIntoBackupVault",
    "Resource": "*"
  }]
}
```

In the source account, the copy action's destination is then `arn:aws:backup:us-east-1:222222222222:backup-vault:central-vault`.

AWS docs: [Copies across Regions](https://docs.aws.amazon.com/aws-backup/latest/devguide/cross-region-backup.html) · [Copies across accounts](https://docs.aws.amazon.com/aws-backup/latest/devguide/create-cross-account-backup.html) · [Encryption for backups](https://docs.aws.amazon.com/aws-backup/latest/devguide/encryption.html)

## Step 7: Vault Lock: make backups undeletable

> **In simple words:** Ransomware and angry insiders try to **delete the backups first**. **Vault Lock** makes a vault **WORM** (write once, read many): nobody can delete a recovery point before its retention ends or shorten its lifecycle. In **compliance mode**, after a grace time, not even the root user or AWS can remove the lock.

```compare
🔓 Governance mode | 🔒 Compliance mode
Created without `--changeable-for-days` | Created with `--changeable-for-days` (3 or more)
Users with the right IAM permissions can change or remove the lock | During the grace time (at least 72 hours) you can still change or remove it
Good for testing and "only the backup team may delete" | After the lock date it is **immutable** forever
Easy to undo | Recovery points stay (and cost money) until their retention ends
```

**Console:** **Backup vaults** → `my-app-vault` → **Vault lock** → **Create vault lock** → **Governance** mode, minimum retention 7 days, maximum 365 days → **Create vault lock**.

**CLI (governance mode, safe to try):**

```bash
aws backup put-backup-vault-lock-configuration --backup-vault-name "$VAULT" \
  --min-retention-days 7 --max-retention-days 365
aws backup describe-backup-vault --backup-vault-name "$VAULT" \
  --query '{Locked:Locked,Min:MinRetentionDays,Max:MaxRetentionDays,LockDate:LockDate}'
# compliance mode would add: --changeable-for-days 3   (do NOT run this in a lab)
```

Once locked, backup and copy jobs whose retention is outside the min/max **fail**, and deleting a recovery point early gives `RecoveryPoint cannot be deleted or updated (Backup vault configured with Lock)`. A governance lock is removed with `aws backup delete-backup-vault-lock-configuration`; a compliance lock never (the empty vault can still be deleted).

> **Warning:** Test with **governance** mode first. Use compliance mode only when the retention numbers are agreed, because a mistake such as "keep for 3650 days" becomes a bill you can't stop.

AWS docs: [AWS Backup Vault Lock](https://docs.aws.amazon.com/aws-backup/latest/devguide/vault-lock.html)

## Step 8: Monitor: notifications, EventBridge and audits

> **In simple words:** A backup that fails silently for three months is worse than no backup, because everyone thinks they're safe. Send **failures** to people, and let **Backup Audit Manager** check every day that the rules are still followed.

Save this EventBridge pattern as `backup-failed-pattern.json`:

```json
{
  "source": ["aws.backup"],
  "detail-type": ["Backup Job State Change", "Copy Job State Change"],
  "detail": { "state": ["FAILED", "ABORTED", "EXPIRED"] }
}
```

```bash
TOPIC_ARN=$(aws sns create-topic --name my-app-backup-alerts --query TopicArn --output text)
aws sns subscribe --topic-arn "$TOPIC_ARN" --protocol email --notification-endpoint ops@example.com
cat > topic-policy.json <<EOF
{"Version": "2012-10-17",
 "Statement": [{"Sid": "AllowBackupAndEventBridge", "Effect": "Allow",
   "Principal": {"Service": ["backup.amazonaws.com", "events.amazonaws.com"]},
   "Action": "SNS:Publish", "Resource": "$TOPIC_ARN"}]}
EOF
aws sns set-topic-attributes --topic-arn "$TOPIC_ARN" --attribute-name Policy --attribute-value file://topic-policy.json

# option A: notifications from one vault
aws backup put-backup-vault-notifications --backup-vault-name "$VAULT" --sns-topic-arn "$TOPIC_ARN" \
  --backup-vault-events BACKUP_JOB_FAILED BACKUP_JOB_EXPIRED COPY_JOB_FAILED RESTORE_JOB_FAILED

# option B: an EventBridge rule for every vault in the Region
aws events put-rule --name my-app-backup-failed --event-pattern file://backup-failed-pattern.json
aws events put-targets --rule my-app-backup-failed --targets "Id=sns,Arn=$TOPIC_ARN"
```

Confirm the subscription email first. More on topics and rules: [SNS and SES guide](#/tool/aws-sns-ses) and [EventBridge in the CloudWatch guide](#/tool/aws-cloudwatch/step-10-react-to-aws-events-with-eventbridge).

| Feature | Where | What it gives you |
|---|---|---|
| **Jobs dashboard** | AWS Backup → **Jobs dashboard** | Completed, failed and expired jobs over time |
| **Backup Audit Manager frameworks** | AWS Backup → **Frameworks** | Daily checks such as "resources are in a backup plan", "minimum frequency and retention", "recovery points are encrypted", "cross-Region copy is scheduled", "resources are in a locked vault". Needs **AWS Config** recording |
| **Report plans** | AWS Backup → **Reports** | Daily job and compliance reports in an S3 bucket, for auditors |
| **CloudWatch metrics** | Namespace `AWS/Backup` | Alarms on numbers of failed jobs |

AWS docs: [Notification options](https://docs.aws.amazon.com/aws-backup/latest/devguide/backup-notifications.html) · [Audit Manager controls](https://docs.aws.amazon.com/aws-backup/latest/devguide/choosing-controls.html)

## AWS DataSync: when and how to use it

> **In simple words:** DataSync copies **files and objects** between storage systems, fast and with checks. It lists both sides, copies only what changed, and then **verifies** that they match. Use it to **migrate** once, or to **sync** on a schedule.

| You need to | Use |
|---|---|
| Migrate an office NFS or SMB server to **EFS** or **FSx** | **DataSync** with an agent |
| Copy between **S3, EFS and FSx**, or a nightly copy of a share to S3 | **DataSync** (no agent between AWS services) |
| Keep versions you can roll back to | **AWS Backup**, not DataSync |
| Copy S3 objects to another bucket continuously | **S3 Replication** ([S3 guide](#/tool/aws-s3/replication-and-event-notifications)) |
| Move a database | **AWS DMS** or native database tools |

| No agent needed | Agent needed |
|---|---|
| Between AWS storage services in the **same account** (same or another Region) | Between AWS and **on-premises** NFS, SMB, HDFS or object storage |
| Between **S3** and another AWS storage service **across accounts** | Between **EFS or FSx** and storage in **other clouds** |
| Between **S3** and object storage in **other clouds** | Across accounts when **neither side is S3** |

**Locations** you can use: Amazon S3, EFS, FSx for Windows File Server, FSx for NetApp ONTAP, FSx for OpenZFS, FSx for Lustre, and (with an agent where needed) NFS, SMB, HDFS, other object storage and Azure Blob. Each has a CLI command such as `create-location-s3`, `create-location-efs` or `create-location-fsx-ontap`.

```compare
⚡ Enhanced mode | 🐢 Basic mode
Lists, prepares, copies and verifies in parallel | Does the steps one after another
Virtually unlimited files and objects | Quotas on files and objects per task
Verifies only the data it transferred | Verifies the whole source and destination by default
Structured JSON logs and more metrics | Plain text logs
Per-GB price plus a fee per task run | Per-GB price only
Not for S3 on Outposts | Works with every location type
```

You choose the mode when you create a task and can't change it later. Options you'll actually use:

| Option | Values | What it does |
|---|---|---|
| `VerifyMode` | `POINT_IN_TIME_CONSISTENT` (Basic default), `ONLY_FILES_TRANSFERRED` (Enhanced default), `NONE` | How DataSync checks integrity at the end |
| `TransferMode` | `CHANGED` (default), `ALL` | Copy only differences, or everything |
| `OverwriteMode` | `ALWAYS` (default), `NEVER` | Whether changed destination files may be overwritten |
| `PreserveDeletedFiles` | `PRESERVE` (default), `REMOVE` | `REMOVE` makes a true **mirror**: deletions at the source are repeated at the destination |
| `PosixPermissions`, `Uid`, `Gid`, `Mtime` | `PRESERVE` / `INT_VALUE`, or `NONE` | Keep owners, permissions and times |
| `BytesPerSecond` | e.g. `10485760` (10 MiB/s); `-1` = no limit | Bandwidth limit for shared links |
| `LogLevel` | `OFF`, `BASIC`, `TRANSFER` | What goes to CloudWatch Logs |
| Include / exclude **filters** | `'/projects'`, `'*/tmp'`; several joined with `\|` | Copy only part of the source |
| **Schedule** | `rate(12 hours)` or cron | Recurring runs, at most once per hour |
| **Task report** | Summary or detailed, in S3 | Proof of what was transferred, skipped, verified or failed |

AWS docs: [What is DataSync?](https://docs.aws.amazon.com/datasync/latest/userguide/what-is-datasync.html) · [Do I need an agent?](https://docs.aws.amazon.com/datasync/latest/userguide/do-i-need-datasync-agent.html) · [Task modes](https://docs.aws.amazon.com/datasync/latest/userguide/choosing-task-mode.html) · [Task reports](https://docs.aws.amazon.com/datasync/latest/userguide/task-reports.html)

## Step 9: DataSync lab: prepare an S3 source and an EFS destination

> **In simple words:** The lab copies files from an **S3 bucket** to an **EFS file system**, a common job when an app moves from object storage to a shared file system. Both are AWS services in one account, so **no agent** is needed.

```bash
BUCKET=my-app-datasync-src-$ACCOUNT_ID
aws s3 mb "s3://$BUCKET"
mkdir -p sample/reports sample/tmp
for i in 1 2 3; do echo "report $i" > "sample/reports/report-$i.txt"; done
echo "scratch file" > sample/tmp/ignore-me.txt
aws s3 sync sample "s3://$BUCKET/data/"

# EFS in the default VPC, with a security group that allows NFS (2049) from itself
VPC_ID=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)
SUBNET_ID=$(aws ec2 describe-subnets --filters Name=vpc-id,Values="$VPC_ID" Name=availability-zone,Values="$AZ" \
  --query 'Subnets[0].SubnetId' --output text)
EFS_SG=$(aws ec2 create-security-group --vpc-id "$VPC_ID" --group-name my-app-efs-sg \
  --description "EFS mount target and DataSync" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id "$EFS_SG" --protocol tcp --port 2049 --source-group "$EFS_SG"

FS_ID=$(aws efs create-file-system --encrypted \
  --tags Key=Name,Value=my-app-efs Key=backup,Value=daily --query FileSystemId --output text)
until [ "$(aws efs describe-file-systems --file-system-id "$FS_ID" \
  --query 'FileSystems[0].LifeCycleState' --output text)" = "available" ]; do sleep 5; done
MT_ID=$(aws efs create-mount-target --file-system-id "$FS_ID" --subnet-id "$SUBNET_ID" \
  --security-groups "$EFS_SG" --query MountTargetId --output text)
until [ "$(aws efs describe-mount-targets --mount-target-id "$MT_ID" \
  --query 'MountTargets[0].LifeCycleState' --output text)" = "available" ]; do sleep 10; done
```

See the tag `backup=daily` on the file system: the plan from Step 3 now protects it too, with no change to the plan. More about EFS: [EFS and FSx guide](#/tool/aws-efs-fsx).

## Step 10: Create the DataSync locations and task

> **In simple words:** Give DataSync a **role** to read the bucket, describe the two **locations**, allow it to write **logs**, and create the **task** that joins them with your options.

**Console:** DataSync console → **Data transfer** → **Tasks** → **Create task** → **Source**: new Amazon S3 location, bucket `my-app-datasync-src-...`, folder `/data`, IAM role **Autogenerate** → **Destination**: Amazon EFS, `my-app-efs`, mount path `/imported`, a subnet in `us-east-1a`, security group `my-app-efs-sg`, in-transit encryption **TLS 1.2** → **Task mode** Basic → **Excludes** `/tmp` → logging: **Autogenerate** a log group → **Create task**.

**CLI:**

```bash
# 1) a role that lets DataSync read the source bucket
cat > datasync-trust.json <<EOF
{"Version": "2012-10-17",
 "Statement": [{"Effect": "Allow", "Principal": {"Service": "datasync.amazonaws.com"},
   "Action": "sts:AssumeRole",
   "Condition": {"StringEquals": {"aws:SourceAccount": "$ACCOUNT_ID"},
                 "ArnLike": {"aws:SourceArn": "arn:aws:datasync:$AWS_REGION:$ACCOUNT_ID:*"}}}]}
EOF
cat > datasync-s3-read.json <<EOF
{"Version": "2012-10-17",
 "Statement": [
   {"Effect": "Allow", "Resource": "arn:aws:s3:::$BUCKET",
    "Action": ["s3:GetBucketLocation", "s3:ListBucket", "s3:ListBucketMultipartUploads"]},
   {"Effect": "Allow", "Resource": "arn:aws:s3:::$BUCKET/*",
    "Action": ["s3:GetObject", "s3:GetObjectTagging", "s3:GetObjectVersion",
               "s3:GetObjectVersionTagging", "s3:ListMultipartUploadParts"]}]}
EOF
aws iam create-role --role-name my-app-datasync-s3-role --assume-role-policy-document file://datasync-trust.json
aws iam put-role-policy --role-name my-app-datasync-s3-role --policy-name read-source-bucket \
  --policy-document file://datasync-s3-read.json
DS_ROLE_ARN=$(aws iam get-role --role-name my-app-datasync-s3-role --query Role.Arn --output text)
sleep 15   # give IAM a moment

# 2) the two locations
SRC_LOC=$(aws datasync create-location-s3 --s3-bucket-arn "arn:aws:s3:::$BUCKET" \
  --subdirectory /data --s3-config BucketAccessRoleArn="$DS_ROLE_ARN" --query LocationArn --output text)
DST_LOC=$(aws datasync create-location-efs \
  --efs-filesystem-arn "arn:aws:elasticfilesystem:$AWS_REGION:$ACCOUNT_ID:file-system/$FS_ID" \
  --subdirectory /imported --in-transit-encryption TLS1_2 \
  --ec2-config SubnetArn="arn:aws:ec2:$AWS_REGION:$ACCOUNT_ID:subnet/$SUBNET_ID",SecurityGroupArns="arn:aws:ec2:$AWS_REGION:$ACCOUNT_ID:security-group/$EFS_SG" \
  --query LocationArn --output text)

# 3) a log group that DataSync may write to
aws logs create-log-group --log-group-name /aws/datasync/my-app
cat > datasync-logs-policy.json <<EOF
{"Version": "2012-10-17",
 "Statement": [{"Sid": "DataSyncLogsToCloudWatchLogs", "Effect": "Allow",
   "Principal": {"Service": "datasync.amazonaws.com"},
   "Action": ["logs:PutLogEvents", "logs:CreateLogStream"],
   "Condition": {"ArnLike": {"aws:SourceArn": ["arn:aws:datasync:$AWS_REGION:$ACCOUNT_ID:task/*"]},
                 "StringEquals": {"aws:SourceAccount": "$ACCOUNT_ID"}},
   "Resource": "arn:aws:logs:$AWS_REGION:$ACCOUNT_ID:log-group:*:*"}]}
EOF
aws logs put-resource-policy --policy-name datasync-to-logs --policy-document file://datasync-logs-policy.json

# 4) the task
TASK_ARN=$(aws datasync create-task --name my-app-s3-to-efs \
  --source-location-arn "$SRC_LOC" --destination-location-arn "$DST_LOC" --task-mode BASIC \
  --cloud-watch-log-group-arn "arn:aws:logs:$AWS_REGION:$ACCOUNT_ID:log-group:/aws/datasync/my-app" \
  --options VerifyMode=POINT_IN_TIME_CONSISTENT,TransferMode=CHANGED,OverwriteMode=ALWAYS,PreserveDeletedFiles=PRESERVE,LogLevel=TRANSFER \
  --excludes FilterType=SIMPLE_PATTERN,Value='/tmp' \
  --query TaskArn --output text)
```

| Piece | Why it's needed |
|---|---|
| S3 location **role** | DataSync reads the bucket as this role. For a **destination** bucket, also allow `PutObject`, `DeleteObject`, `AbortMultipartUpload` and `PutObjectTagging` |
| EFS **subnet** | DataSync creates network interfaces there: same VPC as the file system, same AZ as a mount target |
| EFS **security group** | Must allow NFS **TCP 2049** to the mount target. Reusing the mount target's own group is simplest |
| Logs **resource policy** | Without it, a failed task has no detailed errors |

AWS docs: [S3 locations](https://docs.aws.amazon.com/datasync/latest/userguide/create-s3-location.html) · [EFS locations](https://docs.aws.amazon.com/datasync/latest/userguide/create-efs-location.html) · [Logging](https://docs.aws.amazon.com/datasync/latest/userguide/configure-logging.html)

## Step 11: Run the task and check the result

> **In simple words:** Start the task, watch its phases, read the counters, then prove that a second run copies **only what changed**.

**Console:** **Tasks** → `my-app-s3-to-efs` → **Start** → **Start with defaults**, then open the **History** tab.

**CLI:**

```bash
run_task() {
  EXEC_ARN=$(aws datasync start-task-execution --task-arn "$TASK_ARN" --query TaskExecutionArn --output text)
  while true; do
    STATUS=$(aws datasync describe-task-execution --task-execution-arn "$EXEC_ARN" --query Status --output text)
    echo "$(date +%T) $STATUS"
    case "$STATUS" in SUCCESS|ERROR) break ;; esac
    sleep 15
  done
  aws datasync describe-task-execution --task-execution-arn "$EXEC_ARN" \
    --query '{Status:Status,Files:FilesTransferred,Bytes:BytesTransferred,Error:Result.ErrorCode,Detail:Result.ErrorDetail}'
}

run_task                                   # first run: 3 report files, tmp/ skipped
aws logs tail /aws/datasync/my-app --since 30m

echo "report 4" > sample/reports/report-4.txt
aws s3 cp sample/reports/report-4.txt "s3://$BUCKET/data/reports/"
run_task                                   # second run: only the new file
```

A run goes `QUEUED` → `LAUNCHING` → `PREPARING` (listing both sides) → `TRANSFERRING` → `VERIFYING` → `SUCCESS` or `ERROR`. To see the files, mount the file system on an EC2 instance in the same VPC with `my-app-efs-sg` attached (`sudo mount -t efs -o tls FS_ID:/ /mnt/efs` after installing `amazon-efs-utils`), then look in `/mnt/efs/imported`.

**Make it recurring:** `aws datasync update-task --task-arn "$TASK_ARN" --schedule ScheduleExpression="rate(12 hours)"`. DataSync may pause a schedule by itself when a task keeps failing with the same error, so alarm on failures too.

## DataSync agents: on-premises and other clouds

> **In simple words:** AWS can't reach into your data center, so DataSync gives you an **agent VM** to run **next to your file server**. You start it, **activate** it once with a key that links it to your account and Region, and use it in NFS, SMB or HDFS locations.

```flow
🖥️ | Deploy the agent | A VMware ESXi, KVM or Hyper-V image, or an EC2 instance from the DataSync AMI.
🌐 | Open the network | Mainly outbound HTTPS (443) to AWS; extra ports with a VPC endpoint.
🔑 | Get an activation key | Console, the agent's local console, or `curl` on port 80 (closed after activation).
✅ | Activate | `create-agent` within 30 minutes, before the key expires.
📁 | Create the location | An NFS, SMB or HDFS location that uses the agent.
🚚 | Run tasks | Exactly like the S3 to EFS lab.
```

```bash
DS_AMI=$(aws ssm get-parameter --name /aws/service/datasync/ami --query Parameter.Value --output text)
echo "launch an EC2 instance from $DS_AMI (Basic mode agent image), then:"

AGENT_IP=10.0.1.50                          # replace with the agent's private IP
ACTIVATION_KEY=$(curl -s "http://$AGENT_IP/?gatewayType=SYNC&activationRegion=$AWS_REGION&no_redirect")
AGENT_ARN=$(aws datasync create-agent --agent-name my-app-agent \
  --activation-key "$ACTIVATION_KEY" --query AgentArn --output text)
aws datasync list-agents --query 'Agents[].[Name,Status]' --output table   # want ONLINE

NFS_LOC=$(aws datasync create-location-nfs --server-hostname nfs.example.com \
  --subdirectory /exports/projects --on-prem-config AgentArns="$AGENT_ARN" --query LocationArn --output text)
```

Good practice: use a **VPC endpoint** with Direct Connect or VPN so traffic avoids the public internet ([PrivateLink guide](#/tool/aws-privatelink)); put the agent close to the storage; split huge datasets into several tasks with one agent each; limit `BytesPerSecond` during office hours; and finish a migration with one last sync during a short freeze, which copies only recent changes.

AWS docs: [Deploy an agent](https://docs.aws.amazon.com/datasync/latest/userguide/deploy-agents.html) · [Network requirements](https://docs.aws.amazon.com/datasync/latest/userguide/datasync-network.html)

## Troubleshooting

> **In simple words:** Most backup problems are **permissions, keys or windows**. Most DataSync problems are **network paths and security groups**. Read the job's `StatusMessage` or the task's log group first.

| Problem | Likely cause | Fix |
|---|---|---|
| Backup job `FAILED`, access denied | Role lacks `AWSBackupServiceRolePolicyForBackup`, or you may not `iam:PassRole` it | Attach the policy; allow `iam:PassRole` on the role |
| Backup job fails with a KMS error | The role can't use the source resource's key or the vault key | Allow the role in the key policy (or in IAM, if the key policy delegates to IAM) |
| A resource is never backed up | Tag typo (`Backup` vs `backup`), type not opted in, or resource in another Region | Check tags, **Settings → Service opt-in**, and the plan's Region |
| Job `EXPIRED` | Didn't start or finish inside the windows | Increase **Start within** / **Complete within**; spread schedules |
| Copy job fails | Destination vault uses `aws/backup` for EBS/EC2/RDS, key not shared, no vault access policy, cross-account backup off | Customer managed key, share it, add the policy, turn on the setting |
| Can't delete a vault | It still has recovery points | Delete them first (see Clean up) |
| Can't delete a recovery point | Vault Lock or a legal hold | Remove a **governance** lock; a **compliance** lock means waiting for retention |
| Cold storage setting rejected | Retention isn't 90+ days longer than the cold setting | Increase `DeleteAfterDays` |
| No SNS emails | Topic policy misses `backup.amazonaws.com`, email not confirmed, or topic encrypted with the AWS managed SNS key | Fix the policy, confirm, use a customer managed key |
| DataSync can't mount EFS / stuck in `LAUNCHING` | No TCP 2049 to the mount target, or subnet in an AZ without a mount target | Allow 2049 from the DataSync security group; pick a mount target's AZ |
| DataSync S3 access denied | Role permissions, a bucket policy deny, or an SSE-KMS key that doesn't allow the role | Use the documented permissions; update bucket and key policies |
| Agent `OFFLINE` | VM stopped, firewall blocks outbound 443, endpoint unreachable | Check the VM, firewall and endpoint security group |
| Verification failed | Files changed during the run, or an EFS access point rewrote owners | Run outside working hours; avoid identity-enforcing access points when preserving owners |

## Clean up

> **In simple words:** Delete in reverse order: DataSync first, then the backup plan, then **every recovery point**, then the vaults, keys and test resources. A vault refuses to be deleted while it still holds backups.

```bash
# DataSync (if you made an agent: aws datasync delete-agent, then terminate its instance)
aws datasync delete-task --task-arn "$TASK_ARN"
for L in "$SRC_LOC" "$DST_LOC"; do aws datasync delete-location --location-arn "$L"; done
aws logs delete-log-group --log-group-name /aws/datasync/my-app
aws logs delete-resource-policy --policy-name datasync-to-logs
aws iam delete-role-policy --role-name my-app-datasync-s3-role --policy-name read-source-bucket
aws iam delete-role --role-name my-app-datasync-s3-role

# EFS and the source bucket
aws efs delete-mount-target --mount-target-id "$MT_ID"
until [ "$(aws efs describe-mount-targets --file-system-id "$FS_ID" \
  --query 'length(MountTargets)' --output text)" = "0" ]; do sleep 10; done
aws efs delete-file-system --file-system-id "$FS_ID"
aws ec2 delete-security-group --group-id "$EFS_SG"
aws s3 rb "s3://$BUCKET" --force

# alerts, plan and Vault Lock
aws events remove-targets --rule my-app-backup-failed --ids sns
aws events delete-rule --name my-app-backup-failed
aws backup delete-backup-vault-notifications --backup-vault-name "$VAULT"
aws sns delete-topic --topic-arn "$TOPIC_ARN"
aws backup delete-backup-selection --backup-plan-id "$PLAN_ID" --selection-id "$SELECTION_ID"
aws backup delete-backup-plan --backup-plan-id "$PLAN_ID"
aws backup delete-backup-vault-lock-configuration --backup-vault-name "$VAULT"

# recovery points first, then the vaults (in both Regions)
empty_vault() {   # region vault
  for RP in $(aws backup list-recovery-points-by-backup-vault --region "$1" --backup-vault-name "$2" \
      --query 'RecoveryPoints[].RecoveryPointArn' --output text); do
    aws backup delete-recovery-point --region "$1" --backup-vault-name "$2" --recovery-point-arn "$RP"
  done
}
empty_vault "$AWS_REGION" "$VAULT"
empty_vault "$DR_REGION" my-app-vault-dr
sleep 60   # deletions are asynchronous
aws backup delete-backup-vault --backup-vault-name "$VAULT"
aws backup delete-backup-vault --region "$DR_REGION" --backup-vault-name my-app-vault-dr

# volumes, role and keys (keys are deleted after a 7-day waiting period)
aws ec2 delete-volume --volume-id "$NEW_VOL_ID"
aws ec2 delete-volume --volume-id "$VOL_ID"
for P in AWSBackupServiceRolePolicyForBackup AWSBackupServiceRolePolicyForRestores; do
  aws iam detach-role-policy --role-name my-app-backup-role --policy-arn arn:aws:iam::aws:policy/service-role/$P
done
aws iam delete-role --role-name my-app-backup-role
aws kms delete-alias --alias-name alias/my-app-backup
aws kms schedule-key-deletion --key-id "$KEY_ARN" --pending-window-in-days 7
aws kms schedule-key-deletion --region "$DR_REGION" --key-id "$DR_KEY_ARN" --pending-window-in-days 7
```

If the plan backed up the EFS file system before you deleted it, that recovery point was in `my-app-vault` and the loop removed it. At the end, **Protected resources** and **Backup vaults** should be empty except for `Default`. In real projects, define all of this with **Terraform** (`aws_backup_vault`, `aws_backup_plan`, `aws_backup_selection`, `aws_datasync_location_s3`, `aws_datasync_location_efs`, `aws_datasync_task`): see the [Terraform guide](#/tool/terraform).

## Lab and cheat sheet

> **In simple words:** Practice the full cycle: back up, restore, copy, lock, alert, and move data with DataSync. Then break something on purpose and fix it with the troubleshooting table.

1. Create `my-app-vault` with your own KMS key and a plan with a daily rule (35 days) and a monthly rule (cold after 30 days, 365 days).
2. Assign resources by the tag `backup=daily`, tag a volume, and run an on-demand backup.
3. Restore it to a new volume, attach it to a test instance and compare a file. How many minutes did it take?
4. Copy the recovery point to `us-west-2`, then add `CopyActions` to the daily rule.
5. Add a **governance** Vault Lock, try to delete a recovery point, read the error, then remove the lock.
6. Create the SNS topic and EventBridge rule, then cause a failure (detach `AWSBackupServiceRolePolicyForBackup` and run a backup). Did the email arrive? Re-attach the policy.
7. In the console, create a **restore testing plan** for EBS and an Audit Manager **framework** with two controls.
8. Run the DataSync S3 → EFS lab, add a file and confirm the second run copies only that file.
9. Set `PreserveDeletedFiles=REMOVE`, delete a file in S3, run again and watch it disappear from EFS. Why is that a mirror, not a backup?
10. Clean up and check that no vault, recovery point, file system, task or location is left.

### Cheat sheet

| Task | Command |
|---|---|
| Create a vault | `aws backup create-backup-vault --backup-vault-name V --encryption-key-arn KEY` |
| Create a plan | `aws backup create-backup-plan --backup-plan file://plan.json` |
| Assign by tag | `aws backup create-backup-selection --backup-plan-id P --backup-selection file://selection.json` |
| On-demand backup | `aws backup start-backup-job --backup-vault-name V --resource-arn ARN --iam-role-arn ROLE` |
| Failed jobs | `aws backup list-backup-jobs --by-state FAILED` |
| List backups | `aws backup list-recovery-points-by-backup-vault --backup-vault-name V` |
| Restore | `aws backup start-restore-job --recovery-point-arn RP --iam-role-arn ROLE --metadata k=v,...` |
| Copy | `aws backup start-copy-job --recovery-point-arn RP --source-backup-vault-name V --destination-backup-vault-arn DEST --iam-role-arn ROLE` |
| Vault Lock | `aws backup put-backup-vault-lock-configuration --backup-vault-name V --min-retention-days 7` |
| Delete a backup | `aws backup delete-recovery-point --backup-vault-name V --recovery-point-arn RP` |
| DataSync locations | `aws datasync create-location-s3 ...` / `create-location-efs ...` / `create-location-nfs ...` |
| DataSync task | `aws datasync create-task --source-location-arn SRC --destination-location-arn DST --options ...` |
| Run and watch | `aws datasync start-task-execution --task-arn T` + `describe-task-execution --task-execution-arn E` |
| Agents | `aws datasync list-agents` |
