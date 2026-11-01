# AWS Lab: Host a Website on EC2

In this lab you launch a Linux server on Amazon EC2, install a web server on it automatically, and open your own web page from a public URL. Along the way you'll meet every AWS building block that makes this work (VPC, subnet, internet gateway, route table, security group, AMI, EBS, key pair, IAM role, user data), with what each one does and a link to the official AWS documentation.

> **Note:** Do the AWS guide's **Secure your account first** step (MFA and a budget alert) before this lab. You need console access, and the AWS CLI for the CLI step.

> **Cost:** If you choose an instance type marked **Free tier eligible**, an hour of practice costs a few cents at most. Outside free tier, a `t3.micro` is about $0.01/hour and a public IPv4 address $0.005/hour. **Terminate the instance at the end**: the cleanup step shows how.

## What you will build

> **In simple words:** One rented Linux computer in AWS, running a web server that anyone can reach from a browser.

```text
  Your browser
      │  http://<public-ip>
      ▼
 ┌──────────────────────── AWS Region (e.g. us-east-1) ────────────────────────┐
 │  ┌──────────────────────── VPC 172.31.0.0/16 (default) ──────────────────┐  │
 │  │                                                                       │  │
 │  │   Internet Gateway ◀── Route table: 0.0.0.0/0 → igw-xxxx              │  │
 │  │        │                                                              │  │
 │  │   ┌────▼──────── Public subnet (one Availability Zone) ─────────┐     │  │
 │  │   │  Security group: allow TCP 80 from anywhere, 22 from you    │     │  │
 │  │   │   ┌────────────────────────────────────────────┐            │     │  │
 │  │   │   │ EC2 instance (t3.micro, Amazon Linux 2023) │            │     │  │
 │  │   │   │  nginx  ← installed by user data on boot   │            │     │  │
 │  │   │   │  EBS volume 8 GiB (root disk)              │            │     │  │
 │  │   │   └────────────────────────────────────────────┘            │     │  │
 │  │   └─────────────────────────────────────────────────────────────┘     │  │
 │  └───────────────────────────────────────────────────────────────────────┘  │
 └─────────────────────────────────────────────────────────────────────────────┘
```

When you type the URL, the request follows this path:

1. Your browser sends a request to the instance's **public IPv4 address** on port **80**.
2. The request enters AWS through the VPC's **internet gateway**. The internet gateway translates the public IP to the instance's **private IP**.
3. The subnet's **network ACL** allows it. The default ACL allows everything.
4. The instance's **security group** checks its rules: port 80 from `0.0.0.0/0` is allowed.
5. **nginx** on the instance answers with your `index.html`.
6. The reply goes back the same way. Security groups are *stateful*, so return traffic is allowed automatically.

Everything you need already exists in your account's **default VPC** except the instance itself, its security group and its key pair. You'll create those.

## The building blocks, explained

> **In simple words:** Each AWS piece involved, explained one at a time. Read it once now and come back whenever a word is unfamiliar.

Read this once now, then come back to it while you work through the steps. Each block links to the official AWS page that explains it in full.

### Region and Availability Zone

A **Region** is a geographic area, such as `us-east-1` (N. Virginia) or `ap-south-1` (Mumbai). Each Region contains several **Availability Zones (AZs)**: separate data centers with their own power and networking. Your instance lives in **one AZ**. Real production apps run in two or more AZs, so one data center failing doesn't take the app down.

Pick the Region closest to you in the top-right of the console, and **stay in it**: resources in one Region don't show up in another. AWS docs: [Regions and Zones](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html)

### VPC (Virtual Private Cloud)

Your own private, isolated network inside AWS, with an IP range like `172.31.0.0/16`. Every account comes with a **default VPC** in each Region, already set up so instances can reach the internet. That's what this lab uses. AWS docs: [What is Amazon VPC?](https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html) · [Default VPCs](https://docs.aws.amazon.com/vpc/latest/userguide/default-vpc.html)

### Subnet

A slice of the VPC's IP range that lives in **one AZ**. A subnet is **public** when its route table sends internet traffic to an internet gateway, and **private** when it doesn't. The default VPC has one public subnet per AZ. AWS docs: [Subnets for your VPC](https://docs.aws.amazon.com/vpc/latest/userguide/configure-subnets.html)

### Internet gateway

The VPC's door to the internet. It translates between the instance's private IP and its public IP. Without it, nothing in the VPC can be reached from outside. AWS docs: [Internet gateways](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Internet_Gateway.html)

### Route table

The "signposts" for a subnet. The route `0.0.0.0/0 → igw-xxxx` means "anything not inside the VPC goes to the internet gateway". AWS docs: [Configure route tables](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Route_Tables.html)

### Security group

A **virtual firewall attached to the instance**. It only has *allow* rules, and it is **stateful**: if a request is allowed in, the reply is allowed out automatically. By default, all inbound traffic is denied and all outbound traffic is allowed. AWS docs: [Security groups](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-security-groups.html) · [Rules for common use cases](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/security-group-rules-reference.html)

| | Security group | Network ACL |
|---|---|---|
| Applies to | An instance (its network interface) | A whole subnet |
| Rules | Allow only | Allow and deny |
| State | Stateful | Stateless: return traffic needs its own rule |
| You'll change it in this lab? | **Yes** | No. The default allows all traffic |

AWS docs: [Network ACLs](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html)

### AMI (Amazon Machine Image)

The template the instance's disk is copied from: operating system plus any pre-installed software. You'll use **Amazon Linux 2023**, AWS's own Linux, which uses `dnf` (like Fedora/RHEL) and has the default user `ec2-user`. AWS docs: [AMIs](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html) · [What is Amazon Linux 2023?](https://docs.aws.amazon.com/linux/al2023/ug/what-is-amazon-linux.html)

### Instance type

The size of the virtual machine: CPU, memory and network. `t3.micro` has 2 vCPUs and 1 GiB of memory, plenty for a web page. The `t` family is *burstable*: cheap, and it can burst above its baseline CPU for short periods. AWS docs: [Instance types](https://docs.aws.amazon.com/ec2/latest/instancetypes/instance-types.html)

### EBS volume

The instance's disk, a network-attached block storage volume. It survives a **stop/start**. By default it's **deleted when the instance is terminated**. AWS docs: [What is Amazon EBS?](https://docs.aws.amazon.com/ebs/latest/userguide/what-is-ebs.html)

### Key pair

An SSH key pair. AWS keeps the **public** key and puts it on the instance. You download the **private** key (`.pem`) **once**, and AWS can't give it to you again. AWS docs: [Key pairs](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html)

### Public IP and Elastic IP

An **auto-assigned public IP** comes from AWS's pool and **changes every time the instance stops and starts**. An **Elastic IP** is a fixed public address you allocate and attach, and it stays the same until you release it. Both are charged per hour. AWS docs: [IP addressing](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-ip-addressing.html) · [Elastic IP addresses](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/elastic-ip-addresses-eip.html)

### User data

A script you hand to the instance at launch. It runs **once, as root, on first boot**. That's how the web server gets installed without you logging in. Its output is logged to `/var/log/cloud-init-output.log`. AWS docs: [User data](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html)

### IAM role (instance profile)

Gives the instance AWS permissions **without storing any keys on it**. In this lab, a role with `AmazonSSMManagedInstanceCore` lets you open a shell through **Session Manager**, with no SSH port and no `.pem` file. AWS docs: [IAM roles for EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html) · [What is IAM?](https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction.html)

### Instance metadata (IMDS)

A special address, `169.254.169.254`, that only the instance itself can reach. It returns facts about the instance: its ID, AZ, IPs and role credentials. Your user data script uses it to show the instance details on the page. AWS docs: [Access instance metadata](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instancedata-data-retrieval.html)

## Before you start

> **In simple words:** Sign in, pick one Region and stay in it, and know what this costs (very little if you clean up).

1. **Sign in** to the AWS console as your admin or SSO user, not root.
2. **Choose a Region** in the top-right corner and use the same one for the whole lab.
3. **Check your budget alert** exists: **Billing and Cost Management → Budgets**. AWS docs: [Managing costs with AWS Budgets](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html)
4. Know what you'll pay:

| Item | Price (approximate, us-east-1) | Where to check |
|---|---|---|
| `t3.micro` instance | ~$0.0104/hour, or free if your account's free tier covers it | [EC2 On-Demand pricing](https://aws.amazon.com/ec2/pricing/on-demand/) · [AWS Free Tier](https://aws.amazon.com/free/) |
| Public IPv4 address | $0.005/hour while the instance has it | [VPC pricing → Public IPv4](https://aws.amazon.com/vpc/pricing/) |
| 8 GiB gp3 EBS volume | ~$0.64/month, billed per second | [EBS pricing](https://aws.amazon.com/ebs/pricing/) |

> **Tip:** In the launch wizard, AWS marks AMIs and instance types that your account can use under the free tier with a **Free tier eligible** label. Prefer those.

## Look at your network (default VPC)

> **In simple words:** Look at the network AWS already made for you, and see why a server placed in it can be reached from the internet.

Before launching anything, look at what already exists. This is the part most beginners skip, and the part interviews ask about.

**Console:**
1. Open the **VPC** console → **Your VPCs**. You should see one VPC with **Default VPC = Yes** and CIDR `172.31.0.0/16`.
2. **Subnets**: one per AZ, each with a `/20` CIDR. Look at **Auto-assign public IPv4 address = Yes**. That's why instances launched here get a public IP.
3. **Internet gateways**: one, **Attached** to the default VPC.
4. **Route tables**: open the default VPC's main route table → **Routes** tab. You'll see:

| Destination | Target | Meaning |
|---|---|---|
| `172.31.0.0/16` | `local` | Traffic inside the VPC stays inside |
| `0.0.0.0/0` | `igw-…` | Everything else goes to the internet gateway, which makes the subnets **public** |

**CLI (same information):**

```bash
VPC_ID=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)
echo "Default VPC: $VPC_ID"
aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID \
  --query 'Subnets[].[SubnetId,AvailabilityZone,CidrBlock,MapPublicIpOnLaunch]' --output table
aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=$VPC_ID \
  --query 'InternetGateways[].InternetGatewayId' --output text
aws ec2 describe-route-tables --filters Name=vpc-id,Values=$VPC_ID \
  --query 'RouteTables[].Routes[].[DestinationCidrBlock,GatewayId]' --output table
```

> **Warning:** If you have **no default VPC** (some company accounts delete it), ask your platform team which VPC and **public subnet** to use. Or create a default VPC: VPC console → **Actions → Create default VPC**.

## Create an IAM role for Session Manager

> **In simple words:** Give the server a "badge" that lets you open a terminal on it from the AWS website, with no passwords or keys.

This role lets you open a terminal on the instance from the browser with no SSH keys and no open port 22. It's how most companies connect to servers.

1. Open **IAM → Roles → Create role**.
2. **Trusted entity type:** AWS service. **Use case:** EC2. Click **Next**.
3. Search for and tick **`AmazonSSMManagedInstanceCore`**, then click **Next**.
4. **Role name:** `ec2-ssm-lab-role`, then **Create role**.

What you just did: the role's **trust policy** says "EC2 instances may assume this role", and its **permissions policy** lets the Systems Manager agent on the instance talk to AWS. When you attach the role to an instance, it gets temporary credentials through instance metadata and never stores a key on disk.

AWS docs: [IAM roles for EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html) · [Session Manager instance permissions](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-getting-started-instance-profile.html)

## Launch the instance (console)

> **In simple words:** Fill in the launch form field by field: which operating system, how big, which network, which firewall rules, and a script that installs the website.

Open **EC2 → Instances → Launch instances** and go through the form from top to bottom.

### 1. Name and tags

**Name:** `web-lab-1`. This creates a tag `Name=web-lab-1`. Tags label resources for searching, billing and cleanup.

### 2. Application and OS Images (AMI)

Choose **Amazon Linux** → **Amazon Linux 2023 AMI** (64-bit x86). Note the AMI ID, `ami-…`: it's different in every Region.

### 3. Instance type

**`t3.micro`**, or whichever micro type shows **Free tier eligible** for your account.

### 4. Key pair (login)

Click **Create new key pair**: name `web-lab-key`, type **ED25519**, format **.pem**. The browser downloads `web-lab-key.pem`. **Keep it safe; you can't download it again.** On Linux/WSL/macOS, move it and lock it down:

```bash
mv ~/Downloads/web-lab-key.pem ~/.ssh/ 2>/dev/null || mv /mnt/c/Users/$USER/Downloads/web-lab-key.pem ~/.ssh/
chmod 400 ~/.ssh/web-lab-key.pem
```

### 5. Network settings

Click **Edit**:
- **VPC:** the default VPC. **Subnet:** *No preference*, or pick one. **Auto-assign public IP:** **Enable**.
- **Firewall (security groups):** **Create security group**, named `web-lab-sg`, description `HTTP and SSH for web lab`.
- Rules:

| Type | Port | Source | Why |
|---|---|---|---|
| SSH | 22 | **My IP** | Only your current IP can try to log in |
| HTTP | 80 | **Anywhere (0.0.0.0/0)** | Anyone can load the web page |

> **Warning:** Never open SSH (22) to `0.0.0.0/0`. Bots scan the whole internet for open SSH ports within minutes.

### 6. Configure storage

Leave the default, **8 GiB gp3**. This is the EBS root volume.

### 7. Advanced details

- **IAM instance profile:** `ec2-ssm-lab-role` (from the previous step).
- **Metadata version:** **V2 only (token required)**. This is the secure default.
- **User data:** paste this script. It runs once, as root, the first time the instance boots:

```bash
#!/bin/bash
# Install and start nginx
dnf install -y nginx
systemctl enable --now nginx

# Ask the instance metadata service (IMDSv2) about this instance
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
md() { curl -sH "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/$1"; }
INSTANCE_ID=$(md instance-id)
AZ=$(md placement/availability-zone)
TYPE=$(md instance-type)
PRIVATE_IP=$(md local-ipv4)

# Write the web page
cat > /usr/share/nginx/html/index.html <<EOF
<!doctype html>
<html><head><meta charset="utf-8"><title>Hello from EC2</title>
<style>body{font-family:system-ui,sans-serif;max-width:640px;margin:60px auto;padding:0 16px}
td{padding:6px 14px;border-bottom:1px solid #ddd}</style></head>
<body>
  <h1>It works! 🎉</h1>
  <p>This page is served by <b>nginx</b> on an <b>Amazon EC2</b> instance.</p>
  <table>
    <tr><td>Instance ID</td><td>$INSTANCE_ID</td></tr>
    <tr><td>Instance type</td><td>$TYPE</td></tr>
    <tr><td>Availability Zone</td><td>$AZ</td></tr>
    <tr><td>Private IP</td><td>$PRIVATE_IP</td></tr>
    <tr><td>Built at</td><td>$(date -u)</td></tr>
  </table>
</body></html>
EOF
```

### 8. Launch

Check the **Summary** panel on the right, then click **Launch instance** → **View all instances**.

Watch **Instance state** go `pending` → `running`. **Status checks** go from `Initializing` to **`3/3 checks passed`** in about 1–2 minutes.

AWS docs: [Get started with Amazon EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EC2_GetStarted.html) · [Instance state changes](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-lifecycle.html)

## Open your website

> **In simple words:** Copy the server's public address into your browser, and your page appears.

1. Select the instance. In the **Details** tab, copy the **Public IPv4 address** (or **Public IPv4 DNS**, which looks like `ec2-3-91-…compute-1.amazonaws.com`).
2. In your browser, go to **`http://<public-ip>`**.

You should see **"It works! 🎉"** with your instance ID, type and AZ.

From a terminal:

```bash
curl -i http://<public-ip>
# HTTP/1.1 200 OK
# Server: nginx/...
```

> **Warning:** Type **`http://`**, not `https://`. Your server has no TLS certificate and isn't listening on port 443. Many browsers try HTTPS first and then show *"This site can't be reached"*. HTTPS comes later, with a load balancer and a certificate (see **Next steps**).

If the page doesn't load, wait one more minute (user data is still installing nginx), then work through **Troubleshooting** below.

## Connect to the instance and look around

> **In simple words:** Open a terminal on the server and use your Linux skills to see how the website is running.

Pick **one** of these three ways in.

| Method | Needs | Use when |
|---|---|---|
| **Session Manager** (recommended) | The IAM role from earlier. No open port, no key | Day-to-day work in companies |
| **SSH** from your terminal | `.pem` key + port 22 open to your IP | Classic way; works everywhere |
| **EC2 Instance Connect** (browser) | Port 22 open to AWS's Instance Connect IP range for the Region | Quick checks; often blocked if SSH is limited to *My IP* |

**Session Manager:** select the instance → **Connect** → **Session Manager** tab → **Connect**. You get a shell as `ssm-user`. Run `sudo su - ec2-user` to switch to the normal user. AWS docs: [Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)

**SSH:**

```bash
ssh -i ~/.ssh/web-lab-key.pem ec2-user@<public-ip>
```

AWS docs: [Connect with EC2 Instance Connect](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-connect-methods.html)

### Explore. This is where the Linux guide pays off.

```bash
# Is the web server running and listening?
sudo systemctl status nginx
sudo ss -tulpn | grep :80

# Fetch the page from inside the server
curl -s localhost | head -5

# What did the user data script do? (very useful when something fails)
sudo tail -n 30 /var/log/cloud-init-output.log
sudo cat /var/lib/cloud/instance/user-data.txt

# nginx logs: watch requests arrive while you refresh the browser
sudo tail -f /var/log/nginx/access.log

# Facts about this machine from instance metadata (IMDSv2)
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
curl -sH "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4; echo
curl -sH "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/iam/security-credentials/; echo

# The disk (EBS volume) and the OS
lsblk
df -h /
cat /etc/os-release
```

Notice that `ip a` shows only the **private** IP (`172.31.x.x`). The instance itself never sees its public IP. The internet gateway translates between the two.

## Change the web page

> **In simple words:** Edit the page on the server and watch the change appear in your browser straight away.

Replace the page with your own content:

```bash
sudo tee /usr/share/nginx/html/index.html >/dev/null <<'EOF'
<!doctype html>
<html><head><meta charset="utf-8"><title>My DevOps page</title></head>
<body style="font-family:system-ui;max-width:640px;margin:60px auto">
  <h1>Hi, I'm learning DevOps 👋</h1>
  <p>Served from EC2 + nginx. Next up: Docker, Terraform and Kubernetes.</p>
</body></html>
EOF
curl -s localhost | head -3
```

Refresh the browser and the change shows straight away. nginx serves files from `/usr/share/nginx/html` and doesn't need a restart for content changes.

Try one more: add a second page and open `http://<public-ip>/about.html`.

```bash
echo '<h1>About</h1><p>Built in the EC2 lab.</p>' | sudo tee /usr/share/nginx/html/about.html
```

> **Why:** Editing files by hand on a server is fine for learning, but it doesn't scale. If the instance is replaced, your edits are gone. In real teams, the page is built into an image or deployed by automation. That's exactly what the Docker, Terraform and Argo CD guides teach.

## Do the same with the AWS CLI

> **In simple words:** The same steps as typed commands. Useful for automation, and it shows what the console does behind the scenes.

The console clicks you just made map one-to-one to API calls. Here is the whole lab as a script. Save the user data from the launch step as `user-data.sh`, then:

```bash
export AWS_REGION=us-east-1        # use your Region

# 1. Network: default VPC and one of its subnets
VPC_ID=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)
SUBNET_ID=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID Name=default-for-az,Values=true \
  --query 'Subnets[0].SubnetId' --output text)

# 2. Security group: HTTP from anywhere, SSH from my IP only
MYIP=$(curl -s https://checkip.amazonaws.com)
SG_ID=$(aws ec2 create-security-group --group-name web-lab-cli-sg --description "web lab (cli)" \
  --vpc-id $VPC_ID --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr $MYIP/32

# 3. Key pair
aws ec2 create-key-pair --key-name web-lab-cli-key --key-type ed25519 \
  --query KeyMaterial --output text > ~/.ssh/web-lab-cli-key.pem
chmod 400 ~/.ssh/web-lab-cli-key.pem

# 4. Latest Amazon Linux 2023 AMI for this Region (public SSM parameter)
AMI_ID=$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query Parameter.Value --output text)

# 5. Launch (role from the IAM step; IMDSv2 required)
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID --instance-type t3.micro \
  --subnet-id $SUBNET_ID --security-group-ids $SG_ID --associate-public-ip-address \
  --key-name web-lab-cli-key \
  --iam-instance-profile Name=ec2-ssm-lab-role \
  --metadata-options HttpTokens=required \
  --user-data file://user-data.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=web-lab-cli}]' \
  --query 'Instances[0].InstanceId' --output text)
echo "Launched $INSTANCE_ID"

# 6. Wait, then print the URL
aws ec2 wait instance-status-ok --instance-ids $INSTANCE_ID
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo "Open: http://$PUBLIC_IP"
curl -s http://$PUBLIC_IP | grep -o '<h1>.*</h1>'
```

> **Note:** The console's *Create role* flow also creates an **instance profile** with the same name, and that's what `--iam-instance-profile` refers to. If you created the role from the CLI, you must create the instance profile yourself.

AWS docs: [`run-instances` CLI reference](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/ec2/run-instances.html)

## Stop, start, reboot, terminate

> **In simple words:** What happens to your server, its address, its disk and your bill when you switch it off, on, or delete it.

Try each one and refresh your page afterwards. Knowing the differences avoids nasty surprises.

| Action | What happens | Public IP | EBS data | Billing |
|---|---|---|---|---|
| **Reboot** | OS restarts on the same host | Same | Kept | Continues |
| **Stop** | Instance shuts down; disk kept | **Released**: you get a new one on start | Kept | No instance charge; EBS still charged |
| **Start** (after stop) | Boots, possibly on new hardware. User data does **not** run again | **New** address | Kept | Resumes |
| **Terminate** | Instance deleted permanently | Released | Root volume **deleted** (default) | Stops |

After a stop/start, your old URL stops working because the public IP changed. That's the problem an **Elastic IP** (fixed address) or, better, a **load balancer + DNS name** solves.

AWS docs: [Stop and start](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/Stop_Start.html) · [Terminate](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/terminating-instances.html) · [Instance state changes](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-lifecycle.html)

## Troubleshooting

> **In simple words:** If the page won't load or you can't connect, find your symptom in this table.

Work from the outside in, the same way you'd debug in production:

| Symptom | Likely cause | Check / fix |
|---|---|---|
| Browser spins, then *"took too long to respond"* | Security group doesn't allow port 80 | Instance → **Security** tab → inbound rules need **HTTP 80 from 0.0.0.0/0** |
| *"This site can't be reached"* immediately | You used `https://`, or nginx isn't running | Use `http://`. Connect and run `sudo systemctl status nginx` |
| No **Public IPv4 address** shown | Auto-assign public IP was disabled, or the subnet is private | Launch again with **Auto-assign public IP: Enable** in a **public** subnet (route to an IGW) |
| Page shows the nginx default "Welcome" | User data failed after installing nginx | `sudo cat /var/log/cloud-init-output.log`. Look for the error |
| Nothing installed at all | User data didn't start with `#!/bin/bash`, or `dnf` couldn't reach the internet | Check the log above. Confirm the route table has `0.0.0.0/0 → igw` |
| SSH: `Connection timed out` | Port 22 not open to your **current** IP (it changes on new networks) | Edit the SG rule → **My IP** again |
| SSH: `Permission denied (publickey)` | Wrong user or key | User is `ec2-user` on Amazon Linux (`ubuntu` on Ubuntu). Use the matching `.pem` |
| SSH: `UNPROTECTED PRIVATE KEY FILE` | Key file permissions too open | `chmod 400 ~/.ssh/web-lab-key.pem` |
| Session Manager: *"not connected"* | Role missing, or the agent hasn't registered yet | Attach `ec2-ssm-lab-role` (**Actions → Security → Modify IAM role**), then wait 1–2 min |
| Status check `1/3` or `2/3 failed` | OS or host problem | **Actions → Monitor → Get system log**. Stop/start moves it to new hardware |

AWS docs: [Troubleshoot connecting to your instance](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/TroubleshootingInstancesConnecting.html)

## Clean up

> **In simple words:** Delete what you created so it stops costing money.

Delete everything you created so nothing keeps charging.

**Console:**
1. **EC2 → Instances** → select `web-lab-1` (and `web-lab-cli`) → **Instance state → Terminate instance**. Wait for **Terminated**.
2. **EC2 → Security Groups** → delete `web-lab-sg` and `web-lab-cli-sg`. This only works once the instances are gone.
3. **EC2 → Key Pairs** → delete `web-lab-key` and `web-lab-cli-key`, and delete the `.pem` files on your computer.
4. If you allocated an **Elastic IP**: **EC2 → Elastic IPs → Release**. An unused Elastic IP is still charged.
5. Optional: **IAM → Roles** → delete `ec2-ssm-lab-role`. It's free, so you can also keep it for future labs.

**CLI:**

```bash
aws ec2 terminate-instances --instance-ids $INSTANCE_ID
aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID
aws ec2 delete-security-group --group-id $SG_ID
aws ec2 delete-key-pair --key-name web-lab-cli-key && rm -f ~/.ssh/web-lab-cli-key.pem

# Double-check nothing is left running in this Region
aws ec2 describe-instances --filters Name=instance-state-name,Values=pending,running,stopped \
  --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`]|[0].Value,State.Name]' --output table
aws ec2 describe-addresses --query 'Addresses[].PublicIp'
```

## How to use the AWS documentation

> **In simple words:** Which kind of AWS page to open for which question, so the official docs become useful instead of overwhelming.

AWS docs are huge. Knowing *which* page type to open saves hours.

| Doc type | What it answers | Example |
|---|---|---|
| **User Guide** | *What is it and how do I use it?* Concepts plus console steps | [What is Amazon EC2?](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/concepts.html) |
| **CLI reference** | Every command, flag and output field | [`aws ec2 run-instances`](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/ec2/run-instances.html) |
| **API reference** | The raw API, the same names Terraform and SDKs use | Search "RunInstances API reference" |
| **Pricing page** | What it costs, per Region | [EC2 On-Demand pricing](https://aws.amazon.com/ec2/pricing/on-demand/) |
| **Quotas** | Limits, such as vCPUs per Region or SGs per instance | **Service Quotas** console |
| **Troubleshooting** | Known errors and fixes | [Troubleshoot connecting](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/TroubleshootingInstancesConnecting.html) |

Tips:
- **Start from "What is …?"** for any new service, then read **Getting started**. Skip the rest until you need it.
- **Read the left-hand menu** of a User Guide. It's the best map of what a service can do.
- Every CLI command has built-in help: `aws ec2 run-instances help` (press `q` to quit).
- Learn the **shared responsibility model**: AWS secures the hardware and the hypervisor; *you* secure the OS, the security groups, the data and IAM. [Shared responsibility model](https://aws.amazon.com/compliance/shared-responsibility-model/)

### All docs used in this lab

| Topic | AWS documentation |
|---|---|
| EC2 overview | [What is Amazon EC2?](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/concepts.html) · [Get started](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EC2_GetStarted.html) |
| Regions and AZs | [Regions and Zones](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html) |
| Networking | [VPC](https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html) · [Default VPC](https://docs.aws.amazon.com/vpc/latest/userguide/default-vpc.html) · [Subnets](https://docs.aws.amazon.com/vpc/latest/userguide/configure-subnets.html) · [Internet gateway](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Internet_Gateway.html) · [Route tables](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Route_Tables.html) · [IP addressing](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-ip-addressing.html) |
| Firewalls | [Security groups](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-security-groups.html) · [Network ACLs](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html) |
| Server | [AMIs](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html) · [Amazon Linux 2023](https://docs.aws.amazon.com/linux/al2023/ug/what-is-amazon-linux.html) · [Instance types](https://docs.aws.amazon.com/ec2/latest/instancetypes/instance-types.html) · [EBS](https://docs.aws.amazon.com/ebs/latest/userguide/what-is-ebs.html) |
| Access | [Key pairs](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html) · [Instance Connect](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-connect-methods.html) · [Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html) · [IAM roles for EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html) |
| Automation | [User data](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html) · [Instance metadata](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instancedata-data-retrieval.html) |
| Addresses | [Elastic IP addresses](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/elastic-ip-addresses-eip.html) |
| Cost | [EC2 pricing](https://aws.amazon.com/ec2/pricing/on-demand/) · [VPC pricing (public IPv4)](https://aws.amazon.com/vpc/pricing/) · [Budgets](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html) |

## Next steps and challenge

> **In simple words:** How real websites grow beyond one server, and a small challenge to test what you learned.

You've hosted a site the "single server" way. Here's how real setups grow from it. Each one is a good follow-up lab:

| Problem with one EC2 instance | Solution | AWS docs |
|---|---|---|
| IP changes on stop/start | Elastic IP, or a DNS name in **Route 53** | [Route 53](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/Welcome.html) |
| No HTTPS | **Application Load Balancer** + a free **ACM** certificate | [What is an ALB?](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html) |
| One server = one point of failure | 2+ instances across AZs behind the ALB, in an **Auto Scaling group** | [ALB](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html) |
| Nobody notices when it's down | **CloudWatch** alarms on status checks and CPU | [CloudWatch](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/WhatIsCloudWatch.html) |
| Click-ops isn't repeatable | Build it all with **Terraform** | See the Terraform guide |

**Challenge** (no peeking):
1. Launch a second instance with a **different message** in its user data, in a **different AZ**.
2. Remove the SSH rule from the security group entirely and connect only with **Session Manager**.
3. Stop and start one instance. Explain why its URL changed and the page content didn't.
4. Write down, from memory, the six hops a request takes from your browser to nginx.
5. Clean up and confirm with the CLI that nothing is left running.
