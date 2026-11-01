# AWS IAM: Users, Roles and Policies

IAM (Identity and Access Management) controls **who** can do **what** in your AWS account. Every API call, from a console click or the CLI to Terraform, an EC2 instance or a Kubernetes pod, is checked by IAM. This guide shows how to create users, groups, roles and policies by hand, how to attach them, and how to give **EKS pods** their own AWS permissions with **EKS Pod Identity** and **IRSA**.

> **Note:** Use a sandbox account where you're an administrator. IAM itself is **free**. Only the resources you use with it cost money.

## Start here: IAM in simple words

> **In simple words:** IAM is the **security desk** of your AWS account. It hands out ID cards (**users** and **roles**) and writes the rules about which doors each card opens (**policies**). By default, every door is locked.

### A real-life comparison

Think of an **office building**:

| Office | IAM |
|---|---|
| An employee with a permanent ID card | **IAM user**: a long-term identity with a password or access keys |
| A department, such as "Finance" | **IAM group**: a set of users that share the same permissions |
| A **visitor badge** you pick up at the desk and hand back later | **IAM role**: temporary credentials that someone (or something) *assumes* |
| The list of rooms a card can open | **Policy**: a JSON document listing allowed or denied actions |
| Who is allowed to pick up a visitor badge | **Trust policy**: who may assume a role |

### Key words

| Word | Simple meaning |
|---|---|
| **Principal** | Whoever is making the request: a user, a role, or an AWS service |
| **Action** | What they want to do, such as `s3:GetObject` or `ec2:StartInstances` |
| **Resource** | What they want to do it to, identified by an **ARN** such as `arn:aws:s3:::my-bucket/*` |
| **Policy** | The JSON rules that allow or deny actions on resources |
| **Role** | An identity with **no password**: it gives out short-lived credentials to whoever is trusted to assume it |
| **Assume role** | Swap your current identity for a role's temporary credentials (`sts:AssumeRole`) |
| **Least privilege** | Give only the permissions that are actually needed, nothing more |

### Check yourself

1. What's the difference between a user and a role?
2. If no policy mentions an action, is it allowed or denied?
3. Who should get a role instead of a user?

> **Tip:** Answers: 1) A user is a permanent identity with long-term credentials; a role hands out temporary credentials to whoever assumes it. 2) Denied: everything is denied by default. 3) Applications, servers, pods, CI pipelines, and also humans signing in through SSO.

## How IAM decides: policies explained

> **In simple words:** For every request, IAM checks every policy that applies. **One explicit "Deny" wins over everything.** Otherwise there must be at least one "Allow", or the answer is no.

```text
 Request: alice wants s3:GetObject on arn:aws:s3:::reports/2026.csv
    │
    ├─ Any policy says Deny?  ──yes──▶  DENIED (always wins)
    │        no
    ├─ Any policy says Allow? ──no───▶  DENIED (default deny)
    │        yes
    └────────────────────────────────▶  ALLOWED
```

### Anatomy of a policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadReportsBucket",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::reports-bucket",
        "arn:aws:s3:::reports-bucket/*"
      ],
      "Condition": {
        "IpAddress": { "aws:SourceIp": "203.0.113.0/24" }
      }
    }
  ]
}
```

| Field | Meaning |
|---|---|
| `Version` | Always `"2012-10-17"`, the policy language version (not a date you change) |
| `Effect` | `Allow` or `Deny` |
| `Action` | One or more API actions; wildcards like `s3:Get*` work |
| `Resource` | The ARNs this applies to. `bucket` and `bucket/*` are **different** (the bucket vs the objects in it) |
| `Condition` | Optional extra checks: source IP, MFA, tags, time… |
| `Principal` | Only in **resource-based** and **trust** policies: *who* the rule is about |

### Types of policy

| Type | Attached to | Example |
|---|---|---|
| **AWS managed** | Users, groups, roles | `ReadOnlyAccess`, `AmazonS3ReadOnlyAccess`, maintained by AWS |
| **Customer managed** | Users, groups, roles | Your own reusable policy, such as `S3ReadReports` |
| **Inline** | One single user, group or role | Embedded; avoid it, because it's hard to find and reuse |
| **Resource-based** | A resource (S3 bucket, KMS key, ECR repo…) | A bucket policy allowing another account to read |
| **Trust policy** | A role | Who may assume the role |
| **Permissions boundary / SCP** | A user or role / a whole account | A *ceiling*: maximum permissions, even if other policies allow more |

AWS docs: [Policies and permissions](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html) · [Policy evaluation logic](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic.html)

## Create an IAM user and group

> **In simple words:** Create a person's login, put them in a group, and give the **group** the permissions. Then everyone in the group gets the same access, and you manage it in one place.

> **Note:** For people in a company, **IAM Identity Center** (SSO, covered later in this guide) is the recommended way to sign in. Plain IAM users are still useful for learning, for small sandboxes, and for the rare system that can only use access keys.

### Console

1. **IAM → User groups → Create group**, named `developers`. Attach **ReadOnlyAccess** and create it.
2. **IAM → Users → Create user**, named `alice`.
   - Tick **Provide user access to the AWS Management Console**, choose **I want to create an IAM user**, set a custom password, and tick **Users must create a new password at next sign-in**.
3. **Set permissions → Add user to group →** `developers`, then **Create user**.
4. Copy the **console sign-in URL** (`https://<account-id>.signin.aws.amazon.com/console`) and the password, and send them safely.
5. Open the user → **Security credentials → Assign MFA device**. Every human should have MFA.

### CLI

```bash
aws iam create-group --group-name developers
aws iam attach-group-policy --group-name developers \
  --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess
# lets new users change their own password at first sign-in
aws iam attach-group-policy --group-name developers \
  --policy-arn arn:aws:iam::aws:policy/IAMUserChangePassword

aws iam create-user --user-name alice --tags Key=team,Value=platform
aws iam create-login-profile --user-name alice \
  --password 'Change-Me-Now-2026!' --password-reset-required
aws iam add-user-to-group --user-name alice --group-name developers

# Check
aws iam list-groups-for-user --user-name alice --query 'Groups[].GroupName'
aws iam list-attached-group-policies --group-name developers --output table
```

### Access keys (only when really needed)

```bash
aws iam create-access-key --user-name alice     # shows the secret ONCE
aws iam list-access-keys --user-name alice
aws iam update-access-key --user-name alice --access-key-id AKIA... --status Inactive
aws iam delete-access-key --user-name alice --access-key-id AKIA...
```

> **Warning:** Access keys are long-lived passwords for the API. Never put them in code, Git, Docker images or chat. Prefer roles (for apps), SSO (for people) and OIDC (for CI), which use temporary credentials instead.

AWS docs: [Create an IAM user](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html)

## Write your own policy and attach it

> **In simple words:** AWS's ready-made policies are often too broad. Write a small policy that allows exactly what's needed, then attach it to a group, user or role.

Example: let developers read **only** one bucket. Save as `s3-read-reports.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListTheBucket",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::reports-bucket"
    },
    {
      "Sid": "ReadObjects",
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::reports-bucket/*"
    }
  ]
}
```

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws iam create-policy --policy-name S3ReadReports \
  --policy-document file://s3-read-reports.json \
  --description "Read-only access to the reports bucket"

# Attach to a group, a user or a role
aws iam attach-group-policy --group-name developers \
  --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/S3ReadReports
# aws iam attach-user-policy --user-name alice --policy-arn ...
# aws iam attach-role-policy --role-name my-role --policy-arn ...

# Detach later
aws iam detach-group-policy --group-name developers \
  --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/S3ReadReports
```

Change a policy by creating a **new version**. IAM keeps up to 5 versions, so you can roll back:

```bash
aws iam create-policy-version --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/S3ReadReports \
  --policy-document file://s3-read-reports.json --set-as-default
aws iam list-policy-versions --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/S3ReadReports
```

> **Tip:** Before attaching, paste the JSON into **IAM → Policies → Create policy → JSON**. The editor validates it, and **IAM Access Analyzer** flags mistakes and overly broad permissions.

## Create a role and attach a policy

> **In simple words:** A role needs **two** policies: a **trust policy** (who may wear this badge) and a **permissions policy** (what the badge opens). Here we create a role an EC2 server can use to read S3, with no keys on the server.

### 1. Trust policy: "EC2 may assume this role"

`ec2-trust.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "ec2.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

### 2. Create the role and attach permissions

```bash
aws iam create-role --role-name app-ec2-role \
  --assume-role-policy-document file://ec2-trust.json \
  --description "App servers: read the reports bucket"

aws iam attach-role-policy --role-name app-ec2-role \
  --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/S3ReadReports
aws iam attach-role-policy --role-name app-ec2-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore   # Session Manager access
```

### 3. EC2 needs an "instance profile" wrapper

```bash
aws iam create-instance-profile --instance-profile-name app-ec2-role
aws iam add-role-to-instance-profile --instance-profile-name app-ec2-role --role-name app-ec2-role

# attach to a running instance (or pick it in the launch wizard under Advanced details)
aws ec2 associate-iam-instance-profile --instance-id i-0123456789abcdef0 \
  --iam-instance-profile Name=app-ec2-role
```

On the instance, the AWS CLI and SDKs pick up the role's credentials automatically:

```bash
aws sts get-caller-identity    # "Arn": "arn:aws:sts::…:assumed-role/app-ec2-role/i-0123…"
aws s3 ls s3://reports-bucket/
```

The console's **IAM → Roles → Create role → AWS service → EC2** does steps 1–3 in one go, including the instance profile.

### Common trust principals

| Who assumes the role | `Principal` in the trust policy |
|---|---|
| EC2 instances | `{"Service": "ec2.amazonaws.com"}` |
| Lambda functions | `{"Service": "lambda.amazonaws.com"}` |
| ECS tasks | `{"Service": "ecs-tasks.amazonaws.com"}` |
| EKS pods (Pod Identity) | `{"Service": "pods.eks.amazonaws.com"}` |
| EKS pods (IRSA) / GitHub Actions | `{"Federated": "arn:aws:iam::<acct>:oidc-provider/…"}` |
| People or roles in another account | `{"AWS": "arn:aws:iam::<other-acct>:root"}` |

AWS docs: [IAM roles](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html) · [IAM roles for EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html)

## Let people assume a role

> **In simple words:** Instead of giving someone permanent admin rights, give them a role they **switch into** only when needed, ideally only with MFA. Every switch is logged.

Trust policy `admin-trust.json`, which lets identities in **this** account assume it, but only after MFA:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::111122223333:root" },
      "Action": "sts:AssumeRole",
      "Condition": { "Bool": { "aws:MultiFactorAuthPresent": "true" } }
    }
  ]
}
```

`:root` here means "this account": IAM still requires the caller to have `sts:AssumeRole` permission for this role. Create the role, attach permissions, and allow the `developers` group to switch into it:

```bash
aws iam create-role --role-name break-glass-admin --assume-role-policy-document file://admin-trust.json
aws iam attach-role-policy --role-name break-glass-admin \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

aws iam put-group-policy --group-name developers --policy-name may-assume-admin \
  --policy-document "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"sts:AssumeRole\",\"Resource\":\"arn:aws:iam::$ACCOUNT_ID:role/break-glass-admin\"}]}"
```

Use it from the CLI with a profile in `~/.aws/config`:

```ini
[profile admin]
role_arn = arn:aws:iam::111122223333:role/break-glass-admin
source_profile = default
mfa_serial = arn:aws:iam::111122223333:mfa/alice
```

```bash
aws sts get-caller-identity --profile admin       # asks for the MFA code
# or by hand:
aws sts assume-role --role-arn arn:aws:iam::$ACCOUNT_ID:role/break-glass-admin --role-session-name alice-fix
```

In the console: **account menu → Switch role**.

## IAM Identity Center (SSO) for people

> **In simple words:** In companies, people don't get IAM users at all. They log in once to a portal with their company account, pick an AWS account and a **permission set**, and get temporary credentials. Nothing to rotate, and access disappears when they leave.

1. **IAM Identity Center → Enable** (it uses AWS Organizations).
2. **Users → Add user** (or connect your company directory: Microsoft Entra ID, Okta, Google).
3. **Groups → Create group** `platform`, and add the user.
4. **Permission sets → Create**, for example **Predefined → AdministratorAccess** or **ReadOnlyAccess**.
5. **AWS accounts →** select an account **→ Assign users or groups →** `platform` + the permission set.
6. Users sign in at the **AWS access portal URL**, and on the CLI with:

```bash
aws configure sso          # once: portal URL, region, account, permission set
aws sso login --profile dev
aws s3 ls --profile dev
```

Behind the scenes, each permission set becomes an IAM role in the target account.

AWS docs: [What is IAM Identity Center?](https://docs.aws.amazon.com/singlesignon/latest/userguide/what-is.html)

## EKS: AWS permissions for pods (Pod Identity and IRSA)

> **In simple words:** A pod that reads S3 or a database secret needs AWS permissions. Instead of putting keys in the pod, you link a **Kubernetes service account** to an **IAM role**. Pods using that service account automatically get the role's temporary credentials, and other pods don't.

```text
 Pod (serviceAccountName: s3-reader)
   │  AWS SDK asks for credentials
   ▼
 EKS Pod Identity agent / IRSA token  ──▶  STS  ──▶ temporary creds for role "demo-s3-reader"
                                                     (only this service account can get them)
```

Do this after the Kubernetes guide, on an EKS cluster (see the AWS guide's **EKS** step). Set these first:

```bash
CLUSTER=devops-lab
REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws eks update-kubeconfig --name $CLUSTER --region $REGION
```

### Option A: EKS Pod Identity (recommended for new setups)

```bash
# 1. Install the Pod Identity agent add-on (once per cluster)
aws eks create-addon --cluster-name $CLUSTER --addon-name eks-pod-identity-agent
kubectl get pods -n kube-system -l app.kubernetes.io/name=eks-pod-identity-agent

# 2. Create a role that EKS Pod Identity may assume
cat > pod-identity-trust.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "pods.eks.amazonaws.com" },
      "Action": ["sts:AssumeRole", "sts:TagSession"]
    }
  ]
}
EOF
aws iam create-role --role-name demo-s3-reader --assume-role-policy-document file://pod-identity-trust.json
aws iam attach-role-policy --role-name demo-s3-reader \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

# 3. Create the Kubernetes service account and link it to the role
kubectl create serviceaccount s3-reader -n default
aws eks create-pod-identity-association --cluster-name $CLUSTER \
  --namespace default --service-account s3-reader \
  --role-arn arn:aws:iam::$ACCOUNT_ID:role/demo-s3-reader
aws eks list-pod-identity-associations --cluster-name $CLUSTER --output table
```

### Option B: IRSA (IAM Roles for Service Accounts)

The older method, still very common and needed for some tools. It uses the cluster's **OIDC provider**.

```bash
# 1. Register the cluster's OIDC issuer in IAM (once per cluster)
eksctl utils associate-iam-oidc-provider --cluster $CLUSTER --region $REGION --approve
OIDC=$(aws eks describe-cluster --name $CLUSTER --query "cluster.identity.oidc.issuer" --output text | sed 's|https://||')

# 2. Trust policy: only the service account default/s3-reader-irsa may assume the role
cat > irsa-trust.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC}" },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC}:sub": "system:serviceaccount:default:s3-reader-irsa",
          "${OIDC}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF
aws iam create-role --role-name demo-s3-reader-irsa --assume-role-policy-document file://irsa-trust.json
aws iam attach-role-policy --role-name demo-s3-reader-irsa \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

# 3. Service account annotated with the role ARN
kubectl create serviceaccount s3-reader-irsa -n default
kubectl annotate serviceaccount s3-reader-irsa -n default \
  eks.amazonaws.com/role-arn=arn:aws:iam::$ACCOUNT_ID:role/demo-s3-reader-irsa
```

`eksctl` can do all three IRSA steps in one command:

```bash
eksctl create iamserviceaccount --cluster $CLUSTER --namespace default --name s3-reader-irsa \
  --attach-policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess --approve
```

### Test it

```bash
kubectl run aws-test --rm -it --restart=Never --image=amazon/aws-cli \
  --overrides='{"spec":{"serviceAccountName":"s3-reader"}}' -- sts get-caller-identity
# "Arn": "arn:aws:sts::…:assumed-role/demo-s3-reader/eks-devops-lab-aws-test-…"
```

Use the service account in a Deployment with `spec.template.spec.serviceAccountName: s3-reader`.

| | EKS Pod Identity | IRSA |
|---|---|---|
| Setup | Add-on plus one association per service account | OIDC provider plus a trust policy per role |
| Trust policy | The same simple one for every cluster | Mentions each cluster's OIDC URL and service account |
| Reusing a role across clusters | Easy | One trust statement per cluster |
| Where it works | EKS on EC2 nodes | EKS, and any cluster with a public OIDC issuer |

AWS docs: [EKS Pod Identity](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html) · [IAM roles for service accounts](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)

## EKS: who can use the cluster (access entries)

> **In simple words:** Pod permissions are about pods calling AWS. **Access entries** are the other direction: which AWS **users and roles** can run `kubectl` against the cluster, and with what rights.

```bash
# Give a role (e.g. your SSO developer role) view-only access to one namespace
aws eks create-access-entry --cluster-name $CLUSTER \
  --principal-arn arn:aws:iam::$ACCOUNT_ID:role/developer --type STANDARD

aws eks associate-access-policy --cluster-name $CLUSTER \
  --principal-arn arn:aws:iam::$ACCOUNT_ID:role/developer \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy \
  --access-scope type=namespace,namespaces=team-a

aws eks list-access-entries --cluster-name $CLUSTER
```

| Access policy | Roughly equals |
|---|---|
| `AmazonEKSClusterAdminPolicy` | Full admin on everything (`cluster-admin`) |
| `AmazonEKSAdminPolicy` | Admin inside the scoped namespaces |
| `AmazonEKSEditPolicy` | Create and change most resources |
| `AmazonEKSViewPolicy` | Read-only |

AWS docs: [EKS access entries](https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html)

## Guardrails and best practices

> **In simple words:** Good IAM is mostly habits: few long-lived keys, small permissions, MFA, and regular clean-up of what isn't used.

- **Lock away the root user.** Add MFA, and never use it day to day.
- **People use SSO; workloads use roles.** Avoid IAM users with access keys.
- **Least privilege:** start small and add permissions when something is denied.
- **Grant to groups and roles,** not to individual users.
- **Use conditions:** MFA, source IP, tags, `aws:SecureTransport`.
- **Permissions boundaries** cap what a role can ever do, which is useful when developers may create roles. **SCPs** cap whole accounts in AWS Organizations.
- **Clean up regularly.** These tools help:

```bash
aws iam generate-credential-report && aws iam get-credential-report \
  --query Content --output text | base64 -d | cut -d, -f1,4,5,9,11 | column -s, -t   # passwords, keys, last used
aws iam get-account-authorization-details --filter User --query 'UserDetailList[].UserName'
```

- **IAM Access Analyzer:** finds resources shared outside your account, unused roles and permissions, and validates policies.
- **Policy simulator:** test "would this be allowed?" before changing anything (**IAM → Policy simulator**).

AWS docs: [Security best practices in IAM](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html) · [Permissions boundaries](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_boundaries.html) · [IAM Access Analyzer](https://docs.aws.amazon.com/IAM/latest/UserGuide/what-is-access-analyzer.html) · [Policy simulator](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_testing-policies.html)

## Troubleshooting AccessDenied

> **In simple words:** An "AccessDenied" error tells you **who** was denied, **what** they tried, and often **why**. Read it carefully, then check which identity you are really using.

A typical error:

```text
An error occurred (AccessDenied) when calling the GetObject operation:
User: arn:aws:sts::111122223333:assumed-role/app-ec2-role/i-0abc is not authorized to perform:
s3:GetObject on resource: "arn:aws:s3:::reports-bucket/2026.csv"
because no identity-based policy allows the s3:GetObject action
```

| Step | Command / place |
|---|---|
| Who am I really? | `aws sts get-caller-identity` |
| Which policies are attached? | `aws iam list-attached-role-policies --role-name …` and `list-role-policies` (inline) |
| Encoded EC2 error message | `aws sts decode-authorization-message --encoded-message …` |
| What happened, and when? | **CloudTrail → Event history**, filtered by user or role |
| Would it be allowed? | IAM **policy simulator** |

Common causes:

| Symptom | Cause |
|---|---|
| `ListBucket` works but `GetObject` fails (or the other way round) | Policy has `bucket` but not `bucket/*`, or the other way round |
| Allowed in IAM but still denied | An explicit **Deny**, a permissions boundary, an SCP, or a bucket or KMS **key policy** |
| EC2: `Unable to locate credentials` | No instance profile attached to the instance |
| Pod uses the **node** role, not its own | Pod Identity association missing, or the pod started before the association (**restart the pod**) |
| IRSA: `Not authorized to perform sts:AssumeRoleWithWebIdentity` | Trust policy `sub` doesn't match `system:serviceaccount:<ns>:<name>`, or the annotation has a typo |
| `is not authorized to perform: sts:AssumeRole` | The role's trust policy doesn't trust you, or you lack `sts:AssumeRole` permission |

## Clean up

> **In simple words:** Delete what you created. IAM is free, but unused users, keys and roles are a security risk.

```bash
# user
aws iam remove-user-from-group --user-name alice --group-name developers
aws iam delete-login-profile --user-name alice
for k in $(aws iam list-access-keys --user-name alice --query 'AccessKeyMetadata[].AccessKeyId' --output text); do
  aws iam delete-access-key --user-name alice --access-key-id $k; done
aws iam delete-user --user-name alice

# group
aws iam delete-group-policy --group-name developers --policy-name may-assume-admin 2>/dev/null
for p in $(aws iam list-attached-group-policies --group-name developers --query 'AttachedPolicies[].PolicyArn' --output text); do
  aws iam detach-group-policy --group-name developers --policy-arn $p; done
aws iam delete-group --group-name developers

# role (detach policies, remove from instance profile, then delete)
aws iam remove-role-from-instance-profile --instance-profile-name app-ec2-role --role-name app-ec2-role
aws iam delete-instance-profile --instance-profile-name app-ec2-role
for p in $(aws iam list-attached-role-policies --role-name app-ec2-role --query 'AttachedPolicies[].PolicyArn' --output text); do
  aws iam detach-role-policy --role-name app-ec2-role --policy-arn $p; done
aws iam delete-role --role-name app-ec2-role

# customer managed policy
aws iam delete-policy --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/S3ReadReports
```

Do the same for `break-glass-admin`, `demo-s3-reader` and `demo-s3-reader-irsa`, and run `aws eks delete-pod-identity-association …` for the association.

## Lab: least-privilege access, end to end

> **In simple words:** Practice time: build users, a custom policy, a role for a server, and a role for a pod, then prove each one can do exactly what it should and nothing more.

1. Create a bucket `reports-<your-name>` and upload a file (see the S3 guide).
2. Create the `S3ReadReports` policy for that bucket only, and attach it to a new group `analysts`.
3. Create user `bob` in `analysts`. Sign in as bob: reading the bucket works, but deleting a file or listing **other** buckets' contents is denied.
4. Create the role `app-ec2-role` and attach it to an EC2 instance. On the instance, `aws s3 ls s3://reports-<name>/` works with **no keys configured**.
5. On EKS, give a pod read access to the bucket with **Pod Identity**, and prove a pod **without** that service account can't read it.
6. Create a deliberate mistake (remove `/*` from the policy), read the AccessDenied message, and fix it.
7. Clean up everything.

### Cheat sheet

| Task | Command |
|---|---|
| Who am I | `aws sts get-caller-identity` |
| Create user / group | `aws iam create-user --user-name x` / `create-group --group-name g` |
| Attach managed policy | `aws iam attach-group-policy --group-name g --policy-arn arn` |
| Create custom policy | `aws iam create-policy --policy-name p --policy-document file://p.json` |
| Create role | `aws iam create-role --role-name r --assume-role-policy-document file://trust.json` |
| Assume role | `aws sts assume-role --role-arn arn --role-session-name me` |
| Pod Identity link | `aws eks create-pod-identity-association --cluster-name c --namespace ns --service-account sa --role-arn arn` |
| IRSA in one go | `eksctl create iamserviceaccount --cluster c --name sa --attach-policy-arn arn --approve` |
