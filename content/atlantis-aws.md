# Atlantis on AWS: Manual Setup

Run **Terraform from pull requests** with **Atlantis**, built **by hand** with the AWS console and CLI (no Terraform, no modules). You'll set up the AWS services Atlantis needs one at a time: **ECS on Fargate**, an **Application Load Balancer** with an **ACM** certificate, **Route 53**, **Secrets Manager**, **Parameter Store**, **IAM** roles that reach other accounts, **CloudWatch Logs**, and an **S3 + DynamoDB** state backend in each account. Then you'll connect a **Bitbucket Cloud** repository and run your first plan and apply from a pull request.

> **Cost:** A small setup costs roughly **$60 a month** in `us-east-1`: one Fargate task with 1 vCPU and 2 GB (about $36), an Application Load Balancer (about $16 plus public IPv4 addresses), a few secrets ($0.40 each) and logs. Add a **NAT gateway** (about $33 a month) if your VPC doesn't already have one. See [Fargate pricing](https://aws.amazon.com/fargate/pricing/) and [ELB pricing](https://aws.amazon.com/elasticloadbalancing/pricing/).

## Start here: Atlantis in simple words

> **In simple words:** Atlantis is a **careful robot operator** for Terraform. When someone opens a pull request that changes Terraform code, Atlantis runs `terraform plan` and posts the result as a **comment**. After a teammate approves, someone comments **`atlantis apply`**, and Atlantis applies the change and merges the PR. Nobody needs admin credentials on their laptop, and every change is recorded in the pull request.

### The pull request flow

```flow
🌿 | Open a pull request | A change to Terraform code, e.g. a new S3 bucket in the dev account.
📨 | Webhook | Bitbucket tells Atlantis "this PR was opened or updated".
📝 | Auto plan | Atlantis runs `terraform plan` for each changed project and comments the output on the PR.
👀 | Review and approve | A teammate reads the plan and approves the PR.
🚀 | Apply | Someone comments `atlantis apply`. Atlantis checks the PR is approved and mergeable, then applies.
✅ | Merge | Atlantis comments the result and merges the PR (with automerge on).
```

### Key words

| Word | Meaning |
|---|---|
| **Webhook** | A message Bitbucket sends to Atlantis's URL whenever something happens on a PR |
| **Project** | One Terraform folder (one state file), e.g. `dev/us-east-1/network` |
| **Repo config** (`atlantis.yaml`) | A file in your Terraform repository listing the projects |
| **Server-side config** | Rules set on the Atlantis server that every repository must follow, e.g. "apply only after approval" |
| **Workflow** | The exact commands Atlantis runs for plan and apply |
| **Lock** | While a PR has a plan for a project, other PRs can't plan that project. This stops two changes from colliding |
| **Hub account** | The AWS account where Atlantis runs |
| **Target account** | An account Atlantis changes, through a role it's allowed to assume |

### Why build it by hand?

In real life you would manage Atlantis with code. Doing it once by hand shows you **every AWS piece and why it exists**, which is what you need when it breaks. It also explains a common chicken-and-egg problem: Atlantis can't create the roles and state buckets it needs before it exists. That's why many teams create those first pieces by hand or with CloudFormation, and let Atlantis manage everything after that.

## The architecture we'll build

> **In simple words:** Bitbucket talks to a **load balancer** over HTTPS. The load balancer passes requests to the **Atlantis container** running on Fargate in **private subnets**. Atlantis reads its secrets from Secrets Manager, then **assumes a role in each target account** to run Terraform there, keeping each account's state in that account's own S3 bucket.

```text
 Bitbucket Cloud ─ webhooks, HTTPS (Bitbucket IPs only) ─┐
 Your team (office or VPN) ─ web UI, HTTPS ──────────────┤
                                                         ▼
 HUB ACCOUNT  ┌─ VPC ─────────────────────────────────────┐
              │ public:  [ Load balancer + ACM cert ]     │
              │                    │ port 4141            │
              │ private: [ ECS Fargate task: Atlantis ]   │
              │                    │ out through NAT      │
              └────────────────────┼──────────────────────┘
   Secrets Manager · Parameter Store · CloudWatch · Route 53
                                   │ sts:AssumeRole
                ┌──────────────────┴─────────────────┐
                ▼                                    ▼
   TARGET ACCOUNT A                     TARGET ACCOUNT B
   role atlantis-role-<id>              role atlantis-role-<id>
   S3 + DynamoDB for state              S3 + DynamoDB for state
```

### AWS services used, and their job

| AWS service | Job in this setup | Learn it here |
|---|---|---|
| **VPC** (public and private subnets, NAT) | A private home for Atlantis; the NAT lets it reach Bitbucket and download Terraform | [VPC](#/tool/aws-vpc) |
| **ECS on Fargate** | Runs the Atlantis container without managing servers | [ECS](#/tool/aws-ecs) |
| **Application Load Balancer** | The public HTTPS front door for webhooks and the web UI | [Load balancers](#/tool/aws-elb) |
| **ACM** | A free TLS certificate for `atlantis.example.com` | [ELB: HTTPS](#/tool/aws-elb/https-with-a-free-acm-certificate) |
| **Route 53** | The DNS name pointing at the load balancer | [Route 53](#/tool/aws-route53) |
| **Secrets Manager** | Stores the Bitbucket token, the webhook secret and the UI password; ECS injects them at start-up | This guide, Step 2 |
| **Systems Manager Parameter Store** | Stores Atlantis's server-side repo config as JSON | This guide, Step 7 |
| **IAM** | Roles for ECS, and the cross-account roles Atlantis assumes | [IAM](#/tool/aws-iam) |
| **CloudWatch Logs** | Atlantis's logs, for troubleshooting | This guide, Step 8 |
| **S3 + DynamoDB** | Terraform state and state locks, one set per account | [Terraform: state](#/tool/terraform/state-and-remote-backends) |
| **KMS** (optional) | Your own keys for encrypting state and secrets | [KMS](#/tool/aws-kms) |

## Before you start

> **In simple words:** Collect the few things Atlantis depends on: an AWS account to run it in, a VPC with public and private subnets, a domain in Route 53, and admin rights on the Bitbucket repository. Then set a few shell variables, so every later command can be pasted as-is.

| You need | Notes |
|---|---|
| A **hub account** and admin access with the AWS CLI | Often a "tooling" or "operations" account. See [Create your AWS account](#/tool/aws-account) |
| A **VPC** with 2 public and 2 private subnets and a **NAT gateway** | Build one with the [VPC guide](#/tool/aws-vpc) |
| A **public hosted zone** in Route 53 | E.g. `example.com`. Atlantis will live at `atlantis.example.com` |
| A **Bitbucket Cloud** workspace and repository | E.g. `my-workspace/terraform-infra`, where you're an admin |
| `jq`, `openssl` and Python 3 on your machine | Used to build JSON and generate secrets |
| Admin access to each **target account** | To create the role and state bucket Atlantis will use |

Set these once in your terminal and change the values to yours:

```bash
export AWS_REGION=us-east-1
export HUB_ACCOUNT_ID=111111111111            # the account that runs Atlantis
export DOMAIN=example.com                     # public hosted zone in Route 53
export ATLANTIS_HOST=atlantis.example.com
export BB_WORKSPACE=my-workspace
export BB_REPO=terraform-infra
export BB_USER=atlantis-bot                   # Bitbucket username of the service account
export BB_EMAIL=atlantis-bot@example.com      # its Atlassian account email
export TF_VERSION=1.17.1                      # match required_version in your Terraform code
export VPC_ID=vpc-0123456789abcdef0
export PUBLIC_SUBNETS="subnet-0aaa1111aaaa1111a subnet-0bbb2222bbbb2222b"
export PRIVATE_SUBNETS="subnet-0ccc3333cccc3333c subnet-0ddd4444dddd4444d"
export TEAM_CIDR=203.0.113.0/24               # office or VPN range allowed to open the web UI
```

## Step 1: Bitbucket service account and API token

> **In simple words:** Atlantis needs its own Bitbucket login to read pull requests, post comments, set build statuses and merge. Use a dedicated **service account** (not a person's account), and give it an **API token** with only the permissions it needs.

> **Warning:** Bitbucket Cloud **app passwords stopped working in 2026**. Use an **API token with scopes** instead. Atlantis supports it: `ATLANTIS_BITBUCKET_API_USER` is the account's **email**, used for API calls, and `ATLANTIS_BITBUCKET_USER` is the **Bitbucket username**, used for git.

1. Create (or ask your admin for) a Bitbucket user such as `atlantis-bot` with its own email, and add it to the workspace.
2. Give it **Write** access to the repository: **Repository settings → Repository permissions → Add** `atlantis-bot` → **Write**.
3. Sign in as that user. Choose the **profile picture → Account settings → Security** tab → **Create and manage API tokens → Create API token with scopes**.
4. Name it `atlantis`, set an **expiry date** (for example one year, with a calendar reminder to rotate it), choose **Bitbucket** as the app, and select these scopes:

| Scope | Why Atlantis needs it |
|---|---|
| `read:repository:bitbucket` | Clone the repository and read files |
| `write:repository:bitbucket` | Set commit build statuses (the ✓/✗ next to each commit) |
| `read:pullrequest:bitbucket` | Read pull requests and post comments |
| `write:pullrequest:bitbucket` | Merge the PR after apply (automerge) |
| `read:user:bitbucket` | Read its own account details |

5. Choose **Create token** and **copy it now**: it's shown only once. You'll store it in Secrets Manager in the next step.

> **Note:** Atlantis's documentation doesn't publish an official scope list for Bitbucket API tokens yet. The set above covers everything Atlantis does. If you turn automerge off, you can drop `write:pullrequest:bitbucket`.

Also note the account's **Bitbucket username** (Bitbucket **Personal settings**; it's case-sensitive) and its **Atlassian email**. They go into `BB_USER` and `BB_EMAIL`.

## Step 2: Store the secrets in Secrets Manager

> **In simple words:** Never put tokens in a task definition or in Git. Put them in **Secrets Manager**; ECS reads them when the container starts and hands them to Atlantis as environment variables.

Three secrets: the Bitbucket token, a **webhook secret** (a random string that Bitbucket and Atlantis share), and a password for the Atlantis **web UI**.

**Console:** **Secrets Manager → Store a new secret → Other type of secret → Plaintext**, paste the value, name it `atlantis/bitbucket-token`, and keep the defaults. Repeat for the other two.

**CLI:**

```bash
read -rsp "Paste the Bitbucket API token: " BB_TOKEN; echo
aws secretsmanager create-secret --name atlantis/bitbucket-token --secret-string "$BB_TOKEN"
unset BB_TOKEN

WEBHOOK_SECRET=$(openssl rand -hex 32)
aws secretsmanager create-secret --name atlantis/webhook-secret --secret-string "$WEBHOOK_SECRET"
echo "Save this for Step 12 (Bitbucket webhook): $WEBHOOK_SECRET"

aws secretsmanager create-secret --name atlantis/web-password --secret-string "$(openssl rand -base64 24)"

# full ARNs (with the random suffix) are needed by ECS
SECRET_TOKEN_ARN=$(aws secretsmanager describe-secret --secret-id atlantis/bitbucket-token --query ARN --output text)
SECRET_WEBHOOK_ARN=$(aws secretsmanager describe-secret --secret-id atlantis/webhook-secret --query ARN --output text)
SECRET_WEB_ARN=$(aws secretsmanager describe-secret --secret-id atlantis/web-password --query ARN --output text)
```

To read the UI password later: `aws secretsmanager get-secret-value --secret-id atlantis/web-password --query SecretString --output text`.

AWS docs: [Pass Secrets Manager secrets to ECS](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/secrets-envvar-secrets-manager.html)

## Step 3: TLS certificate with ACM

> **In simple words:** Bitbucket only sends webhooks to **HTTPS** addresses with a valid certificate. ACM gives you one for free, and proves you own the domain by checking a DNS record that Route 53 can create for you.

**Console:** **Certificate Manager → Request → Request a public certificate** → domain `atlantis.example.com` → **DNS validation** → **Request**. Open the certificate → **Create records in Route 53** → **Create records**. Wait until the status is **Issued** (usually a few minutes).

**CLI:**

```bash
CERT_ARN=$(aws acm request-certificate --domain-name "$ATLANTIS_HOST" \
  --validation-method DNS --query CertificateArn --output text)
ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name "$DOMAIN" \
  --query 'HostedZones[0].Id' --output text | cut -d/ -f3)

sleep 15   # give ACM a moment to generate the validation record
read -r REC_NAME REC_VALUE < <(aws acm describe-certificate --certificate-arn "$CERT_ARN" \
  --query 'Certificate.DomainValidationOptions[0].ResourceRecord.[Name,Value]' --output text)

aws route53 change-resource-record-sets --hosted-zone-id "$ZONE_ID" --change-batch \
  "{\"Changes\":[{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{\"Name\":\"$REC_NAME\",\"Type\":\"CNAME\",\"TTL\":300,\"ResourceRecords\":[{\"Value\":\"$REC_VALUE\"}]}}]}"

aws acm wait certificate-validated --certificate-arn "$CERT_ARN"
echo "Certificate issued: $CERT_ARN"
```

## Step 4: Security groups

> **In simple words:** Two firewalls. The **load balancer** accepts HTTPS only from **Bitbucket's published IP ranges** and your **team's network**. The **Atlantis task** accepts traffic only **from the load balancer**. Atlantis is never directly reachable from the internet.

Atlassian publishes the addresses Bitbucket Cloud uses to send webhooks in a machine-readable list. The commands below download it, keep the Bitbucket outgoing (egress) IPv4 ranges, merge overlapping ranges, and add one rule per range:

```bash
ALB_SG=$(aws ec2 create-security-group --vpc-id "$VPC_ID" --group-name atlantis-alb \
  --description "Atlantis load balancer" --query GroupId --output text)
TASK_SG=$(aws ec2 create-security-group --vpc-id "$VPC_ID" --group-name atlantis-task \
  --description "Atlantis ECS task" --query GroupId --output text)

# Bitbucket Cloud webhook sources: Atlassian's published egress ranges for Bitbucket (IPv4)
curl -s https://ip-ranges.atlassian.com/ \
  | jq -r '.items[] | select((.product | index("bitbucket")) and (.direction | index("egress")) and (.cidr | contains(":") | not)) | .cidr' \
  | python3 -c 'import ipaddress,sys; [print(n) for n in ipaddress.collapse_addresses(ipaddress.ip_network(l.strip()) for l in sys.stdin if l.strip())]' \
  > bitbucket-cidrs.txt
echo "Bitbucket ranges: $(wc -l < bitbucket-cidrs.txt)"

while read -r cidr; do
  aws ec2 authorize-security-group-ingress --group-id "$ALB_SG" --protocol tcp --port 443 --cidr "$cidr" > /dev/null
done < bitbucket-cidrs.txt

# your team, for the web UI (port 80 only redirects to 443)
aws ec2 authorize-security-group-ingress --group-id "$ALB_SG" --protocol tcp --port 443 --cidr "$TEAM_CIDR"
aws ec2 authorize-security-group-ingress --group-id "$ALB_SG" --protocol tcp --port 80  --cidr "$TEAM_CIDR"

# the task only accepts traffic from the load balancer
aws ec2 authorize-security-group-ingress --group-id "$TASK_SG" --protocol tcp --port 4141 --source-group "$ALB_SG"
```

> **Warning:** Bitbucket's ranges change over time (in late 2026 the list had more than 50 entries, about 40 after merging). **Re-run the download every few months** and add any new ranges, or webhooks from new Bitbucket addresses will be silently blocked. A security group allows **60 inbound rules** by default; request a quota increase if you get close.

## Step 5: IAM roles in the hub account

> **In simple words:** ECS needs two roles. The **task execution role** is used by ECS itself to pull the image, read the secrets and write logs. The **task role** is what **Atlantis** uses, and it's allowed to do exactly one thing: **assume the `atlantis-role-*` role in target accounts**.

```bash
cat > ecs-tasks-trust.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "ecs-tasks.amazonaws.com" },
    "Action": "sts:AssumeRole",
    "Condition": { "StringEquals": { "aws:SourceAccount": "${HUB_ACCOUNT_ID}" } }
  }]
}
EOF

# 1) task execution role: pull image, write logs, read the secrets and the config parameter
aws iam create-role --role-name atlantis-task-execution --assume-role-policy-document file://ecs-tasks-trust.json
aws iam attach-role-policy --role-name atlantis-task-execution \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

cat > exec-secrets.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    { "Effect": "Allow", "Action": "secretsmanager:GetSecretValue",
      "Resource": ["${SECRET_TOKEN_ARN}", "${SECRET_WEBHOOK_ARN}", "${SECRET_WEB_ARN}"] },
    { "Effect": "Allow", "Action": "ssm:GetParameters",
      "Resource": "arn:aws:ssm:${AWS_REGION}:${HUB_ACCOUNT_ID}:parameter/atlantis/*" }
  ]
}
EOF
aws iam put-role-policy --role-name atlantis-task-execution --policy-name read-atlantis-secrets \
  --policy-document file://exec-secrets.json

# 2) task role: what Atlantis itself can do = assume the Atlantis role in target accounts
aws iam create-role --role-name atlantis-task-role --assume-role-policy-document file://ecs-tasks-trust.json
cat > assume-targets.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [{ "Effect": "Allow", "Action": "sts:AssumeRole",
                  "Resource": "arn:aws:iam::*:role/atlantis-role-*" }]
}
EOF
aws iam put-role-policy --role-name atlantis-task-role --policy-name assume-atlantis-roles \
  --policy-document file://assume-targets.json
```

> **Note:** Some teams simply attach `AdministratorAccess` to the task role. It works, but anyone who can change a workflow could then do anything in the hub account. The pattern above keeps the hub clean: if Atlantis also manages hub resources, create an `atlantis-role-<hub-id>` in the hub too, exactly as in Step 6.

## Step 6: Prepare each target account

> **In simple words:** In **every account Atlantis will change** (dev, staging, prod, and the hub itself if needed), create the same three things: an **S3 bucket** for Terraform state, a **DynamoDB table** for state locks, and the **`atlantis-role-<account-id>`** role that trusts only the Atlantis task role.

Run this with admin credentials **for the target account** (for example an `AWS_PROFILE` for that account):

```bash
export AWS_PROFILE=dev-admin                  # credentials for the target account
TARGET_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="terraform-backend-${TARGET_ACCOUNT_ID}"

# --- state bucket: versioned, encrypted, private, protected from deletion
aws s3api create-bucket --bucket "$BUCKET" --region "$AWS_REGION"
# outside us-east-1 add:  --create-bucket-configuration LocationConstraint=$AWS_REGION
aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled
aws s3api put-public-access-block --bucket "$BUCKET" --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-encryption --bucket "$BUCKET" --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"aws:kms"},"BucketKeyEnabled":true}]}'
aws s3api put-bucket-policy --bucket "$BUCKET" --policy \
  "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"DeletionProtection\",\"Effect\":\"Deny\",\"Principal\":\"*\",\"Action\":\"s3:DeleteBucket\",\"Resource\":\"arn:aws:s3:::${BUCKET}\"}]}"

# --- lock table (needed for Terraform versions that lock with DynamoDB)
aws dynamodb create-table --table-name "$BUCKET" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST

# --- the role Atlantis assumes; it trusts ONLY the Atlantis task role in the hub
cat > atlantis-role-trust.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "AWS": "arn:aws:iam::${HUB_ACCOUNT_ID}:role/atlantis-task-role" },
    "Action": "sts:AssumeRole"
  }]
}
EOF
aws iam create-role --role-name "atlantis-role-${TARGET_ACCOUNT_ID}" \
  --assume-role-policy-document file://atlantis-role-trust.json
aws iam attach-role-policy --role-name "atlantis-role-${TARGET_ACCOUNT_ID}" \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

unset AWS_PROFILE                             # back to the hub account
```

| Choice | Why |
|---|---|
| One bucket and table **per account** | A mistake in dev can never touch prod's state |
| Role name includes the account ID | Easy to read in logs, and one IAM pattern (`atlantis-role-*`) matches every account |
| `AdministratorAccess` on the target role | Terraform often needs broad rights. Protect it with **PR approval rules** (Step 7), and use a narrower policy where you can |
| Deny `s3:DeleteBucket` | Losing state is one of the worst Terraform accidents |

> **Tip:** Terraform **1.11 and later** can lock state with a small lock file in S3 (`use_lockfile = true`), and DynamoDB locking is deprecated. Older versions such as 1.8 still need the DynamoDB table. Keeping both during a migration is supported.

> **Tip:** With many accounts, roll these three resources out with **CloudFormation StackSets** (one template, deployed to every account in your organization) instead of running this by hand each time.

## Step 7: Server-side repo config in Parameter Store

> **In simple words:** The **server-side config** holds the rules Atlantis enforces for every repository: which branch, which file lists the projects, and that **apply needs an approved, mergeable PR**. You store it in Parameter Store and Atlantis reads it at start-up.

Create `repos.yaml`:

```yaml
repos:
  - id: /.*/                     # every allowlisted repository
    branch: /main/               # only PRs that target main
    repo_config_file: atlantis.yaml
    apply_requirements: [approved, mergeable]   # no apply without review
    allowed_overrides: [workflow]               # a project may pick a workflow defined below...
    allow_custom_workflows: false               # ...but can't invent its own commands

workflows:
  standard:
    plan:
      steps:
        - env:
            name: TF_PLUGIN_CACHE_DIR       # reuse downloaded providers between runs
            command: 'mkdir -p "$(pwd)/.terraform-cache" && echo "$(pwd)/.terraform-cache"'
        - run: terraform version
        - init
        - plan
  with-shared-vars:
    plan:
      steps:
        - init
        - plan:
            extra_args: ["-var-file=../../shared.tfvars"]
    apply:
      steps:
        - apply
```

Convert it to JSON and store it:

```bash
python3 -c 'import json,yaml; print(json.dumps(yaml.safe_load(open("repos.yaml"))))' > repos.json   # pip install pyyaml
aws ssm put-parameter --name /atlantis/repo-config-json --type String --value file://repos.json
```

| Setting | What it protects |
|---|---|
| `apply_requirements: [approved, mergeable]` | Nobody can apply an unreviewed change, or a PR with conflicts or failing checks |
| `allow_custom_workflows: false` | A PR can't add a workflow that runs any command it likes with Atlantis's admin role |
| `branch: /main/` | Plans only for PRs into `main` |

Atlantis docs: [Server-side repo config](https://www.runatlantis.io/docs/server-side-repo-config) · [Custom workflows](https://www.runatlantis.io/docs/custom-workflows)

## Step 8: ECS cluster and logs

> **In simple words:** An ECS **cluster** is just a named group for your tasks. On Fargate there are no servers to add. The **log group** is where Atlantis's output goes, and it's the first place to look when something doesn't work.

```bash
aws ecs create-cluster --cluster-name atlantis
aws logs create-log-group --log-group-name /ecs/atlantis
aws logs put-retention-policy --log-group-name /ecs/atlantis --retention-in-days 30
```

## Step 9: Task definition

> **In simple words:** The **task definition** is Atlantis's recipe: which image, how much CPU and memory, which port, which settings, and which secrets to inject. Settings are plain environment variables; secrets come from Secrets Manager and Parameter Store.

```bash
cat > atlantis-task.json <<EOF
{
  "family": "atlantis",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "1024",
  "memory": "2048",
  "runtimePlatform": { "cpuArchitecture": "X86_64", "operatingSystemFamily": "LINUX" },
  "executionRoleArn": "arn:aws:iam::${HUB_ACCOUNT_ID}:role/atlantis-task-execution",
  "taskRoleArn": "arn:aws:iam::${HUB_ACCOUNT_ID}:role/atlantis-task-role",
  "containerDefinitions": [{
    "name": "atlantis",
    "image": "ghcr.io/runatlantis/atlantis:v0.49.0",
    "essential": true,
    "portMappings": [{ "containerPort": 4141, "protocol": "tcp" }],
    "environment": [
      { "name": "ATLANTIS_ATLANTIS_URL",               "value": "https://${ATLANTIS_HOST}" },
      { "name": "ATLANTIS_PORT",                       "value": "4141" },
      { "name": "ATLANTIS_REPO_ALLOWLIST",             "value": "bitbucket.org/${BB_WORKSPACE}/${BB_REPO}" },
      { "name": "ATLANTIS_BITBUCKET_USER",             "value": "${BB_USER}" },
      { "name": "ATLANTIS_BITBUCKET_API_USER",         "value": "${BB_EMAIL}" },
      { "name": "ATLANTIS_DEFAULT_TF_VERSION",         "value": "${TF_VERSION}" },
      { "name": "ATLANTIS_WRITE_GIT_CREDS",            "value": "true" },
      { "name": "ATLANTIS_ENABLE_DIFF_MARKDOWN_FORMAT", "value": "true" },
      { "name": "ATLANTIS_WEB_BASIC_AUTH",             "value": "true" },
      { "name": "ATLANTIS_WEB_USERNAME",               "value": "admin" }
    ],
    "secrets": [
      { "name": "ATLANTIS_BITBUCKET_TOKEN",          "valueFrom": "${SECRET_TOKEN_ARN}" },
      { "name": "ATLANTIS_BITBUCKET_WEBHOOK_SECRET", "valueFrom": "${SECRET_WEBHOOK_ARN}" },
      { "name": "ATLANTIS_WEB_PASSWORD",             "valueFrom": "${SECRET_WEB_ARN}" },
      { "name": "ATLANTIS_REPO_CONFIG_JSON",
        "valueFrom": "arn:aws:ssm:${AWS_REGION}:${HUB_ACCOUNT_ID}:parameter/atlantis/repo-config-json" }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": { "awslogs-group": "/ecs/atlantis", "awslogs-region": "${AWS_REGION}", "awslogs-stream-prefix": "atlantis" }
    }
  }]
}
EOF
aws ecs register-task-definition --cli-input-json file://atlantis-task.json
```

| Setting | What it does |
|---|---|
| `ATLANTIS_ATLANTIS_URL` | The public URL, used in links inside PR comments |
| `ATLANTIS_REPO_ALLOWLIST` | Only webhooks from this repository are accepted (comma-separate several) |
| `ATLANTIS_BITBUCKET_USER` / `_API_USER` | Username for git, email for API calls (API tokens need both) |
| `ATLANTIS_DEFAULT_TF_VERSION` | Terraform version Atlantis downloads and uses unless a project says otherwise |
| `ATLANTIS_WRITE_GIT_CREDS` | Lets Terraform clone **private modules** from Bitbucket with the same token |
| `ATLANTIS_ENABLE_DIFF_MARKDOWN_FORMAT` | Colours `+` / `-` lines in plan comments |
| `ATLANTIS_WEB_BASIC_AUTH` | Puts a username and password on the web UI. Webhooks (`/events`) and health checks (`/healthz`) are not affected |

**Sizing:** 1 vCPU and 2 GB is fine to start. A repository with hundreds of projects, or big plans, can need **4 vCPU and 16 GB**. Watch memory in the ECS console and resize by registering a new revision.

> **Note:** On Fargate the container's disk is **temporary**. Atlantis keeps its locks and saved plans on disk, so a restart forgets them and open PRs need a fresh plan (comment `atlantis plan`). For persistence, mount an **EFS** volume as the data directory.

## Step 10: Load balancer and target group

> **In simple words:** The **target group** knows where the Atlantis task is and checks it's healthy (`/healthz`). The **load balancer** listens on HTTPS with your certificate and forwards to the target group. Port 80 just redirects to HTTPS.

**Console:** **EC2 → Target groups → Create**: type **IP addresses**, protocol **HTTP**, port **4141**, your VPC, health check path **`/healthz`**; don't register targets (ECS will). Then **Load balancers → Create → Application Load Balancer**: **Internet-facing**, the two **public** subnets, security group **atlantis-alb**, listener **HTTPS:443** → forward to the target group, certificate from ACM. Add listener **HTTP:80** → redirect to HTTPS.

**CLI:**

```bash
TG_ARN=$(aws elbv2 create-target-group --name atlantis --protocol HTTP --port 4141 \
  --vpc-id "$VPC_ID" --target-type ip --health-check-path /healthz --matcher HttpCode=200 \
  --query 'TargetGroups[0].TargetGroupArn' --output text)
aws elbv2 modify-target-group-attributes --target-group-arn "$TG_ARN" \
  --attributes Key=deregistration_delay.timeout_seconds,Value=30

ALB_ARN=$(aws elbv2 create-load-balancer --name atlantis --type application --scheme internet-facing \
  --subnets $PUBLIC_SUBNETS --security-groups "$ALB_SG" \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text)
aws elbv2 wait load-balancer-available --load-balancer-arns "$ALB_ARN"

aws elbv2 create-listener --load-balancer-arn "$ALB_ARN" --protocol HTTPS --port 443 \
  --certificates CertificateArn="$CERT_ARN" --ssl-policy ELBSecurityPolicy-TLS13-1-2-2021-06 \
  --default-actions Type=forward,TargetGroupArn="$TG_ARN"
aws elbv2 create-listener --load-balancer-arn "$ALB_ARN" --protocol HTTP --port 80 \
  --default-actions 'Type=redirect,RedirectConfig={Protocol=HTTPS,Port=443,StatusCode=HTTP_301}'

aws elbv2 modify-load-balancer-attributes --load-balancer-arn "$ALB_ARN" \
  --attributes Key=deletion_protection.enabled,Value=true
```

## Step 11: ECS service and DNS name

> **In simple words:** The **service** keeps exactly **one** Atlantis task running in the private subnets and registers it with the load balancer. Then a Route 53 **alias record** gives it a friendly name.

```bash
aws ecs create-service --cluster atlantis --service-name atlantis \
  --task-definition atlantis --desired-count 1 --launch-type FARGATE \
  --deployment-configuration "minimumHealthyPercent=0,maximumPercent=100" \
  --network-configuration "awsvpcConfiguration={subnets=[${PRIVATE_SUBNETS// /,}],securityGroups=[$TASK_SG],assignPublicIp=DISABLED}" \
  --load-balancers "targetGroupArn=$TG_ARN,containerName=atlantis,containerPort=4141" \
  --health-check-grace-period-seconds 120
aws ecs wait services-stable --cluster atlantis --services atlantis

read -r ALB_DNS ALB_ZONE < <(aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN" \
  --query 'LoadBalancers[0].[DNSName,CanonicalHostedZoneId]' --output text)
aws route53 change-resource-record-sets --hosted-zone-id "$ZONE_ID" --change-batch \
  "{\"Changes\":[{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{\"Name\":\"$ATLANTIS_HOST\",\"Type\":\"A\",\"AliasTarget\":{\"HostedZoneId\":\"$ALB_ZONE\",\"DNSName\":\"dualstack.$ALB_DNS\",\"EvaluateTargetHealth\":false}}}]}"

curl -s "https://$ATLANTIS_HOST/healthz"     # from your team network: {"status":"ok"}
```

| Setting | Why |
|---|---|
| `--desired-count 1` | Run **exactly one** Atlantis. Two copies would each keep their own locks and plans |
| `minimumHealthyPercent=0, maximumPercent=100` | During a deploy, the old task stops **before** the new one starts, so two never run at once (expect about a minute of downtime) |
| `assignPublicIp=DISABLED` | The task has no public IP; it reaches the internet through the NAT gateway |
| Health check grace period | Gives Atlantis time to start and download Terraform before health checks count |

Open `https://atlantis.example.com` from your team network and sign in as **admin** with the password from Step 2. You should see the Atlantis page with no locks yet.

## Step 12: Connect Bitbucket (webhook)

> **In simple words:** Tell Bitbucket to **call Atlantis** whenever a pull request is opened, updated, merged, declined or commented on. The shared secret lets Atlantis check that the call really came from your repository.

In the repository: **Repository settings → Webhooks → Add webhook**:

| Field | Value |
|---|---|
| **Title** | `Atlantis` |
| **URL** | `https://atlantis.example.com/events` |
| **Secret** | The webhook secret from Step 2 |
| **Status** | Active |
| **SSL / TLS** | Keep certificate verification **on** |
| **Triggers** | **Choose from a full list of triggers**. Under **Pull Request**, tick **Created**, **Updated**, **Merged**, **Declined** and **Comment created**. Leave everything else unticked |

**Save**, then open the webhook and use **View requests** to watch deliveries. A `200` means Atlantis received it.

Atlantis docs: [Configuring webhooks](https://www.runatlantis.io/docs/configuring-webhooks)

## Step 13: Prepare the Terraform repository

> **In simple words:** Add an **`atlantis.yaml`** file listing your projects, and make each project's Terraform **assume the target account's Atlantis role**, both for the AWS provider and for the state backend.

`atlantis.yaml` at the repository root:

```yaml
version: 3
automerge: true                    # merge the PR after a successful apply
parallel_plan: false
parallel_apply: false
abort_on_execution_order_fail: true

projects:
  - name: dev-us-east-1-network
    dir: dev/us-east-1/network
    autoplan:
      enabled: true
      when_modified: ["*.tf", "*.tfvars", "../../modules/**/*.tf"]
    workflow: standard

  - name: prod-us-east-1-network
    dir: prod/us-east-1/network
    autoplan:
      enabled: true
      when_modified: ["*.tf", "*.tfvars"]
    workflow: standard
```

In each project folder, for example `dev/us-east-1/network/providers.tf` (use the **target** account's ID):

```hcl
terraform {
  required_version = "1.17.1"

  backend "s3" {
    bucket         = "terraform-backend-222222222222"
    key            = "us-east-1/network/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-backend-222222222222"   # or: use_lockfile = true (Terraform 1.11+)
    assume_role = {
      role_arn     = "arn:aws:iam::222222222222:role/atlantis-role-222222222222"
      session_name = "atlantis"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  assume_role {
    role_arn     = "arn:aws:iam::222222222222:role/atlantis-role-222222222222"
    session_name = "atlantis"
  }
  allowed_account_ids = ["222222222222"]   # refuse to run against any other account
}
```

Atlantis docs: [Repo-level atlantis.yaml](https://www.runatlantis.io/docs/repo-level-atlantis-yaml)

## Step 14: Your first plan and apply

> **In simple words:** Prove the whole chain works: open a small PR, watch Atlantis comment a plan, get it approved, comment `atlantis apply`, and see it apply and merge.

1. On a new branch, make a harmless change in `dev/us-east-1/network`, e.g. add a tag. Push it and **open a pull request to `main`**.
2. Within a minute, Atlantis comments **"Ran Plan for project: dev-us-east-1-network"** with the plan output, and the commit shows an **atlantis/plan** status.
3. A teammate reviews the plan and **approves** the PR.
4. Comment **`atlantis apply`**. Atlantis applies, comments the output and, with `automerge: true`, **merges** the PR.
5. In the **target account**, check the change happened, and that the state file appeared in `terraform-backend-<account-id>`.

| Comment | What it does |
|---|---|
| `atlantis help` | Lists the commands |
| `atlantis plan` | Plans every changed project again (e.g. after a restart) |
| `atlantis plan -p dev-us-east-1-network` | Plans one project |
| `atlantis plan -- -target=aws_s3_bucket.logs` | Passes extra flags to Terraform |
| `atlantis apply` | Applies every planned project in the PR |
| `atlantis apply -p dev-us-east-1-network` | Applies one project |
| `atlantis unlock` | Throws away this PR's plans and releases its locks |

## Day-2 operations

> **In simple words:** Most changes later are small: a new Atlantis version, a new token, a config change or a new account. Each one is "update one thing, then restart the service".

| Task | How |
|---|---|
| **Upgrade Atlantis** | Change the image tag in `atlantis-task.json` (check the [release notes](https://github.com/runatlantis/atlantis/releases) first), run `aws ecs register-task-definition --cli-input-json file://atlantis-task.json`, then `aws ecs update-service --cluster atlantis --service atlantis --task-definition atlantis` |
| **Rotate the Bitbucket token** | Create a new token (Step 1), `aws secretsmanager put-secret-value --secret-id atlantis/bitbucket-token --secret-string "$NEW"`, then `aws ecs update-service --cluster atlantis --service atlantis --force-new-deployment` |
| **Change server-side rules** | Edit `repos.yaml`, convert it, run `aws ssm put-parameter --name /atlantis/repo-config-json --type String --value file://repos.json --overwrite`, then force a new deployment |
| **Add an account** | Run Step 6 in the new account, then add its projects to `atlantis.yaml` |
| **Add a repository** | Add it to `ATLANTIS_REPO_ALLOWLIST` (new task definition revision) and add the webhook (Step 12) to that repository |
| **See what Atlantis is doing** | `aws logs tail /ecs/atlantis --follow` |
| **Refresh Bitbucket IP ranges** | Re-run the download in Step 4 and add any new ranges |

> **Warning:** Restarting Atlantis forgets locks and saved plans (unless you use EFS). Deploy when nobody is in the middle of an apply, then ask open PRs to comment `atlantis plan`.

## Troubleshooting

> **In simple words:** Follow the request: **Bitbucket → load balancer → Atlantis → AWS role → Terraform**. Bitbucket's **View requests**, the target group's **health status** and the **CloudWatch logs** tell you which hop failed.

| Problem | Likely cause | Fix |
|---|---|---|
| No comment on the PR at all | Webhook not delivered: blocked by the ALB security group, wrong URL, or wrong triggers | Bitbucket **View requests** shows the error. Check the URL ends in `/events`, refresh the Bitbucket IP ranges, check the triggers |
| Webhook returns `400` / "repo not allowlisted" in the logs | `ATLANTIS_REPO_ALLOWLIST` doesn't match `bitbucket.org/<workspace>/<repo>` | Fix the value and register a new task definition |
| Webhook rejected after adding the secret | The secret in Bitbucket differs from `atlantis/webhook-secret` | Paste the same value in both places and redeploy |
| Task keeps stopping, target **unhealthy** | Task SG doesn't allow 4141 from the ALB SG, or wrong health check path | Allow 4141 from `atlantis-alb`; the health path is `/healthz` |
| `ResourceInitializationError: unable to pull secrets` | The execution role can't read a secret or parameter, or an ARN is wrong | Check `read-atlantis-secrets` lists the exact ARNs, and the parameter name is under `/atlantis/` |
| `CannotPullContainerError` | Private subnets have no route to the internet | Make sure the private route table sends `0.0.0.0/0` to a NAT gateway |
| `401` from the Bitbucket API in the logs | Expired token, missing scope, or `ATLANTIS_BITBUCKET_API_USER` isn't the account **email** | Create a new token with the scopes in Step 1 and update the secret |
| `git clone` fails with "Authentication failed" | `ATLANTIS_BITBUCKET_USER` isn't the exact Bitbucket **username** (it's case-sensitive) | Copy it from the account's Bitbucket settings |
| `AccessDenied ... sts:AssumeRole` | The target role's trust policy doesn't name `atlantis-task-role`, or the role name doesn't match `atlantis-role-*` | Fix the trust policy. If you recreated the task role, update every trust policy too |
| `Error acquiring the state lock` | Another plan or apply holds the lock, or an old lock was left behind | Wait, or comment `atlantis unlock`. Use `terraform force-unlock` only if you're sure nothing is running |
| "Pull request must be approved before running apply" | `apply_requirements` working as designed | Get an approval from someone else, and fix merge conflicts or failing checks |
| Terraform download or signature verification fails at start-up | Network or verification problem with downloads | Check the NAT gateway. Some teams build a small custom image `FROM ghcr.io/runatlantis/atlantis` with the Terraform binary already installed |
| `RulesPerSecurityGroupLimitExceeded` | More than 60 rules in the ALB security group | Request a quota increase, or move the team's UI rules to a second security group on the ALB |

## Clean up

> **In simple words:** Remove things in reverse order: the webhook and service first, then the load balancer, then the cluster, roles, secrets and certificate. Leave the **state buckets** alone if any Terraform state lives in them.

```bash
# remove the webhook in Bitbucket first (Repository settings -> Webhooks)
aws ecs update-service --cluster atlantis --service atlantis --desired-count 0
aws ecs delete-service --cluster atlantis --service atlantis --force
aws ecs delete-cluster --cluster atlantis

aws elbv2 modify-load-balancer-attributes --load-balancer-arn "$ALB_ARN" \
  --attributes Key=deletion_protection.enabled,Value=false
aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN"
aws elbv2 wait load-balancers-deleted --load-balancer-arns "$ALB_ARN"
aws elbv2 delete-target-group --target-group-arn "$TG_ARN"

aws route53 change-resource-record-sets --hosted-zone-id "$ZONE_ID" --change-batch \
  "{\"Changes\":[{\"Action\":\"DELETE\",\"ResourceRecordSet\":{\"Name\":\"$ATLANTIS_HOST\",\"Type\":\"A\",\"AliasTarget\":{\"HostedZoneId\":\"$ALB_ZONE\",\"DNSName\":\"dualstack.$ALB_DNS\",\"EvaluateTargetHealth\":false}}}]}"
aws acm delete-certificate --certificate-arn "$CERT_ARN"

sleep 60   # let the load balancer's network interfaces disappear
aws ec2 delete-security-group --group-id "$TASK_SG"
aws ec2 delete-security-group --group-id "$ALB_SG"

for s in atlantis/bitbucket-token atlantis/webhook-secret atlantis/web-password; do
  aws secretsmanager delete-secret --secret-id "$s" --force-delete-without-recovery
done
aws ssm delete-parameter --name /atlantis/repo-config-json
aws logs delete-log-group --log-group-name /ecs/atlantis

aws iam delete-role-policy --role-name atlantis-task-role --policy-name assume-atlantis-roles
aws iam delete-role --role-name atlantis-task-role
aws iam delete-role-policy --role-name atlantis-task-execution --policy-name read-atlantis-secrets
aws iam detach-role-policy --role-name atlantis-task-execution \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
aws iam delete-role --role-name atlantis-task-execution
```

Then revoke the Bitbucket API token (**Account settings → Security → API tokens**), and, in each target account, delete the `atlantis-role-<account-id>` role if nothing else uses it.

## Cheat sheet

> **In simple words:** The commands you'll use again and again, in one place.

| Task | Command |
|---|---|
| Atlantis logs, live | `aws logs tail /ecs/atlantis --follow` |
| Service health | `aws ecs describe-services --cluster atlantis --services atlantis --query 'services[0].[status,runningCount,deployments[0].rolloutState]'` |
| Target health | `aws elbv2 describe-target-health --target-group-arn $TG_ARN` |
| Restart Atlantis | `aws ecs update-service --cluster atlantis --service atlantis --force-new-deployment` |
| New version or settings | `aws ecs register-task-definition --cli-input-json file://atlantis-task.json` then `update-service --task-definition atlantis` |
| Update a secret | `aws secretsmanager put-secret-value --secret-id atlantis/bitbucket-token --secret-string "$NEW"` |
| Update server-side rules | `aws ssm put-parameter --name /atlantis/repo-config-json --type String --value file://repos.json --overwrite` |
| Health check | `curl https://atlantis.example.com/healthz` |
| PR commands | `atlantis plan`, `atlantis apply`, `atlantis plan -p <project>`, `atlantis unlock` |

**Next:** manage this setup itself as code once you understand it: the target-account pieces with CloudFormation StackSets, and Atlantis with a Terraform module. See the [Terraform guide](#/tool/terraform).
