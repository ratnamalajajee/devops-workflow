# VPC Endpoints and AWS PrivateLink

Let servers in private subnets reach AWS services, and services owned by other teams, **without internet access, a NAT gateway or public IPs**. This guide builds free **gateway endpoints** for S3 and DynamoDB, **interface endpoints** for Systems Manager and STS (with private DNS and endpoint policies), and then shares **your own service** with another VPC through **AWS PrivateLink**: a Network Load Balancer, an endpoint service, an allow list and connection acceptance. Every step shows the **console clicks** and the matching **AWS CLI** commands.

> **Cost:** **Gateway endpoints are free.** Interface endpoints cost about **$0.01 per hour per Availability Zone** (about $7.30/month per AZ) plus **$0.01 per GB** processed (us-east-1). This lab runs 5 interface endpoints in 2 AZs (about $0.10/hour), a Network Load Balancer (about $0.0225/hour) and two `t3.micro` servers. Delete everything at the end. See [PrivateLink pricing](https://aws.amazon.com/privatelink/pricing/) and [VPC pricing](https://aws.amazon.com/vpc/pricing/).

## Start here: VPC endpoints in simple words

> **In simple words:** A private server normally reaches AWS services (S3, Systems Manager, STS) the long way: out through a **NAT gateway** to the services' public addresses. A **VPC endpoint** is a **private door** from your VPC straight to the service, so the server needs no internet at all. **PrivateLink** is the technology behind most of these doors, and you can use it to open a door to **your own** service for another team or account.

### Why endpoints?

```text
 BEFORE: private server ─▶ NAT gateway ─▶ internet gateway
                                              │ public IPs
                                              ▼
                                       AWS service (SSM, S3)

 AFTER:  private server ─▶ VPC endpoint (private IP in your VPC)
                                              │ AWS network only
                                              ▼
                                       AWS service (SSM, S3)
```

- **Security:** the server needs no route to the internet, so it can't leak data to (or download malware from) random websites. Policies on the endpoint limit what can pass through it.
- **Cost:** NAT gateways charge about $0.045 per GB processed. S3 and DynamoDB traffic through a gateway endpoint costs **nothing**, and interface endpoints charge $0.01 per GB.
- **Sharing:** with PrivateLink, another team can call **one** of your services by a private IP in **their own** VPC, without connecting the two networks.

### The office building comparison

| Office building | AWS |
|---|---|
| Driving across town to the bank's main branch | Calling an AWS service through a NAT gateway and public IPs |
| A private tunnel from your basement to the bank vault (only two banks build these) | **Gateway endpoint**: S3 and DynamoDB only |
| A bank counter opened inside your own building | **Interface endpoint**: a network card with a private IP in your subnet |
| The building directory lists the in-house counter under the bank's usual name | **Private DNS** |
| A guard at the counter checking who may use it | **Security group** (port 443) and **endpoint policy** |
| A partner opens a service window in your lobby; you can use it, but you can't walk into their building | **PrivateLink endpoint service**: one service, one direction |
| The partner keeps a guest list and approves each new window | **Allowed principals** and **acceptance** |

### Two kinds of endpoint

```compare
🚪 Gateway endpoint | 🔌 Interface endpoint (PrivateLink)
Only S3 and DynamoDB | Most AWS services, plus your own and partner services
A route in your route table (prefix list → vpce-…) | A network card (ENI) with a private IP in each subnet you choose
Free | About $0.01 per hour per AZ, plus $0.01 per GB (us-east-1)
Usable only from inside the same VPC | Also reachable over peering, Transit Gateway, VPN and Direct Connect
No security group | A security group on the network card (allow 443)
Same Region only | Can reach supported services in another Region
```

### Key words

| Word | Simple meaning |
|---|---|
| **VPC endpoint** | A private door from your VPC to a service. No internet gateway or NAT needed |
| **Gateway endpoint** | A route-table entry that sends S3 or DynamoDB traffic to the endpoint. Free |
| **Interface endpoint** | An **ENI** (elastic network interface: a virtual network card) with a private IP in your subnet, which forwards traffic to the service |
| **AWS PrivateLink** | The AWS technology behind interface endpoints and endpoint services |
| **Private DNS** | Makes the normal service name, such as `ssm.us-east-1.amazonaws.com`, resolve to the endpoint's private IPs inside your VPC |
| **Endpoint policy** | A JSON policy on the endpoint: which principals, actions and resources may pass through it |
| **Prefix list** | A named list of IP ranges, such as all S3 addresses in a Region, usable in routes and security groups |
| **Endpoint service** | Your own service offered through PrivateLink. It needs a **Network Load Balancer (NLB)** in front |
| **Provider / consumer** | The owner of the endpoint service / the VPC that connects to it |
| **Allowed principals** | The accounts, users or roles that may connect to your endpoint service |
| **AZ ID** | A stable Availability Zone ID such as `use1-az1`. Zone **names** like `us-east-1a` can point to different data centers in different accounts |

### Check yourself

1. Which two services have free gateway endpoints?
2. You created an STS interface endpoint, but `sts.us-east-1.amazonaws.com` still resolves to a public IP inside the VPC. What do you check?
3. Two VPCs both use `10.10.0.0/16`. Can they use PrivateLink? VPC peering?

> **Tip:** Answers: 1) Amazon S3 and Amazon DynamoDB. 2) That **private DNS** is enabled on the endpoint, and that the VPC has both **DNS resolution** and **DNS hostnames** turned on. 3) PrivateLink: **yes**, overlapping addresses don't matter because there is no routing between the VPCs. Peering: **no**, peered VPCs must not overlap.

## What we'll build

> **In simple words:** A VPC with **no internet at all**, made useful by endpoints, plus a second "provider" VPC that shares a small API with it through PrivateLink. Both VPCs use the **same** address range on purpose, to prove PrivateLink doesn't care.

```flow
🏗️ | Private-only VPC | Two private subnets in two AZs. No internet gateway, no NAT gateway.
🚪 | Gateway endpoints | Free routes to S3 and DynamoDB, with a policy that allows only one bucket.
🔌 | Interface endpoints | ssm, ssmmessages, ec2messages and sts, with private DNS and a security group.
🧪 | Test | Session Manager into a server that has no internet, and check DNS answers with private IPs.
📦 | Share a service | A small API behind an internal NLB, published as an endpoint service.
🤝 | Connect and accept | The consumer creates an endpoint, the provider accepts it, and curl reaches the API privately.
```

```text
 pl-lab-vpc 10.10.0.0/16 (consumer)
 ┌──────────────────────────────────────┐
 │ test server (no internet)            │
 │  ├─▶ ssm, ssmmessages, ec2messages,  │──▶ AWS services
 │  │   sts interface endpoints         │
 │  ├─▶ S3 / DynamoDB gateway endpoints │──▶ S3, DynamoDB
 │  └─▶ my-api interface endpoint       │──┐
 └──────────────────────────────────────┘  │ PrivateLink
 provider-vpc 10.10.0.0/16 (same range!)   │
 ┌──────────────────────────────────────┐  │
 │ internal NLB :8080 ◀─────────────────┼──┘
 │  └─▶ my-api server                   │
 └──────────────────────────────────────┘
```

You need the **Session Manager role** `ec2-ssm-lab-role` (with the `AmazonSSMManagedInstanceCore` policy) from the [EC2 lab](#/tool/ec2-website), and the Session Manager plugin for the AWS CLI if you connect from your laptop.

## Step 1: Create a VPC with no internet access

> **In simple words:** Build a small network with two private subnets and **no way out**: no internet gateway, no NAT. Anything the servers reach from now on must go through an endpoint. Turn on **both DNS settings**, because private DNS for endpoints needs them.

**Console:** VPC console → **Your VPCs** → **Create VPC** → **VPC only** → Name `pl-lab-vpc`, IPv4 CIDR `10.10.0.0/16` → **Create VPC**. **Actions → Edit VPC settings** → tick **Enable DNS resolution** and **Enable DNS hostnames** → **Save**. Then **Subnets → Create subnet**: `pl-lab-private-a` (`10.10.11.0/24`, us-east-1a) and `pl-lab-private-b` (`10.10.12.0/24`, us-east-1b). Finally **Route tables → Create route table** `pl-lab-private-rt` and associate both subnets.

**CLI:**

```bash
export AWS_REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AZ1=${AWS_REGION}a
AZ2=${AWS_REGION}b

VPC_ID=$(aws ec2 create-vpc --cidr-block 10.10.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=pl-lab-vpc}]' \
  --query Vpc.VpcId --output text)

# private DNS for interface endpoints needs BOTH attributes
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support '{"Value":true}'
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames '{"Value":true}'

PRIV1=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.10.11.0/24 --availability-zone $AZ1 \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=pl-lab-private-a}]' \
  --query Subnet.SubnetId --output text)
PRIV2=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.10.12.0/24 --availability-zone $AZ2 \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=pl-lab-private-b}]' \
  --query Subnet.SubnetId --output text)

PRIV_RT=$(aws ec2 create-route-table --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=pl-lab-private-rt}]' \
  --query RouteTable.RouteTableId --output text)
aws ec2 associate-route-table --route-table-id $PRIV_RT --subnet-id $PRIV1
aws ec2 associate-route-table --route-table-id $PRIV_RT --subnet-id $PRIV2
echo "VPC $VPC_ID  subnets $PRIV1 $PRIV2  route table $PRIV_RT"
```

The route table has only the `local` route. Without endpoints, a server here can talk to other servers in the VPC and nothing else. To compare with a normal VPC with a NAT gateway, see the [VPC guide](#/tool/aws-vpc).

## Step 2: Gateway endpoints for S3 and DynamoDB

> **In simple words:** A gateway endpoint adds one route to your route table: "traffic for S3 (or DynamoDB) in this Region goes to the endpoint". It's **free**, so add one to every VPC, even VPCs that have a NAT gateway. The [VPC guide](#/tool/aws-vpc/step-6-create-the-private-route-table) already showed the S3 one; here we add both and lock S3 down to one bucket.

**Console:** **Endpoints** → **Create endpoint** → Name `pl-lab-s3` → **Type: AWS services** → filter **Type = Gateway** → select `com.amazonaws.us-east-1.s3` → VPC `pl-lab-vpc` → **Route tables:** tick `pl-lab-private-rt` → **Policy: Full access** → **Create endpoint**. Repeat for `com.amazonaws.us-east-1.dynamodb`.

**CLI:**

```bash
S3_EP=$(aws ec2 create-vpc-endpoint --vpc-id $VPC_ID --vpc-endpoint-type Gateway \
  --service-name com.amazonaws.$AWS_REGION.s3 --route-table-ids $PRIV_RT \
  --tag-specifications 'ResourceType=vpc-endpoint,Tags=[{Key=Name,Value=pl-lab-s3}]' \
  --query VpcEndpoint.VpcEndpointId --output text)

DDB_EP=$(aws ec2 create-vpc-endpoint --vpc-id $VPC_ID --vpc-endpoint-type Gateway \
  --service-name com.amazonaws.$AWS_REGION.dynamodb --route-table-ids $PRIV_RT \
  --tag-specifications 'ResourceType=vpc-endpoint,Tags=[{Key=Name,Value=pl-lab-dynamodb}]' \
  --query VpcEndpoint.VpcEndpointId --output text)

# the endpoints added routes: destination = a prefix list (pl-...), target = the endpoint (vpce-...)
aws ec2 describe-route-tables --route-table-ids $PRIV_RT \
  --query 'RouteTables[0].Routes[].[DestinationCidrBlock,DestinationPrefixListId,GatewayId]' --output table

```

| Route | Target | Meaning |
|---|---|---|
| `10.10.0.0/16` | `local` | Traffic inside the VPC stays inside |
| `pl-…` (S3) | `vpce-…` | S3 in us-east-1 goes to the S3 gateway endpoint |
| `pl-…` (DynamoDB) | `vpce-…` | DynamoDB in us-east-1 goes to the DynamoDB gateway endpoint |

You can't edit these routes by hand: AWS adds them when you associate a route table with the endpoint and removes them when you disassociate it. Gateway endpoints work only for the **same Region**, and only from inside **this VPC**: traffic arriving over a VPN, peering or a Transit Gateway can't use them (use an S3 **interface** endpoint for that).

### Endpoint policy: allow only one bucket

By default an endpoint has a **Full access** policy. A custom policy lets servers in this VPC use **only your bucket**, even if their IAM role would allow more. That blocks a classic data-theft path: copying data to the attacker's own bucket.

**Console:** select `pl-lab-s3` → **Policy** tab → **Edit policy** → **Custom** → paste the JSON from the block below (with your bucket name, for example `my-app-pl-lab-111111111111`) → **Save**.

**CLI:** create the bucket from your laptop, then apply the policy:

```bash
BUCKET=my-app-pl-lab-$ACCOUNT_ID
aws s3 mb s3://$BUCKET
echo "hello from s3" > hello.txt
aws s3 cp hello.txt s3://$BUCKET/hello.txt

cat > s3-endpoint-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowOnlyMyAppBucket",
      "Effect": "Allow",
      "Principal": "*",
      "Action": ["s3:ListBucket", "s3:GetObject", "s3:PutObject"],
      "Resource": ["arn:aws:s3:::$BUCKET", "arn:aws:s3:::$BUCKET/*"]
    }
  ]
}
EOF
aws ec2 modify-vpc-endpoint --vpc-endpoint-id $S3_EP --policy-document file://s3-endpoint-policy.json
```

> **Warning:** Some AWS features read from **AWS-owned** S3 buckets through your endpoint, for example **ECR image layers** and Systems Manager **patching**. A strict one-bucket policy breaks them until you also allow those buckets. Check the docs of each service you use before locking the policy down.

The other side of the lock is the **bucket policy**: a `Deny` with the condition `aws:SourceVpce` makes the bucket usable **only** through your endpoint. Test that carefully, because it also blocks you in the console and on your laptop.

AWS docs: [Gateway endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/gateway-endpoints.html) · [Gateway endpoints for S3](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-s3.html) · [Gateway endpoints for DynamoDB](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-ddb.html)

## Step 3: Interface endpoints for AWS services

> **In simple words:** For every other service you create an **interface endpoint**. AWS puts a small network card with a **private IP** in each subnet you choose, and **private DNS** makes the normal service name point at those IPs. Your code and the AWS CLI don't change at all: they just get a private answer when they look up the name.

### How it works

| Piece | What it does |
|---|---|
| **One ENI per subnet** | You choose at most one subnet per AZ. Pick one in each AZ your servers use, so an AZ problem doesn't cut access |
| **Private DNS** | AWS adds a hidden private hosted zone, so `sts.us-east-1.amazonaws.com` resolves to the ENIs **inside this VPC only**. It needs **DNS resolution** and **DNS hostnames** on the VPC |
| **Security group** | Attached to the ENIs. Must allow **TCP 443** (HTTPS) **from your servers** (here: the whole VPC CIDR). If you don't choose one, the VPC's default security group is used |
| **Endpoint policy** | Optional, like the S3 one. Not every service supports it |
| **Bandwidth** | Up to 10 Gbps per AZ by default, scaling automatically up to 100 Gbps |
| **Quota** | 50 interface endpoints per VPC by default (adjustable) |

### Which endpoints does a fully private subnet need?

The full service name is `com.amazonaws.us-east-1.` followed by the short name in the table.

| You want to… | Endpoints | Type |
|---|---|---|
| Connect with **Session Manager**, use Run Command | `ssm`, `ssmmessages`, `ec2messages` | Interface |
| Read **Parameter Store** values | `ssm` (the same endpoint) | Interface |
| Pull images from **ECR** (Docker, ECS, EKS) | `ecr.api`, `ecr.dkr` **and** the `s3` gateway, because image layers are stored in S3 | Interface + Gateway |
| Send logs to **CloudWatch Logs** (the `awslogs` driver, the CloudWatch agent) | `logs` | Interface |
| Send custom metrics to **CloudWatch** | `monitoring` | Interface |
| Get temporary credentials, assume roles, `aws sts get-caller-identity` | `sts` | Interface |
| Read **Secrets Manager** secrets | `secretsmanager` | Interface |
| Encrypt or decrypt with **KMS** keys | `kms` | Interface |
| Use **S3** objects and **DynamoDB** tables | `s3`, `dynamodb` | Gateway (free) |

Related guides: [Secrets Manager](#/tool/aws-secrets), [Systems Manager](#/tool/aws-ssm), [CloudWatch](#/tool/aws-cloudwatch), [ECR](#/tool/aws-ecr), [ECS](#/tool/aws-ecs).

### Are endpoints cheaper than a NAT gateway?

Not always. Gateway endpoints always save money. Interface endpoints save money when a lot of data flows, but each one costs about $14.60/month in two AZs even when idle:

| Traffic per month | Through a NAT gateway (processing) | Through endpoints |
|---|---|---|
| 1 TB to S3 | 1,024 GB × $0.045 ≈ **$46** | **$0** with the gateway endpoint |
| 1 TB to CloudWatch Logs | ≈ **$46** | 1,024 GB × $0.01 + $14.60 ≈ **$25** |
| A few GB each to 10 services | a few cents (plus the NAT's hourly fee) | 10 × $14.60 ≈ **$146** |

When the goal is **no internet at all** (common for regulated workloads), you need the endpoints whatever the cost. Large companies often place shared interface endpoints in one central VPC and reach them over a Transit Gateway, so they don't pay for the same endpoints in every VPC.

### Create the security group and the endpoints

**Console:** **Security groups** → **Create security group** → Name `pl-lab-endpoints-sg`, VPC `pl-lab-vpc`, inbound rule **HTTPS (443)** from `10.10.0.0/16` → **Create**. Then **Endpoints** → **Create endpoint** → Name `pl-lab-ssm` → **Type: AWS services** → search `ssm` and select `com.amazonaws.us-east-1.ssm` → VPC `pl-lab-vpc` → **Additional settings:** keep **Enable DNS name** ticked → **Subnets:** tick both AZs and choose the private subnets → **Security groups:** `pl-lab-endpoints-sg` → **Policy: Full access** → **Create endpoint**. Repeat for `ssmmessages`, `ec2messages` and `sts`.

**CLI:**

```bash
EP_SG=$(aws ec2 create-security-group --vpc-id $VPC_ID --group-name pl-lab-endpoints-sg \
  --description "HTTPS from the VPC to interface endpoints" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id $EP_SG --protocol tcp --port 443 --cidr 10.10.0.0/16

# is the service offered in our AZs, and does it support endpoint policies?
aws ec2 describe-vpc-endpoint-services --service-names com.amazonaws.$AWS_REGION.ssm \
  --query 'ServiceDetails[0].[ServiceName,AvailabilityZones,VpcEndpointPolicySupported]' --output json

for SVC in ssm ssmmessages ec2messages sts; do
  aws ec2 create-vpc-endpoint --vpc-id $VPC_ID --vpc-endpoint-type Interface \
    --service-name com.amazonaws.$AWS_REGION.$SVC \
    --subnet-ids $PRIV1 $PRIV2 --security-group-ids $EP_SG --private-dns-enabled \
    --tag-specifications "ResourceType=vpc-endpoint,Tags=[{Key=Name,Value=pl-lab-$SVC}]" \
    --query VpcEndpoint.VpcEndpointId --output text
done

# wait until every endpoint in the VPC is "available" (usually 1-3 minutes)
until [ -z "$(aws ec2 describe-vpc-endpoints --filters Name=vpc-id,Values=$VPC_ID \
  --query 'VpcEndpoints[?State!=`available`].VpcEndpointId' --output text)" ]; do sleep 15; done

aws ec2 describe-vpc-endpoints --filters Name=vpc-id,Values=$VPC_ID \
  --query 'VpcEndpoints[].[ServiceName,VpcEndpointType,State,PrivateDnsEnabled]' --output table

# the network cards AWS created: one per endpoint per subnet (4 endpoints x 2 subnets = 8)
aws ec2 describe-network-interfaces --filters Name=vpc-id,Values=$VPC_ID Name=interface-type,Values=vpc_endpoint \
  --query 'NetworkInterfaces[].[PrivateIpAddress,AvailabilityZone,Description]' --output table
```

AWS docs: [Access an AWS service using an interface endpoint](https://docs.aws.amazon.com/vpc/latest/privatelink/create-interface-endpoint.html) · [AWS services that integrate with PrivateLink](https://docs.aws.amazon.com/vpc/latest/privatelink/aws-services-privatelink-support.html) · [VPC endpoints for Systems Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-create-vpc.html) · [ECR interface endpoints](https://docs.aws.amazon.com/AmazonECR/latest/userguide/vpc-endpoints.html) · [Quotas](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-limits-endpoints.html)

## Step 4: Test from a server with no internet

> **In simple words:** Launch a server in the private subnet and connect with **Session Manager**. If you can get a shell at all, the three SSM endpoints work. Then check that service names resolve to **private** IPs, that STS answers, and that the internet is really unreachable.

**Console:** **EC2** → **Launch instance** → Amazon Linux 2023, `t3.micro`, no key pair → **Network settings → Edit**: VPC `pl-lab-vpc`, subnet `pl-lab-private-a`, **Auto-assign public IP: Disable**, a new security group with **no inbound rules** → **Advanced details → IAM instance profile:** `ec2-ssm-lab-role` → **Launch**. A few minutes later: select it → **Connect** → **Session Manager** → **Connect**.

**CLI** (from your laptop):

```bash
AMI_ID=$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query Parameter.Value --output text)

TEST_SG=$(aws ec2 create-security-group --vpc-id $VPC_ID --group-name pl-lab-test-sg \
  --description "test server, no inbound rules" --query GroupId --output text)

TEST_VM=$(aws ec2 run-instances --image-id $AMI_ID --instance-type t3.micro --subnet-id $PRIV1 \
  --security-group-ids $TEST_SG --iam-instance-profile Name=ec2-ssm-lab-role \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=pl-lab-test}]' \
  --query 'Instances[0].InstanceId' --output text)
aws ec2 wait instance-status-ok --instance-ids $TEST_VM

# "Online" means the SSM Agent registered through your endpoints
aws ssm describe-instance-information --filters Key=InstanceIds,Values=$TEST_VM \
  --query 'InstanceInformationList[].[InstanceId,PingStatus,IPAddress]' --output table

aws ssm start-session --target $TEST_VM
```

**Inside the session** on the test server:

```bash
export AWS_REGION=us-east-1

getent hosts ssm.us-east-1.amazonaws.com           # 10.10.11.x / 10.10.12.x = the endpoint ENIs
getent hosts sts.us-east-1.amazonaws.com
nslookup sts.us-east-1.amazonaws.com               # if installed (package bind-utils)
dig +short ssmmessages.us-east-1.amazonaws.com     # same, shorter output

aws sts get-caller-identity --cli-connect-timeout 5   # works: answered by the sts endpoint

# interface endpoints don't answer ping: test the TCP port instead
timeout 3 bash -c '</dev/tcp/sts.us-east-1.amazonaws.com/443' && echo "port 443 open"

curl -s --max-time 5 https://checkip.amazonaws.com || echo "no internet, as expected"

BUCKET=my-app-pl-lab-111111111111                  # use your account ID
aws s3 ls s3://$BUCKET --cli-connect-timeout 5      # see the table below
```

Now run `nslookup sts.us-east-1.amazonaws.com` **on your laptop**: it returns **public** IPs. Same name, different answer: that's private DNS at work.

| Test | Expected result | If not |
|---|---|---|
| Session Manager connects | A shell prompt | One of `ssm`, `ssmmessages`, `ec2messages` is missing, or the role lacks `AmazonSSMManagedInstanceCore` |
| `getent hosts ssm.us-east-1.amazonaws.com` | Private IPs from `10.10.11.0/24` and `10.10.12.0/24` | Private DNS off, or a VPC DNS setting is off |
| `aws sts get-caller-identity` | Your account and the role ARN | No `sts` endpoint, or its security group blocks 443 |
| `curl https://checkip.amazonaws.com` | Times out | Good: there is no route to the internet |
| `aws s3 ls s3://$BUCKET` | A listing, or **AccessDenied** | An AccessDenied answer still proves the request reached S3 (the lab role has no S3 rights). A **hang** means no route: check the S3 gateway route |

## Step 5: Endpoint policies

> **In simple words:** An endpoint policy is a **guard at the door**. It never grants permissions by itself; it only narrows them. A request must be allowed by the caller's **IAM policy**, by the **endpoint policy**, and (where one exists) by the **resource policy**, such as a bucket policy.

| Gate | Where it lives | Typical use |
|---|---|---|
| **IAM policy** | On the user or role | What this identity may do anywhere |
| **Endpoint policy** | On the VPC endpoint | What may pass **through this door**: only our account, only our bucket |
| **Resource policy** | On the bucket, key, secret… | Who may touch this resource, for example "only via endpoint `vpce-…`" with `aws:SourceVpce` |

Example: only identities from **your own account** may use the STS endpoint. A second statement keeps web-identity and SAML logins working for roles in your account, because those callers aren't signed-in AWS principals yet (so `aws:PrincipalAccount` doesn't exist for them).

**Console:** select `pl-lab-sts` → **Policy** → **Edit policy** → **Custom** → paste the JSON from the block below with your account ID → **Save**.

**CLI:**

```bash
STS_EP=$(aws ec2 describe-vpc-endpoints --filters Name=vpc-id,Values=$VPC_ID \
  Name=service-name,Values=com.amazonaws.$AWS_REGION.sts --query 'VpcEndpoints[0].VpcEndpointId' --output text)

cat > sts-endpoint-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowMyAccountPrincipals",
      "Effect": "Allow",
      "Principal": { "AWS": "*" },
      "Action": "sts:*",
      "Resource": "*",
      "Condition": { "StringEquals": { "aws:PrincipalAccount": "$ACCOUNT_ID" } }
    },
    {
      "Sid": "AllowFederatedIntoMyAccount",
      "Effect": "Allow",
      "Principal": "*",
      "Action": ["sts:AssumeRoleWithSAML", "sts:AssumeRoleWithWebIdentity"],
      "Resource": "*",
      "Condition": { "StringEquals": { "aws:ResourceAccount": "$ACCOUNT_ID" } }
    }
  ]
}
EOF
aws ec2 modify-vpc-endpoint --vpc-endpoint-id $STS_EP --policy-document file://sts-endpoint-policy.json
aws ec2 describe-vpc-endpoints --vpc-endpoint-ids $STS_EP --query 'VpcEndpoints[0].PolicyDocument' --output text
```

Run `aws sts get-caller-identity` on the test server again: it still works, because the role belongs to your account. Credentials stolen from **another** account would now be refused at this door. Policy changes can take a few minutes to apply.

AWS docs: [Endpoint policies](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-access.html)

## Step 6: Share your own service (provider side)

> **In simple words:** Now **you** are the provider. Put a **Network Load Balancer** in front of your service (an API or a database), turn the NLB into an **endpoint service**, and say **who** may connect. Consumers get one private door to that one port, never a route into your network.

```text
 consumer VPC                          provider VPC
 ┌──────────────────┐                  ┌──────────────────────┐
 │ app ─▶ endpoint ─┼── PrivateLink ──▶│ NLB ─▶ my-api :8080  │
 │      (ENI, :8080)│   one way only   │ endpoint service     │
 └──────────────────┘                  └──────────────────────┘
```

| Provider setting | Meaning |
|---|---|
| **Network Load Balancer** | Required, normally **internal**. Enable it in every AZ consumers will use (at least two) |
| **Acceptance required** | Each new connection waits as `pendingAcceptance` until you approve it. Turn it off only if the allow list is enough |
| **Allowed principals** | Who may connect: a whole account (`arn:aws:iam::222222222222:root`), a role or user ARN. `*` means **any** AWS account: avoid it |
| **Private DNS name** | Optional friendly name such as `api.example.com`, after you prove you own the domain (Step 8) |
| **Supported Regions** | Optional extra Regions for cross-Region consumers (see the cross-Region section) |

**What your application sees:** the source IP of PrivateLink traffic is the **NLB's private IP**, not the consumer's (consumer addresses may overlap with yours). If you need the real client, turn on **proxy protocol v2** on the target group; its header carries the client IP and the endpoint ID.

### 6a. A provider VPC with the same CIDR, and a small API

Use the same `10.10.0.0/16` as the consumer VPC, on purpose. The API is Python's built-in web server, so the server needs no internet to install anything.

```bash
PROV_VPC=$(aws ec2 create-vpc --cidr-block 10.10.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=provider-vpc}]' --query Vpc.VpcId --output text)
PROV1=$(aws ec2 create-subnet --vpc-id $PROV_VPC --cidr-block 10.10.11.0/24 --availability-zone $AZ1 \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=provider-a}]' --query Subnet.SubnetId --output text)
PROV2=$(aws ec2 create-subnet --vpc-id $PROV_VPC --cidr-block 10.10.12.0/24 --availability-zone $AZ2 \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=provider-b}]' --query Subnet.SubnetId --output text)

# the NLB's own IPs are in this VPC, so allowing the VPC range on 8080 is enough
API_SG=$(aws ec2 create-security-group --vpc-id $PROV_VPC --group-name my-api-sg \
  --description "my-api: port 8080 from the NLB" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id $API_SG --protocol tcp --port 8080 --cidr 10.10.0.0/16

API_VM=$(aws ec2 run-instances --image-id $AMI_ID --instance-type t3.micro --subnet-id $PROV1 \
  --security-group-ids $API_SG \
  --user-data '#!/bin/bash
mkdir -p /srv/api
echo "hello from my-api in the provider VPC" > /srv/api/index.html
systemd-run --unit=my-api /usr/bin/python3 -m http.server 8080 --directory /srv/api' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=my-api}]' \
  --query 'Instances[0].InstanceId' --output text)
```

### 6b. The internal Network Load Balancer

**Console:** **EC2 → Target groups → Create target group**: Instances, name `my-api-tg`, **TCP 8080**, VPC `provider-vpc`, health check **TCP** → register `my-api` → **Create**. **Load balancers → Create load balancer → Network Load Balancer**: name `my-api-nlb`, scheme **Internal**, VPC `provider-vpc`, both subnets, listener **TCP 8080 → `my-api-tg`** → **Create**. The [load balancer guide](#/tool/aws-elb/network-load-balancer-example) explains NLBs in more detail.

```bash
NLB_ARN=$(aws elbv2 create-load-balancer --name my-api-nlb --type network --scheme internal \
  --subnets $PROV1 $PROV2 --query 'LoadBalancers[0].LoadBalancerArn' --output text)

TG_ARN=$(aws elbv2 create-target-group --name my-api-tg --protocol TCP --port 8080 \
  --vpc-id $PROV_VPC --target-type instance --health-check-protocol TCP \
  --query 'TargetGroups[0].TargetGroupArn' --output text)
aws elbv2 register-targets --target-group-arn $TG_ARN --targets Id=$API_VM

aws elbv2 create-listener --load-balancer-arn $NLB_ARN --protocol TCP --port 8080 \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN

# one server in AZ a, but the NLB lives in two AZs: let each AZ forward to any healthy target
aws elbv2 modify-load-balancer-attributes --load-balancer-arn $NLB_ARN \
  --attributes Key=load_balancing.cross_zone.enabled,Value=true

aws elbv2 wait load-balancer-available --load-balancer-arns $NLB_ARN
aws elbv2 wait target-in-service --target-group-arn $TG_ARN --targets Id=$API_VM
echo "NLB ready, target healthy"
```

In production, run a target in **every** enabled AZ instead of relying on cross-zone (which adds data charges). If your NLB has **security groups**, they must allow the traffic, or you set **Enforce inbound rules on PrivateLink traffic** to off ([NLB security groups](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/load-balancer-security-groups.html)).

### 6c. The endpoint service and its allow list

**Console:** VPC console → **Endpoint services** → **Create endpoint service** → Name `my-api-service` → **Load balancer type: Network** → select `my-api-nlb` → **Require acceptance for endpoint:** tick **Acceptance required** → **Supported IP address types: IPv4** → **Create**. Then the **Allow principals** tab → **Allow principals** → `arn:aws:iam::111111111111:root` (a partner would give you their account ID instead).

```bash
SVC_ID=$(aws ec2 create-vpc-endpoint-service-configuration \
  --network-load-balancer-arns $NLB_ARN --acceptance-required \
  --tag-specifications 'ResourceType=vpc-endpoint-service,Tags=[{Key=Name,Value=my-api-service}]' \
  --query ServiceConfiguration.ServiceId --output text)
SVC_NAME=$(aws ec2 describe-vpc-endpoint-service-configurations --service-ids $SVC_ID \
  --query 'ServiceConfigurations[0].ServiceName' --output text)
echo "$SVC_ID  $SVC_NAME"      # the name looks like com.amazonaws.vpce.us-east-1.vpce-svc-0123...

# who may connect: here our own account; for a partner use arn:aws:iam::222222222222:root
aws ec2 modify-vpc-endpoint-service-permissions --service-id $SVC_ID \
  --add-allowed-principals arn:aws:iam::$ACCOUNT_ID:root
aws ec2 describe-vpc-endpoint-service-permissions --service-id $SVC_ID \
  --query 'AllowedPrincipals[].Principal' --output text
```

Send the consumer the **service name** and the **AZ IDs** where your NLB runs.

AWS docs: [Share your services through PrivateLink](https://docs.aws.amazon.com/vpc/latest/privatelink/privatelink-share-your-services.html) · [Create an endpoint service](https://docs.aws.amazon.com/vpc/latest/privatelink/create-endpoint-service.html) · [Configure an endpoint service](https://docs.aws.amazon.com/vpc/latest/privatelink/configure-endpoint-service.html)

## Step 7: Connect from the consumer VPC and accept

> **In simple words:** The consumer creates an **interface endpoint** pointing at the service name. The connection waits as **pendingAcceptance** until the provider clicks **Accept**. Then the consumer reaches the API through the endpoint's DNS name, on a private IP in its own subnet.

**Console (consumer):** **Endpoints** → **Create endpoint** → Name `my-api-consumer` → **Type: Endpoint services that use NLBs and GWLBs** → paste the service name → **Verify service** → VPC `pl-lab-vpc` → subnets in both AZs → security group `my-api-endpoint-sg` (TCP 8080 from `10.10.0.0/16`) → **Create endpoint**.
**Console (provider):** **Endpoint services** → `my-api-service` → **Endpoint connections** tab → select the request → **Actions → Accept endpoint connection request**.

**CLI:**

```bash
# consumer: which AZs does the service offer?
aws ec2 describe-vpc-endpoint-services --service-names $SVC_NAME \
  --query 'ServiceDetails[0].[ServiceName,AvailabilityZones,AcceptanceRequired]' --output json

API_EP_SG=$(aws ec2 create-security-group --vpc-id $VPC_ID --group-name my-api-endpoint-sg \
  --description "my-api endpoint: 8080 from the lab VPC" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id $API_EP_SG --protocol tcp --port 8080 --cidr 10.10.0.0/16

API_EP=$(aws ec2 create-vpc-endpoint --vpc-id $VPC_ID --vpc-endpoint-type Interface \
  --service-name $SVC_NAME --subnet-ids $PRIV1 $PRIV2 --security-group-ids $API_EP_SG \
  --no-private-dns-enabled \
  --tag-specifications 'ResourceType=vpc-endpoint,Tags=[{Key=Name,Value=my-api-consumer}]' \
  --query VpcEndpoint.VpcEndpointId --output text)
aws ec2 describe-vpc-endpoints --vpc-endpoint-ids $API_EP --query 'VpcEndpoints[0].State' --output text
# pendingAcceptance (if it already says "available", acceptance was not required: skip the accept command)

# provider: see and accept the request
aws ec2 describe-vpc-endpoint-connections --filters Name=service-id,Values=$SVC_ID \
  --query 'VpcEndpointConnections[].[VpcEndpointId,VpcEndpointOwner,VpcEndpointState]' --output table
aws ec2 accept-vpc-endpoint-connections --service-id $SVC_ID --vpc-endpoint-ids $API_EP

# consumer: wait for "available", then get the DNS name (the first entry is the Regional name)
until [ "$(aws ec2 describe-vpc-endpoints --vpc-endpoint-ids $API_EP \
  --query 'VpcEndpoints[0].State' --output text)" = "available" ]; do sleep 15; done
API_DNS=$(aws ec2 describe-vpc-endpoints --vpc-endpoint-ids $API_EP \
  --query 'VpcEndpoints[0].DnsEntries[0].DnsName' --output text)
echo $API_DNS
```

**Test** from the Session Manager shell on `pl-lab-test`:

```bash
API_DNS=vpce-0123456789abcdef0-abcd1234.vpce-svc-0123456789abcdef0.us-east-1.vpce.amazonaws.com   # paste yours
getent hosts $API_DNS          # private IPs in the CONSUMER subnets (10.10.11.x, 10.10.12.x)
curl -s http://$API_DNS:8080   # hello from my-api in the provider VPC
```

Both VPCs use `10.10.0.0/16`, yet it works: the consumer only ever talks to IPs in its own subnets, and AWS carries the traffic to the NLB.

| Situation | What to do |
|---|---|
| Consumer is **another account** | Provider allows `arn:aws:iam::222222222222:root`. Compare **AZ IDs** (`aws ec2 describe-availability-zones --query 'AvailabilityZones[].[ZoneName,ZoneId]'`), because `us-east-1a` may be a different zone in each account |
| Provider wants to cut a consumer off | `aws ec2 reject-vpc-endpoint-connections --service-id SVC --vpc-endpoint-ids VPCE` (works on available connections too) |
| Sharing a database | Same pattern with the database port (for example 5432) behind the NLB. For RDS, also look at **resource endpoints** in the comparison section below, and the [RDS guide](#/tool/aws-rds) |

### Get an alert for new connection requests

A forgotten `pendingAcceptance` request means a team waiting for days. Let PrivateLink publish connection events to an SNS topic (see the [SNS guide](#/tool/aws-sns-ses)). The topic's access policy must allow the service principal `vpce.amazonaws.com` to publish (the AWS page below has the exact policy):

```bash
TOPIC_ARN=$(aws sns create-topic --name my-api-endpoint-events --query TopicArn --output text)
# ...add the access policy from the AWS docs to the topic, and subscribe your email, then:
NOTIF_ID=$(aws ec2 create-vpc-endpoint-connection-notification --service-id $SVC_ID \
  --connection-notification-arn $TOPIC_ARN --connection-events Connect Accept Reject Delete \
  --query ConnectionNotification.ConnectionNotificationId --output text)
```

AWS docs: [Receive alerts for endpoint service events](https://docs.aws.amazon.com/vpc/latest/privatelink/create-notification-endpoint-service.html) · [PrivateLink concepts and endpoint states](https://docs.aws.amazon.com/vpc/latest/privatelink/concepts.html)

## Step 8: A friendly name with private DNS (optional)

> **In simple words:** `vpce-0123…vpce.amazonaws.com` is hard to remember and different for every consumer. The provider can give the service a **private DNS name** like `api.example.com`, after proving it owns `example.com` with a **TXT record**. Consumers then simply call `api.example.com`. This step needs a domain whose public DNS you control (for example a [Route 53](#/tool/aws-route53) hosted zone).

**Console (provider):** **Endpoint services** → select → **Actions → Modify private DNS name** → tick **Associate a private DNS name with the service** → `api.example.com` → **Save**. On the **Details** tab, copy **Domain verification name** and **Domain verification value**, create that TXT record in your **public** zone, then **Actions → Verify domain ownership for private DNS name**.
**Console (consumer):** **Endpoints** → select → **Actions → Modify private DNS name** → **Enable**.

**CLI:**

```bash
aws ec2 modify-vpc-endpoint-service-configuration --service-id $SVC_ID --private-dns-name api.example.com

# the TXT record to create: Name (e.g. _6e86v84tqgqubxbwii1m) + ".example.com", and Value (vpce:...)
aws ec2 describe-vpc-endpoint-service-configurations --service-ids $SVC_ID \
  --query 'ServiceConfigurations[0].PrivateDnsNameConfiguration' --output json
# -> create that TXT record in the PUBLIC hosted zone for example.com (Route 53 console, TTL 1800)

# ask AWS to check now (otherwise it checks by itself after a while)
aws ec2 start-vpc-endpoint-service-private-dns-verification --service-id $SVC_ID
aws ec2 describe-vpc-endpoint-service-configurations --service-ids $SVC_ID \
  --query 'ServiceConfigurations[0].PrivateDnsNameConfiguration.State' --output text
# pendingVerification ... then verified

# consumer: use the friendly name inside the VPC
aws ec2 modify-vpc-endpoint --vpc-endpoint-id $API_EP --private-dns-enabled
```

From the test server: `curl -s http://api.example.com:8080`. Inside the consumer VPC the name resolves to the endpoint; everywhere else it follows your public DNS. An endpoint service has **one** private DNS name. If verification stays pending, the TXT record is usually in a **private** zone or has the wrong name.

AWS docs: [Manage DNS names for endpoint services](https://docs.aws.amazon.com/vpc/latest/privatelink/manage-dns-names.html)

## Cross-Region PrivateLink

> **In simple words:** Normally an endpoint and the service must be in the **same Region**. With **cross-Region** PrivateLink, a provider in us-east-1 can also offer the service in, say, us-west-2, and a consumer there creates an endpoint that names **us-east-1** as the service Region. AWS carries the traffic between Regions privately.

**Provider:** choose the extra Regions under **Service Regions** when you create the endpoint service (or add them later with the CLI below). **Consumer:** **Create endpoint** → **Endpoint services that use NLBs and GWLBs** → **Service Region: Enable Cross Region endpoint** → choose the Region → service name → **Verify service**.

```bash
# provider (home Region us-east-1): also offer the service in us-west-2
aws ec2 modify-vpc-endpoint-service-configuration --service-id $SVC_ID --add-supported-regions us-west-2

# consumer: a VPC in us-west-2 (replace these IDs with your own)
WEST_VPC_ID=vpc-0123456789abcdef0
WEST_SUBNETS="subnet-0123456789abcdef0 subnet-0fedcba9876543210"
WEST_SG=sg-0123456789abcdef0
aws ec2 create-vpc-endpoint --region us-west-2 --service-region us-east-1 \
  --vpc-id $WEST_VPC_ID --vpc-endpoint-type Interface --service-name $SVC_NAME \
  --subnet-ids $WEST_SUBNETS --security-group-ids $WEST_SG
```

| Good to know | Details |
|---|---|
| **Permission** | Both sides need the IAM permission-only action `vpce:AllowMultiRegion` (admins have it) |
| **AZs** | No AZ matching needed across Regions. The provider still needs at least two AZs, and a few AZs (for example `use1-az3`) don't support cross-Region access |
| **Failover** | PrivateLink fails over between AZs, **not** between Regions. For Region-level resilience, deploy the service in several Regions |
| **Limits** | Not for NLBs with a custom TCP idle timeout, and not with UDP fragmentation |
| **AWS services** | Some AWS services also accept cross-Region endpoints (for example S3, ECR, KMS, Lambda): see the list linked below |
| **Cost** | Consumer: normal endpoint hours and GB, **plus** inter-Region data transfer. Provider: a fixed hourly fee per active remote Region |

Prefer same-Region endpoints when you can: lower latency and lower cost.

AWS docs: [Cross-Region access](https://docs.aws.amazon.com/vpc/latest/privatelink/privatelink-share-your-services.html) · [Cross-Region enabled AWS services](https://docs.aws.amazon.com/vpc/latest/privatelink/aws-services-cross-region-privatelink-support.html)

## PrivateLink vs VPC peering vs Transit Gateway

> **In simple words:** **Peering** and **Transit Gateway** join whole **networks**: every server can reach every other server if routes and security groups allow. **PrivateLink** shares **one service**, in **one direction**, and the networks never see each other. Pick the smallest connection that does the job.

| | PrivateLink | VPC peering | Transit Gateway |
|---|---|---|---|
| What is shared | One service (an NLB port) | The whole VPC network | Many whole networks, plus VPN and Direct Connect |
| Direction | One way: consumer → service | Both ways | Both ways, controlled by routes |
| Overlapping CIDRs | **Allowed** | Not allowed | Not allowed |
| Routes to manage | None: an IP and DNS name in your own subnet | A route in both VPCs | Routes in every VPC and in the TGW route tables |
| Scale | Many consumers per service, each with its own endpoint | 50 peerings per VPC by default (up to 125) | Many VPCs through one hub |
| Cost | Per endpoint per AZ per hour, plus per GB | No hourly fee; you pay data transfer | Per attachment per hour, plus per GB |
| Best for | Platform teams, partners and SaaS offering an API or database to other accounts | A few VPCs that need full connectivity | Many VPCs, multi-account, hybrid networks |

The [VPC guide](#/tool/aws-vpc/transit-gateway-connect-many-vpcs) shows peering and Transit Gateway step by step.

> **Note:** For sharing a **single resource** such as an RDS database, an IP address or a domain name, PrivateLink also offers **resource endpoints**: the provider creates a **resource gateway** and a **resource configuration** (shared with AWS RAM), and no NLB is needed. See [Access VPC resources through PrivateLink](https://docs.aws.amazon.com/vpc/latest/privatelink/privatelink-access-resources.html). It is billed differently from interface endpoints (check the pricing page).

AWS docs: [What is PrivateLink?](https://docs.aws.amazon.com/vpc/latest/privatelink/what-is-privatelink.html) · [What is VPC peering?](https://docs.aws.amazon.com/vpc/latest/peering/what-is-vpc-peering.html)

## Troubleshooting

> **In simple words:** Walk the path: **DNS name → private IP → security group on the endpoint → endpoint state → policy → (for your own service) NLB and targets**. Most problems are a DNS setting or a missing port 443 rule.

| Problem | Likely cause | Fix |
|---|---|---|
| Endpoint stuck in `pendingAcceptance` | The provider hasn't accepted yet | Provider runs `accept-vpc-endpoint-connections`, or turns off acceptance. Add SNS notifications so requests are noticed |
| "Service not found" when creating the endpoint | Your account isn't an allowed principal, or wrong Region / service name | Provider adds `arn:aws:iam::ACCOUNT:root`; check the Region and the exact name |
| Service name still resolves to **public** IPs inside the VPC | Private DNS is off on the endpoint, or the VPC's `enableDnsSupport` / `enableDnsHostnames` is off, or servers use a custom DNS server that doesn't forward to the Amazon DNS | `modify-vpc-endpoint --private-dns-enabled`; turn on both VPC DNS attributes; forward to the VPC resolver |
| Connection to the endpoint **times out** | The endpoint's security group doesn't allow 443 (or your port) from the client, or a network ACL blocks it. (`ping` never works: endpoints don't answer it) | Allow the port from the client's security group or VPC CIDR; test with `curl` or `/dev/tcp` |
| Endpoint `available` but your service doesn't answer, or only from one AZ | NLB targets unhealthy; the target's security group blocks the NLB IPs; wrong listener port; no healthy target in that AZ with cross-zone off | `aws elbv2 describe-target-health --target-group-arn TG`; allow the provider VPC CIDR; targets in every AZ or cross-zone on |
| "Service not available in this AZ" (consumer) | The provider's NLB isn't in that AZ; AZ names differ between accounts | Compare **AZ IDs**; provider adds that AZ to the NLB or consumer picks matching subnets |
| Private DNS name stuck on `pendingVerification` | TXT record in a private zone, wrong record name, or the domain's name servers are wrong | Put the TXT record in the **public** zone, then start verification again |
| `AccessDenied` although the IAM policy allows it | The endpoint policy or a bucket policy with `aws:SourceVpce` blocks it | Read the endpoint policy (`describe-vpc-endpoints --query 'VpcEndpoints[].PolicyDocument'`) |
| Session Manager doesn't list the instance | One of `ssm`, `ssmmessages`, `ec2messages` is missing, or the role lacks `AmazonSSMManagedInstanceCore` | Create all three; restart the SSM Agent or reboot |
| ECR image pull fails in a private subnet | Missing `ecr.dkr` or `ecr.api`, or no S3 gateway route for the image layers | Create both interface endpoints and the S3 gateway endpoint |
| Unexpected bill | Interface endpoints in many VPCs and AZs, left running | Delete unused endpoints; share central endpoints; add free gateway endpoints |

AWS re:Post: [Troubleshoot connectivity between a VPC endpoint and an endpoint service](https://repost.aws/knowledge-center/connect-endpoint-service-vpc)

## Clean up

> **In simple words:** Interface endpoints and the NLB are billed every hour, even when idle. Delete servers first, then the consumer endpoint, the endpoint service, the NLB, the remaining endpoints, and finally the networks.

```bash
# servers
aws ec2 terminate-instances --instance-ids $TEST_VM $API_VM
aws ec2 wait instance-terminated --instance-ids $TEST_VM $API_VM

# consumer endpoint, notification, endpoint service, SNS topic
aws ec2 delete-vpc-endpoints --vpc-endpoint-ids $API_EP
aws ec2 delete-vpc-endpoint-connection-notifications --connection-notification-ids $NOTIF_ID
until [ -z "$(aws ec2 describe-vpc-endpoints --vpc-endpoint-ids $API_EP \
  --query 'VpcEndpoints[?State!=`deleted`].VpcEndpointId' --output text 2>/dev/null)" ]; do sleep 15; done
aws ec2 delete-vpc-endpoint-service-configurations --service-ids $SVC_ID
aws sns delete-topic --topic-arn $TOPIC_ARN

# NLB and target group
aws elbv2 delete-load-balancer --load-balancer-arn $NLB_ARN
aws elbv2 wait load-balancers-deleted --load-balancer-arns $NLB_ARN
aws elbv2 delete-target-group --target-group-arn $TG_ARN

# all remaining endpoints in the lab VPC (interface and gateway)
EPS=$(aws ec2 describe-vpc-endpoints --filters Name=vpc-id,Values=$VPC_ID \
  --query 'VpcEndpoints[?State!=`deleted`].VpcEndpointId' --output text)
[ -n "$EPS" ] && aws ec2 delete-vpc-endpoints --vpc-endpoint-ids $EPS
until [ -z "$(aws ec2 describe-vpc-endpoints --filters Name=vpc-id,Values=$VPC_ID \
  --query 'VpcEndpoints[?State!=`deleted`].VpcEndpointId' --output text)" ]; do sleep 15; done
sleep 60   # give AWS a moment to release the endpoint network cards

# security groups, subnets, route table, VPCs
for SG in $EP_SG $TEST_SG $API_EP_SG $API_SG; do aws ec2 delete-security-group --group-id $SG; done
for S in $PRIV1 $PRIV2 $PROV1 $PROV2; do aws ec2 delete-subnet --subnet-id $S; done
aws ec2 delete-route-table --route-table-id $PRIV_RT
aws ec2 delete-vpc --vpc-id $VPC_ID
aws ec2 delete-vpc --vpc-id $PROV_VPC

# bucket and local files
aws s3 rb s3://$BUCKET --force
rm -f hello.txt s3-endpoint-policy.json sts-endpoint-policy.json
```

If you did Step 8, delete the TXT record in Route 53. If you tried cross-Region, delete the endpoint in us-west-2 (`aws ec2 delete-vpc-endpoints --region us-west-2 --vpc-endpoint-ids VPCE`). If a security group refuses to delete with `DependencyViolation`, wait a minute and run the line again.

In real projects, build all of this with [Terraform](#/tool/terraform): `aws_vpc_endpoint` (one `for_each` over a list of service names), `aws_vpc_endpoint_service`, `aws_vpc_endpoint_service_allowed_principal` and `aws_vpc_endpoint_connection_accepter` cover everything in this guide.

```hcl
resource "aws_vpc_endpoint" "interface" {
  for_each            = toset(["ssm", "ssmmessages", "ec2messages", "sts", "logs"])
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
}
```

## Lab and cheat sheet

> **In simple words:** Practice time: build a VPC that works with no internet, break it on purpose, then share a service with a "partner" VPC that uses the very same addresses.

1. Create `pl-lab-vpc` with no internet and DNS on. Add the S3 and DynamoDB gateway endpoints, and find the `pl-…` routes in the route table.
2. Create the `ssm`, `ssmmessages`, `ec2messages` and `sts` endpoints. Launch the test server and connect with Session Manager.
3. On the test server, resolve `sts.us-east-1.amazonaws.com` with `getent hosts` (or `dig`); on your laptop, resolve it with `nslookup`. Explain the difference.
4. **Break it:** turn off private DNS on the `sts` endpoint (`aws ec2 modify-vpc-endpoint --vpc-endpoint-id STS_EP --no-private-dns-enabled`). `aws sts get-caller-identity --cli-connect-timeout 5` now fails. Turn it back on.
5. **Break it:** remove the 443 rule from `pl-lab-endpoints-sg`. What happens to your Session Manager session after a while? Put the rule back.
6. Attach `AmazonS3ReadOnlyAccess` to the lab role for a moment: `aws s3 ls s3://$BUCKET` works, `aws s3 ls` (all buckets) is denied by the endpoint policy. Detach the policy afterwards.
7. Publish `my-api` as an endpoint service with acceptance required, connect from `pl-lab-vpc`, accept, and `curl` it. Note that both VPCs are `10.10.0.0/16`. Then reject the connection (`reject-vpc-endpoint-connections`) and watch `curl` stop working.
8. Work out the monthly cost of 6 interface endpoints in 3 AZs (answer: 6 × 3 × $7.30 ≈ $131 before data), then clean up and check that `describe-vpc-endpoints` and `describe-vpc-endpoint-service-configurations` return nothing from the lab.

### Cheat sheet

| Task | Command |
|---|---|
| List AWS endpoint services | `aws ec2 describe-vpc-endpoint-services --query ServiceNames` |
| Gateway endpoint (S3) | `aws ec2 create-vpc-endpoint --vpc-endpoint-type Gateway --vpc-id V --service-name com.amazonaws.us-east-1.s3 --route-table-ids R` |
| Interface endpoint | `aws ec2 create-vpc-endpoint --vpc-endpoint-type Interface --vpc-id V --service-name com.amazonaws.us-east-1.sts --subnet-ids S1 S2 --security-group-ids SG --private-dns-enabled` |
| List endpoints and states | `aws ec2 describe-vpc-endpoints --query 'VpcEndpoints[].[VpcEndpointId,ServiceName,State]'` |
| Change the endpoint policy | `aws ec2 modify-vpc-endpoint --vpc-endpoint-id E --policy-document file://policy.json` |
| Private DNS on / off | `aws ec2 modify-vpc-endpoint --vpc-endpoint-id E --private-dns-enabled` (or `--no-private-dns-enabled`) |
| Create an endpoint service | `aws ec2 create-vpc-endpoint-service-configuration --network-load-balancer-arns NLB --acceptance-required` |
| Allow a consumer account | `aws ec2 modify-vpc-endpoint-service-permissions --service-id SVC --add-allowed-principals arn:aws:iam::222222222222:root` |
| See connection requests | `aws ec2 describe-vpc-endpoint-connections` |
| Accept / reject | `aws ec2 accept-vpc-endpoint-connections --service-id SVC --vpc-endpoint-ids E` (or `reject-…`) |
| Private DNS name for a service | `aws ec2 modify-vpc-endpoint-service-configuration --service-id SVC --private-dns-name api.example.com` |
| Offer in another Region | `aws ec2 modify-vpc-endpoint-service-configuration --service-id SVC --add-supported-regions us-west-2` |
| Delete endpoints | `aws ec2 delete-vpc-endpoints --vpc-endpoint-ids E1 E2` |
