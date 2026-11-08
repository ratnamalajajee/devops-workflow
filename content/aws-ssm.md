# AWS Systems Manager: Manage Servers Without SSH

Log in to servers with **no SSH keys and no open port 22**, run one command on fifty servers at once, keep an agent installed on every new server automatically, and keep settings in one safe place. This guide covers the **Systems Manager** tools you will use every week: **Session Manager**, **Run Command**, **custom documents**, **State Manager**, **Automation runbooks**, **Parameter Store** and **Patch Manager**, with **console clicks** and the matching **AWS CLI** commands.

> **Cost:** On EC2 instances, **Session Manager, Run Command, State Manager, Patch Manager, Fleet Manager and Inventory have no extra charge**. **Standard** parameters are free; **advanced** parameters cost $0.05 per parameter per month plus $0.05 per 10,000 API interactions. **Automation** costs $0.002 per step (plus $0.00003 per second for `aws:executeScript` steps). You still pay for the EC2 instances (a `t3.micro` is about $0.0104 per hour in us-east-1), S3, CloudWatch Logs and any VPC endpoints. On hybrid and multicloud (non-AWS) servers, sessions ($0.05 each) and Run Command ($0.002 per invocation) are billed. See [Systems Manager pricing](https://aws.amazon.com/systems-manager/pricing/).

## Start here: Systems Manager in simple words

> **In simple words:** **AWS Systems Manager** (often called **SSM**) is a **toolbox for looking after servers** without logging in to them one by one. A small program on each server, the **SSM Agent**, keeps a connection open **out** to AWS. Through it you can open a shell, run scripts, install software, apply patches and check settings on one server or thousands.

### The building caretaker comparison

| Apartment building | Systems Manager |
|---|---|
| An intercom in every flat, wired to the caretaker's office | **SSM Agent** on every server |
| The caretaker's ID badge | The server's **IAM role** (instance profile) |
| Talking through the intercom instead of copying spare keys | **Session Manager**: a shell with no SSH keys |
| A message to "every flat on floor 3" | **Run Command** sent to every server with a tag |
| A written instruction card | An **SSM document** |
| House rules checked every week, and fixed if broken | A **State Manager association** |
| The emergency checklist for a burst pipe | An **Automation runbook** |
| The notice board with the Wi-Fi name | **Parameter Store** |

### How it works

```text
 You (console, CLI) ──HTTPS──▶ AWS Systems Manager
                                       ▲
                    outbound 443 only  │  (the agent calls AWS)
                                       │
               EC2 instance: SSM Agent + IAM role,
               no inbound ports open
```

### The main tools

| Tool | What it does | Step |
|---|---|---|
| **Fleet Manager** | Lists every managed node with its status, OS and agent version | 2, 9 |
| **Session Manager** | A shell or a port tunnel in the browser or CLI, with no SSH | 3 |
| **Run Command** | Runs a script on many servers at once, chosen by tag | 4 |
| **Documents** | Reusable instructions (Command, Automation, Session) in JSON or YAML | 5 |
| **State Manager** | Keeps a configuration applied on a schedule, and on new servers | 6 |
| **Automation** | Multi-step runbooks: stop, start, patch, create images, call AWS APIs | 7 |
| **Parameter Store** | A key-value store for settings and encrypted values | 8 |
| **Patch Manager**, **Inventory** | OS updates; a list of installed software per node | 9 |

### Key words

| Word | Meaning |
|---|---|
| **Managed node** | A server (EC2, on-premises or other cloud) that Systems Manager can talk to |
| **Instance profile** | The box that attaches an IAM role to an EC2 instance |
| **Document** | A JSON or YAML file that says what to do. AWS provides hundreds (names start with `AWS-`) |
| **Target** | Which servers to act on: instance IDs, a **tag**, or a resource group |
| **Rate control** | How many servers at a time (**concurrency**) and how many failures before stopping (**error threshold**) |
| **Association** | "Apply this document to these targets on this schedule", kept by State Manager |
| **Runbook** | An Automation document: steps that run in AWS, not inside one server |

### Check yourself

1. Which inbound port must you open for Session Manager?
2. What three things does an EC2 instance need to become a managed node?
3. What is the difference between Run Command and State Manager?

> **Tip:** Answers: 1) **None.** The agent makes outbound HTTPS (443) connections to AWS. 2) The **SSM Agent** running, **permissions** (an instance profile with `AmazonSSMManagedInstanceCore`, or Default Host Management Configuration), and a **network path** to the Systems Manager endpoints. 3) Run Command runs **once, now**. State Manager **keeps** a configuration applied on a schedule, and applies it to new matching servers by itself.

## Before you start: variables, bucket and log groups

> **In simple words:** Set a few shell variables once, and create an S3 bucket and two CloudWatch log groups. Later steps save command output and session logs there.

You need the AWS CLI v2 signed in as an admin user (see [Create Your AWS Account](#/tool/aws-account) and [Workstation setup](#/tool/setup)).

```bash
export AWS_REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET=ssm-lab-output-$ACCOUNT_ID       # command and association output
ROLE=ssm-lab-ec2-role                   # role for the test servers

aws s3 mb s3://$BUCKET
for LG in /ssm/run-command /ssm/sessions; do
  aws logs create-log-group --log-group-name $LG
  aws logs put-retention-policy --log-group-name $LG --retention-in-days 7
done
```

## Step 1: Make a server manageable: agent, role and network

> **In simple words:** A server becomes a **managed node** when three things are true: the **agent** is running, the server has **permission** to talk to Systems Manager, and it has a **network path** to the Systems Manager endpoints. Most problems come from one of these three.

| Need | How to get it |
|---|---|
| **SSM Agent** | Preinstalled on Amazon Linux 2023, Amazon Linux 2, Ubuntu Server LTS, Windows Server and some other AWS AMIs. Install it yourself on RHEL, CentOS and similar |
| **Permissions** | An **instance profile** with the managed policy `AmazonSSMManagedInstanceCore`, or **Default Host Management Configuration** (Step 2) |
| **Network** | Outbound HTTPS (443) to the `ssm`, `ssmmessages` and `ec2messages` endpoints: through an internet gateway, a NAT gateway, or **interface VPC endpoints** |

**Console:** **IAM → Roles → Create role** → Trusted entity **AWS service**, Use case **EC2** → tick **AmazonSSMManagedInstanceCore** and **CloudWatchAgentServerPolicy** → Role name `ssm-lab-ec2-role` → **Create role**. The console also creates an instance profile with the same name.

**CLI:**

```bash
aws iam create-role --role-name $ROLE --assume-role-policy-document \
  '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
aws iam attach-role-policy --role-name $ROLE --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
aws iam attach-role-policy --role-name $ROLE --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy

# let the servers write command output into the lab bucket only
aws iam put-role-policy --role-name $ROLE --policy-name ssm-output-to-s3 --policy-document \
  "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"s3:PutObject\",\"s3:GetEncryptionConfiguration\"],\"Resource\":[\"arn:aws:s3:::$BUCKET\",\"arn:aws:s3:::$BUCKET/*\"]}]}"

aws iam create-instance-profile --instance-profile-name $ROLE
aws iam add-role-to-instance-profile --instance-profile-name $ROLE --role-name $ROLE
sleep 15   # give IAM a moment
```

`CloudWatchAgentServerPolicy` lets the server write **command output and session logs** to CloudWatch Logs (and run the CloudWatch agent).

### Servers in private subnets: VPC endpoints

With **no internet path** (no NAT gateway), create **interface VPC endpoints** for `com.amazonaws.us-east-1.ssm`, `...ssmmessages` and `...ec2messages` in the server's subnets, with **private DNS** turned on and a security group that allows inbound TCP 443 from the VPC. Add `logs`, `kms` and an S3 gateway endpoint if you send output there or use KMS. Interface endpoints are billed per hour in each Availability Zone. How to create them: [VPC endpoints and PrivateLink guide](#/tool/aws-privatelink) and [VPC guide](#/tool/aws-vpc).

AWS docs: [Instance permissions](https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-instance-permissions.html) · [AMIs with SSM Agent preinstalled](https://docs.aws.amazon.com/systems-manager/latest/userguide/ami-preinstalled-agent.html) · [VPC endpoints for Systems Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-create-vpc.html)

## Step 2: Launch two test servers and check they are managed

> **In simple words:** Start two small Amazon Linux servers with the role from Step 1, **no SSH key** and a security group with **no inbound rules at all**. Within a few minutes they appear in **Fleet Manager** as **Online**.

**Console:** **EC2 → Launch instances** → Name `ssm-lab`, **Amazon Linux 2023**, `t3.micro`, Key pair **Proceed without a key pair**, a new security group with **no inbound rules** → **Advanced details**: IAM instance profile `ssm-lab-ec2-role`, **Metadata version: V2 only (token required)** → 2 instances → **Launch**. Add the tags `Environment=dev` and `Monitoring=node-exporter`. Then open **Systems Manager → Fleet Manager**.

**CLI:**

```bash
AMI_ID=$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query Parameter.Value --output text)
VPC_ID=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)
SG_ID=$(aws ec2 create-security-group --group-name ssm-lab-sg \
  --description "SSM lab: no inbound rules" --vpc-id $VPC_ID --query GroupId --output text)

INSTANCE_IDS=$(aws ec2 run-instances --image-id $AMI_ID --instance-type t3.micro --count 2 \
  --security-group-ids $SG_ID --iam-instance-profile Name=$ROLE \
  --metadata-options HttpTokens=required,HttpEndpoint=enabled \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=ssm-lab},{Key=Environment,Value=dev},{Key=Monitoring,Value=node-exporter}]' \
  --query 'Instances[].InstanceId' --output text)
read -r INSTANCE_1 INSTANCE_2 <<< "$INSTANCE_IDS"
aws ec2 wait instance-status-ok --instance-ids $INSTANCE_1 $INSTANCE_2

aws ssm describe-instance-information --filters "Key=InstanceIds,Values=$INSTANCE_1,$INSTANCE_2" \
  --query 'InstanceInformationList[].[InstanceId,PingStatus,PlatformName,AgentVersion]' --output table
```

Both should show `Online`. The default VPC gives them a public IP, so the agent reaches AWS through the internet gateway, but nothing can connect **in**.

### Option: Default Host Management Configuration

**Default Host Management Configuration (DHMC)** makes **every EC2 instance in a Region** managed without attaching an instance profile to each one. It uses the role `AWSSystemsManagerDefaultEC2InstanceManagementRole` with the managed policy `AmazonSSMManagedEC2InstanceDefaultPolicy`.

- The instance must use **IMDSv2** and SSM Agent **3.2.582.0 or later**. Turn it on **in each Region**; it can take up to 30 minutes to apply.
- The agent tries the instance profile first: if that role allows `ssm:UpdateInstanceInformation`, DHMC isn't used. DHMC only makes the instance **managed**; access to S3, logs or other services still needs an instance role.

**Console:** **Systems Manager → Fleet Manager → Account management → Configure Default Host Management Configuration** → turn on **Enable Default Host Management Configuration** → keep the default role → **Configure**.

**CLI:** check whether it is already on (some newer accounts have it turned on for you):

```bash
aws ssm get-service-setting \
  --setting-id arn:aws:ssm:$AWS_REGION:$ACCOUNT_ID:servicesetting/ssm/managed-instance/default-ec2-instance-management-role \
  --query ServiceSetting.SettingValue --output text
```

AWS docs: [Default Host Management Configuration](https://docs.aws.amazon.com/systems-manager/latest/userguide/fleet-manager-default-host-management-configuration.html)

## Step 3: Session Manager: a shell without SSH

> **In simple words:** Session Manager gives you a terminal on the server **through the agent**. Who may connect is decided by **IAM**, not by SSH keys, and sessions can be **recorded**. It also builds **port tunnels**, so you can reach a private database from your laptop without a bastion host.

```compare
🔑 SSH with a bastion host | 🛡️ Session Manager
Port 22 open in a security group | No inbound ports at all
SSH keys to create, share, rotate and lose | No keys: access comes from IAM permissions
A bastion server to patch and pay for | No bastion: the agent connects out to AWS
Hard to know who typed what | Sessions in CloudTrail, shell output in CloudWatch Logs or S3
Needs a public IP or a VPN | Works on servers in private subnets
```

**Console:** **Systems Manager → Session Manager → Start session** → pick `ssm-lab` → **Start session**. Or **EC2 → Instances** → select it → **Connect → Session Manager** → **Connect**. You arrive as `ssm-user`, who can use `sudo`.

**CLI:** install the **Session Manager plugin** on your laptop first (macOS and Windows installers are on the [plugin install page](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)):

```bash
# Amazon Linux, RHEL, Fedora (x86_64)
sudo yum install -y https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm
# Ubuntu, Debian (x86_64)
curl -o session-manager-plugin.deb "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb"
sudo dpkg -i session-manager-plugin.deb

session-manager-plugin --version     # use 1.2.764.0 or later
aws ssm start-session --target $INSTANCE_1
```

### Control who can connect

This policy lets people start sessions only on instances tagged `Environment=dev`, and end or resume only **their own** sessions ([how to attach a policy](#/tool/aws-iam)):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    { "Effect": "Allow", "Action": "ssm:StartSession",
      "Resource": "arn:aws:ec2:us-east-1:111111111111:instance/*",
      "Condition": { "StringEquals": { "ssm:resourceTag/Environment": "dev" } } },
    { "Effect": "Allow", "Action": "ssm:StartSession",
      "Resource": [
        "arn:aws:ssm:us-east-1:111111111111:document/SSM-SessionManagerRunShell",
        "arn:aws:ssm:*::document/AWS-StartPortForwardingSession",
        "arn:aws:ssm:*::document/AWS-StartPortForwardingSessionToRemoteHost" ] },
    { "Effect": "Allow",
      "Action": ["ssm:DescribeSessions", "ssm:GetConnectionStatus", "ssm:DescribeInstanceProperties", "ec2:DescribeInstances"],
      "Resource": "*" },
    { "Effect": "Allow",
      "Action": ["ssm:TerminateSession", "ssm:ResumeSession", "ssmmessages:OpenDataChannel"],
      "Resource": "arn:aws:ssm:*:*:session/*",
      "Condition": { "StringEquals": { "ssm:resourceTag/aws:ssmmessages:session-id": "${aws:userid}" } } }
  ]
}
```

### Record every session

Session Manager settings live in a Session document called `SSM-SessionManagerRunShell`, one per Region.

**Console:** **Session Manager → Preferences → Edit** → **CloudWatch logging: Enable** → **Stream session logs** → clear **Allow only encrypted CloudWatch log groups** (the lab log group has no KMS key) → log group `/ssm/sessions` → **Idle session timeout** `20` minutes → **Save**.

**CLI:**

```bash
cat > SessionManagerRunShell.json <<'EOF'
{
  "schemaVersion": "1.0",
  "description": "Document to hold regional settings for Session Manager",
  "sessionType": "Standard_Stream",
  "inputs": {
    "s3BucketName": "", "s3KeyPrefix": "", "s3EncryptionEnabled": false,
    "cloudWatchLogGroupName": "/ssm/sessions", "cloudWatchEncryptionEnabled": false,
    "cloudWatchStreamingEnabled": true, "kmsKeyId": "", "runAsEnabled": false, "runAsDefaultUser": "",
    "idleSessionTimeout": "20", "maxSessionDuration": "60", "shellProfile": { "windows": "", "linux": "" }
  }
}
EOF
# update the settings; if the document doesn't exist yet in this Region, create it
aws ssm update-document --name SSM-SessionManagerRunShell \
  --content file://SessionManagerRunShell.json --document-version '$LATEST' \
|| aws ssm create-document --name SSM-SessionManagerRunShell --document-type Session \
  --content file://SessionManagerRunShell.json --document-format JSON

# start a session, type a few commands, exit, then:
aws logs tail /ssm/sessions --since 15m
```

`idleSessionTimeout` closes quiet sessions (minutes), `maxSessionDuration` is a hard limit, and `kmsKeyId` adds encryption with your own key ([KMS guide](#/tool/aws-kms)).

> **Warning:** **Port forwarding and SSH sessions are not logged**: Session Manager is only a tunnel for them. Session start and end are still recorded in **CloudTrail**.

### Port forwarding: reach private things from your laptop

```bash
# 1) a port on the server itself: node_exporter on 9100 (after Step 5)
aws ssm start-session --target $INSTANCE_1 --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["9100"],"localPortNumber":["9100"]}'
# then open http://localhost:9100/metrics

# 2) a private database, using the server as a jump host
DB_HOST=my-db.abcdefghijkl.us-east-1.rds.amazonaws.com   # your RDS endpoint
aws ssm start-session --target $INSTANCE_1 --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "{\"host\":[\"$DB_HOST\"],\"portNumber\":[\"5432\"],\"localPortNumber\":[\"15432\"]}"
# in a second terminal:
psql -h localhost -p 15432 -U postgres -d postgres
```

The database's security group must allow 5432 **from the server's security group**. Creating the database is in the [RDS guide](#/tool/aws-rds/step-4-connect-to-the-database).

AWS docs: [Start a session](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-sessions-start.html) · [Session logging](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-logging.html) · [Preferences from the CLI](https://docs.aws.amazon.com/systems-manager/latest/userguide/getting-started-configure-preferences-cli.html) · [Sample IAM policies](https://docs.aws.amazon.com/systems-manager/latest/userguide/getting-started-restrict-access-quickstart.html)

## Step 4: Run Command: one command, many servers

> **In simple words:** Run Command sends a **document** (like "run this shell script") to many servers at once, picked by **tag**. You control how many run at the same time, when to stop if things fail, and where the output goes. Nobody logs in, and every run is recorded.

| AWS document | What it does |
|---|---|
| `AWS-RunShellScript` | Shell commands on Linux and macOS |
| `AWS-RunPowerShellScript` | PowerShell commands on Windows (same `commands` parameter) |
| `AWS-ConfigureAWSPackage` | Installs AWS packages, e.g. `AmazonCloudWatchAgent` |
| `AWS-UpdateSSMAgent` | Updates the SSM Agent |
| `AWS-RunPatchBaseline` | Scans for or installs OS patches (Step 9) |

**Console:** **Systems Manager → Run Command → Run command** → **AWS-RunShellScript** → **Commands**: `hostname`, `uptime`, `df -h /` → **Target selection: Specify instance tags** → `Environment` = `dev` → **Add** → **Rate control**: Concurrency `50` percent, Error threshold `1` → **Output options**: your S3 bucket and CloudWatch log group `/ssm/run-command` → **Run**.

**CLI:**

```bash
CMD_ID=$(aws ssm send-command --document-name AWS-RunShellScript \
  --targets Key=tag:Environment,Values=dev \
  --parameters '{"commands":["hostname","uptime","df -h /"]}' \
  --comment "dev health check" \
  --max-concurrency 50% --max-errors 1 --timeout-seconds 600 \
  --output-s3-bucket-name $BUCKET --output-s3-key-prefix run-command \
  --cloud-watch-output-config CloudWatchOutputEnabled=true,CloudWatchLogGroupName=/ssm/run-command \
  --query Command.CommandId --output text)
aws ssm wait command-executed --command-id $CMD_ID --instance-id $INSTANCE_1

aws ssm list-command-invocations --command-id $CMD_ID --query 'CommandInvocations[].[InstanceId,Status]' --output table
aws ssm get-command-invocation --command-id $CMD_ID --instance-id $INSTANCE_1 \
  --query StandardOutputContent --output text
aws s3 ls s3://$BUCKET/run-command/ --recursive
```

| Option | Meaning |
|---|---|
| `--targets Key=tag:Environment,Values=dev` | Every managed node with that tag. `Key=InstanceIds,Values=i-...` picks exact servers |
| `--max-concurrency 50%` / `--max-errors 1` | At most half the servers at once; stop after one failure |
| `--timeout-seconds 600` | Skip a server that hasn't **started** the command within 10 minutes |
| `executionTimeout` (document parameter) | How long the script itself may run (default 3600 seconds) |
| S3 / CloudWatch output | Full output. The API and console show only the first **24,000 characters** |

> **Tip:** Start risky commands with `--max-concurrency 1 --max-errors 0`. If the first server fails, nothing else is touched.

AWS docs: [Run Command](https://docs.aws.amazon.com/systems-manager/latest/userguide/run-command.html) · [Run Command output to CloudWatch Logs](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-rc-setting-up-cwlogs.html)

## Step 5: Write your own Command document

> **In simple words:** When you run the same script again and again, turn it into **your own document**: a YAML file with **parameters** (things you can change, like a version) and **steps**. This one installs **Prometheus node_exporter**, a small monitoring agent that shows CPU, memory and disk metrics on port 9100.

Save as `install-node-exporter.yaml`:

```yaml
schemaVersion: "2.2"
description: "Install Prometheus node_exporter and keep it running (Linux)."
parameters:
  Version:
    type: String
    default: "1.12.1"
    allowedPattern: "^[0-9]+\\.[0-9]+\\.[0-9]+$"
mainSteps:
  - action: aws:runShellScript
    name: InstallNodeExporter
    precondition:
      StringEquals: [platformType, Linux]
    inputs:
      timeoutSeconds: "300"
      runCommand:
        - |
          #!/bin/bash
          set -euo pipefail
          VERSION="{{ Version }}"
          BIN=/usr/local/bin/node_exporter
          if systemctl is-active --quiet node_exporter && "$BIN" --version 2>&1 | grep -q "version $VERSION "; then
            echo "node_exporter $VERSION already running. Nothing to do."; exit 0
          fi
          case "$(uname -m)" in x86_64) ARCH=amd64 ;; aarch64) ARCH=arm64 ;; *) exit 1 ;; esac
          NAME="node_exporter-${VERSION}.linux-${ARCH}"
          cd /tmp
          curl -sSfLO "https://github.com/prometheus/node_exporter/releases/download/v${VERSION}/${NAME}.tar.gz"
          tar -xzf "${NAME}.tar.gz"
          systemctl stop node_exporter 2>/dev/null || true
          install -m 0755 "${NAME}/node_exporter" "$BIN"
          id node_exporter >/dev/null 2>&1 || useradd --system --no-create-home --shell /sbin/nologin node_exporter
          printf '[Unit]\nDescription=node_exporter\n[Service]\nUser=node_exporter\nExecStart=%s\nRestart=on-failure\n[Install]\nWantedBy=multi-user.target\n' "$BIN" \
            > /etc/systemd/system/node_exporter.service
          systemctl daemon-reload
          systemctl enable --now node_exporter
          echo "node_exporter $VERSION installed and running"
```

`schemaVersion: "2.2"` is the format for **Command** documents. `{{ Version }}` is replaced by the parameter, and `allowedPattern` rejects bad values. The `precondition` makes Windows servers **skip** the step instead of failing (Windows uses `aws:runPowerShellScript`). The "already running" check makes the script **idempotent**, safe to run again and again, which State Manager needs. The file comes from the public [node_exporter project](https://github.com/prometheus/node_exporter), so the server needs internet access (or copy the file to S3 first).

**Console:** **Systems Manager → Documents → Create document → Command or Session** → Name `my-app-InstallNodeExporter`, type **Command document**, **YAML** → paste → **Create document**.

**CLI:**

```bash
aws ssm create-document --name my-app-InstallNodeExporter \
  --document-type Command --document-format YAML --content file://install-node-exporter.yaml

CMD_ID=$(aws ssm send-command --document-name my-app-InstallNodeExporter \
  --targets Key=tag:Monitoring,Values=node-exporter --parameters '{"Version":["1.12.1"]}' \
  --cloud-watch-output-config CloudWatchOutputEnabled=true,CloudWatchLogGroupName=/ssm/run-command \
  --query Command.CommandId --output text)
aws ssm wait command-executed --command-id $CMD_ID --instance-id $INSTANCE_1
aws ssm get-command-invocation --command-id $CMD_ID --instance-id $INSTANCE_1 --query StandardOutputContent --output text
```

To see the metrics, use the port forwarding example from Step 3 and open `http://localhost:9100/metrics`.

**Changing it later:** `aws ssm update-document ... --document-version '$LATEST'` creates a new version; `aws ssm update-document-default-version` chooses which version runs by default.

> **Note:** For the **CloudWatch agent** you don't need a custom document: use `AWS-ConfigureAWSPackage` and `AmazonCloudWatch-ManageAgent`, as in the [CloudWatch guide](#/tool/aws-cloudwatch/step-2-install-the-cloudwatch-agent-with-systems-manager).

AWS docs: [Systems Manager documents](https://docs.aws.amazon.com/systems-manager/latest/userguide/documents.html) · [Command document plugin reference](https://docs.aws.amazon.com/systems-manager/latest/userguide/documents-command-ssm-plugin-reference.html)

## Step 6: State Manager: keep it installed everywhere

> **In simple words:** Run Command is "do it now". A **State Manager association** is a **standing order**: "every server tagged `Monitoring=node-exporter` must have node_exporter running; check every day and fix it if not". New servers with the tag get it automatically, and each server is reported as compliant or not.

```flow
📝 | Write the document | Your idempotent install script from Step 5.
🎯 | Create the association | Document + targets (tag `Monitoring=node-exporter`) + schedule.
⚡ | First run | It runs right away on every matching server.
🆕 | New server appears | An instance launched with the tag gets it immediately.
🔁 | Scheduled re-check | It runs again and fixes drift, e.g. a stopped service.
📊 | Compliance | Each server shows as Compliant or Non-compliant.
↻ Runs again on every schedule tick
```

**Console:** **Systems Manager → State Manager → Create association** → Name `node-exporter-everywhere` → Document **Owned by me** → `my-app-InstallNodeExporter` → **Version** `1.12.1` → **Targets: Specify instance tags** `Monitoring` = `node-exporter` → **Specify schedule: On Schedule**, every 1 day → **Compliance severity: Medium** → Rate control 50 percent / 10 percent → Output to your S3 bucket → **Create Association**.

**CLI:**

```bash
ASSOC_ID=$(aws ssm create-association --association-name node-exporter-everywhere \
  --name my-app-InstallNodeExporter \
  --targets Key=tag:Monitoring,Values=node-exporter \
  --parameters '{"Version":["1.12.1"]}' \
  --schedule-expression "rate(1 day)" \
  --max-concurrency 50% --max-errors 10% --compliance-severity MEDIUM \
  --output-location "S3Location={OutputS3BucketName=$BUCKET,OutputS3KeyPrefix=associations}" \
  --query AssociationDescription.AssociationId --output text)

aws ssm describe-instance-associations-status --instance-id $INSTANCE_1 \
  --query 'InstanceAssociationStatusInfos[].[Name,Status,DetailedStatus]' --output table
aws ssm list-compliance-items --resource-ids $INSTANCE_1 --resource-types ManagedInstance \
  --filters Key=ComplianceType,Values=Association --query 'ComplianceItems[].[Title,Status,Severity]' --output table

# watch it heal: stop the service, run the association now, check again
aws ssm send-command --document-name AWS-RunShellScript --instance-ids $INSTANCE_2 \
  --parameters '{"commands":["systemctl stop node_exporter"]}' --query Command.CommandId --output text
sleep 30
aws ssm start-associations-once --association-ids $ASSOC_ID
```

Schedules use `rate(...)` or `cron(...)` and must be **30 minutes or longer** (`rate(15 minutes)` is rejected). `--apply-only-at-cron-interval` skips the first run and waits for the cron time. A node can be targeted by up to **20 associations**, and `--compliance-severity` (`CRITICAL`, `HIGH`, `MEDIUM`, `LOW`, `UNSPECIFIED`) says how bad a failure is.

> **Tip:** In real projects these documents and associations are created with **Terraform** (`aws_ssm_document` plus `aws_ssm_association`), so every account gets the same agents. See the [Terraform guide](#/tool/terraform).

AWS docs: [State Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-state.html) · [Cron and rate expressions](https://docs.aws.amazon.com/systems-manager/latest/userguide/reference-cron-and-rate-expressions.html)

## Step 7: Automation runbooks

> **In simple words:** A **runbook** is a checklist that **AWS runs for you**, step by step: stop a server, wait, start it, check a service. Unlike Run Command, the steps run in AWS and can call any AWS API. AWS ships hundreds of ready-made runbooks, and you can write your own.

**Console:** **Systems Manager → Automation → Execute automation** → search **AWS-RestartEC2Instance** → **Next** → **Simple execution** → **InstanceId**: one lab server → **Execute**. Watch each step turn green.

**CLI:**

```bash
EXEC_ID=$(aws ssm start-automation-execution --document-name AWS-RestartEC2Instance \
  --parameters "InstanceId=$INSTANCE_2" --query AutomationExecutionId --output text)
aws ssm describe-automation-step-executions --automation-execution-id $EXEC_ID --query 'StepExecutions[].[StepName,StepStatus]'
```

Other handy runbooks: `AWS-StopEC2Instance`, `AWS-StartEC2Instance` and `AWS-CreateImage`.

### The automation assume role

Without the `AutomationAssumeRole` parameter, a runbook uses **your own** permissions. For schedules, other teams or EventBridge triggers, give it a **service role** that Systems Manager assumes. Whoever starts the runbook needs `iam:PassRole` on it.

```bash
aws iam create-role --role-name ssm-lab-automation-role --assume-role-policy-document \
  '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ssm.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
aws iam attach-role-policy --role-name ssm-lab-automation-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonSSMAutomationRole
aws iam put-role-policy --role-name ssm-lab-automation-role --policy-name describe-instances \
  --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":"ec2:DescribeInstances","Resource":"*"}]}'
AUTOMATION_ROLE_ARN=arn:aws:iam::$ACCOUNT_ID:role/ssm-lab-automation-role
```

`AmazonSSMAutomationRole` allows all Systems Manager actions and common EC2 actions (start, stop, images, tags), but not `ec2:DescribeInstances`, so we add it.

### A short custom runbook

Restart a server, **wait until the agent is back online**, then check node_exporter. Save as `restart-and-check.yaml`:

```yaml
schemaVersion: "0.3"
description: "Restart an instance, wait for the SSM Agent, then check node_exporter."
assumeRole: "{{ AutomationAssumeRole }}"
parameters:
  InstanceId: { type: String, description: "The instance to restart" }
  AutomationAssumeRole: { type: String, description: "Role ARN that Automation uses" }
mainSteps:
  - name: StopInstance
    action: aws:changeInstanceState
    inputs: { InstanceIds: ["{{ InstanceId }}"], DesiredState: stopped }
  - name: StartInstance
    action: aws:changeInstanceState
    inputs: { InstanceIds: ["{{ InstanceId }}"], DesiredState: running }
  - name: WaitForAgent
    action: aws:waitForAwsResourceProperty
    timeoutSeconds: 600
    inputs:
      Service: ssm
      Api: DescribeInstanceInformation
      Filters: [{ Key: InstanceIds, Values: ["{{ InstanceId }}"] }]
      PropertySelector: "$.InstanceInformationList[0].PingStatus"
      DesiredValues: ["Online"]
  - name: CheckExporter
    action: aws:runCommand
    inputs:
      DocumentName: AWS-RunShellScript
      InstanceIds: ["{{ InstanceId }}"]
      Parameters: { commands: ["systemctl is-active node_exporter"] }
```

`aws:changeInstanceState` starts or stops and waits for the new state, `aws:waitForAwsResourceProperty` calls an API until a field has the value you want, and `aws:runCommand` runs a Command document as one step. Others include `aws:executeAwsApi` (any AWS API), `aws:executeScript` (short Python or PowerShell) and `aws:approve` (wait for a person).

```bash
aws ssm create-document --name my-app-RestartAndCheck \
  --document-type Automation --document-format YAML --content file://restart-and-check.yaml
EXEC_ID=$(aws ssm start-automation-execution --document-name my-app-RestartAndCheck \
  --parameters "InstanceId=$INSTANCE_1,AutomationAssumeRole=$AUTOMATION_ROLE_ARN" \
  --query AutomationExecutionId --output text)
sleep 180
aws ssm get-automation-execution --automation-execution-id $EXEC_ID \
  --query 'AutomationExecution.[AutomationExecutionStatus,FailureMessage]' --output text
```

This runbook has 4 steps, so each run costs about $0.008. Runbooks can also be started by **EventBridge**, **State Manager** and **Maintenance Windows**. For a weekend shutdown schedule, compare with the [Lambda approach](#/tool/aws-lambda/project-weekend-shutdown-to-save-money).

AWS docs: [Automation](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-automation.html) · [Actions reference](https://docs.aws.amazon.com/systems-manager/latest/userguide/automation-actions.html) · [AWS-RestartEC2Instance](https://docs.aws.amazon.com/systems-manager-automation-runbooks/latest/userguide/automation-aws-restartec2instance.html) · [AWS-StopEC2Instance](https://docs.aws.amazon.com/systems-manager-automation-runbooks/latest/userguide/automation-aws-stopec2instance.html)

## Step 8: Parameter Store: settings in one place

> **In simple words:** Parameter Store is a **labelled shelf for settings**: database host names, feature flags, URLs, AMI IDs. You name them like folders (`/my-app/dev/db-host`), control who reads them with IAM, and can encrypt sensitive values with KMS. Apps, scripts, Terraform and SSM documents all read from the same place.

| Type | Holds | Example |
|---|---|---|
| `String` | One plain-text value | `/my-app/dev/db-host` = `db.dev.example.com` |
| `StringList` | Comma-separated values | `/my-app/dev/allowed-origins` = `https://example.com,https://www.example.com` |
| `SecureString` | A value encrypted with KMS (default key `alias/aws/ssm`, or your own) | `/my-app/dev/api-key` |

Naming by **app → environment → setting** (`/my-app/dev/...`, `/my-app/prod/...`) lets you read a whole environment at once and write IAM rules like "the dev app may read only `/my-app/dev/*`".

**Console:** **Systems Manager → Parameter Store → Create parameter** → Name `/my-app/dev/db-host`, Tier **Standard**, Type **String**, Value `db.dev.example.com` → **Create parameter**.

**CLI:**

```bash
aws ssm put-parameter --name /my-app/dev/db-host --type String --value db.dev.example.com
aws ssm put-parameter --name /my-app/dev/allowed-origins --type StringList --value "https://example.com,https://www.example.com"
aws ssm put-parameter --name /my-app/dev/api-key --type SecureString --value "dev-api-key-123"

aws ssm get-parameter --name /my-app/dev/api-key --with-decryption --query Parameter.Value --output text
aws ssm get-parameters-by-path --path /my-app/dev --recursive --with-decryption \
  --query 'Parameters[].[Name,Type,Value]' --output table

# every change keeps a version; labels give versions a name
aws ssm put-parameter --name /my-app/dev/db-host --type String --value db2.dev.example.com --overwrite
aws ssm label-parameter-version --name /my-app/dev/db-host --parameter-version 1 --labels stable
aws ssm get-parameter --name /my-app/dev/db-host:stable --query Parameter.Value --output text

# AWS publishes public parameters too, e.g. the latest AMI IDs
aws ssm get-parameters-by-path --path /aws/service/ami-amazon-linux-latest --query 'Parameters[].Name'
```

| | Standard | Advanced |
|---|---|---|
| Parameters per account and Region | 10,000 | 100,000 |
| Maximum value size | 4 KB | 8 KB |
| Parameter policies (expiry, "not changed" alerts) / sharing with other accounts | No | Yes |
| Price | No additional charge | $0.05 per parameter per month, plus API interactions |
| Change tier | Can be upgraded | Can't go back (delete and recreate) |

An app role that may read only its own dev settings, decrypted with a customer managed KMS key:

```json
{ "Version": "2012-10-17", "Statement": [
  { "Effect": "Allow", "Action": ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"],
    "Resource": "arn:aws:ssm:us-east-1:111111111111:parameter/my-app/dev/*" },
  { "Effect": "Allow", "Action": "kms:Decrypt",
    "Resource": "arn:aws:kms:us-east-1:111111111111:key/11111111-2222-3333-4444-555555555555" } ] }
```

> **Warning:** `AmazonSSMManagedInstanceCore` allows `ssm:GetParameter` and `ssm:GetParameters` on **all** parameters, so any managed server can read plain `String` values. Store sensitive values as `SecureString` with **your own KMS key**, and allow `kms:Decrypt` only to the roles that need it.

**Parameter Store or Secrets Manager?** Parameter Store for configuration; Secrets Manager for passwords and API keys that need **automatic rotation**, cross-account access or replication. See the comparison in the [Secrets Manager guide](#/tool/aws-secrets/secrets-manager-or-parameter-store).

AWS docs: [Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html) · [Parameter tiers](https://docs.aws.amazon.com/systems-manager/latest/userguide/parameter-store-advanced-parameters.html)

## Step 9: Patch Manager, Fleet Manager and Inventory

> **In simple words:** **Patch Manager** keeps operating systems up to date: it **scans** for missing updates and **installs** them on a schedule you choose. **Fleet Manager** is the dashboard of all your managed nodes, and **Inventory** records what software each one has.

| Term | Meaning |
|---|---|
| **Patch baseline** | Rules for which patches are approved. AWS provides a default per OS |
| **Scan** / **Install** | Only report what is missing / install approved patches and reboot if needed |
| **Patch policy** | The recommended setup in **Quick Setup**: scan and install schedules, baselines and targets in one wizard, even across accounts and Regions |
| **Maintenance window** | A time slot (e.g. Sunday 02:00 UTC) when installs and reboots may happen |

**Console:** **Systems Manager → Quick Setup → Patch Manager → Create** → **Scan and install** → keep the recommended schedules (daily scan, weekly install) → targets, e.g. tag `Environment=dev` → **Create**.

**CLI:** a one-off scan, then the results:

```bash
CMD_ID=$(aws ssm send-command --document-name AWS-RunPatchBaseline \
  --targets Key=tag:Environment,Values=dev --parameters '{"Operation":["Scan"]}' \
  --query Command.CommandId --output text)
aws ssm wait command-executed --command-id $CMD_ID --instance-id $INSTANCE_1   # if it times out, run it again
aws ssm describe-instance-patch-states --instance-ids $INSTANCE_1 $INSTANCE_2 \
  --query 'InstancePatchStates[].[InstanceId,InstalledCount,MissingCount,FailedCount]' --output table
```

To install, use `"Operation":["Install"]` with `"RebootOption":["RebootIfNeeded"]` (or `NoReboot`). Patch in **waves**: dev first, prod a few days later.

**Fleet Manager** lists every managed node with its ping status, OS and agent version; from a node you can browse files, view performance counters and, on Windows, open Remote Desktop in the browser. **Inventory** is an association with the AWS document `AWS-GatherSoftwareInventory` (target `Key=InstanceIds,Values=*` for all nodes); read the results with `aws ssm list-inventory-entries --instance-id ID --type-name AWS:Application`.

> **Note:** Bigger fleets may use **Just-in-time node access** (people request access before a session; priced per node per hour) and **hybrid activations** for on-premises servers. Check the pricing page first.

AWS docs: [Patch Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/patch-manager.html) · [Patch policies](https://docs.aws.amazon.com/systems-manager/latest/userguide/patch-manager-policies.html) · [Fleet Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/fleet-manager.html) · [Inventory](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-inventory.html)

## Troubleshooting

> **In simple words:** When a server is missing or a command fails, check the same three things every time: **is the agent running, does it have permissions, can it reach the endpoints?** Then read the output in S3 or CloudWatch Logs.

| Problem | Likely cause | Fix |
|---|---|---|
| Instance not in Fleet Manager | No instance profile, or the role lacks `AmazonSSMManagedInstanceCore` | Attach the role (EC2 → Actions → Security → Modify IAM role), wait a few minutes |
| Still not managed | No path to the endpoints: no NAT or VPC endpoints, endpoint security group blocks 443, private DNS off | Add NAT or the `ssm`, `ssmmessages`, `ec2messages` endpoints with **private DNS** |
| Not managed with DHMC | IMDSv1, agent older than 3.2.582.0, DHMC off in that Region | Require IMDSv2, update the agent, check `get-service-setting` |
| Agent stopped or crashing (Linux) | Service down, disk full, broken update | Reach the server another way (EC2 serial console or EC2 Instance Connect), run `sudo systemctl restart amazon-ssm-agent`, read `/var/log/amazon/ssm/amazon-ssm-agent.log` |
| `SessionManagerPlugin is not found` | Plugin missing on your laptop | Install it (Step 3) and open a new terminal |
| `TargetNotConnected` | Node offline or not managed | Check Ping status in Fleet Manager |
| No session logs | Log group missing, role can't write logs, or "encrypted only" with an unencrypted log group | Create the log group, attach `CloudWatchAgentServerPolicy`, clear the encryption option |
| Command `Undeliverable` or `Delivery Timed Out` | Node offline, or it didn't start within `--timeout-seconds` | Check Ping status; raise the timeout |
| Association `Failed` | Script error, no internet for the download, wrong parameter | Read the output in S3; test the document with Run Command |
| `ValidationException` on an association schedule | Interval shorter than 30 minutes | Use `rate(30 minutes)` or longer |
| `AccessDenied` running a runbook with a role | You lack `iam:PassRole`, or the role lacks an action | Add it; the failed step's message names the missing action |
| `AccessDeniedException` with `--with-decryption` | No `kms:Decrypt` on the parameter's key | Allow `kms:Decrypt` on that key |
| `ParameterNotFound` | Missing leading `/`, wrong Region, or no permission on that path | Check the name and `AWS_REGION` |

More IAM debugging: [Troubleshooting AccessDenied](#/tool/aws-iam/troubleshooting-accessdenied). AWS docs: [Troubleshooting SSM Agent](https://docs.aws.amazon.com/systems-manager/latest/userguide/troubleshooting-ssm-agent.html) · [Troubleshooting Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-troubleshooting.html)

## Clean up

> **In simple words:** Delete what costs money first (the servers), then the Systems Manager pieces, then the roles, bucket and log groups. Turn session logging off so the preferences don't point at a deleted log group.

```bash
aws ec2 terminate-instances --instance-ids $INSTANCE_1 $INSTANCE_2
aws ec2 wait instance-terminated --instance-ids $INSTANCE_1 $INSTANCE_2
aws ec2 delete-security-group --group-id $SG_ID

aws ssm delete-association --association-id $ASSOC_ID
aws ssm delete-document --name my-app-InstallNodeExporter
aws ssm delete-document --name my-app-RestartAndCheck
aws ssm delete-parameters --names /my-app/dev/db-host /my-app/dev/allowed-origins /my-app/dev/api-key

# Session Manager preferences: stop logging to the lab log group
sed -i.bak 's#"/ssm/sessions"#""#' SessionManagerRunShell.json
aws ssm update-document --name SSM-SessionManagerRunShell \
  --content file://SessionManagerRunShell.json --document-version '$LATEST'

aws iam remove-role-from-instance-profile --instance-profile-name $ROLE --role-name $ROLE
aws iam delete-instance-profile --instance-profile-name $ROLE
aws iam delete-role-policy --role-name $ROLE --policy-name ssm-output-to-s3
for P in AmazonSSMManagedInstanceCore CloudWatchAgentServerPolicy; do
  aws iam detach-role-policy --role-name $ROLE --policy-arn arn:aws:iam::aws:policy/$P; done
aws iam delete-role --role-name $ROLE
AR=ssm-lab-automation-role
aws iam delete-role-policy --role-name $AR --policy-name describe-instances
aws iam detach-role-policy --role-name $AR --policy-arn arn:aws:iam::aws:policy/service-role/AmazonSSMAutomationRole
aws iam delete-role --role-name $AR

aws s3 rb s3://$BUCKET --force
aws logs delete-log-group --log-group-name /ssm/run-command
aws logs delete-log-group --log-group-name /ssm/sessions
rm -f SessionManagerRunShell.json SessionManagerRunShell.json.bak
```

Also delete any **VPC endpoints** you created (billed per hour), turn **DHMC** off in **Fleet Manager → Account management** if you enabled it only for practice, and delete Quick Setup **patch policies** from **Quick Setup**.

## Lab and cheat sheet

> **In simple words:** Practice time: manage two servers without ever opening port 22, make an agent install itself on every tagged server, and automate a safe restart.

1. Launch two servers with **no key pair** and **no inbound rules**; confirm both are `Online`.
2. Open a shell from the console and from the CLI. Find your commands in the `/ssm/sessions` log group.
3. Run `df -h` on every `Environment=dev` server, with output to S3 and CloudWatch Logs.
4. Create the node_exporter document and run it. Forward port 9100 and open the metrics page.
5. Create the association. Launch a **third** server tagged `Monitoring=node-exporter` and check that node_exporter appears on it by itself.
6. **Break it:** stop node_exporter, run `start-associations-once`, and watch it come back.
7. Create the automation role and the `my-app-RestartAndCheck` runbook, and run it.
8. Store one parameter of each type under `/my-app/dev`, read them by path, and label a version.
9. **Break it:** detach `AmazonSSMManagedInstanceCore` from the role, watch the node go offline, then fix it.
10. Clean up everything.

### Cheat sheet

| Task | Command |
|---|---|
| List managed nodes | `aws ssm describe-instance-information --output table` |
| Open a shell | `aws ssm start-session --target i-0123456789abcdef0` |
| Forward a port | `aws ssm start-session --target ID --document-name AWS-StartPortForwardingSession --parameters '{"portNumber":["80"],"localPortNumber":["8080"]}'` |
| Run a command by tag | `aws ssm send-command --document-name AWS-RunShellScript --targets Key=tag:Environment,Values=dev --parameters '{"commands":["uptime"]}'` |
| Read command output | `aws ssm get-command-invocation --command-id CMD --instance-id ID` |
| Create a document | `aws ssm create-document --name NAME --document-type Command --document-format YAML --content file://doc.yaml` |
| Create an association | `aws ssm create-association --name DOC --targets Key=tag:K,Values=V --schedule-expression "rate(1 day)"` |
| Run an association now | `aws ssm start-associations-once --association-ids ID` |
| Start a runbook | `aws ssm start-automation-execution --document-name AWS-RestartEC2Instance --parameters InstanceId=ID` |
| Put / read a parameter | `aws ssm put-parameter --name /my-app/dev/key --type SecureString --value V` / `aws ssm get-parameter --name /my-app/dev/key --with-decryption` |
| Read a whole path | `aws ssm get-parameters-by-path --path /my-app/dev --recursive --with-decryption` |
| Patch scan | `aws ssm send-command --document-name AWS-RunPatchBaseline --targets Key=tag:K,Values=V --parameters '{"Operation":["Scan"]}'` |
| Agent log (Linux) | `sudo tail -f /var/log/amazon/ssm/amazon-ssm-agent.log` |
