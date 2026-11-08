# Amazon SNS and SES: Notifications and Email

AWS has two services that "send messages", and new joiners often mix them up. **Amazon SNS** (Simple Notification Service) takes **one message and fans it out** to many subscribers at once: email, SMS, HTTPS, Lambda functions and SQS queues. **Amazon SES** (Simple Email Service) sends **real emails from your own app and domain** to your customers. This guide builds both step by step: an alert topic with email and queue subscribers, KMS encryption, filters, a dead-letter queue and chat alerts, then a verified SES domain with DKIM, SPF and DMARC, test emails, bounce notifications and SMTP credentials. Every step shows the **console clicks** and the matching **AWS CLI** commands.

> **Cost:** **SNS:** every month the first 1 million publishes, 100,000 HTTP/S deliveries and 1,000 email deliveries are free. After that it's about **$0.50 per million publishes**, **$0.06 per 100,000 HTTP/S deliveries** and **$2.00 per 100,000 email deliveries**. Deliveries to SQS and Lambda have no per-delivery fee (only data transfer), and SMS prices depend on the country. **SES:** new accounts start on the **Essentials plan at $0.16 per 1,000 emails**; you can switch to **à la carte pricing at $0.10 per 1,000 emails** (plus $0.12 per GB of attachments). Emails to the SES mailbox simulator are billed like normal emails. The customer managed **KMS key** in Step 4 costs $1 per month (prorated per hour). The whole lab costs a few cents. See [SNS pricing](https://aws.amazon.com/sns/pricing/) and [SES pricing](https://aws.amazon.com/ses/pricing/).

## Start here: SNS and SES in simple words

> **In simple words:** **SNS** is a **group announcement**: you say something once into a topic, and everyone who joined that topic hears it (a person's inbox, a phone, a program). **SES** is your company's **post office**: it delivers proper letters (emails) with your company's name and letterhead on them, to any customer's mailbox, and tells you when a letter comes back.

### SNS or SES: which one?

```compare
📣 Amazon SNS | ✉️ Amazon SES
One message fans out to many subscribers at once | One email per recipient, sent from your app
Subscribers: email, SMS, HTTPS, Lambda, SQS, mobile push | Recipients: any email inbox (after you leave the sandbox)
For alerts, events and app-to-app messages | For sign-up, password reset, receipts, reports, newsletters
Emails are plain "AWS Notification" messages with an unsubscribe link | You control the From address, subject, HTML and attachments
Each email or HTTPS subscriber must confirm first | You must verify the sender domain or address first
Billed per publish and per delivery | Billed per email sent (plus attachment data)
```

**Rule of thumb:** alerts for **your team** go through **SNS**. Emails for **your customers** go through **SES**. Never send customer emails with SNS: the sender isn't your domain, and every SNS email carries an "unsubscribe from this topic" link.

### Everyday comparison

| Everyday life | AWS |
|---|---|
| A group chat or a loudspeaker: say it once, everyone in the group hears it | **SNS topic** |
| Joining the group, and replying "yes, add me" | **Subscription** and **confirmation** |
| "Only call me for urgent things" | **Filter policy** on a subscription |
| The group rules: who is allowed to post | **Topic access policy** |
| A sealed envelope only some people can open | **Encryption with a KMS key** |
| The post office's box of undeliverable letters | **Dead-letter queue (DLQ)** |
| A post office that delivers letters with your company letterhead | **SES** |
| Proving to the post office that the letterhead is really yours | **Verified identity** (domain with DKIM, or one email address) |
| A trainee period: you may only send to people you know | **SES sandbox** |
| Letters that come back, and "stop sending me this" | **Bounces** and **complaints** |

### What we'll build with SNS

```text
  CloudWatch alarm    EventBridge rule    your app
          │                   │               │
          └───────────────────┼───────────────┘
                              ▼
                   ┌─────────────────────┐
                   │  SNS topic          │  access policy
                   │  my-app-alerts      │  + KMS key
                   └──────────┬──────────┘
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
        email            SQS queue             Lambda
     (everything)     (critical only)      (Slack / Teams)
                              │ fails after retries
                              ▼
                      dead-letter queue
```

### Key words

| Word | Meaning |
|---|---|
| **Topic** | A named channel in SNS. Publishers send to it; subscribers receive from it |
| **Publish** | Send one message to a topic |
| **Subscription** | One receiver of a topic: an email address, a phone, a URL, a Lambda function or an SQS queue |
| **Standard topic** | The normal topic type: very high throughput, best-effort order, a message can rarely arrive twice |
| **FIFO topic** | "First in, first out": strict order and no duplicates, but only SQS queues can subscribe |
| **Message attributes** | Small labels sent with a message, such as `severity=critical`. Filters use them |
| **Filter policy** | A rule on a subscription: "only give me messages whose attributes match this" |
| **Access policy** | A JSON policy on the topic that says who may publish or subscribe |
| **KMS key** | An encryption key in AWS Key Management Service (see [KMS](#/tool/aws-kms)) |
| **SQS** | Simple Queue Service: a queue that holds messages until a program reads them |
| **DLQ** | Dead-letter queue: an SQS queue that keeps messages SNS could not deliver |
| **Identity (SES)** | A domain or email address you have proved you own, so SES lets you send from it |
| **DKIM** | A digital signature on every email, checked with a public key in your DNS |
| **SPF** | A DNS record that lists which servers may send mail for a domain |
| **DMARC** | A DNS record that tells mailbox providers what to do when SPF or DKIM checks fail |
| **Sandbox (SES)** | The starting mode: you can only send to verified addresses, 200 emails a day |
| **Bounce** | An email that could not be delivered (for example, the address doesn't exist) |
| **Complaint** | The recipient clicked "This is spam" |
| **Configuration set** | A group of SES settings, such as "send bounce events to this SNS topic" |

### Check yourself

1. Your CloudWatch alarm fires, but no email arrives. The topic is encrypted with the AWS managed key `alias/aws/sns`. Why?
2. Your SES account is still in the sandbox. Can you send a welcome email to a new customer?
3. The team mailbox should get every alert, but the on-call system only critical ones. Which SNS feature does that?

> **Tip:** Answers: 1) CloudWatch isn't allowed to use that key, and you can't change an AWS managed key's policy. Use a **customer managed key** whose key policy allows `cloudwatch.amazonaws.com` (Step 4). 2) No. In the sandbox you can send only to **verified** addresses; request production access first (Step 14). 3) A **filter policy** on the on-call subscription (Step 5).

## Before you start: variables

> **In simple words:** Set a few shell variables once, so every command in this guide can reuse them. Use your **real email address**: you'll click links in emails it receives.

You need the AWS CLI v2 signed in as an admin user (see [Create your AWS account](#/tool/aws-account) and [Workstation setup](#/tool/setup)). For the SES domain steps you also need a domain with a **Route 53 hosted zone** (see [Route 53](#/tool/aws-route53/hosted-zones-public-and-private)); if you don't have one, you can still do everything with a single verified email address.

```bash
export AWS_REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
EMAIL=you@example.com          # your real email address
DOMAIN=example.com             # a domain you own, hosted in Route 53 (optional)

mkdir -p ~/sns-ses-lab && cd ~/sns-ses-lab
echo "Account $ACCOUNT_ID, Region $AWS_REGION"
```

## Standard or FIFO topic?

> **In simple words:** Choose the topic type when you create it; you can't change it later. For alerts and notifications, always use **Standard**. Use **FIFO** only when the order of messages really matters, for example "price changed" events that must be applied in sequence.

| | Standard topic | FIFO topic |
|---|---|---|
| Order | Best effort | Strict order inside each **message group** |
| Duplicates | Rare duplicates are possible (at-least-once) | Removed within a 5-minute window (deduplication ID or content-based) |
| Subscribers | Email, SMS, HTTP/S, Lambda, SQS, Firehose, mobile push | **SQS queues only** (FIFO or standard) |
| Name | Any name | Must end with `.fifo` (create it with `--attributes FifoTopic=true`) |
| Used by AWS services | CloudWatch alarms, EventBridge, SES and others publish here | Mostly your own apps (SES, for example, does **not** support FIFO topics) |

AWS docs: [What is Amazon SNS?](https://docs.aws.amazon.com/sns/latest/dg/welcome.html) · [FIFO topics](https://docs.aws.amazon.com/sns/latest/dg/sns-fifo-topics.html)

## Step 1: Create a topic and an email subscription

> **In simple words:** Create the topic `my-app-alerts`, then subscribe your email address to it. SNS sends you a confirmation email first; nothing is delivered to you until you click **Confirm subscription**. This protects people from being subscribed to things against their will.

**Console:** **SNS** → **Topics** → **Create topic** → Type **Standard**, Name `my-app-alerts` → **Create topic**. On the topic page: **Create subscription** → Protocol **Email**, Endpoint your email → **Create subscription**. Open the email "AWS Notification - Subscription Confirmation" and choose **Confirm subscription**.

**CLI:**

```bash
TOPIC_ARN=$(aws sns create-topic --name my-app-alerts --query TopicArn --output text)
echo "$TOPIC_ARN"     # arn:aws:sns:us-east-1:111111111111:my-app-alerts

aws sns subscribe --topic-arn "$TOPIC_ARN" --protocol email --notification-endpoint "$EMAIL"
# now open your inbox (and spam folder) and click "Confirm subscription"

aws sns list-subscriptions-by-topic --topic-arn "$TOPIC_ARN" \
  --query 'Subscriptions[].[Protocol,Endpoint,SubscriptionArn]' --output table
# SubscriptionArn shows "PendingConfirmation" until you click the link
```

The confirmation link is valid for **2 days**. If it expires, select the subscription in the console and choose **Request confirmation**, or subscribe again.

### Subscription types

| Protocol | Endpoint example | Needs confirmation? | Good for |
|---|---|---|---|
| `email` | `ops@example.com` | Yes | People. Limited to 10 messages per second per subscription |
| `email-json` | `ops@example.com` | Yes | Programs that read the full JSON envelope |
| `sms` | `+15555550100` | No | Urgent pages. New accounts start in an **SMS sandbox** with a $1.00 default spend limit |
| `https` | `https://hooks.example.com/sns` | Yes (your server must answer the confirmation request) | Webhooks into other tools |
| `lambda` | A function ARN | No (the function needs a permission) | Custom actions, e.g. post to chat (Step 8) |
| `sqs` | A queue ARN | No in the same account (the queue needs a policy) | Reliable processing by programs (Step 5) |

> **Tip:** Every SNS email has an **unsubscribe** link, and anyone who receives a forwarded copy can click it. For important alert lists, confirm the subscription yourself with `aws sns confirm-subscription --topic-arn "$TOPIC_ARN" --token TOKEN --authenticate-on-unsubscribe true` (the token is the `Token=` value in the confirmation link). Then only someone signed in to AWS can unsubscribe.

## Step 2: Publish a test message

> **In simple words:** Send one message to the topic and check that it lands in your inbox. You can also attach **message attributes** (labels such as `severity`), which the filters in Step 5 will use.

**Console:** **Topics** → `my-app-alerts` → **Publish message** → Subject `Test from the console`, Message body `Hello from SNS` → (optional) add **Message attributes** → **Publish message**.

**CLI:**

```bash
aws sns publish --topic-arn "$TOPIC_ARN" \
  --subject "Test from the CLI" \
  --message "Hello from SNS. If you can read this, the topic works."

# the same, with message attributes
aws sns publish --topic-arn "$TOPIC_ARN" \
  --subject "Disk almost full on web-1" \
  --message "web-1: disk 91% used" \
  --message-attributes '{"severity":{"DataType":"String","StringValue":"high"},"service":{"DataType":"String","StringValue":"web"}}'
```

| Option | What it does |
|---|---|
| `--subject` | The email subject line (under 100 characters). Ignored by SQS and Lambda subscribers |
| `--message` | The text. Up to **256 KiB** by default; a topic can raise this to 1 MiB with the `MaximumMessageSize` attribute |
| `--message-attributes` | Labels for filtering, sent next to the message, not inside it |
| `--message-structure json` | Send a different text per protocol, e.g. a short one for SMS and a long one for email |

Billing note: each **64 KB chunk** of a message counts as one request, so a 256 KiB message is billed as 4 publishes.

## Step 3: The topic access policy: who may publish

> **In simple words:** Every topic has an **access policy** (a resource policy) that works like the group rules: who may post and who may join. The default policy lets only your own account in. AWS services such as **EventBridge**, **SES** and **S3**, and **other AWS accounts**, need their own "allow" statement.

**Console:** **Topics** → `my-app-alerts` → **Edit** → expand **Access policy - optional** → edit the JSON → **Save changes**.

**CLI:** replace the default policy with one that keeps full control for your account and lets CloudWatch alarms and EventBridge rules from **your account only** publish:

```bash
cat > topic-policy.json <<EOF
{"Version": "2012-10-17", "Statement": [
  {"Sid": "OwnerFullControl", "Effect": "Allow", "Principal": {"AWS": "arn:aws:iam::${ACCOUNT_ID}:root"},
   "Action": ["sns:Publish", "sns:Subscribe", "sns:GetTopicAttributes", "sns:SetTopicAttributes",
              "sns:ListSubscriptionsByTopic", "sns:DeleteTopic"], "Resource": "${TOPIC_ARN}"},
  {"Sid": "AllowCloudWatchAlarms", "Effect": "Allow", "Principal": {"Service": "cloudwatch.amazonaws.com"},
   "Action": "sns:Publish", "Resource": "${TOPIC_ARN}",
   "Condition": {"ArnLike": {"aws:SourceArn": "arn:aws:cloudwatch:${AWS_REGION}:${ACCOUNT_ID}:alarm:*"},
                 "StringEquals": {"aws:SourceAccount": "${ACCOUNT_ID}"}}},
  {"Sid": "AllowEventBridgeRules", "Effect": "Allow", "Principal": {"Service": "events.amazonaws.com"},
   "Action": "sns:Publish", "Resource": "${TOPIC_ARN}",
   "Condition": {"StringEquals": {"aws:SourceAccount": "${ACCOUNT_ID}"}}}
]}
EOF
python3 -m json.tool topic-policy.json > /dev/null && echo "policy JSON is valid"

aws sns set-topic-attributes --topic-arn "$TOPIC_ARN" \
  --attribute-name Policy --attribute-value file://topic-policy.json
aws sns get-topic-attributes --topic-arn "$TOPIC_ARN" --query Attributes.Policy --output text
```

The `aws:SourceAccount` and `aws:SourceArn` conditions stop the **confused deputy** problem: without them, a CloudWatch alarm in *someone else's* account could be pointed at your topic.

**Let another AWS account publish** (for example a shared "alerts" account): add a statement like this to the `Statement` list. The other account also needs `sns:Publish` in its own IAM policy.

```json
{"Sid": "AllowOtherAccountToPublish", "Effect": "Allow",
 "Principal": {"AWS": "arn:aws:iam::222222222222:root"},
 "Action": "sns:Publish", "Resource": "arn:aws:sns:us-east-1:111111111111:my-app-alerts"}
```

| Publisher | Topic access policy needs | If the topic uses your KMS key, the key policy needs |
|---|---|---|
| CloudWatch alarm | `cloudwatch.amazonaws.com` (or the default policy, same account) | `cloudwatch.amazonaws.com` |
| EventBridge rule | `events.amazonaws.com` | `events.amazonaws.com` |
| SES notifications | `ses.amazonaws.com` | `ses.amazonaws.com` |
| S3 event notifications | `s3.amazonaws.com` | `s3.amazonaws.com` |
| Your app (IAM role in your account) | Nothing extra (IAM policy with `sns:Publish`) | `kms:GenerateDataKey*` and `kms:Decrypt` in the role's IAM policy |
| Another AWS account | That account as principal | That account allowed to use the key |

AWS docs: [Access control examples](https://docs.aws.amazon.com/sns/latest/dg/sns-access-policy-use-cases.html)

## Step 4: Encrypt the topic with your own KMS key

> **In simple words:** With **server-side encryption**, SNS stores messages encrypted while it delivers them. The easy choice, the AWS managed key `alias/aws/sns`, has a **fixed key policy** that CloudWatch, EventBridge and SES are not in. So for any topic that AWS services publish to, create a **customer managed key** and allow those services in its key policy.

```compare
🔑 AWS managed key (alias/aws/sns) | 🗝️ Customer managed key
Created by AWS, free | You create it, about $1 per month
You can't edit its key policy | You write the key policy
CloudWatch alarms, EventBridge, SES can't use it, so their messages fail | Allow cloudwatch, events, ses (and others) to use it
OK for topics only your own apps publish to | The right choice for alert topics
```

**Console:** **KMS** → **Customer managed keys** → **Create key** → Symmetric, Encrypt and decrypt → Alias `my-app-sns` → choose key administrators and users → on the key policy page, add the statement shown below → **Finish**. Then **SNS** → `my-app-alerts` → **Edit** → **Encryption - optional** → **Enable encryption** → AWS KMS key `alias/my-app-sns` → **Save changes**.

**CLI:**

```bash
cat > sns-key-policy.json <<EOF
{"Version": "2012-10-17", "Statement": [
  {"Sid": "EnableIAMPolicies", "Effect": "Allow",
   "Principal": {"AWS": "arn:aws:iam::${ACCOUNT_ID}:root"}, "Action": "kms:*", "Resource": "*"},
  {"Sid": "AllowAwsServicesToPublishToEncryptedTopics", "Effect": "Allow",
   "Principal": {"Service": ["cloudwatch.amazonaws.com", "events.amazonaws.com", "ses.amazonaws.com"]},
   "Action": ["kms:GenerateDataKey*", "kms:Decrypt"], "Resource": "*"}
]}
EOF

KEY_ID=$(aws kms create-key --description "Key for my-app SNS topics" \
  --policy file://sns-key-policy.json --query KeyMetadata.KeyId --output text)
aws kms create-alias --alias-name alias/my-app-sns --target-key-id "$KEY_ID"
aws kms enable-key-rotation --key-id "$KEY_ID"

aws sns set-topic-attributes --topic-arn "$TOPIC_ARN" \
  --attribute-name KmsMasterKeyId --attribute-value alias/my-app-sns
aws sns get-topic-attributes --topic-arn "$TOPIC_ARN" --query Attributes.KmsMasterKeyId --output text
```

In a key policy, `"Resource": "*"` means "this key", not every key. The first statement lets IAM policies in your account (like your admin user's) use the key, so you can still publish from the CLI.

> **Warning:** This is the most common "my alarm never emails me" cause. The alarm shows **ALARM**, but its history says *"CloudWatch Alarms does not have authorization to access the SNS topic encryption key"*. The fix is always the same: a customer managed key whose policy allows `cloudwatch.amazonaws.com` to use `kms:GenerateDataKey*` and `kms:Decrypt`.

AWS docs: [SNS server-side encryption](https://docs.aws.amazon.com/sns/latest/dg/sns-server-side-encryption.html) · [CloudWatch alarm with an encrypted topic](https://repost.aws/knowledge-center/cloudwatch-configure-alarm-sns) · Key policies in depth: [KMS guide](#/tool/aws-kms/key-policies-iam-policies-and-grants)

## Step 5: Fan out to an SQS queue with a filter policy

> **In simple words:** Add a second subscriber: an **SQS queue** that an on-call or automation program reads. It should only receive **critical** messages, so it gets a **filter policy**. Your email subscription has no filter, so it still receives everything. One publish, two different deliveries.

**Console:** **SQS** → **Create queue** → Standard, Name `my-app-critical` → **Create queue**. On the queue page: **SNS subscriptions** → **Subscribe to Amazon SNS topic** → `my-app-alerts` → **Save** (the console also adds the queue policy). Then **SNS** → **Subscriptions** → the new SQS subscription → **Edit** → **Subscription filter policy - optional** → turn it on, scope **Message attributes**, paste `{"severity": ["critical"]}` → **Save changes**.

**CLI:** create the queue, allow **only our topic** to send to it, and subscribe with a filter:

```bash
QUEUE_URL=$(aws sqs create-queue --queue-name my-app-critical --query QueueUrl --output text)
QUEUE_ARN=$(aws sqs get-queue-attributes --queue-url "$QUEUE_URL" \
  --attribute-names QueueArn --query Attributes.QueueArn --output text)

# helper: queue policy that lets one SNS topic send messages to one queue
allow_topic_to_send() {   # usage: allow_topic_to_send QUEUE_URL QUEUE_ARN TOPIC_ARN
  python3 - "$2" "$3" > queue-attrs.json <<'EOF'
import json, sys
queue_arn, topic_arn = sys.argv[1], sys.argv[2]
policy = {"Version": "2012-10-17", "Statement": [{
    "Sid": "AllowSnsTopic", "Effect": "Allow",
    "Principal": {"Service": "sns.amazonaws.com"},
    "Action": "sqs:SendMessage", "Resource": queue_arn,
    "Condition": {"ArnEquals": {"aws:SourceArn": topic_arn}}}]}
print(json.dumps({"Policy": json.dumps(policy)}))
EOF
  aws sqs set-queue-attributes --queue-url "$1" --attributes file://queue-attrs.json
}
allow_topic_to_send "$QUEUE_URL" "$QUEUE_ARN" "$TOPIC_ARN"

# the filter policy is a JSON document stored as a string attribute
cat > critical-sub-attrs.json <<'EOF'
{
  "FilterPolicy": "{\"severity\": [\"critical\"]}",
  "FilterPolicyScope": "MessageAttributes",
  "RawMessageDelivery": "true"
}
EOF
SQS_SUB_ARN=$(aws sns subscribe --topic-arn "$TOPIC_ARN" --protocol sqs \
  --notification-endpoint "$QUEUE_ARN" --attributes file://critical-sub-attrs.json \
  --query SubscriptionArn --output text)
echo "$SQS_SUB_ARN"
```

`RawMessageDelivery` puts only your message text in the queue, instead of the full SNS JSON envelope. **Test it:**

```bash
# low severity: only the email subscription receives it
aws sns publish --topic-arn "$TOPIC_ARN" --subject "Low: cache hit rate dropped" \
  --message "cache hit rate 82%" \
  --message-attributes '{"severity":{"DataType":"String","StringValue":"low"}}'

# critical: the email AND the queue receive it
aws sns publish --topic-arn "$TOPIC_ARN" --subject "CRITICAL: checkout is down" \
  --message "checkout returns HTTP 500 for all requests" \
  --message-attributes '{"severity":{"DataType":"String","StringValue":"critical"}}'

aws sqs receive-message --queue-url "$QUEUE_URL" --wait-time-seconds 10 \
  --query 'Messages[].Body' --output text      # only the critical message
```

### Filter policy cheat sheet

A filter policy lists attribute names and the values that are allowed. Different attributes are **AND**, the values inside one list are **OR**:

```json
{
  "severity": ["critical", "high"],
  "service": [{"prefix": "web"}],
  "env": [{"anything-but": "dev"}],
  "error_rate": [{"numeric": [">=", 5]}]
}
```

Values are case-sensitive, and `[{"exists": false}]` matches messages that **don't** have that attribute.

**Two scopes:** `MessageAttributes` (the default, filters on the labels, free) or `MessageBody` (filters on fields inside a JSON message body, billed per amount of data scanned). A message with **no** `severity` attribute, such as a CloudWatch alarm notification, does not match `{"severity": ["critical"]}`, so the queue won't get alarm messages.

AWS docs: [Message filtering](https://docs.aws.amazon.com/sns/latest/dg/sns-message-filtering.html)

## Step 6: Retries and a dead-letter queue

> **In simple words:** If a subscriber is down, SNS **tries again** many times. If it still fails, the message is **thrown away**, unless the subscription has a **dead-letter queue**: an SQS queue that keeps the failed messages so you can see and replay them.

### How long SNS keeps retrying

| Endpoint type | Examples | Retries |
|---|---|---|
| AWS managed endpoints | Lambda, SQS | **100,015 attempts over 23 days** |
| Customer managed endpoints | Email, SMS, mobile push | **50 attempts over 6 hours** |
| HTTP/S | Your webhooks | A delivery policy you can change, at most 1 hour of retries in total |

Retries only happen for **server-side** errors (the endpoint is unavailable). **Client-side** errors, such as a deleted queue, a missing queue policy or a KMS key the service can't use, are not retried: the message goes straight to the DLQ, or is lost.

**Console:** create an SQS queue `my-app-critical-dlq` → **SNS** → **Subscriptions** → the SQS subscription → **Edit** → **Redrive policy (dead-letter queue)** → turn it on → choose `my-app-critical-dlq` → **Save changes**.

**CLI:**

```bash
DLQ_URL=$(aws sqs create-queue --queue-name my-app-critical-dlq \
  --attributes MessageRetentionPeriod=1209600 --query QueueUrl --output text)   # keep 14 days
DLQ_ARN=$(aws sqs get-queue-attributes --queue-url "$DLQ_URL" \
  --attribute-names QueueArn --query Attributes.QueueArn --output text)

# the DLQ must also allow the topic to send to it
allow_topic_to_send "$DLQ_URL" "$DLQ_ARN" "$TOPIC_ARN"

aws sns set-subscription-attributes --subscription-arn "$SQS_SUB_ARN" \
  --attribute-name RedrivePolicy --attribute-value "{\"deadLetterTargetArn\":\"$DLQ_ARN\"}"
aws sns get-subscription-attributes --subscription-arn "$SQS_SUB_ARN" \
  --query Attributes.RedrivePolicy --output text
```

The DLQ must be in the **same account and Region** as the subscription, and of the same type (a standard queue for a standard topic). Each subscription gets its own DLQ setting.

> **Tip:** For Lambda, SQS, HTTP/S and Firehose subscriptions you can also turn on **Delivery status logging** (topic → **Edit** → **Delivery status logging**). SNS then writes every success or failure to CloudWatch Logs, which helps when you're not sure whether SNS delivered a message at all.

AWS docs: [Delivery retries](https://docs.aws.amazon.com/sns/latest/dg/sns-message-delivery-retries.html) · [Dead-letter queues](https://docs.aws.amazon.com/sns/latest/dg/sns-dead-letter-queues.html)

## Step 7: Alarm to SNS to email, end to end

> **In simple words:** Put it all together: a CloudWatch alarm that fires when the DLQ is **not empty** (something failed to deliver) and notifies the encrypted topic. Then force the alarm into ALARM to prove that the whole path, **including the KMS key policy**, really works.

The [CloudWatch guide](#/tool/aws-cloudwatch/step-4-create-a-cpu-alarm-that-emails-you) explains alarms in detail. Here we only need one.

**Console:** **CloudWatch** → **Alarms** → **Create alarm** → **Select metric** → **SQS** → **Queue Metrics** → `my-app-critical-dlq` / `ApproximateNumberOfMessagesVisible` → Statistic **Maximum**, Period **5 minutes** → **Greater/Equal** `1` → **Next** → **In alarm** → existing topic `my-app-alerts` → **Next** → Name `my-app-dlq-not-empty` → **Create alarm**.

**CLI:**

```bash
aws cloudwatch put-metric-alarm --alarm-name my-app-dlq-not-empty \
  --alarm-description "Messages failed delivery and are waiting in the DLQ" \
  --namespace AWS/SQS --metric-name ApproximateNumberOfMessagesVisible \
  --dimensions Name=QueueName,Value=my-app-critical-dlq \
  --statistic Maximum --period 300 --evaluation-periods 1 \
  --threshold 1 --comparison-operator GreaterThanOrEqualToThreshold \
  --treat-missing-data notBreaching \
  --alarm-actions "$TOPIC_ARN" --ok-actions "$TOPIC_ARN"

# test the notification path now, without waiting for a real failure
aws cloudwatch set-alarm-state --alarm-name my-app-dlq-not-empty \
  --state-value ALARM --state-reason "Testing the notification path"

sleep 30
aws cloudwatch describe-alarm-history --alarm-name my-app-dlq-not-empty \
  --history-item-type Action --query 'AlarmHistoryItems[].HistorySummary' --output text
```

| History says | Meaning |
|---|---|
| `Successfully executed action arn:aws:sns:...` | It worked. Check your inbox: an email "ALARM: my-app-dlq-not-empty" |
| `... does not have authorization to access the SNS topic encryption key` | The KMS key policy doesn't allow `cloudwatch.amazonaws.com` (Step 4) |
| `... is not authorized to perform: SNS:Publish` | The topic access policy blocks CloudWatch (Step 3) |

At the next evaluation the alarm goes back to **OK** by itself, and because of `--ok-actions` you get an "OK" email too. For EventBridge rules that send AWS events to the same topic, see [EventBridge in the CloudWatch guide](#/tool/aws-cloudwatch/step-10-react-to-aws-events-with-eventbridge) and the [Lambda and EventBridge guide](#/tool/aws-lambda).

## Step 8: Send alerts to Slack or Microsoft Teams

> **In simple words:** People react faster to a chat message than to an email. There are two ways: **Amazon Q Developer in chat applications** (the new name of AWS Chatbot) subscribes to your topic and posts nicely formatted alerts, with no code. Or a small **Lambda function** subscribes to the topic and posts to any chat tool's webhook.

| | Amazon Q Developer in chat applications | Lambda forwarder |
|---|---|---|
| Chat tools | Slack and Microsoft Teams | Anything with a webhook URL |
| Code | None | A few lines of Python |
| Message format | Understands CloudWatch alarms and AWS events; your own messages must use its **custom notification** JSON | Whatever you build |
| Extras | Can run read-only AWS commands from the channel, if you allow it | You maintain it |

### Option A: Amazon Q Developer in chat applications (Slack example)

1. In Slack, invite the app to your channel: `/invite @Amazon Q`.
2. Open the **Amazon Q Developer in chat applications** console → **Configure new client** → **Slack** → **Configure** → allow access to your workspace.
3. **Configure new channel** → name `alerts-prod` → choose the Slack channel.
4. **Role settings:** **Channel role** → **Create an IAM role using a template** → policy template **Notification permissions**.
5. **Channel guardrail policies:** keep them narrow, for example `ReadOnlyAccess`.
6. **Notifications:** Region `us-east-1`, SNS topic `my-app-alerts` → **Configure**.

It subscribes an HTTPS endpoint to your topic for you. To post your **own** message to the channel, publish JSON in the custom notification format:

```bash
aws sns publish --topic-arn "$TOPIC_ARN" --message '{
  "version": "1.0",
  "source": "custom",
  "content": {
    "title": ":rocket: Deploy finished",
    "description": "my-app v1.4.2 is live in prod."
  }
}'
```

AWS docs: [Get started with Slack](https://docs.aws.amazon.com/chatbot/latest/adminguide/slack-setup.html) · [Get started with Microsoft Teams](https://docs.aws.amazon.com/chatbot/latest/adminguide/teams-setup.html) · [Custom notifications](https://docs.aws.amazon.com/chatbot/latest/adminguide/custom-notifs.html)

### Option B: a Lambda function that posts to a webhook

Create an **incoming webhook** URL in your chat tool first. This handler turns CloudWatch alarm JSON into one short line and posts it as `{"text": "..."}` (Slack's format; other tools need a different body). It reuses `hello-lambda-role` from [Step 1 of the Lambda guide](#/tool/aws-lambda/step-1-create-the-execution-role), which only allows writing logs (create it as shown there if you deleted it):

```bash
cat > chat_forwarder.py <<'EOF'
import json, os, urllib.request

def handler(event, context):
    for record in event["Records"]:
        sns = record["Sns"]
        text = sns["Message"]
        try:  # CloudWatch alarms send JSON: make it short and readable
            alarm = json.loads(text)
            text = f"{alarm['NewStateValue']}: {alarm['AlarmName']}\n{alarm['NewStateReason']}"
        except (ValueError, KeyError, TypeError):
            pass  # plain text: send it as it is
        body = json.dumps({"text": f"*{sns.get('Subject') or 'Notification'}*\n{text}"}).encode()
        req = urllib.request.Request(os.environ["WEBHOOK_URL"], data=body,
                                     headers={"Content-Type": "application/json"})
        urllib.request.urlopen(req, timeout=10)
EOF
zip -q chat-forwarder.zip chat_forwarder.py

WEBHOOK_URL="https://hooks.example.com/services/replace-me"   # your real webhook URL
FN_ARN=$(aws lambda create-function --function-name sns-to-chat \
  --runtime python3.13 --handler chat_forwarder.handler \
  --role "arn:aws:iam::${ACCOUNT_ID}:role/hello-lambda-role" --zip-file fileb://chat-forwarder.zip \
  --environment "Variables={WEBHOOK_URL=$WEBHOOK_URL}" --query FunctionArn --output text)

# let SNS (only from our topic) invoke the function, then subscribe it
aws lambda add-permission --function-name sns-to-chat --statement-id sns-invoke \
  --action lambda:InvokeFunction --principal sns.amazonaws.com --source-arn "$TOPIC_ARN"
aws sns subscribe --topic-arn "$TOPIC_ARN" --protocol lambda --notification-endpoint "$FN_ARN"
```

A webhook URL is a password: anyone who has it can post to your channel. In real projects keep it in [Secrets Manager](#/tool/aws-secrets) instead of an environment variable. The [Lambda guide](#/tool/aws-lambda) explains functions, roles and logs in more detail.

## Message data protection (availability change)

> **In simple words:** SNS used to offer **message data protection**: policies that scan messages for sensitive data (names, card numbers, health data) and **audit**, **mask** or **block** them. Since **April 30, 2026** it is **no longer available to new customers**. Accounts that already had policies can keep using it, but AWS adds no new features.

It worked on standard topics only, with three actions: **audit** (report what it found), **de-identify** (mask or redact) and **deny** (block the message).

Check whether an older topic still has a policy, and remove it if you no longer need it:

```bash
aws sns get-data-protection-policy --resource-arn "$TOPIC_ARN"
```

**What AWS recommends instead:** publishers send to an "inbound" topic; a **Lambda function** subscribed to it checks each message with **Amazon Bedrock Guardrails** (log, block or redact), then publishes the clean message to the real topic. For alert topics, the simplest protection is a team rule: **never put passwords, tokens or customer personal data in alerts**. Send IDs and links to dashboards instead.

AWS docs: [Message data protection availability change](https://docs.aws.amazon.com/sns/latest/dg/sns-message-data-protection-availability-change.html)

## Step 9: SES: verify an email address and a domain

> **In simple words:** SES only sends from addresses you have **proved you own**. A single **email address** is quick: click a link. A whole **domain** is better for real apps: you add three DNS records (Easy DKIM), and then you can send from any address at that domain, with a proper signature.

```text
 your app ──API / SMTP──▶ Amazon SES ──▶ recipient's mail server
                              │            checks the email:
                              │             DKIM  signature
                              │             SPF   MAIL FROM
                              │             DMARC policy
                              ▼
        bounces / complaints ──▶ SNS topic ──▶ you
```

### 9a. An email address (fastest)

**Console:** **SES** → **Configuration** → **Identities** → **Create identity** → **Email address** → your address → **Create identity**. Click the link in the verification email within **24 hours**.

```bash
aws sesv2 create-email-identity --email-identity "$EMAIL"
# click the link in the verification email, then:
aws sesv2 get-email-identity --email-identity "$EMAIL" --query VerifiedForSendingStatus
```

### 9b. A domain with Easy DKIM and Route 53

**Console:** **Identities** → **Create identity** → **Domain** → `example.com` → under **Advanced DKIM settings** keep **Easy DKIM** and **RSA_2048_BIT** → **Create identity**. If the domain's hosted zone is in Route 53 in the same account, the console can publish the DNS records for you; otherwise copy the three CNAME records into your DNS provider.

**CLI:**

```bash
DKIM_TOKENS=$(aws sesv2 create-email-identity --email-identity "$DOMAIN" \
  --query 'DkimAttributes.Tokens' --output text)
ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name "$DOMAIN" \
  --query "HostedZones[?Name=='${DOMAIN}.'].Id | [0]" --output text)

# build the three DKIM CNAME records and create them in Route 53
python3 - "$DOMAIN" $DKIM_TOKENS > dkim-records.json <<'EOF'
import json, sys
domain, tokens = sys.argv[1], sys.argv[2:]
changes = [{"Action": "UPSERT", "ResourceRecordSet": {
    "Name": f"{t}._domainkey.{domain}", "Type": "CNAME", "TTL": 1800,
    "ResourceRecords": [{"Value": f"{t}.dkim.amazonses.com"}]}} for t in tokens]
print(json.dumps({"Changes": changes}, indent=2))
EOF
aws route53 change-resource-record-sets --hosted-zone-id "$ZONE_ID" --change-batch file://dkim-records.json

# usually verified within minutes; some DNS providers take up to 72 hours
aws sesv2 get-email-identity --email-identity "$DOMAIN" \
  --query '{Verified:VerifiedForSendingStatus,Dkim:DkimAttributes.Status}'
```

Each record looks like `token1._domainkey.example.com  CNAME  token1.dkim.amazonses.com`. The CNAMEs point to public keys that SES manages. SES signs every email from the domain with a **2048-bit DKIM key**, and the domain is verified when SES finds the records (DKIM status `SUCCESS`).

AWS docs: [Creating and verifying identities](https://docs.aws.amazon.com/ses/latest/dg/creating-identities.html) · [Easy DKIM](https://docs.aws.amazon.com/ses/latest/dg/send-email-authentication-dkim-easy.html)

## Step 10: SES sandbox: send test emails

> **In simple words:** Every new account starts in the **sandbox**, separately in each Region. It's a safe practice mode: you can use every feature, but only send **to verified addresses** (or the **mailbox simulator**), at most **200 emails per 24 hours** and **1 per second**.

```bash
aws sesv2 get-account --query '{Production:ProductionAccessEnabled,Max24h:SendQuota.Max24HourSend,PerSecond:SendQuota.MaxSendRate,SentLast24h:SendQuota.SentLast24Hours}'
```

**Console:** **Identities** → choose your verified identity → **Send test email** → Scenario **Custom** (your verified address) or a simulator scenario → **Send test email**.

**CLI:**

```bash
FROM_ADDR="noreply@$DOMAIN"     # or FROM_ADDR="$EMAIL" if you verified only an email address

aws sesv2 send-email --from-email-address "$FROM_ADDR" \
  --destination "ToAddresses=$EMAIL" \
  --content '{"Simple":{"Subject":{"Data":"Hello from Amazon SES"},"Body":{"Text":{"Data":"It works! Sent with aws sesv2 send-email."},"Html":{"Data":"<h1>It works!</h1><p>Sent with <b>aws sesv2 send-email</b>.</p>"}}}}'
```

The command prints a `MessageId`. Always send a **Text** part next to the **Html** part: some mail clients and spam filters look for it.

### The mailbox simulator

Send to these addresses to test without hurting your reputation. They work in the sandbox, don't count against the daily quota, and are billed like normal emails:

| Address | Simulates |
|---|---|
| `success@simulator.amazonses.com` | A normal successful delivery |
| `bounce@simulator.amazonses.com` | A hard bounce (address doesn't exist) |
| `complaint@simulator.amazonses.com` | The recipient marks the email as spam |
| `ooto@simulator.amazonses.com` | An out-of-office auto reply |

AWS docs: [Sending test emails with the simulator](https://docs.aws.amazon.com/ses/latest/dg/send-an-email-from-console.html)

## Step 11: Bounces and complaints to SNS with a configuration set

> **In simple words:** You must **listen** for bounces and complaints and stop emailing those addresses, or SES pauses your account. A **configuration set** is a named bundle of sending settings; an **event destination** inside it sends bounce and complaint events to an SNS topic, which emails you or feeds a program.

First, a **standard** topic for SES events (SES doesn't support FIFO topics). It reuses the KMS key from Step 4, which already allows `ses.amazonaws.com`:

```bash
SES_TOPIC_ARN=$(aws sns create-topic --name my-app-ses-events \
  --attributes KmsMasterKeyId=alias/my-app-sns --query TopicArn --output text)
aws sns subscribe --topic-arn "$SES_TOPIC_ARN" --protocol email --notification-endpoint "$EMAIL"
# confirm this second subscription in your inbox too

cat > ses-topic-policy.json <<EOF
{"Version": "2012-10-17", "Statement": [
  {"Sid": "OwnerFullControl", "Effect": "Allow", "Principal": {"AWS": "arn:aws:iam::${ACCOUNT_ID}:root"},
   "Action": ["sns:Publish", "sns:Subscribe", "sns:GetTopicAttributes", "sns:SetTopicAttributes",
              "sns:ListSubscriptionsByTopic", "sns:DeleteTopic"], "Resource": "${SES_TOPIC_ARN}"},
  {"Sid": "AllowSESToPublish", "Effect": "Allow", "Principal": {"Service": "ses.amazonaws.com"},
   "Action": "sns:Publish", "Resource": "${SES_TOPIC_ARN}",
   "Condition": {"StringEquals": {"aws:SourceAccount": "${ACCOUNT_ID}"}}}
]}
EOF
aws sns set-topic-attributes --topic-arn "$SES_TOPIC_ARN" \
  --attribute-name Policy --attribute-value file://ses-topic-policy.json
```

**Console:** **SES** → **Configuration** → **Configuration sets** → **Create set** → Name `my-app-emails` → **Create set** → **Event destinations** → **Add destination** → tick **Hard bounces**, **Complaints** and **Rejects** → **Next** → Destination **Amazon SNS**, topic `my-app-ses-events` → **Add destination**.

**CLI:**

```bash
aws sesv2 create-configuration-set --configuration-set-name my-app-emails

aws sesv2 create-configuration-set-event-destination --configuration-set-name my-app-emails \
  --event-destination-name bounces-to-sns \
  --event-destination "{\"Enabled\":true,\"MatchingEventTypes\":[\"BOUNCE\",\"COMPLAINT\",\"REJECT\"],\"SnsDestination\":{\"TopicArn\":\"$SES_TOPIC_ARN\"}}"

# use this configuration set by default for everything sent from the domain
aws sesv2 put-email-identity-configuration-set-attributes \
  --email-identity "$DOMAIN" --configuration-set-name my-app-emails

# test: this bounces, and a few seconds later the SES topic emails you the bounce event
aws sesv2 send-email --from-email-address "$FROM_ADDR" \
  --destination "ToAddresses=bounce@simulator.amazonses.com" \
  --content '{"Simple":{"Subject":{"Data":"Bounce test"},"Body":{"Text":{"Data":"This email should bounce."}}}}' \
  --configuration-set-name my-app-emails
```

The notification is JSON with `"eventType": "Bounce"`, the bounce type (`Permanent` means "remove this address") and the recipient. In production, subscribe an **SQS queue** or **Lambda** to this topic so your app marks those addresses as "do not email" automatically.

| Event type | Sent when |
|---|---|
| `SEND` / `DELIVERY` | SES accepted the email / the recipient's server accepted it |
| `BOUNCE` | Delivery failed (permanent or temporary) |
| `COMPLAINT` | The recipient reported it as spam |
| `REJECT` | SES refused to send it (for example, it contained a virus) |
| `DELIVERY_DELAY` | Delivery is delayed and SES keeps trying |
| `OPEN` / `CLICK` | The recipient opened the email or clicked a link (tracking) |

You can also set feedback per identity instead: **Identities** → your identity → **Notifications** → **Edit** under **Feedback notifications** → choose an SNS topic for bounces and complaints. SES additionally keeps an account-level **suppression list** of addresses that bounced or complained (`aws sesv2 list-suppressed-destinations`).

AWS docs: [Configuration sets](https://docs.aws.amazon.com/ses/latest/dg/using-configuration-sets.html) · [SNS notifications for SES](https://docs.aws.amazon.com/ses/latest/dg/configure-sns-notifications.html)

## Step 12: SPF, DMARC and a custom MAIL FROM domain

> **In simple words:** DKIM proves the email really came from you. Two more DNS records make mailbox providers trust you: **SPF** lists the servers allowed to send for your domain, and **DMARC** says "both checks must match my domain; tell me about failures". Large providers such as Gmail and Yahoo now expect all three, so skipping them is the usual reason for "my emails go to spam".

| Check | DNS record | What it proves |
|---|---|---|
| **DKIM** | 3 CNAMEs (Step 9) | The email was signed by your domain and not changed on the way |
| **SPF** | TXT on the **MAIL FROM** domain | The sending server is allowed to send for that domain |
| **DMARC** | TXT on `_dmarc.example.com` | Your policy when checks fail; the From domain must **align** with DKIM or SPF |

By default SES uses an `amazonses.com` subdomain as the hidden **MAIL FROM** (bounce) address, so SPF passes for `amazonses.com` but doesn't **align** with your From domain. A **custom MAIL FROM domain** such as `mail.example.com` fixes that.

**Console:** **Identities** → your domain → **Custom MAIL FROM domain** → **Edit** → tick **Use a custom MAIL FROM domain** → `mail` → Behavior on MX failure **Use default MAIL FROM domain** → **Save changes** (the console shows the MX and TXT records to create).

**CLI:**

```bash
MAIL_FROM="mail.$DOMAIN"
aws sesv2 put-email-identity-mail-from-attributes --email-identity "$DOMAIN" \
  --mail-from-domain "$MAIL_FROM" --behavior-on-mx-failure USE_DEFAULT_VALUE

# MX + SPF for mail.example.com, and a starter DMARC record (p=none only reports, never blocks)
cat > mail-auth-records.json <<EOF
{"Changes": [
  {"Action": "UPSERT", "ResourceRecordSet": {"Name": "${MAIL_FROM}", "Type": "MX", "TTL": 300,
    "ResourceRecords": [{"Value": "10 feedback-smtp.${AWS_REGION}.amazonses.com"}]}},
  {"Action": "UPSERT", "ResourceRecordSet": {"Name": "${MAIL_FROM}", "Type": "TXT", "TTL": 300,
    "ResourceRecords": [{"Value": "\"v=spf1 include:amazonses.com ~all\""}]}},
  {"Action": "UPSERT", "ResourceRecordSet": {"Name": "_dmarc.${DOMAIN}", "Type": "TXT", "TTL": 300,
    "ResourceRecords": [{"Value": "\"v=DMARC1; p=none; rua=mailto:dmarc-reports@${DOMAIN}\""}]}}
]}
EOF
aws route53 change-resource-record-sets --hosted-zone-id "$ZONE_ID" --change-batch file://mail-auth-records.json

dig +short TXT "_dmarc.$DOMAIN"
aws sesv2 get-email-identity --email-identity "$DOMAIN" --query MailFromAttributes
```

> **Warning:** `UPSERT` **replaces** an existing record with the same name and type. If your domain already has a DMARC record (or an SPF record for other mail services), edit it instead of overwriting it.

Start DMARC with `p=none` and read the reports for a few weeks; then move to `p=quarantine` and later `p=reject`. Keep SPF alignment **relaxed** (the default; don't add `aspf=s`), because the MAIL FROM domain is a subdomain. To check a received email, open its headers ("Show original" in Gmail) and look for `dkim=pass`, `spf=pass` and `dmarc=pass`.

AWS docs: [Custom MAIL FROM domain](https://docs.aws.amazon.com/ses/latest/dg/mail-from.html) · [DMARC in SES](https://docs.aws.amazon.com/ses/latest/dg/send-email-authentication-dmarc.html)

## Step 13: SMTP credentials for apps

> **In simple words:** Many apps and tools (WordPress, Jenkins, Grafana, a Java or Python app) only know how to send email over **SMTP**. SES has an SMTP endpoint. It needs a special **SMTP user name and password**, which are **not** your AWS access keys, and which are valid in **one Region** only.

**Console:** **SES** → **SMTP settings** → note the **SMTP endpoint** → **Create SMTP credentials** → keep or change the IAM user name → **Create user** → **Show** / **Download .csv file**. You can't see the password again later.

Behind the scenes this creates an IAM user whose only permission is `ses:SendRawEmail`, and derives the SMTP password from its secret key.

| Setting | Value |
|---|---|
| Server | `email-smtp.us-east-1.amazonaws.com` (one per Region) |
| STARTTLS ports | 587 (most common), 2587, 25 |
| TLS Wrapper ports | 465, 2465 |
| User name / password | From the downloaded .csv |
| From address | Must be a verified identity |

> **Note:** EC2 **throttles outbound port 25** by default. From EC2, use **587** or **2587**. You can also reach SES SMTP privately through a VPC interface endpoint (see [VPC endpoints and PrivateLink](#/tool/aws-privatelink)).

Store the credentials in Secrets Manager, and test the connection:

```bash
aws secretsmanager create-secret --name my-app/ses-smtp \
  --secret-string '{"username":"PASTE_SMTP_USERNAME","password":"PASTE_SMTP_PASSWORD"}'

# after the TLS handshake, type: EHLO example.com
# lines starting with 250 mean it works; type QUIT to leave
openssl s_client -crlf -quiet -starttls smtp -connect "email-smtp.${AWS_REGION}.amazonaws.com:587"
```

AWS docs: [Obtaining SMTP credentials](https://docs.aws.amazon.com/ses/latest/dg/smtp-credentials.html) · [Connecting to the SMTP endpoint](https://docs.aws.amazon.com/ses/latest/dg/smtp-connect.html)

## Step 14: Leave the sandbox and watch your quotas

> **In simple words:** When the app is ready for real customers, ask AWS for **production access** (per Region). Explain what you send and how you handle bounces; a verified domain helps the request get approved. After that, keep your **bounce** and **complaint** rates low, or SES reviews or pauses your account.

**Console:** **SES** → **Get set up** → **Request production access** → Mail type **Transactional** (or Marketing) → Website URL → describe your use case → additional contacts → **Submit request**. AWS reviews it and answers by email in a support case.

**CLI:**

```bash
aws sesv2 put-account-details --production-access-enabled \
  --mail-type TRANSACTIONAL --website-url "https://$DOMAIN" \
  --contact-language EN --additional-contact-email-addresses "$EMAIL" \
  --use-case-description "Password resets and order receipts for registered users of my-app, about 2,000 emails a day. Bounces and complaints go to SNS and those addresses are removed automatically."

aws sesv2 get-account --query '{Production:ProductionAccessEnabled,Review:Details.ReviewDetails.Status,Max24h:SendQuota.Max24HourSend,PerSecond:SendQuota.MaxSendRate}'
```

| Limit | Sandbox | Production |
|---|---|---|
| Recipients | Verified addresses and the simulator only | Anyone |
| Emails per 24 hours | 200 | Set by AWS for your use case; you can ask for more |
| Emails per second | 1 | Set by AWS; you can ask for more |
| From address | Must be verified | Must still be verified |

Quotas count **recipients**, not messages: one email to 3 people uses 3.

| Reputation metric | Under review at | Sending may be paused at |
|---|---|---|
| Bounce rate | 5% | 10% |
| Complaint rate | 0.1% | 0.5% |

Get warned **before** AWS acts, with an alarm on `Reputation.BounceRate` (values are fractions: `0.03` = 3%). Create a second one on `Reputation.ComplaintRate` with threshold `0.001` the same way:

```bash
aws cloudwatch put-metric-alarm --alarm-name ses-bounce-rate-high \
  --namespace AWS/SES --metric-name Reputation.BounceRate \
  --statistic Average --period 3600 --evaluation-periods 1 \
  --threshold 0.03 --comparison-operator GreaterThanOrEqualToThreshold \
  --treat-missing-data notBreaching --alarm-actions "$TOPIC_ARN"
```

AWS docs: [Request production access](https://docs.aws.amazon.com/ses/latest/dg/request-production-access.html) · [SES quotas](https://docs.aws.amazon.com/ses/latest/dg/quotas.html) · [Sending review FAQs](https://docs.aws.amazon.com/ses/latest/dg/faqs-enforcement.html)

## Troubleshooting

> **In simple words:** For SNS, follow the message: **publisher allowed? → key allowed? → filter matches? → subscriber confirmed and reachable?** For SES, check **identity verified? → sandbox? → right Region? → DNS records?**

| Problem | Likely cause | Fix |
|---|---|---|
| Subscription stays **PendingConfirmation** | Email not clicked, in spam, or the 2-day link expired | Check spam; **Request confirmation** in the console, or subscribe again |
| Everyone suddenly stops getting alerts | Someone clicked **unsubscribe** in a forwarded email | Subscribe again; confirm with `--authenticate-on-unsubscribe true` |
| Alarm is in ALARM but no email; history: *does not have authorization to access the SNS topic encryption key* | Topic uses `alias/aws/sns`, or your key policy lacks `cloudwatch.amazonaws.com` | Use a customer managed key with the Step 4 statement |
| Alarm history: *not authorized to perform: SNS:Publish* | The topic access policy blocks CloudWatch | Add the `cloudwatch.amazonaws.com` statement (Step 3) |
| EventBridge rule matches, nothing arrives | No `events.amazonaws.com` statement in the topic or key policy | Add both; check the rule's `FailedInvocations` metric |
| SQS subscriber gets nothing | Missing queue policy; filter doesn't match (names and values are case-sensitive); queue encrypted with a KMS key that doesn't allow `sns.amazonaws.com` | Add the queue policy; test the filter; use SSE-SQS or allow SNS in the queue's key |
| Can't subscribe email or HTTPS to a topic | It's a **FIFO** topic: only SQS can subscribe | Use a standard topic for notifications |
| App gets `AuthorizationError` on Publish | The IAM role lacks `sns:Publish`, or `kms:GenerateDataKey*` for an encrypted topic | Add both to the role's policy |
| SES: *Email address is not verified. The following identities failed the check in region US-EAST-1* | Sandbox and the **recipient** isn't verified, the **From** address isn't verified, or you're in a different Region | Verify the address, use the simulator, request production access, check `AWS_REGION` |
| Domain stays "Verification pending" | DKIM CNAMEs missing, in the wrong hosted zone, or the registrar doesn't use Route 53 name servers | `dig +short CNAME token1._domainkey.example.com`; fix the records; wait up to 72 hours |
| Emails land in **spam** | No custom MAIL FROM or DMARC, HTML-only body, a brand-new domain, or people never asked for the email | Steps 9 and 12; add a text part; send only to people who signed up; check `dmarc=pass` in the headers |
| SES `Throttling: Maximum sending rate exceeded` | Sending faster than `MaxSendRate` | Slow down and retry with backoff, or ask for a higher rate |
| SMTP times out from EC2 | Port 25 is throttled on EC2 | Use port 587 or 2587 |
| SMTP `535 Authentication Credentials Invalid` | Using AWS access keys, or SMTP credentials from another Region | Create SMTP credentials in the same Region as the endpoint |
| SES account **under review** | Bounce rate 5% or more, or complaint rate 0.1% or more | Handle bounce events (Step 11), clean your lists, never send to bought lists |

## Clean up

> **In simple words:** Delete what you created, in reverse order: alarms, Lambda, queues, topics (this removes their subscriptions), SES settings and identities, DNS records, secrets, and finally schedule the KMS key for deletion.

```bash
# alarms
aws cloudwatch delete-alarms --alarm-names my-app-dlq-not-empty ses-bounce-rate-high

# Lambda forwarder (if you did Option B)
aws lambda delete-function --function-name sns-to-chat

# SNS topics (deleting a topic also deletes its subscriptions) and SQS queues
aws sns delete-topic --topic-arn "$TOPIC_ARN"
aws sns delete-topic --topic-arn "$SES_TOPIC_ARN"
aws sqs delete-queue --queue-url "$QUEUE_URL"
aws sqs delete-queue --queue-url "$DLQ_URL"

# SES: identities, then the configuration set
aws sesv2 delete-email-identity --email-identity "$EMAIL"
aws sesv2 delete-email-identity --email-identity "$DOMAIN"
aws sesv2 delete-configuration-set --configuration-set-name my-app-emails

# DNS records: delete exactly what we created
sed 's/"UPSERT"/"DELETE"/' dkim-records.json > dkim-delete.json
sed 's/"UPSERT"/"DELETE"/' mail-auth-records.json > mail-auth-delete.json
aws route53 change-resource-record-sets --hosted-zone-id "$ZONE_ID" --change-batch file://dkim-delete.json
aws route53 change-resource-record-sets --hosted-zone-id "$ZONE_ID" --change-batch file://mail-auth-delete.json

# SMTP secret, then the KMS key (waits 7 days before it is really deleted)
aws secretsmanager delete-secret --secret-id my-app/ses-smtp --force-delete-without-recovery
aws kms delete-alias --alias-name alias/my-app-sns
aws kms schedule-key-deletion --key-id "$KEY_ID" --pending-window-in-days 7
```

Also remove the **SMTP IAM user** (IAM → **Users** → the `ses-smtp-user...` user → delete), and, if you set it up, the **Amazon Q Developer** channel configuration. Don't delete a DMARC record that existed before this lab.

## Lab and cheat sheet

> **In simple words:** Practice time: build an alert topic that really works, break it on purpose the way it breaks in real life, then send real email from your own domain.

1. Create `my-app-alerts`, subscribe your email, confirm it, and publish a test message.
2. Lock down the topic access policy so only CloudWatch alarms and EventBridge from your account (and you) can publish.
3. Encrypt the topic with a customer managed key, create the DLQ alarm, and prove the path with `set-alarm-state`.
4. **Break it:** create a second topic encrypted with `alias/aws/sns`, point an alarm at it, run `set-alarm-state`, and find the KMS error in the alarm history. Fix it by switching to your own key.
5. Subscribe an SQS queue with the `severity = critical` filter. Publish `low`, `high` and `critical` messages and check which ones reach the queue.
6. Attach the DLQ, then **delete the main queue** and publish a critical message. Find it in the DLQ (and watch the alarm fire).
7. Send alarms to a chat channel with Amazon Q Developer in chat applications or the Lambda forwarder.
8. Verify your domain with Easy DKIM, add the custom MAIL FROM and DMARC records, and send yourself an email. Check the headers for `dkim=pass`, `spf=pass` and `dmarc=pass`.
9. Send to `bounce@` and `complaint@simulator.amazonses.com` with the configuration set, and read the events that arrive through SNS.
10. Clean up everything, and check that no topics, queues or SES identities are left.

### Cheat sheet

| Task | Command |
|---|---|
| Create topic | `aws sns create-topic --name my-app-alerts` |
| Subscribe email | `aws sns subscribe --topic-arn T --protocol email --notification-endpoint you@example.com` |
| List subscriptions | `aws sns list-subscriptions-by-topic --topic-arn T` |
| Publish | `aws sns publish --topic-arn T --subject S --message M` |
| Publish with attributes | `aws sns publish ... --message-attributes '{"severity":{"DataType":"String","StringValue":"critical"}}'` |
| Set access policy | `aws sns set-topic-attributes --topic-arn T --attribute-name Policy --attribute-value file://p.json` |
| Encrypt topic | `aws sns set-topic-attributes --topic-arn T --attribute-name KmsMasterKeyId --attribute-value alias/K` |
| Filter policy | `aws sns set-subscription-attributes --subscription-arn S --attribute-name FilterPolicy --attribute-value '{"severity":["critical"]}'` |
| Dead-letter queue | `aws sns set-subscription-attributes --subscription-arn S --attribute-name RedrivePolicy --attribute-value '{"deadLetterTargetArn":"Q"}'` |
| Test an alarm | `aws cloudwatch set-alarm-state --alarm-name A --state-value ALARM --state-reason test` |
| Verify email / domain | `aws sesv2 create-email-identity --email-identity you@example.com` (or `example.com`) |
| Identity status | `aws sesv2 get-email-identity --email-identity example.com` |
| Sandbox and quotas | `aws sesv2 get-account` |
| Send email | `aws sesv2 send-email --from-email-address F --destination ToAddresses=R --content file://c.json` |
| Configuration set | `aws sesv2 create-configuration-set --configuration-set-name C` |
| Custom MAIL FROM | `aws sesv2 put-email-identity-mail-from-attributes --email-identity example.com --mail-from-domain mail.example.com` |
| Production access | `aws sesv2 put-account-details --production-access-enabled --mail-type TRANSACTIONAL --website-url URL` |
| Suppressed addresses | `aws sesv2 list-suppressed-destinations` |
