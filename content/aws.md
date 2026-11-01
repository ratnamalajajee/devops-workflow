# AWS (Amazon Web Services)

AWS is the most widely used cloud platform. This guide sets up an account **safely** first, then covers the services a DevOps engineer touches every day: IAM, the CLI, VPC networking, EC2, S3, ECR, and EKS. Everything is shown with the AWS CLI, so you understand what Terraform automates later.

> **Cost:** Several steps create billable resources (NAT gateways, EKS, load balancers). Those steps are marked. **Always run the cleanup step** when you finish, and set up a budget alert first.

## Core concepts

| Concept | Meaning |
|---|---|
| **Region** | A geographic area, for example `us-east-1` or `ap-south-1`. Most resources live in one region. |
| **Availability Zone (AZ)** | An isolated data center group inside a region (`us-east-1a`). Spread resources across AZs for high availability. |
| **Account** | Billing and security boundary. Companies use many accounts (dev, staging, prod) under AWS Organizations. |
| **ARN** | Amazon Resource Name, the unique ID of any resource: `arn:aws:s3:::my-bucket` |
| **Shared responsibility** | AWS secures the cloud itself. *You* secure what you put in it: IAM, data, network rules, patching. |

Services you will use most:

| Area | Services |
|---|---|
| Identity | IAM, IAM Identity Center (SSO) |
| Compute | EC2, Lambda, ECS, EKS |
| Network | VPC, Route 53, ELB (ALB/NLB), CloudFront |
| Storage | S3, EBS, EFS |
| Databases | RDS, DynamoDB |
| Ops | CloudWatch, CloudTrail, Systems Manager |

## Secure your account first

If you have a company account, your platform team gives you access. Skip to the CLI step. If you are using a **personal learning account**, do this immediately after signing up:

1. **Enable MFA on the root user:** account menu → **Security credentials** → **Assign MFA device**.
2. **Never use root day to day.** Lock the password and MFA device away.
3. **Create a budget alert:** **Billing → Budgets → Create budget → "Zero spend" or "Monthly cost" template** with your email. You'll hear about charges within hours, not at month end.
4. **Create an admin identity** for daily use (next step).
5. Turn on **CloudTrail** (enabled by default for 90 days of event history). It records who did what.

> **Warning:** Leaked access keys get found by bots within minutes and used to mine cryptocurrency on your bill. Never commit keys to Git.

## IAM: users, roles and policies

IAM answers **who** (principal) can do **what** (action) on **which resource**.

| Thing | What it is |
|---|---|
| **User** | A long-term identity for a person or app. Avoid for humans. Use SSO. |
| **Group** | A collection of users that share policies |
| **Role** | An identity that is *assumed* temporarily: by EC2, Lambda, Kubernetes pods, CI, or people via SSO |
| **Policy** | A JSON document granting or denying permissions |

A policy allowing read-only access to one bucket:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::my-app-bucket",
        "arn:aws:s3:::my-app-bucket/*"
      ]
    }
  ]
}
```

Principles:

- **Least privilege:** grant only what's needed, then widen if something fails.
- **Roles over keys:** EC2 instances, Lambda, EKS pods and CI pipelines should **assume roles**. Never hard-code keys.
- **Humans use SSO:** set up **IAM Identity Center**, create a user and a permission set (`AdministratorAccess` for a sandbox), and log in through the access portal.

## Install and configure the AWS CLI

You installed AWS CLI v2 during setup. Now connect it.

### Option A: SSO (recommended, used by most companies)

```bash
aws configure sso
# SSO session name: my-sso
# SSO start URL: https://<your-org>.awsapps.com/start
# SSO region: us-east-1
# then pick account + role, and name the profile e.g. "dev"

aws sso login --profile dev
export AWS_PROFILE=dev
```

### Option B: access keys (personal sandbox only)

Create an access key for an IAM user under **IAM → Users → Security credentials**, then:

```bash
aws configure --profile sandbox
# AWS Access Key ID, Secret, default region (us-east-1), output (json)
export AWS_PROFILE=sandbox
```

### Verify

```bash
aws sts get-caller-identity          # who am I?
aws configure list                   # active settings
aws ec2 describe-regions --query 'Regions[].RegionName' --output table
cat ~/.aws/config                    # profiles live here
```

> **Tip:** `--query` (JMESPath) and `--output table|text|json` make the CLI much nicer. For example: `aws ec2 describe-instances --query 'Reservations[].Instances[].[InstanceId,State.Name]' --output table`.

## VPC networking

A **VPC** is your private network in AWS. Understanding it is essential: EC2, RDS, EKS, and load balancers all live inside one.

```text
VPC 10.0.0.0/16  (region us-east-1)
├── AZ us-east-1a
│   ├── Public subnet  10.0.1.0/24   ← route 0.0.0.0/0 → Internet Gateway
│   └── Private subnet 10.0.11.0/24  ← route 0.0.0.0/0 → NAT Gateway
└── AZ us-east-1b
    ├── Public subnet  10.0.2.0/24
    └── Private subnet 10.0.12.0/24
```

| Component | Role |
|---|---|
| **Subnet** | A slice of the VPC CIDR in one AZ |
| **Internet Gateway (IGW)** | Lets public subnets reach, and be reached from, the internet |
| **NAT Gateway** | Lets private subnets reach out (for updates) without being reachable from outside |
| **Route table** | Decides where traffic from a subnet goes |
| **Security Group** | **Stateful** firewall on an instance or ENI. Allow rules only. |
| **Network ACL** | **Stateless** firewall on a subnet. Allow and deny rules. |

Rule of thumb: **load balancers in public subnets, apps and databases in private subnets.**

Explore the default VPC:

```bash
aws ec2 describe-vpcs --query 'Vpcs[].[VpcId,CidrBlock,IsDefault]' --output table
aws ec2 describe-subnets --query 'Subnets[].[SubnetId,AvailabilityZone,CidrBlock]' --output table
```

> **Cost:** NAT Gateways cost money per hour and per GB, even when idle. In the Terraform guide you'll build a full VPC and destroy it with one command.

## EC2: launch a server from the CLI

```bash
export AWS_REGION=us-east-1

# 1. Key pair for SSH
aws ec2 create-key-pair --key-name devops-lab --query 'KeyMaterial' --output text > ~/.ssh/devops-lab.pem
chmod 600 ~/.ssh/devops-lab.pem

# 2. Security group allowing SSH from your IP only, HTTP from anywhere
MYIP=$(curl -s https://checkip.amazonaws.com)
SG_ID=$(aws ec2 create-security-group --group-name devops-lab-sg --description "lab" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr $MYIP/32
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0

# 3. Latest Amazon Linux 2023 AMI via public SSM parameter
AMI_ID=$(aws ssm get-parameters --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 --query 'Parameters[0].Value' --output text)

# 4. Launch with a user-data script that installs nginx on boot
INSTANCE_ID=$(aws ec2 run-instances --image-id $AMI_ID --instance-type t3.micro \
  --key-name devops-lab --security-group-ids $SG_ID \
  --user-data '#!/bin/bash
dnf install -y nginx && systemctl enable --now nginx' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=devops-lab}]' \
  --query 'Instances[0].InstanceId' --output text)

aws ec2 wait instance-running --instance-ids $INSTANCE_ID
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo "http://$PUBLIC_IP"
```

Give it about a minute, then:

```bash
curl http://$PUBLIC_IP
ssh -i ~/.ssh/devops-lab.pem ec2-user@$PUBLIC_IP
```

> **Tip:** In real environments, prefer **SSM Session Manager** (`aws ssm start-session --target $INSTANCE_ID`) over SSH. No open port 22 and no keys to manage. It needs the `AmazonSSMManagedInstanceCore` role on the instance.

### Cleanup EC2

```bash
aws ec2 terminate-instances --instance-ids $INSTANCE_ID
aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID
aws ec2 delete-security-group --group-id $SG_ID
aws ec2 delete-key-pair --key-name devops-lab
```

## S3: object storage

```bash
BUCKET=devops-lab-$(date +%s)          # bucket names are globally unique
aws s3 mb s3://$BUCKET
echo "hello s3" > hello.txt
aws s3 cp hello.txt s3://$BUCKET/
aws s3 ls s3://$BUCKET/
aws s3 sync ./site s3://$BUCKET/site/   # sync a folder
aws s3 presign s3://$BUCKET/hello.txt --expires-in 300   # temporary share link

# Turn on versioning (protects against accidental deletes)
aws s3api put-bucket-versioning --bucket $BUCKET --versioning-configuration Status=Enabled

# Cleanup
aws s3 rb s3://$BUCKET --force
```

Good defaults that AWS now applies to new buckets: **Block Public Access on**, **encryption at rest on**. Keep them that way unless you really mean to host public content (and even then, prefer CloudFront in front).

## ECR: container registry

ECR stores your Docker images privately in your account. EKS and ECS pull from it.

```bash
aws ecr create-repository --repository-name hello-docker --image-scanning-configuration scanOnPush=true
aws ecr describe-repositories --query 'repositories[].repositoryUri' --output text
```

The login, tag and push commands are in the **Docker → Push to a registry** step. After pushing:

```bash
aws ecr list-images --repository-name hello-docker
aws ecr describe-image-scan-findings --repository-name hello-docker --image-id imageTag=1.0.0
```

Add a **lifecycle policy** so old images don't pile up:

```bash
aws ecr put-lifecycle-policy --repository-name hello-docker --lifecycle-policy-text '{
  "rules": [{"rulePriority": 1, "description": "keep last 20",
    "selection": {"tagStatus": "any", "countType": "imageCountMoreThan", "countNumber": 20},
    "action": {"type": "expire"}}]}'
```

## EKS: managed Kubernetes

> **Cost:** An EKS control plane costs roughly $0.10/hour, plus EC2 nodes and a NAT gateway. Learn Kubernetes basics locally with **kind** first (Kubernetes guide), then come back. Delete the cluster the same day.

`eksctl` creates a working cluster, including the VPC, node group and IAM, in one command:

```bash
eksctl create cluster \
  --name devops-lab \
  --region us-east-1 \
  --nodegroup-name workers \
  --node-type t3.medium \
  --nodes 2 \
  --managed
# takes ~15 minutes; it writes your kubeconfig automatically

kubectl get nodes
kubectl get pods -A
```

Connect to an existing cluster, for example one created by Terraform:

```bash
aws eks update-kubeconfig --name devops-lab --region us-east-1
kubectl config current-context
```

Things worth knowing about EKS:

- **Access entries** map IAM users and roles to Kubernetes permissions.
- **Pod Identity** (or IRSA) gives pods an IAM role, so pods never need access keys.
- The **AWS Load Balancer Controller** turns Kubernetes Ingress and Services into ALBs and NLBs.
- **Managed node groups** or **Karpenter** handle node scaling.

### Cleanup EKS

```bash
eksctl delete cluster --name devops-lab --region us-east-1
```

## CloudWatch and cost control

```bash
# Logs
aws logs describe-log-groups --query 'logGroups[].logGroupName'
aws logs tail /aws/eks/devops-lab/cluster --follow

# An alarm when an instance's CPU > 80% for 10 minutes
aws cloudwatch put-metric-alarm --alarm-name high-cpu \
  --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average \
  --period 300 --evaluation-periods 2 --threshold 80 --comparison-operator GreaterThanThreshold \
  --dimensions Name=InstanceId,Value=$INSTANCE_ID
```

### Find what's costing money

```bash
aws ce get-cost-and-usage --time-period Start=$(date -d '-7 days' +%F),End=$(date +%F) \
  --granularity DAILY --metrics UnblendedCost --group-by Type=DIMENSION,Key=SERVICE \
  --query 'ResultsByTime[].Groups[?Metrics.UnblendedCost.Amount>`0.01`].[Keys[0],Metrics.UnblendedCost.Amount]'
```

Common forgotten resources: **NAT gateways, load balancers, EKS clusters, unattached EBS volumes, Elastic IPs, RDS instances**. Check **Billing → Bills** weekly while learning.

> **Tip:** Tag everything (`Owner`, `Project`, `Environment`). Tags make cost reports and cleanup straightforward.

## Lab: a public web server done right

1. Using only the CLI, create a security group allowing HTTP from anywhere and SSH from **your IP only**.
2. Launch a `t3.micro` with user-data that installs nginx and writes your name to the index page.
3. Attach an IAM role with `AmazonSSMManagedInstanceCore` and connect with **Session Manager** instead of SSH.
4. Create an S3 bucket, upload a file **from the EC2 instance** (grant the role `s3:PutObject` on that bucket only).
5. Create an ECR repo and push your Docker image from the Docker lab.
6. Create a CloudWatch CPU alarm for the instance.
7. **Clean up everything** and confirm in Cost Explorer the next day that spend stopped.

### Cheat sheet

| Task | Command |
|---|---|
| Who am I | `aws sts get-caller-identity` |
| Switch profile | `export AWS_PROFILE=dev` |
| SSO login | `aws sso login --profile dev` |
| List instances | `aws ec2 describe-instances --output table` |
| Copy to S3 | `aws s3 cp file s3://bucket/` |
| ECR login | `aws ecr get-login-password \| docker login --username AWS --password-stdin <acct>.dkr.ecr.<region>.amazonaws.com` |
| kubeconfig for EKS | `aws eks update-kubeconfig --name <cluster>` |
