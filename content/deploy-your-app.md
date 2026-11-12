# Deploy Your App: EC2, ECS or EKS

Your app works on your laptop. How do you put it on the internet, on AWS, the way real teams do? This guide takes **one small app** and deploys it **three ways**: on plain servers (**EC2**), as containers without servers (**ECS on Fargate**), and on Kubernetes (**EKS**). Each path is shown as a simple chain, such as `VPC → EC2 → load balancer → Route 53`, and every link in the chain is explained in plain words before you build it.

> **Note:** You can read this page just to understand the three flows, or follow it with commands. The commands are complete and work together from top to bottom. Each step links to the full guide for that service when you want to go deeper.

## Start here: you have code, now what?

> **In simple words:** To put an app on the internet you always need the same four things: a **network** to live in (VPC), a **front door** that users knock on (load balancer), a **padlock** for HTTPS (ACM certificate) and an **address** people can type (Route 53). Only the middle part changes: **what runs your code**. On EC2 it's a server you set up yourself, on ECS it's AWS running your container, and on EKS it's Kubernetes running your container.

```svg Every path shares the network, the address and the front door. Only the engine room in the private subnets changes.
<svg viewBox="0 0 480 346" role="img" aria-label="Users reach Route 53, then a load balancer with an ACM certificate in the public subnets of a VPC. The load balancer sends traffic to EC2 servers, ECS tasks or EKS pods in the private subnets. Code comes from S3 for EC2, or from ECR as an image for ECS and EKS.">
  <rect x="6" y="116" width="468" height="204" rx="14" class="dg-region"/>
  <text x="18" y="136" font-size="13" font-weight="800" fill="#f97316">VPC: your private network</text>
  <rect x="20" y="144" width="440" height="50" rx="10" fill="none" stroke="#10b981" stroke-width="1.5" stroke-dasharray="5 4"/>
  <text x="452" y="174" text-anchor="end" font-size="11" class="dg-muted">public subnets</text>
  <rect x="20" y="206" width="440" height="104" rx="10" fill="none" stroke="#3b82f6" stroke-width="1.5" stroke-dasharray="5 4"/>
  <text x="240" y="302" text-anchor="middle" font-size="11" class="dg-muted">private subnets: the internet can't reach these directly</text>
  <g fill="none" stroke="#94a3b8" stroke-width="2.5">
    <line x1="240" y1="42" x2="240" y2="56"/>
    <line x1="240" y1="96" x2="240" y2="146"/>
    <line x1="240" y1="186" x2="240" y2="200"/>
    <line x1="96" y1="200" x2="384" y2="200"/>
    <line x1="96" y1="200" x2="96" y2="217"/>
    <line x1="240" y1="200" x2="240" y2="217"/>
    <line x1="384" y1="200" x2="384" y2="217"/>
  </g>
  <g fill="#94a3b8">
    <polygon points="234,55 246,55 240,62"/>
    <polygon points="234,145 246,145 240,152"/>
    <polygon points="90,217 102,217 96,224"/>
    <polygon points="234,217 246,217 240,224"/>
    <polygon points="378,217 390,217 384,224"/>
  </g>
  <g font-size="14" font-weight="800" text-anchor="middle">
    <rect x="170" y="8" width="140" height="34" rx="17" class="dg-pill" stroke="#6366f1" stroke-width="2.5"/>
    <text x="240" y="30" class="dg-text">Users</text>
    <rect x="110" y="62" width="260" height="34" rx="17" class="dg-pill" stroke="#7c3aed" stroke-width="2.5"/>
    <text x="240" y="84" class="dg-text">Route 53: app.example.com</text>
    <rect x="110" y="152" width="260" height="34" rx="17" class="dg-pill" stroke="#c026d3" stroke-width="2.5"/>
    <text x="240" y="174" class="dg-text">Load balancer + ACM padlock</text>
    <rect x="28" y="224" width="136" height="60" rx="10" class="dg-box" stroke="#f59e0b" stroke-width="2.5"/>
    <text x="96" y="249" class="dg-text">EC2 servers</text>
    <rect x="172" y="224" width="136" height="60" rx="10" class="dg-box" stroke="#10b981" stroke-width="2.5"/>
    <text x="240" y="249" class="dg-text">ECS tasks</text>
    <rect x="316" y="224" width="136" height="60" rx="10" class="dg-box" stroke="#3b82f6" stroke-width="2.5"/>
    <text x="384" y="249" class="dg-text">EKS pods</text>
  </g>
  <g font-size="12" text-anchor="middle" class="dg-muted">
    <text x="96" y="269">your code + systemd</text>
    <text x="240" y="269">containers, no servers</text>
    <text x="384" y="269">Kubernetes + Ingress</text>
    <text x="240" y="338">Code comes from S3 (EC2) or from ECR as an image (ECS, EKS)</text>
  </g>
</svg>
```

### The three chains

Read each line left to right. That is the order you build things in, and the order a user's request travels in reverse.

```text
EC2:  VPC → security group → EC2 servers (your code) → target group → load balancer (HTTPS) → Route 53
ECS:  VPC → Docker image → ECR → ECS cluster → task definition → ECS service → load balancer (HTTPS) → Route 53
EKS:  VPC → Docker image → ECR → EKS cluster → Deployment + Service → Ingress → load balancer (made for you) → Route 53
```

### Words you will meet

| Word | What it means, simply |
|---|---|
| **VPC** | Your own private network inside AWS, like a compound wall around your buildings |
| **Subnet** | One part of the VPC, in one data center (Availability Zone). **Public** subnets hold the front door; **private** subnets hold your app, hidden from the internet |
| **Security group** | A small firewall around one thing: which ports are open, and to whom |
| **EC2 instance** | A virtual server you rent by the hour |
| **Docker image** | Your app plus everything it needs (Python, libraries) packed into one file |
| **ECR** | AWS's private shelf for Docker images |
| **Task (ECS) / Pod (EKS)** | One running copy of your container |
| **Load balancer (ALB)** | The front door: one address that spreads users across your copies and skips broken ones |
| **Target group** | The list of copies behind the load balancer, plus the health check it runs on them |
| **ACM certificate** | The padlock for HTTPS. Free from AWS |
| **Route 53** | AWS's DNS: turns `ec2.example.com` into the load balancer's address |
| **Ingress** | A Kubernetes rule like "send `eks.example.com` to this app". On EKS it creates the load balancer for you |

### The app we deploy

All three paths ship the same tiny Python app, `hello-app`, from [CI/CD Basics: the sample app](#/tool/cicd-basics/the-sample-app-used-in-every-ci-cd-guide). It listens on port **8000**, answers `/` with a message and its version, and answers `/health` with `{"status":"ok"}`. Load balancers use that `/health` page to check each copy is alive.

> **Tip:** Your own app works the same way. You only need to know three things about it: **how to start it**, **which port it listens on**, and **a URL that says "I'm healthy"**.

## Which path should I choose?

> **In simple words:** Think of renting a home. **EC2** is an empty flat: you buy the furniture, cook and clean yourself. **ECS on Fargate** is a serviced apartment: you bring your suitcase (the container) and AWS looks after the building. **EKS** is running a hotel with a professional manager (Kubernetes): very powerful and flexible, but there are more rules to learn.

| | EC2 | ECS on Fargate | EKS |
|---|---|---|---|
| **In one line** | Rent servers and set them up yourself | Give AWS a container; it runs it | A Kubernetes cluster runs your containers |
| **You package the app as** | Files (a `.tgz`) and a start script | A Docker image | A Docker image and Kubernetes YAML |
| **Who patches the operating system** | You | AWS | You update the worker nodes (AWS gives you new images) |
| **What restarts a crashed app** | systemd on the server | The ECS service | The Kubernetes Deployment |
| **Who creates the load balancer** | You | You | The Ingress, through the Load Balancer Controller |
| **Shipping a new version** | Copy new files and restart | New task definition revision | New image tag in the Deployment |
| **Skills you need first** | Linux | Linux and Docker | Linux, Docker and Kubernetes |
| **Fixed cost before your app runs** | Lowest | Low: you pay only per running task | Highest: about $73 a month for the cluster itself, plus nodes |
| **First deploy takes** | About 1 hour | About 1 hour | About 2 hours (the cluster alone takes 20 minutes) |
| **Best for** | One app, older software, anything that needs a full server | A few container apps and a small team | Many services, teams that know Kubernetes, GitOps with Argo CD |

**Choose in 30 seconds:**

1. Your app is **not** in a Docker image yet → **EC2**. (Or put it in one first with the [Docker guide](#/tool/docker).)
2. It's in an image, you have **a few services** and **no Kubernetes skills** on the team → **ECS on Fargate**.
3. You have **many services**, or your company already uses **Kubernetes, Helm or Argo CD** → **EKS**.

> **Tip:** To learn, do all three in order: EC2, then ECS, then EKS. EC2 shows you every moving part. ECS hides the servers. EKS adds Kubernetes on top. Real companies often use all three side by side, as the [AWS real deployment guide](#/tool/aws-real-deployment/running-the-application) shows.

## Before you start

> **In simple words:** Get your account, tools and app ready, and set a few variables once. Every command after this uses them, so you never type an account ID or Region twice.

### What you need

| Need | EC2 | ECS | EKS | Where to get it |
|---|---|---|---|---|
| An AWS account and an admin user (not root) | ✔ | ✔ | ✔ | [Create your AWS account](#/tool/aws-account) |
| AWS CLI v2, logged in | ✔ | ✔ | ✔ | [Workstation setup](#/tool/setup) |
| A domain with a Route 53 hosted zone | ✔ | ✔ | ✔ | [Get a domain and point it to Route 53](#/tool/aws-route53/get-a-domain-and-point-it-to-route-53) |
| The `hello-app` code (or your own app) | ✔ | ✔ | ✔ | [The sample app](#/tool/cicd-basics/the-sample-app-used-in-every-ci-cd-guide) |
| Docker | | ✔ | ✔ | [Docker](#/tool/docker) |
| kubectl, eksctl and Helm | | | ✔ | [Workstation setup](#/tool/setup) |

> **Note:** No domain? You can still do every path. Skip common step 2, and in each path follow the **"No domain"** notes: you'll open the app on the load balancer's own `http://…amazonaws.com` address instead of `https://ec2.example.com`.

### Set your variables

Run everything in **bash** (Linux, WSL2, or type `bash` first on a Mac: the Mac's default shell, zsh, handles lists of IDs differently).

```bash
export AWS_REGION=us-east-1                        # CHANGE: your Region
export DOMAIN=example.com                          # CHANGE: your domain in Route 53
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name $DOMAIN \
  --query 'HostedZones[0].Id' --output text | cut -d/ -f3)

aws route53 get-hosted-zone --id $ZONE_ID --query HostedZone.Name --output text   # must print your domain + "."
cd ~/code/hello-app                                # the app's folder
```

> **Warning:** Some parts cost money every hour they exist, even when nobody uses them: the **NAT gateway**, each **load balancer** and the **EKS cluster**. With all three paths running it's about **$9 a day**. Do the [clean-up step](#/tool/deploy-your-app/clean-up-and-cost) as soon as you finish.

> **Tip:** Closed your terminal? The [cheat sheet](#/tool/deploy-your-app/cheat-sheet) has one block that finds everything again by name and sets all the variables back.

## Common step 1: the network (VPC)

> **In simple words:** The VPC is your compound wall. Inside it, **public subnets** are the gate area: only the load balancer stands there, facing the internet. **Private subnets** are the inner rooms where your app runs; nobody outside can reach them directly. A **NAT gateway** is a one-way door: your servers can go *out* (to download updates or pull images), but nobody can come *in* through it. You build this once, and all three paths use it.

```text
 Internet
    │
 ┌─ VPC hello-vpc  10.0.0.0/16 ───────────────────────────────────┐
 │        Availability Zone a              Availability Zone b    │
 │  ┌ public subnet ────────────────┐  ┌ public subnet ─────────┐ │
 │  │ load balancer · NAT gateway   │  │ load balancer          │ │
 │  └───────────────────────────────┘  └────────────────────────┘ │
 │  ┌ private subnet ───────────────┐  ┌ private subnet ────────┐ │
 │  │ your app: EC2 / task / pod    │  │ your app               │ │
 │  └───────────────────────────────┘  └────────────────────────┘ │
 └────────────────────────────────────────────────────────────────┘
```

Two Availability Zones means two separate data centers: if one has a problem, your app keeps running in the other.

### Create it with the console wizard

1. Open the **VPC console** → **Create VPC** → choose **VPC and more**.
2. **Name tag auto-generation:** `hello`. **IPv4 CIDR block:** `10.0.0.0/16`.
3. **Number of Availability Zones:** `2`. **Public subnets:** `2`. **Private subnets:** `2`.
4. **NAT gateways:** `In 1 AZ` (cheaper for learning; production uses `1 per AZ`).
5. **VPC endpoints:** `S3 Gateway` (free, and keeps S3 traffic off the NAT gateway).
6. Keep **DNS hostnames** and **DNS resolution** ticked → **Create VPC**.

The wizard names everything from `hello`, for example `hello-vpc` and `hello-subnet-private1-us-east-1a`. Want to build each piece by hand and see how it fits? Follow [AWS VPC: Step-by-Step](#/tool/aws-vpc).

### Save the IDs and tag the subnets

```bash
export VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=hello-vpc \
  --query 'Vpcs[0].VpcId' --output text)
export PUBLIC_SUBNETS=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID \
  "Name=tag:Name,Values=hello-subnet-public*" --query 'Subnets[].SubnetId' --output text)
export PRIVATE_SUBNETS=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID \
  "Name=tag:Name,Values=hello-subnet-private*" --query 'Subnets[].SubnetId' --output text)
echo "VPC $VPC_ID | public: $PUBLIC_SUBNETS | private: $PRIVATE_SUBNETS"   # 2 public, 2 private

# Tags tell Kubernetes (Path 3) where load balancers may go. Harmless for the other paths.
aws ec2 create-tags --resources $PUBLIC_SUBNETS --tags Key=kubernetes.io/role/elb,Value=1
aws ec2 create-tags --resources $PRIVATE_SUBNETS --tags Key=kubernetes.io/role/internal-elb,Value=1
```

### The load balancer's firewall

Paths 1 and 2 put their load balancer behind this security group: web traffic in from anywhere, nothing else. (On EKS, the Load Balancer Controller makes its own.)

```bash
export ALB_SG=$(aws ec2 create-security-group --group-name hello-alb-sg --vpc-id $VPC_ID \
  --description "Load balancer: HTTP and HTTPS from the internet" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id $ALB_SG --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $ALB_SG --protocol tcp --port 443 --cidr 0.0.0.0/0
```

**Check:** in the VPC console, **Subnets** shows 4 `hello-subnet-…` subnets in 2 AZs, and **NAT gateways** shows one `Available`.

## Common step 2: the address and the padlock (Route 53 and ACM)

> **In simple words:** **Route 53** is the phone book: it turns `ecs.example.com` into the load balancer's address. **ACM** gives you a free HTTPS certificate, the padlock in the browser. You prove you own the domain by adding one DNS record. One **wildcard** certificate (`*.example.com`) covers `ec2.`, `ecs.` and `eks.example.com`, so all three paths share it.

### Get the certificate

```bash
export CERT_ARN=$(aws acm request-certificate --domain-name "$DOMAIN" \
  --subject-alternative-names "*.$DOMAIN" --validation-method DNS \
  --query CertificateArn --output text)
```

**Prove you own the domain.** Easiest: in the **ACM console**, open the certificate and click **Create records in Route 53**. Or from the CLI:

```bash
sleep 15     # ACM needs a few seconds to prepare the validation record
read -r V_NAME V_VALUE <<< "$(aws acm describe-certificate --certificate-arn $CERT_ARN \
  --query 'Certificate.DomainValidationOptions[0].ResourceRecord.[Name,Value]' --output text)"
cat > validate.json <<EOF
{"Changes": [{"Action": "UPSERT", "ResourceRecordSet": {"Name": "$V_NAME", "Type": "CNAME",
  "TTL": 300, "ResourceRecords": [{"Value": "$V_VALUE"}]}}]}
EOF
aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch file://validate.json

aws acm wait certificate-validated --certificate-arn $CERT_ARN     # usually 2–10 minutes
```

Leave that CNAME record in place for good: ACM uses it to **renew the certificate automatically** every year.

> **Note:** The certificate must be in the **same Region** as the load balancer. Already have one for your domain? Reuse it: `aws acm list-certificates --query "CertificateSummaryList[?DomainName=='$DOMAIN'].CertificateArn" --output text`.

### A helper to point a name at a load balancer

Every path ends the same way: "make `something.example.com` point at this load balancer". This small function does it with an **alias** record (an A record that follows the load balancer even if its IPs change). Paste it once into your terminal:

```bash
point_dns() {   # usage: point_dns <your hostname> <load balancer DNS name>
  local lb_zone
  lb_zone=$(aws elbv2 describe-load-balancers \
    --query "LoadBalancers[?DNSName=='$2'].CanonicalHostedZoneId" --output text)
  cat > dns.json <<EOF
{"Changes": [{"Action": "UPSERT", "ResourceRecordSet": {"Name": "$1", "Type": "A",
  "AliasTarget": {"HostedZoneId": "$lb_zone", "DNSName": "$2", "EvaluateTargetHealth": true}}}]}
EOF
  aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch file://dns.json \
    --query ChangeInfo.Status --output text
}
```

`HostedZoneId` inside the alias is the **load balancer's** zone, not yours. Getting that wrong is the most common Route 53 mistake, which is why the function looks it up for you. More in [Route 53: alias records](#/tool/aws-route53/alias-records-point-names-at-aws-resources).

## Path 1: EC2 (a server you run yourself)

> **In simple words:** You rent two Linux servers and put them in the private subnets. When each one boots for the first time, a small script installs Python, downloads your code from S3 and starts it as a **systemd** service (so Linux restarts it if it crashes). A load balancer in front checks each server's `/health` page and spreads users across the healthy ones. Then Route 53 gives it a nice name.

```flow
🧱 | VPC | Ready from common step 1: public subnets for the load balancer, private subnets for the servers.
🛡️ | Security group | A firewall for the servers: port 8000 open **only** to the load balancer. No SSH port at all.
🪪 | IAM role | Lets the servers read your code from S3 and be managed by Systems Manager. No passwords or keys on the servers.
📦 | Your code in S3 | You pack the code into `hello-app-1.0.0.tgz` and upload it to a bucket.
🖥️ | EC2 servers | Two servers, one per private subnet. A boot script installs the app and starts it with systemd.
🎯 | Target group | The list of servers behind the load balancer. It checks `/health` every 15 seconds.
⚖️ | Load balancer | The front door in the public subnets: HTTPS with your certificate, and HTTP redirected to HTTPS.
🌐 | Route 53 | `ec2.example.com` points at the load balancer. Open it in a browser.
```

### 1. Firewall and permissions

```bash
# Servers accept port 8000 from the load balancer only
export EC2_SG=$(aws ec2 create-security-group --group-name hello-ec2-sg --vpc-id $VPC_ID \
  --description "hello-app servers: 8000 from the load balancer" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id $EC2_SG --protocol tcp --port 8000 --source-group $ALB_SG

# A bucket for release files (the account ID makes the name unique)
export BUCKET=hello-app-releases-$ACCOUNT_ID
aws s3 mb s3://$BUCKET

# A role the servers wear: Systems Manager + read-only access to the releases
cat > ec2-trust.json <<'EOF'
{"Version": "2012-10-17", "Statement": [{"Effect": "Allow",
  "Principal": {"Service": "ec2.amazonaws.com"}, "Action": "sts:AssumeRole"}]}
EOF
cat > read-releases.json <<EOF
{"Version": "2012-10-17", "Statement": [{"Effect": "Allow", "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::$BUCKET/releases/*"}]}
EOF
aws iam create-role --role-name hello-app-ec2 --assume-role-policy-document file://ec2-trust.json
aws iam attach-role-policy --role-name hello-app-ec2 \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
aws iam put-role-policy --role-name hello-app-ec2 --policy-name read-releases \
  --policy-document file://read-releases.json
aws iam create-instance-profile --instance-profile-name hello-app-ec2
aws iam add-role-to-instance-profile --instance-profile-name hello-app-ec2 --role-name hello-app-ec2
```

An **instance profile** is just the "holder" that attaches a role to a server.

### 2. Upload your code

```bash
tar czf hello-app-1.0.0.tgz app.py requirements.txt
aws s3 cp hello-app-1.0.0.tgz s3://$BUCKET/releases/
```

### 3. The boot script (user data)

Save this as `user-data.tpl`. EC2 runs it **once, as root, on the first boot**. It creates a tiny command, `deploy-app <version>`, that you'll reuse later for every new version.

```bash
#!/bin/bash
# Runs once, as root, the first time the server boots.
set -euxo pipefail
dnf install -y python3 python3-pip
useradd --system appuser || true                  # the app never runs as root
mkdir -p /opt/hello-app/releases

# deploy-app <version>: download that release from S3, install it, restart the app
cat > /usr/local/bin/deploy-app <<'SCRIPT'
#!/bin/bash
set -euo pipefail
VERSION="$1"
DIR="/opt/hello-app/releases/$VERSION"
mkdir -p "$DIR"
aws s3 cp "s3://__BUCKET__/releases/hello-app-$VERSION.tgz" - --region __REGION__ | tar xz -C "$DIR"
python3 -m venv "$DIR/venv"
"$DIR/venv/bin/pip" install --quiet -r "$DIR/requirements.txt"
echo "APP_VERSION=$VERSION" > /opt/hello-app/app.env
ln -sfn "$DIR" /opt/hello-app/current             # "current" now points at this version
systemctl restart hello-app
echo "hello-app $VERSION is running"
SCRIPT
chmod +x /usr/local/bin/deploy-app

# systemd starts the app at boot and restarts it if it crashes
cat > /etc/systemd/system/hello-app.service <<'UNIT'
[Unit]
Description=hello-app
After=network-online.target
Wants=network-online.target

[Service]
User=appuser
EnvironmentFile=/opt/hello-app/app.env
WorkingDirectory=/opt/hello-app/current
ExecStart=/opt/hello-app/current/venv/bin/gunicorn -b 0.0.0.0:8000 app:app
Restart=always

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable hello-app

/usr/local/bin/deploy-app 1.0.0
```

Fill in your bucket and Region:

```bash
sed -e "s/__BUCKET__/$BUCKET/" -e "s/__REGION__/$AWS_REGION/" user-data.tpl > user-data.sh
```

### 4. Launch two servers

```bash
AMI=resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64
sleep 10    # a brand-new instance profile takes a few seconds before EC2 can use it

for SUBNET in $PRIVATE_SUBNETS; do              # one server in each private subnet
  aws ec2 run-instances --image-id $AMI --instance-type t3.micro \
    --subnet-id $SUBNET --security-group-ids $EC2_SG \
    --iam-instance-profile Name=hello-app-ec2 \
    --metadata-options HttpTokens=required \
    --user-data file://user-data.sh \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=hello-app},{Key=App,Value=hello-app}]' \
    --query 'Instances[0].InstanceId' --output text
done

export INSTANCE_IDS=$(aws ec2 describe-instances \
  --filters Name=tag:App,Values=hello-app Name=instance-state-name,Values=pending,running \
  --query 'Reservations[].Instances[].InstanceId' --output text)
aws ec2 wait instance-running --instance-ids $INSTANCE_IDS
```

`resolve:ssm:…` always picks the newest Amazon Linux 2023 image, so you never hunt for an AMI ID. `HttpTokens=required` turns on the safer version of the instance metadata service (IMDSv2).

### 5. Target group and load balancer

```bash
export EC2_TG=$(aws elbv2 create-target-group --name hello-ec2-tg --protocol HTTP --port 8000 \
  --vpc-id $VPC_ID --target-type instance --health-check-path /health \
  --health-check-interval-seconds 15 --healthy-threshold-count 2 \
  --query 'TargetGroups[0].TargetGroupArn' --output text)
aws elbv2 register-targets --target-group-arn $EC2_TG --targets $(printf 'Id=%s ' $INSTANCE_IDS)

read -r EC2_ALB EC2_ALB_DNS <<< "$(aws elbv2 create-load-balancer --name hello-ec2-alb \
  --type application --subnets $PUBLIC_SUBNETS --security-groups $ALB_SG \
  --query 'LoadBalancers[0].[LoadBalancerArn,DNSName]' --output text)"

# HTTPS: forward to the servers. HTTP: send the browser to HTTPS.
aws elbv2 create-listener --load-balancer-arn $EC2_ALB --protocol HTTPS --port 443 \
  --certificates CertificateArn=$CERT_ARN --default-actions Type=forward,TargetGroupArn=$EC2_TG
aws elbv2 create-listener --load-balancer-arn $EC2_ALB --protocol HTTP --port 80 \
  --default-actions 'Type=redirect,RedirectConfig={Protocol=HTTPS,Port=443,StatusCode=HTTP_301}'

aws elbv2 wait load-balancer-available --load-balancer-arns $EC2_ALB
aws elbv2 describe-target-health --target-group-arn $EC2_TG \
  --query 'TargetHealthDescriptions[].[Target.Id,TargetHealth.State]' --output table   # wait for "healthy"
```

The servers need 2–3 minutes after boot to install everything. Run the last command again until both show `healthy`.

> **Note:** **No domain?** Replace the two `create-listener` commands with one HTTP listener that forwards: `aws elbv2 create-listener --load-balancer-arn $EC2_ALB --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=$EC2_TG`, then skip step 6 and open `http://$EC2_ALB_DNS/`.

### 6. Give it a name and open it

```bash
point_dns ec2.$DOMAIN $EC2_ALB_DNS              # prints PENDING, then it's live within a minute
for i in 1 2 3 4; do curl -s https://ec2.$DOMAIN/; echo; done
```

You'll see `"version":"1.0.0"` and a `host` that changes between the two servers. That is the load balancer at work.

**Look inside a server** without SSH: **EC2 console → select the server → Connect → Session Manager**. Then:

```bash
systemctl status hello-app                       # active (running)
journalctl -u hello-app -n 20                    # the app's own log
sudo tail -30 /var/log/cloud-init-output.log     # what the boot script did
```

### 7. Ship a new version

Change the code, pack it with a new version number and tell both servers to install it, **one at a time** so the other keeps serving users:

```bash
tar czf hello-app-1.1.0.tgz app.py requirements.txt
aws s3 cp hello-app-1.1.0.tgz s3://$BUCKET/releases/

CMD_ID=$(aws ssm send-command --document-name AWS-RunShellScript \
  --targets Key=tag:App,Values=hello-app --max-concurrency 1 --max-errors 0 \
  --parameters 'commands=["/usr/local/bin/deploy-app 1.1.0"]' \
  --comment "hello-app 1.1.0" --query Command.CommandId --output text)
aws ssm list-command-invocations --command-id $CMD_ID \
  --query 'CommandInvocations[].[InstanceId,Status]' --output table      # Success on both
```

**Roll back** with the same command and the old version, `deploy-app 1.0.0`. The old release is still on disk, so it takes seconds.

> **Tip:** Hand-made servers are perfect for learning. In production you put a **launch template** and an **Auto Scaling group** behind the target group: AWS replaces a broken server by itself and adds servers on busy days. See [Load balancers with Auto Scaling](#/tool/aws-elb/load-balancers-with-auto-scaling-ecs-and-kubernetes) and, for running commands on many servers, [Systems Manager](#/tool/aws-ssm).

## Path 2: ECS on Fargate (containers, no servers)

> **In simple words:** You pack the app into a **Docker image** and put it on AWS's image shelf, **ECR**. Then you tell ECS: "keep 2 copies of this image running, each with a quarter of a CPU and half a GB of memory, behind this load balancer". **Fargate** finds the computers to run them on. There are no servers for you to patch, log in to or even see.

```flow
🧱 | VPC | Ready from common step 1.
🐳 | Docker image | `docker build` packs your code, Python and the libraries into one image.
🗄️ | ECR | AWS's private shelf for images. You `docker push` the image there.
🏢 | ECS cluster | An empty, named home for your app. With Fargate there are no servers in it to manage.
📝 | Task definition | The recipe: which image, how much CPU and memory, which port, where the logs go.
🔁 | ECS service | Keeps 2 copies (tasks) running in the private subnets, replaces any that die, and adds them to the target group.
🎯 | Target group | Lists the tasks by IP address and checks `/health`.
⚖️ | Load balancer | HTTPS front door in the public subnets.
🌐 | Route 53 | `ecs.example.com` points at the load balancer. Open it in a browser.
```

### 1. Build the image and push it to ECR

```bash
aws ecr create-repository --repository-name hello-app \
  --image-scanning-configuration scanOnPush=true --image-tag-mutability IMMUTABLE
export REPO=$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/hello-app

docker build --platform linux/amd64 --build-arg APP_VERSION=1.0.0 -t $REPO:1.0.0 .
aws ecr get-login-password | docker login --username AWS --password-stdin ${REPO%%/*}
docker push $REPO:1.0.0
```

- `--platform linux/amd64` matters on Apple-silicon Macs: without it the image is built for ARM and fails on AWS with `exec format error`.
- `IMMUTABLE` means a tag like `1.0.0` can never be overwritten, so "1.0.0" always means the same code. Every release gets a new tag.
- `scanOnPush` checks the image for known vulnerabilities. Details in the [ECR guide](#/tool/aws-ecr).

### 2. Cluster, role, logs and firewall

```bash
aws ecs create-cluster --cluster-name hello

# The task execution role lets ECS pull your image and write logs.
# Skip these two commands if the role already exists (for example from the ECS guide).
cat > ecs-trust.json <<'EOF'
{"Version": "2012-10-17", "Statement": [{"Effect": "Allow",
  "Principal": {"Service": "ecs-tasks.amazonaws.com"}, "Action": "sts:AssumeRole"}]}
EOF
aws iam create-role --role-name ecsTaskExecutionRole --assume-role-policy-document file://ecs-trust.json
aws iam attach-role-policy --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

aws logs create-log-group --log-group-name /ecs/hello-app
aws logs put-retention-policy --log-group-name /ecs/hello-app --retention-in-days 7

export ECS_SG=$(aws ec2 create-security-group --group-name hello-ecs-sg --vpc-id $VPC_ID \
  --description "hello-app tasks: 8000 from the load balancer" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id $ECS_SG --protocol tcp --port 8000 --source-group $ALB_SG
```

### 3. The task definition (the recipe)

```bash
cat > taskdef.json <<EOF
{
  "family": "hello-app",
  "requiresCompatibilities": ["FARGATE"],
  "networkMode": "awsvpc",
  "cpu": "256",
  "memory": "512",
  "runtimePlatform": { "cpuArchitecture": "X86_64", "operatingSystemFamily": "LINUX" },
  "executionRoleArn": "arn:aws:iam::$ACCOUNT_ID:role/ecsTaskExecutionRole",
  "containerDefinitions": [{
    "name": "web",
    "image": "$REPO:1.0.0",
    "essential": true,
    "portMappings": [{ "containerPort": 8000, "protocol": "tcp" }],
    "logConfiguration": { "logDriver": "awslogs", "options": {
      "awslogs-group": "/ecs/hello-app", "awslogs-region": "$AWS_REGION", "awslogs-stream-prefix": "web" } }
  }]
}
EOF
aws ecs register-task-definition --cli-input-json file://taskdef.json --query taskDefinition.revision
```

`256` CPU units is a quarter of a CPU; `512` is half a GB of memory. Each registration gets a new **revision** number: 1, 2, 3…

### 4. Target group and load balancer

```bash
export ECS_TG=$(aws elbv2 create-target-group --name hello-ecs-tg --protocol HTTP --port 8000 \
  --vpc-id $VPC_ID --target-type ip --health-check-path /health \
  --health-check-interval-seconds 15 --healthy-threshold-count 2 \
  --query 'TargetGroups[0].TargetGroupArn' --output text)
aws elbv2 modify-target-group-attributes --target-group-arn $ECS_TG \
  --attributes Key=deregistration_delay.timeout_seconds,Value=30

read -r ECS_ALB ECS_ALB_DNS <<< "$(aws elbv2 create-load-balancer --name hello-ecs-alb \
  --type application --subnets $PUBLIC_SUBNETS --security-groups $ALB_SG \
  --query 'LoadBalancers[0].[LoadBalancerArn,DNSName]' --output text)"
aws elbv2 create-listener --load-balancer-arn $ECS_ALB --protocol HTTPS --port 443 \
  --certificates CertificateArn=$CERT_ARN --default-actions Type=forward,TargetGroupArn=$ECS_TG
aws elbv2 create-listener --load-balancer-arn $ECS_ALB --protocol HTTP --port 80 \
  --default-actions 'Type=redirect,RedirectConfig={Protocol=HTTPS,Port=443,StatusCode=HTTP_301}'
```

The target type is `ip`, not `instance`: each Fargate task gets its own IP address in your subnet. The 30-second deregistration delay makes new versions roll out faster (the default is 5 minutes). **No domain?** Use one HTTP listener that forwards, as in Path 1.

### 5. The service: keep 2 copies running

```bash
aws ecs create-service --cluster hello --service-name hello-app \
  --task-definition hello-app --desired-count 2 --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$(echo $PRIVATE_SUBNETS | tr ' ' ',')],securityGroups=[$ECS_SG],assignPublicIp=DISABLED}" \
  --load-balancers "targetGroupArn=$ECS_TG,containerName=web,containerPort=8000" \
  --health-check-grace-period-seconds 30 \
  --deployment-configuration "deploymentCircuitBreaker={enable=true,rollback=true}" \
  --query service.status --output text

aws ecs wait services-stable --cluster hello --services hello-app      # 2–4 minutes
```

The tasks run in the **private** subnets with no public IP. They pull the image from ECR through the NAT gateway.

### 6. Give it a name and open it

```bash
point_dns ecs.$DOMAIN $ECS_ALB_DNS
for i in 1 2 3 4; do curl -s https://ecs.$DOMAIN/; echo; done      # host changes between the 2 tasks
aws logs tail /ecs/hello-app --since 10m                             # the app's log
```

**Test self-healing:** stop one task and watch ECS start a new one by itself:

```bash
aws ecs stop-task --cluster hello --task $(aws ecs list-tasks --cluster hello \
  --service-name hello-app --query 'taskArns[0]' --output text) --query task.lastStatus
aws ecs describe-services --cluster hello --services hello-app \
  --query 'services[0].[runningCount,desiredCount]' --output text     # back to 2 2 within a minute
```

### 7. Ship a new version

```bash
docker build --platform linux/amd64 --build-arg APP_VERSION=1.1.0 -t $REPO:1.1.0 .
docker push $REPO:1.1.0

sed -i "s|$REPO:1.0.0|$REPO:1.1.0|" taskdef.json        # on a Mac: sed -i '' "s|…|…|" taskdef.json
aws ecs register-task-definition --cli-input-json file://taskdef.json --query taskDefinition.revision
aws ecs update-service --cluster hello --service hello-app --task-definition hello-app \
  --query 'service.deployments[0].rolloutState' --output text
aws ecs wait services-stable --cluster hello --services hello-app
```

ECS starts the new tasks, waits until the load balancer says they're healthy, and only then stops the old ones. If the new version never gets healthy, the **circuit breaker** rolls back by itself. **Roll back** by hand with `aws ecs update-service --cluster hello --service hello-app --task-definition hello-app:1`.

> **Tip:** More on scaling, secrets and a shell inside a running task in the [Amazon ECS guide](#/tool/aws-ecs).

## Path 3: EKS (containers on Kubernetes)

> **In simple words:** EKS gives you a **Kubernetes cluster**: AWS runs the "brain" (the control plane) and you add a few EC2 **worker nodes**. You describe your app in YAML: a **Deployment** (keep 2 copies running), a **Service** (one stable name for those copies) and an **Ingress** (send `eks.example.com` to that Service). An add-on called the **AWS Load Balancer Controller** reads the Ingress and builds a real AWS load balancer for you, with your certificate. So the chain is: VPC → EKS → Docker image → Kubernetes → Ingress (ALB) → Route 53.

```flow
🧱 | VPC | Ready from common step 1, with the subnet tags that tell Kubernetes where load balancers go.
🐳 | Docker image in ECR | The same image as Path 2, step 1 (build and push).
☸️ | EKS cluster | AWS runs the Kubernetes control plane; `eksctl` adds 2 worker nodes in the private subnets.
🔌 | Load Balancer Controller | An add-on that turns every Ingress into a real AWS load balancer.
📦 | Deployment | Kubernetes keeps 2 pods (copies of your container) running and replaces broken ones.
🔗 | Service | One stable name inside the cluster for the 2 pods.
🚪 | Ingress | The rule "`eks.example.com` → this Service". The controller builds an HTTPS load balancer from it.
🌐 | Route 53 | `eks.example.com` points at that load balancer. Open it in a browser.
```

### 1. The image

Did Path 2? The image `$REPO:1.0.0` is already in ECR. If not, do [Path 2, step 1](#/tool/deploy-your-app/path-2-ecs-on-fargate-containers-no-servers) first (create the repository, build, push), then come back.

```bash
export REPO=$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/hello-app
aws ecr describe-images --repository-name hello-app --query 'imageDetails[].imageTags' --output text   # 1.0.0
```

### 2. Create the cluster

This writes the cluster file for you, with your VPC and the two private subnets filled in:

```bash
SUBNET_LINES=$(aws ec2 describe-subnets --subnet-ids $PRIVATE_SUBNETS \
  --query 'Subnets[].[AvailabilityZone,SubnetId]' --output text \
  | awk '{ printf "      %s: { id: %s }\n", $1, $2 }')

cat > eks.yaml <<EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: hello-eks
  region: $AWS_REGION
  version: "1.36"                  # a version in EKS standard support
iam:
  withOIDC: true                   # lets add-ons get their own IAM roles
vpc:
  id: $VPC_ID
  subnets:
    private:
$SUBNET_LINES
managedNodeGroups:
  - name: workers
    instanceType: t3.medium
    minSize: 2
    desiredCapacity: 2
    maxSize: 3
    privateNetworking: true        # worker nodes get private IPs only
EOF
cat eks.yaml                       # check: two subnet lines under "private:"

eksctl create cluster -f eks.yaml  # about 20 minutes: get a coffee
kubectl get nodes                  # 2 nodes, STATUS Ready
```

When `eksctl` finishes, `kubectl` already points at the new cluster. Choosing a Kubernetes version and every setting in this file are explained in the [EKS cluster runbook](#/tool/eks-cluster).

### 3. Install the AWS Load Balancer Controller

```bash
export CLUSTER=hello-eks LBC_VERSION=v3.6.2

# The controller needs an IAM role to create load balancers. The policy comes from the same release.
curl -fsSL -o lbc-iam-policy.json \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/$LBC_VERSION/docs/install/iam_policy.json
aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy-$CLUSTER \
  --policy-document file://lbc-iam-policy.json
eksctl create iamserviceaccount --cluster $CLUSTER --region $AWS_REGION \
  --namespace kube-system --name aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole-$CLUSTER \
  --attach-policy-arn arn:aws:iam::$ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy-$CLUSTER \
  --approve

helm repo add eks https://aws.github.io/eks-charts && helm repo update eks
helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system \
  --version ${LBC_VERSION#v} --set clusterName=$CLUSTER \
  --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller \
  --set region=$AWS_REGION --set vpcId=$VPC_ID

kubectl -n kube-system rollout status deploy/aws-load-balancer-controller   # successfully rolled out
```

More detail, and what to change in a cluster without internet access, in [the runbook's controller step](#/tool/eks-cluster/install-the-aws-load-balancer-controller).

### 4. Describe the app: Deployment, Service, Ingress

```bash
cat > hello-app.yaml <<EOF
apiVersion: apps/v1
kind: Deployment                   # keep 2 copies of the container running
metadata:
  name: hello-app
spec:
  replicas: 2
  selector:
    matchLabels: { app: hello-app }
  template:
    metadata:
      labels: { app: hello-app }
    spec:
      containers:
        - name: web
          image: $REPO:1.0.0
          ports:
            - containerPort: 8000
          readinessProbe:          # send users only to pods that answer /health
            httpGet: { path: /health, port: 8000 }
          livenessProbe:           # restart a pod that stops answering
            httpGet: { path: /health, port: 8000 }
          resources:
            requests: { cpu: 100m, memory: 128Mi }
            limits: { memory: 256Mi }
---
apiVersion: v1
kind: Service                      # one stable name for the pods
metadata:
  name: hello-app
spec:
  selector: { app: hello-app }
  ports:
    - port: 80
      targetPort: 8000
---
apiVersion: networking.k8s.io/v1
kind: Ingress                      # "eks.example.com goes to the hello-app Service"
metadata:
  name: hello-app
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: "443"
    alb.ingress.kubernetes.io/certificate-arn: $CERT_ARN
    alb.ingress.kubernetes.io/healthcheck-path: /health
    alb.ingress.kubernetes.io/target-group-attributes: deregistration_delay.timeout_seconds=30
spec:
  ingressClassName: alb
  rules:
    - host: eks.$DOMAIN
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: hello-app
                port:
                  number: 80
EOF

kubectl apply -f hello-app.yaml
kubectl get pods -l app=hello-app          # 2 pods, READY 1/1, STATUS Running
kubectl get ingress hello-app              # ADDRESS appears after about a minute
```

| Annotation | What it tells the controller |
|---|---|
| `scheme: internet-facing` | Put the load balancer in the **public** subnets, reachable from the internet |
| `target-type: ip` | Send traffic straight to the pods' IP addresses |
| `listen-ports` + `ssl-redirect` | Listen on 80 and 443; send HTTP visitors to HTTPS |
| `certificate-arn` | The ACM padlock from common step 2 |
| `healthcheck-path` | Check `/health` on each pod |

**No domain?** Delete the `listen-ports`, `ssl-redirect` and `certificate-arn` lines and the `- host: eks.$DOMAIN` line (start that rule with `- http:` instead), apply again, and open `http://<ADDRESS>/`.

### 5. Give it a name and open it

```bash
export EKS_ALB_DNS=$(kubectl get ingress hello-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
point_dns eks.$DOMAIN $EKS_ALB_DNS
for i in 1 2 3 4; do curl -s https://eks.$DOMAIN/; echo; done      # host changes between the 2 pods
kubectl logs -l app=hello-app --tail 20                             # the app's log
```

A new load balancer needs 2–3 minutes before it answers. Until then `curl` may fail to connect: wait and retry.

**Test self-healing:** `kubectl delete pod -l app=hello-app --wait=false`, then `kubectl get pods -w`. Kubernetes starts replacements straight away.

### 6. Ship a new version

```bash
# Skip the build if you already pushed 1.1.0 in Path 2 (tags can't be overwritten)
docker build --platform linux/amd64 --build-arg APP_VERSION=1.1.0 -t $REPO:1.1.0 . && docker push $REPO:1.1.0

kubectl set image deployment/hello-app web=$REPO:1.1.0
kubectl rollout status deployment/hello-app         # new pods come up, old ones go away
kubectl rollout undo deployment/hello-app           # roll back, if you need to
```

> **Tip:** `kubectl set image` is fine for learning. Real teams put the image tag in a **Helm values file in Git**, and **Argo CD** deploys whatever Git says. See [Helm per environment](#/tool/helm-environments) and [Argo CD: from commit to running pod](#/tool/argocd/sample-application-flow-from-commit-to-running-pod).

## Automate it: from git push to production

> **In simple words:** So far you typed the commands yourself. A **pipeline** types them for you on every change: test the code, scan it, package it, deploy it and check it works. The first half is the same for all three paths. Only the last two steps differ, and they are exactly the "Ship a new version" commands you already ran.

```flow
👩‍💻 | Push | A developer pushes code to Git and opens a merge request.
🧪 | Test | The pipeline runs `pytest`. One failed test stops everything.
🛡️ | Scan | **Gitleaks** for leaked secrets, **SonarQube** for code problems, **Trivy** for vulnerable libraries and images.
📦 | Package | EC2: a `.tgz` in S3. ECS and EKS: a Docker image in ECR, tagged with the version or the Git commit.
🚀 | Deploy | EC2: Run Command `deploy-app`. ECS: new task definition and `update-service`. EKS: new tag in Git, Argo CD syncs it.
✅ | Check | `curl https://…/health` after the deploy. If it fails, roll back automatically.
📈 | Watch | Alarms in CloudWatch or Prometheus tell you if users start seeing errors.
```

### What the deploy job runs on each path

```bash
VERSION=1.2.0        # in a pipeline: the Git tag or the short commit ID

# EC2: package, upload, install on one server at a time
tar czf hello-app-$VERSION.tgz app.py requirements.txt
aws s3 cp hello-app-$VERSION.tgz s3://$BUCKET/releases/
aws ssm send-command --document-name AWS-RunShellScript --targets Key=tag:App,Values=hello-app \
  --max-concurrency 1 --max-errors 0 --parameters "commands=[\"/usr/local/bin/deploy-app $VERSION\"]"

# ECS: image, new revision from a template kept in Git ("image": "__IMAGE__"), rolling update
docker build --platform linux/amd64 --build-arg APP_VERSION=$VERSION -t $REPO:$VERSION . && docker push $REPO:$VERSION
sed "s|__IMAGE__|$REPO:$VERSION|" taskdef.template.json > taskdef.json
aws ecs register-task-definition --cli-input-json file://taskdef.json
aws ecs update-service --cluster hello --service hello-app --task-definition hello-app
aws ecs wait services-stable --cluster hello --services hello-app

# EKS with GitOps: image, then change the tag in the deploy repo; Argo CD does the rest
docker build --platform linux/amd64 --build-arg APP_VERSION=$VERSION -t $REPO:$VERSION . && docker push $REPO:$VERSION
sed -i "s|tag: .*|tag: \"$VERSION\"|" deploy-repo/hello-app/values-prod.yaml
git -C deploy-repo commit -am "hello-app $VERSION" && git -C deploy-repo push
```

### What the pipeline is allowed to do

Give the pipeline an IAM role with **only** what its path needs, never an admin key:

| Path | Permissions the pipeline role needs |
|---|---|
| EC2 | `s3:PutObject` on the releases folder, `ssm:SendCommand` and `ssm:ListCommandInvocations` |
| ECS | Push to the ECR repository, `ecs:RegisterTaskDefinition`, `ecs:UpdateService`, `ecs:DescribeServices`, and `iam:PassRole` for `ecsTaskExecutionRole` |
| EKS | Push to the ECR repository, and write access to the deploy Git repository. It needs **no** access to the cluster: Argo CD pulls from Git |

### Build the pipeline

| Step | Guide |
|---|---|
| Pick a CI tool | [Jenkins](#/tool/jenkins) · [GitHub Actions](#/tool/github-actions) · [GitLab CI](#/tool/gitlab-ci) |
| Add the security scans | [Gitleaks](#/tool/gitleaks) · [SonarQube](#/tool/sonarqube) · [Trivy](#/tool/trivy) · [Full DevSecOps pipeline](#/tool/jenkins-devsecops) |
| Deploy to EKS with GitOps | [Argo CD](#/tool/argocd) · [Argo CD on EKS](#/tool/argocd-eks) |
| Keep passwords out of the code | [Secrets Manager: use secrets from ECS, EC2 and Kubernetes](#/tool/aws-secrets/step-8-use-secrets-from-ecs-lambda-ec2-and-kubernetes) |
| Build all of this with code instead of commands | [Terraform](#/tool/terraform), then the [capstone project](#/tool/capstone) |

## Something broken? Walk the chain

> **In simple words:** A request travels Route 53 → certificate → load balancer → target group → your app. When something fails, **walk that chain from the outside in** and check one link at a time. The error message usually tells you which link broke: no name means DNS, a browser warning means the certificate, and 502, 503 or 504 come from the load balancer talking about what is behind it.

| What you see | Broken link | How to check | Fix |
|---|---|---|---|
| `Could not resolve host` | Route 53 | `dig +short ecs.example.com` prints nothing | Run `point_dns` again. If the domain was bought elsewhere, its name servers must be the Route 53 ones |
| Browser says the certificate isn't valid | ACM | `aws acm describe-certificate --certificate-arn $CERT_ARN --query Certificate.Status` | Wait for `ISSUED`. `*.example.com` covers `ecs.example.com` but **not** `a.ecs.example.com` |
| The page never loads (timeout) | Load balancer firewall or listener | The ALB security group allows 80 and 443 from `0.0.0.0/0`; a 443 listener exists | Add the rule or the listener. The load balancer must be in the **public** subnets |
| `503 Service Temporarily Unavailable` | Target group | `aws elbv2 describe-target-health --target-group-arn …` | There are no healthy targets: read `Reason` and fix the app or its security group |
| `502 Bad Gateway` | Your app | The app's log | The app crashed or closed the connection, or it listens on a different port |
| `504 Gateway Timeout` | App firewall | The app's security group allows 8000 **from the ALB security group** | Add the rule, or find out why the app is so slow |
| Targets stay `unhealthy` | Health check | From inside: `curl localhost:8000/health` | The path must be `/health` on port 8000 and return 200 |
| EC2: never healthy | Boot script | Session Manager: `sudo tail -50 /var/log/cloud-init-output.log` | Usually `pip` couldn't download (no route to the NAT gateway) or a typo in `user-data.tpl` |
| ECS: tasks start, then stop | Task | The stopped reason (command below) | `CannotPullContainerError`: wrong image name or no NAT. `exec format error`: rebuild with `--platform linux/amd64` |
| EKS: Ingress has no ADDRESS | Load Balancer Controller | `kubectl describe ingress hello-app` and the controller's log | Subnet tags missing, the controller isn't running, or `ingressClassName` isn't `alb` |
| EKS: `ImagePullBackOff` | Image | `kubectl describe pod -l app=hello-app` | Wrong image name, or that tag was never pushed |
| EKS: pods `Pending` | Nodes | `kubectl describe pod` → Events | Not enough CPU or memory: add a node or lower the requests |

Commands for the rows above:

```bash
# Why did my ECS task stop?
aws ecs describe-tasks --cluster hello --tasks $(aws ecs list-tasks --cluster hello \
  --desired-status STOPPED --query 'taskArns[0]' --output text) \
  --query 'tasks[0].[stoppedReason,containers[0].reason]' --output text

# Why is a target unhealthy?
aws elbv2 describe-target-health --target-group-arn $ECS_TG \
  --query 'TargetHealthDescriptions[].[Target.Id,TargetHealth.State,TargetHealth.Reason]' --output table

# What is the Load Balancer Controller complaining about?
kubectl logs -n kube-system deploy/aws-load-balancer-controller --tail 50
```

> **Tip:** Deeper troubleshooting: [Kubernetes Troubleshooting](#/tool/k8s-troubleshooting), [Load balancers](#/tool/aws-elb/troubleshooting) and [CI/CD Troubleshooting](#/tool/cicd-troubleshooting).

## Clean up and cost

> **In simple words:** Delete in the **reverse order** you built: first the apps and their load balancers, then the cluster and servers, and the network last. Order matters on EKS: delete the Ingress **before** the cluster, or its load balancer is left behind, keeps costing money and blocks the VPC from being deleted.

### What costs money while it exists

Rough prices in `us-east-1`; check the AWS pricing pages for your Region.

| Part | About per hour | Used by |
|---|---|---|
| NAT gateway | $0.045 + data | All paths |
| Each load balancer | $0.0225 + traffic | One per path |
| Public IPv4 addresses | $0.005 each | The load balancers and the NAT gateway |
| EKS cluster | $0.10 | Path 3 |
| `t3.medium` worker node | $0.042 each | Path 3 (2 nodes) |
| `t3.micro` server | $0.0104 each | Path 1 (2 servers) |
| Fargate task (0.25 CPU, 0.5 GB) | $0.012 each | Path 2 (2 tasks) |

All three paths together come to about **$9 a day**. The S3 bucket, ECR images and Route 53 cost a few cents a month.

### Path 3: EKS

```bash
kubectl delete -f hello-app.yaml        # FIRST: this also deletes the load balancer the Ingress made
helm uninstall aws-load-balancer-controller -n kube-system
eksctl delete cluster -f eks.yaml --wait                            # about 10 minutes
aws iam delete-policy --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy-hello-eks
```

### Path 2: ECS

```bash
aws ecs delete-service --cluster hello --service hello-app --force
aws ecs wait services-inactive --cluster hello --services hello-app
aws ecs delete-cluster --cluster hello
ALB=$(aws elbv2 describe-load-balancers --names hello-ecs-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text)
aws elbv2 delete-load-balancer --load-balancer-arn $ALB && aws elbv2 wait load-balancers-deleted --load-balancer-arns $ALB
aws elbv2 delete-target-group --target-group-arn $(aws elbv2 describe-target-groups --names hello-ecs-tg \
  --query 'TargetGroups[0].TargetGroupArn' --output text)
aws logs delete-log-group --log-group-name /ecs/hello-app
aws ecr delete-repository --repository-name hello-app --force      # after Path 3 too: both use it
```

### Path 1: EC2

```bash
aws ec2 terminate-instances --instance-ids $(aws ec2 describe-instances \
  --filters Name=tag:App,Values=hello-app Name=instance-state-name,Values=pending,running,stopped \
  --query 'Reservations[].Instances[].InstanceId' --output text) --query 'TerminatingInstances[].InstanceId'
ALB=$(aws elbv2 describe-load-balancers --names hello-ec2-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text)
aws elbv2 delete-load-balancer --load-balancer-arn $ALB && aws elbv2 wait load-balancers-deleted --load-balancer-arns $ALB
aws elbv2 delete-target-group --target-group-arn $(aws elbv2 describe-target-groups --names hello-ec2-tg \
  --query 'TargetGroups[0].TargetGroupArn' --output text)
aws iam remove-role-from-instance-profile --instance-profile-name hello-app-ec2 --role-name hello-app-ec2
aws iam delete-instance-profile --instance-profile-name hello-app-ec2
aws iam delete-role-policy --role-name hello-app-ec2 --policy-name read-releases
aws iam detach-role-policy --role-name hello-app-ec2 --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
aws iam delete-role --role-name hello-app-ec2
aws s3 rb s3://$BUCKET --force
```

### Common parts, last

1. **Route 53 console** → your hosted zone → delete the `ec2`, `ecs` and `eks` A records. Keep the ACM validation CNAME if you keep the certificate.
2. **ACM:** certificates are free, so keeping it is fine. To delete: `aws acm delete-certificate --certificate-arn $CERT_ARN` (only after the load balancers are gone).
3. **VPC console** → **NAT gateways** → delete `hello-nat-…` and wait until it shows `Deleted`. Then **Elastic IPs** → release its address.
4. **Your VPCs** → select `hello-vpc` → **Delete VPC**. This also removes the subnets, route tables, internet gateway, S3 endpoint and the `hello-…-sg` security groups.

## Cheat sheet

> **In simple words:** The whole page on one screen: the three chains, the command that does each link, and a block that sets all your variables again in a new terminal.

### The three chains

| Link | EC2 | ECS on Fargate | EKS |
|---|---|---|---|
| Network | VPC wizard `hello` | same VPC | same VPC + subnet tags |
| Package | `tar czf` → `aws s3 cp` | `docker build` → `docker push` to ECR | `docker build` → `docker push` to ECR |
| Run it | `aws ec2 run-instances` + user data + systemd | `register-task-definition` + `create-service` | `eksctl create cluster` + `kubectl apply` |
| Keep it alive | systemd (`Restart=always`) | ECS service (`desired-count 2`) | Deployment (`replicas: 2`) |
| Front door | `create-target-group` + `create-load-balancer` + listeners | same, with `--target-type ip` | Ingress + Load Balancer Controller |
| Padlock | ACM certificate on the 443 listener | same | `certificate-arn` annotation |
| Address | `point_dns ec2.$DOMAIN …` | `point_dns ecs.$DOMAIN …` | `point_dns eks.$DOMAIN …` |
| New version | `ssm send-command deploy-app 1.1.0` | new revision + `update-service` | `kubectl set image` or Argo CD |
| Roll back | `deploy-app 1.0.0` | `--task-definition hello-app:1` | `kubectl rollout undo` |
| See the logs | `journalctl -u hello-app` | `aws logs tail /ecs/hello-app` | `kubectl logs -l app=hello-app` |

### Lost your variables? Set them all again

Paste this into a new terminal. It finds everything by the names this guide used. Anything you haven't built yet just comes back as `None`.

```bash
export AWS_REGION=us-east-1 DOMAIN=example.com     # CHANGE: same values as before
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name $DOMAIN \
  --query 'HostedZones[0].Id' --output text | cut -d/ -f3)
export VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=hello-vpc --query 'Vpcs[0].VpcId' --output text)
export PUBLIC_SUBNETS=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID \
  "Name=tag:Name,Values=hello-subnet-public*" --query 'Subnets[].SubnetId' --output text)
export PRIVATE_SUBNETS=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID \
  "Name=tag:Name,Values=hello-subnet-private*" --query 'Subnets[].SubnetId' --output text)
sg() { aws ec2 describe-security-groups --filters Name=vpc-id,Values=$VPC_ID Name=group-name,Values=$1 \
  --query 'SecurityGroups[0].GroupId' --output text; }
export ALB_SG=$(sg hello-alb-sg) EC2_SG=$(sg hello-ec2-sg) ECS_SG=$(sg hello-ecs-sg)
export CERT_ARN=$(aws acm list-certificates \
  --query "CertificateSummaryList[?DomainName=='$DOMAIN'].CertificateArn | [0]" --output text)
export BUCKET=hello-app-releases-$ACCOUNT_ID
export REPO=$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/hello-app
tg() { aws elbv2 describe-target-groups --names $1 --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null; }
export EC2_TG=$(tg hello-ec2-tg) ECS_TG=$(tg hello-ecs-tg)
lb() { aws elbv2 describe-load-balancers --names $1 --query 'LoadBalancers[0].DNSName' --output text 2>/dev/null; }
export EC2_ALB_DNS=$(lb hello-ec2-alb) ECS_ALB_DNS=$(lb hello-ecs-alb)
# then paste the point_dns function from common step 2 again
```

### Check each path is healthy

```bash
curl -s https://ec2.$DOMAIN/health; curl -s https://ecs.$DOMAIN/health; curl -s https://eks.$DOMAIN/health
aws elbv2 describe-target-health --target-group-arn $EC2_TG --query 'TargetHealthDescriptions[].TargetHealth.State'
aws ecs describe-services --cluster hello --services hello-app --query 'services[0].[runningCount,desiredCount]'
kubectl get deploy,pods,ingress -l app=hello-app
```

### Go deeper

| Link in the chain | Full guide |
|---|---|
| VPC | [AWS VPC: Step-by-Step](#/tool/aws-vpc) |
| EC2 and Systems Manager | [Website on EC2](#/tool/ec2-website) · [Systems Manager](#/tool/aws-ssm) |
| Docker and ECR | [Docker](#/tool/docker) · [Amazon ECR](#/tool/aws-ecr) |
| ECS | [Amazon ECS](#/tool/aws-ecs) |
| EKS and Kubernetes | [Kubernetes](#/tool/kubernetes) · [EKS cluster runbook](#/tool/eks-cluster) · [Helm per environment](#/tool/helm-environments) |
| Load balancer, HTTPS and DNS | [Load Balancers](#/tool/aws-elb) · [Route 53 and ACM](#/tool/aws-route53) |
| Every service in one real company | [AWS Services in a Real Deployment](#/tool/aws-real-deployment) |
