# Amazon CloudWatch: Metrics, Alarms, Logs and Dashboards

Amazon CloudWatch is the monitoring service of AWS: it collects **metrics** (numbers over time) and **logs** (text lines) from your servers, databases, load balancers and apps, raises **alarms** when something looks wrong, and shows everything on **dashboards**. This guide sets it up step by step on one EC2 instance: memory and disk metrics with the **CloudWatch agent**, a **custom metric**, **alarms** that email you through SNS, **Logs Insights** searches, an **ERROR-count alarm** from log lines, a **dashboard**, and **EventBridge rules** that react to AWS events. Every step shows the **console clicks** and the matching **AWS CLI** commands.

> **Cost:** Metrics that AWS services send by default (basic monitoring) are **free**. Each month the free tier also covers **10 custom or detailed-monitoring metrics**, **10 alarm metrics**, **5 GB of log data** (ingestion, storage and Logs Insights scanning together) and **3 dashboards**. Beyond that, in us-east-1: a custom metric costs about **$0.30/month**, a standard alarm **$0.10/month per metric** (high-resolution $0.30, composite $0.50), log ingestion **$0.50/GB**, log storage **$0.03/GB per month**, Logs Insights **$0.005 per GB scanned**, and a dashboard **$3/month**. This lab costs a few cents plus the small EC2 instance. See [CloudWatch pricing](https://aws.amazon.com/cloudwatch/pricing/).

## Start here: CloudWatch in simple words

> **In simple words:** CloudWatch is the **dashboard and warning lights of your car**, for AWS. Gauges show speed and fuel (**metrics**), a warning light turns on when the engine is too hot (**alarm**), your phone rings (**SNS notification**), and a black box records what happened (**logs**) so you can find out why.

### The car comparison

| In a car | In CloudWatch |
|---|---|
| Speedometer, fuel gauge, engine temperature | **Metrics**: CPU %, free memory, requests, errors |
| A warning light that turns on above a limit | **Alarm**: watches one metric against a threshold |
| A call to your mechanic when the light turns on | **Alarm action**: a message to an **SNS topic** (email, chat, Lambda) |
| The trip recorder (black box) | **Logs**: every line your app and AWS services write |
| Searching the recorder after a problem | **Logs Insights**: a query language for logs |
| The panel in front of the driver | **Dashboard**: the important graphs on one screen |
| "If a door opens, turn on the inside light" | **EventBridge rule**: "if an instance stops, send a message" |

### How monitoring works

```flow
📥 | Collect | AWS services send metrics automatically. The CloudWatch agent adds memory, disk and log files from inside your servers.
🚨 | Detect | An **alarm** compares a metric with a threshold, for example "CPU above 80% for 10 minutes".
📣 | Notify | The alarm sends a message to an **SNS topic**, which emails you or posts to chat.
🔎 | Investigate | Open the **dashboard**, then search the **logs** with Logs Insights to find the cause.
🛠️ | Fix and improve | Fix the problem, then tune thresholds or add a missing alarm.
↻ Monitoring never stops: every incident teaches you a better alarm.
```

### Key words

| Word | Meaning |
|---|---|
| **Metric** | A named number measured over time, e.g. `CPUUtilization` |
| **Namespace** | A folder for metrics. AWS uses `AWS/<service>` (`AWS/EC2`, `AWS/RDS`); the agent uses `CWAgent`; you pick your own for custom metrics |
| **Dimension** | A name/value label that says **which** thing is measured, e.g. `InstanceId=i-0abc…` |
| **Data point** | One value at one time |
| **Period** | The time bucket for a statistic, e.g. 60 or 300 seconds |
| **Statistic** | How data points in a period are combined: `Average`, `Sum`, `Minimum`, `Maximum`, `SampleCount`, percentiles like `p99` |
| **Alarm** | Watches one metric (or an expression) and is in state `OK`, `ALARM` or `INSUFFICIENT_DATA` |
| **SNS topic** | A "mailing list" that alarms publish to; subscribers get the message (see [SNS and SES](#/tool/aws-sns-ses)) |
| **Log group / log stream** | A folder of logs for one app or service / one source inside it (e.g. one server) |
| **Retention** | How many days a log group keeps its logs. The default is **never expire** |
| **Metric filter** | Turns matching log lines into a metric, so you can alarm on them |
| **EventBridge rule** | Matches events ("instance stopped") and sends them to a target such as SNS |

### What we'll build

```text
 ┌────────────── EC2 instance ──────────────┐
 │ CloudWatch agent: memory, disk, log file │
 └──────┬──────────────────────┬────────────┘
  metrics│                  logs│
        ▼                      ▼
  ┌───────────┐  metric  ┌─────────────┐
  │  Metrics  │◀─────────│  Log group  │
  └─────┬─────┘  filter  └─────────────┘
        │ alarms: CPU, memory, errors
        ▼
  ┌───────────┐     ┌─────────┐
  │ SNS topic │────▶│  Email  │
  └───────────┘     └─────────┘
        ▲
  EventBridge rule: "instance stopped"
```

### Check yourself

1. Why can't you see the memory usage of an EC2 instance in CloudWatch by default?
2. An alarm uses a 5-minute period, 3 evaluation periods and 2 datapoints to alarm. When does it go to `ALARM`?
3. Why should every log group have a retention setting?

> **Tip:** Answers: 1) AWS measures the instance from the outside (the hypervisor) and can't see inside the operating system. You need the **CloudWatch agent** for memory and disk space. 2) When **2 of the last 3** five-minute periods (15 minutes) break the threshold. 3) The default is **never expire**, so storage (and the bill) grows forever, and you may keep data longer than your rules allow.

## Before you start: variables, SNS topic and a test server

> **In simple words:** Set a few shell variables, create one **SNS topic** that all alarms will email, and launch one small EC2 instance with an IAM role that lets the CloudWatch agent and Systems Manager do their work.

You need the AWS CLI v2 signed in as an admin user (see [Create your AWS account](#/tool/aws-account) and [Workstation setup](#/tool/setup)). The instance goes into your **default VPC**, which gives it a public IP so it can reach the Systems Manager and CloudWatch endpoints.

**Console:** **SNS → Topics → Create topic** → Type **Standard**, Name `cw-lab-alerts` → **Create topic** → **Create subscription** → Protocol **Email**, Endpoint your email → **Create subscription**. Open the email and choose **Confirm subscription**.

**CLI:**

```bash
export AWS_REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
EMAIL=you@example.com            # use your real email address

# 1) SNS topic + email subscription (click the link in the email!)
TOPIC_ARN=$(aws sns create-topic --name cw-lab-alerts --query TopicArn --output text)
aws sns subscribe --topic-arn $TOPIC_ARN --protocol email --notification-endpoint $EMAIL
aws sns list-subscriptions-by-topic --topic-arn $TOPIC_ARN \
  --query 'Subscriptions[].[Endpoint,SubscriptionArn]' --output table   # "PendingConfirmation" until you click

# 2) IAM role for the instance: CloudWatch agent + Systems Manager
cat > ec2-trust.json <<'EOF'
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}
EOF
aws iam create-role --role-name cw-lab-ec2-role --assume-role-policy-document file://ec2-trust.json
aws iam attach-role-policy --role-name cw-lab-ec2-role --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
aws iam attach-role-policy --role-name cw-lab-ec2-role --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
aws iam create-instance-profile --instance-profile-name cw-lab-ec2-role
aws iam add-role-to-instance-profile --instance-profile-name cw-lab-ec2-role --role-name cw-lab-ec2-role
sleep 15   # IAM changes take a few seconds to spread

# 3) A small Amazon Linux 2023 instance
AMI_ID=$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query Parameter.Value --output text)
INSTANCE_ID=$(aws ec2 run-instances --image-id $AMI_ID --instance-type t3.micro \
  --iam-instance-profile Name=cw-lab-ec2-role \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=cw-lab}]' \
  --query 'Instances[0].InstanceId' --output text)
aws ec2 wait instance-status-ok --instance-ids $INSTANCE_ID
echo "Instance: $INSTANCE_ID  Topic: $TOPIC_ARN"
```

| Managed policy | What it allows |
|---|---|
| `CloudWatchAgentServerPolicy` | The agent sends metrics and logs, and reads its config from Parameter Store parameters whose names start with `AmazonCloudWatch-` |
| `AmazonSSMManagedInstanceCore` | Systems Manager can manage the instance: Run Command, Session Manager (see [Systems Manager](#/tool/aws-ssm)) |

## Step 1: Explore metrics

> **In simple words:** A metric is a number measured again and again over time. You find it by **namespace** (which service), **metric name** (what is measured) and **dimensions** (which resource). Then you choose a **statistic** and a **period** to draw or alarm on it.

**Console:** **CloudWatch → Metrics → All metrics** → **Browse** → **EC2** → **Per-Instance Metrics** → tick `CPUUtilization` for your instance. On the **Graphed metrics** tab, change **Statistic** (Average, Maximum…) and **Period** (1 minute, 5 minutes…) and watch the graph change.

**CLI:**

```bash
# which metrics exist for this instance?
aws cloudwatch list-metrics --namespace AWS/EC2 \
  --dimensions Name=InstanceId,Value=$INSTANCE_ID --query 'Metrics[].MetricName' --output table

# average and maximum CPU per 5 minutes, for the last hour (GNU date; on macOS use: date -u -v-1H ...)
START=$(date -u -d '-1 hour' +%Y-%m-%dT%H:%M:%SZ)
END=$(date -u +%Y-%m-%dT%H:%M:%SZ)
aws cloudwatch get-metric-statistics --namespace AWS/EC2 --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=$INSTANCE_ID \
  --start-time $START --end-time $END --period 300 --statistics Average Maximum --output table
```

### Common namespaces

| Namespace | Example metrics |
|---|---|
| `AWS/EC2` | `CPUUtilization`, `NetworkIn`, `StatusCheckFailed` |
| `AWS/RDS` | `CPUUtilization`, `FreeStorageSpace`, `DatabaseConnections` |
| `AWS/ApplicationELB` | `RequestCount`, `HTTPCode_Target_5XX_Count`, `TargetResponseTime` |
| `AWS/ECS` | `CPUUtilization`, `MemoryUtilization` (per cluster and service) |
| `CWAgent` | What the CloudWatch agent sends: `mem_used_percent`, `disk_used_percent` |
| Your own, e.g. `MyApp` | Custom metrics you publish (Step 3) |

### How long CloudWatch keeps metric data

| Data point period | Kept for |
|---|---|
| Less than 60 seconds (high-resolution) | 3 hours |
| 60 seconds | 15 days |
| 5 minutes | 63 days |
| 1 hour | 455 days (15 months) |

Older data is rolled up into longer periods. Metrics **can't be deleted**: they expire after 15 months with no new data.

### Basic or detailed monitoring for EC2

```compare
🆓 Basic monitoring (default) | 💲 Detailed monitoring
Metrics every 5 minutes (status checks every 1 minute) | Metrics every 1 minute
No charge | Charged per metric, at custom-metric prices
Good for most dashboards and alarms | Faster alarms and faster Auto Scaling reactions
```

```bash
aws ec2 monitor-instances --instance-ids $INSTANCE_ID     # turn on detailed monitoring
aws ec2 unmonitor-instances --instance-ids $INSTANCE_ID   # back to basic (free)
```

### What EC2 does NOT measure for you

| Built in (`AWS/EC2`) | NOT built in: needs the agent (`CWAgent`) |
|---|---|
| CPU utilization, network in/out, status checks | **Memory** used |
| Disk read/write operations on instance store | **Disk space** used on each file system (EBS volumes included) |
| CPU credit balance (T instances) | Swap, processes, and your **log files** |

The reason: AWS sees the virtual machine from the **outside**. Memory and file systems live **inside** the operating system, so a program running inside (the agent) has to report them.

AWS docs: [Metrics concepts](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/cloudwatch_concepts.html) · [EC2 detailed monitoring](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/manage-detailed-monitoring.html)

## Step 2: Install the CloudWatch agent with Systems Manager

> **In simple words:** The **CloudWatch agent** is a small program that runs inside the server, reads memory, disk and log files, and sends them to CloudWatch. We store its settings once in **Parameter Store** and let **Systems Manager** install and configure it, so you never need to SSH into the server.

### 2a. Write the agent config and store it in Parameter Store

A minimal config: memory and root-disk usage every 60 seconds, plus one log file.

```json
{
  "metrics": {
    "namespace": "CWAgent",
    "append_dimensions": { "InstanceId": "${aws:InstanceId}" },
    "metrics_collected": {
      "mem": { "measurement": ["mem_used_percent"], "metrics_collection_interval": 60 },
      "disk": {
        "measurement": ["used_percent"],
        "resources": ["/"],
        "drop_device": true,
        "metrics_collection_interval": 60
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/my-app/app.log",
            "log_group_name": "/my-app/app",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
```

| Setting | Meaning |
|---|---|
| `append_dimensions` | Adds `InstanceId` to every metric, so you can tell servers apart |
| `mem` → `mem_used_percent` | Becomes the metric `mem_used_percent` |
| `disk` → `used_percent`, `resources: ["/"]` | Becomes `disk_used_percent` for the `/` file system (dimensions `InstanceId`, `path`, `fstype`) |
| `drop_device: true` | Leaves out the device name, which can change between reboots on Nitro instances |
| `collect_list` | Each file to ship: path, log group, and stream name (`{instance_id}` = one stream per server) |

**Console:** **Systems Manager → Parameter Store → Create parameter** → Name `AmazonCloudWatch-linux-basic`, Tier **Standard**, Type **String** → paste the JSON → **Create parameter**.

**CLI:** save the JSON above as `cw-agent-config.json`, then:

```bash
# create the log group first, with a retention, so it never grows forever
aws logs create-log-group --log-group-name /my-app/app
aws logs put-retention-policy --log-group-name /my-app/app --retention-in-days 14

aws ssm put-parameter --name AmazonCloudWatch-linux-basic --type String \
  --value file://cw-agent-config.json --overwrite
```

> **Note:** Keep the `AmazonCloudWatch-` prefix: `CloudWatchAgentServerPolicy` only lets the agent read parameters with that prefix. The agent can also set retention itself (`retention_in_days` in the config), but then its role needs the extra `logs:PutRetentionPolicy` permission, so we create the log group ourselves.

### 2b. Install and start the agent

**Console:** **Systems Manager → Run Command → Run command**:
1. Document **AWS-ConfigureAWSPackage** → Action **Install**, Name `AmazonCloudWatchAgent` → **Targets**: choose your instance → **Run**. Wait for **Success**.
2. **Run command** again → Document **AmazonCloudWatch-ManageAgent** → Action **configure**, Mode **ec2**, Optional Configuration Source **ssm**, Optional Configuration Location `AmazonCloudWatch-linux-basic`, Optional Restart **yes** → your instance → **Run**.

**CLI:**

```bash
CMD_ID=$(aws ssm send-command --document-name AWS-ConfigureAWSPackage --instance-ids $INSTANCE_ID \
  --parameters '{"action":["Install"],"name":["AmazonCloudWatchAgent"]}' \
  --query Command.CommandId --output text)
aws ssm wait command-executed --command-id $CMD_ID --instance-id $INSTANCE_ID

CMD_ID=$(aws ssm send-command --document-name AmazonCloudWatch-ManageAgent --instance-ids $INSTANCE_ID \
  --parameters '{"action":["configure"],"mode":["ec2"],"optionalConfigurationSource":["ssm"],"optionalConfigurationLocation":["AmazonCloudWatch-linux-basic"],"optionalRestart":["yes"]}' \
  --query Command.CommandId --output text)
aws ssm wait command-executed --command-id $CMD_ID --instance-id $INSTANCE_ID

# after 2-3 minutes the new metrics appear
aws cloudwatch list-metrics --namespace CWAgent \
  --query 'Metrics[].[MetricName,Dimensions[0].Value]' --output table
```

To check the agent from inside the server, open a shell with `aws ssm start-session --target $INSTANCE_ID` and run:

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a status
sudo tail -n 50 /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log
```

**Production tip:** use a Systems Manager **State Manager association** with the same two documents, targeted by tag. Every new instance then gets the agent and the config automatically. If you change the parameter later, run **AmazonCloudWatch-ManageAgent** (configure) again.

AWS docs: [Install the agent with Systems Manager](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/installing-cloudwatch-agent-ssm.html) · [Agent configuration file](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Agent-Configuration-File-Details.html)

## Step 3: Publish a custom metric

> **In simple words:** AWS can't know your business numbers: orders per minute, jobs waiting in a queue, failed logins. You can send any number yourself with **`put-metric-data`**, and then graph and alarm on it like any AWS metric.

```bash
# one value
aws cloudwatch put-metric-data --namespace MyApp --metric-name OrdersPlaced \
  --dimensions Environment=dev --value 5 --unit Count

# a few values, one per minute, so the graph has something to show
for i in 1 2 3 4 5; do
  aws cloudwatch put-metric-data --namespace MyApp --metric-name QueueDepth \
    --dimensions Environment=dev --value $((RANDOM % 50)) --unit Count
  sleep 60
done

aws cloudwatch list-metrics --namespace MyApp --output table
```

Then **CloudWatch → Metrics → All metrics → Custom namespaces → MyApp** shows them.

| Good to know | Why it matters |
|---|---|
| Each unique **namespace + name + dimensions** is one metric | `Environment=dev` and `Environment=prod` are **two** metrics, billed separately |
| Never use user IDs, request IDs or IPs as dimension values | Thousands of values = thousands of paid metrics |
| `--storage-resolution 1` | A high-resolution metric (per second); costs more, kept only 3 hours at that detail |
| From code, prefer the SDK or the **Embedded Metric Format** (EMF) | EMF writes metrics inside structured log lines, with no extra API calls |

AWS docs: [Publish custom metrics](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/publishingMetrics.html)

## Step 4: Create a CPU alarm that emails you

> **In simple words:** An alarm watches one metric and asks, every period, "is it over the line?". When enough periods break the line, it switches to **ALARM** and sends a message to your SNS topic. When things are normal again it switches back to **OK** and can tell you that too.

### Alarm states

| State | Meaning |
|---|---|
| `OK` | The metric is within the threshold |
| `ALARM` | The metric broke the threshold for enough data points |
| `INSUFFICIENT_DATA` | Not enough data to decide: just created, the metric has no data, or the dimensions are wrong |

### Period, evaluation periods and datapoints to alarm

```text
 Period = 5 min, Evaluation periods = 3, Datapoints to alarm = 2

 period:    1      2      3        threshold = 70%
 CPU:      85%    40%    90%
 breach?    ✗      ✓      ✗        2 of last 3 breached → ALARM
```

| Setting | Meaning | Example |
|---|---|---|
| **Period** | Length of one data point | 300 seconds |
| **Evaluation periods** (N) | How many recent periods to look at | 3 (= 15 minutes) |
| **Datapoints to alarm** (M) | How many of those must breach ("M out of N") | 2 |
| **Threshold + comparison** | The line, and which side is bad | `>= 70` |

"2 out of 3" ignores a single spike but still catches real problems quickly.

**Console:** **CloudWatch → Alarms → All alarms → Create alarm → Select metric** → **EC2 → Per-Instance Metrics** → `CPUUtilization` of your instance → **Select metric**. Statistic **Average**, Period **5 minutes**. Conditions: **Static**, **Greater/Equal**, `70`. Open **Additional configuration**: Datapoints to alarm **2 out of 3**, Missing data treatment **Treat missing data as missing** → **Next**. Notification: **In alarm** → **Select an existing SNS topic** → `cw-lab-alerts`; choose **Add notification** and repeat for **OK** → **Next** → Name `cw-lab-high-cpu` → **Create alarm**.

**CLI:**

```bash
aws cloudwatch put-metric-alarm --alarm-name cw-lab-high-cpu \
  --alarm-description "EC2 CPU >= 70% in 2 of the last 3 five-minute periods" \
  --namespace AWS/EC2 --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=$INSTANCE_ID \
  --statistic Average --period 300 \
  --evaluation-periods 3 --datapoints-to-alarm 2 \
  --threshold 70 --comparison-operator GreaterThanOrEqualToThreshold \
  --treat-missing-data missing \
  --alarm-actions $TOPIC_ARN --ok-actions $TOPIC_ARN

# memory alarm on the agent metric; "breaching" = no data (agent dead) also alerts
aws cloudwatch put-metric-alarm --alarm-name cw-lab-high-memory \
  --alarm-description "Memory used > 85%, or the CloudWatch agent stopped sending" \
  --namespace CWAgent --metric-name mem_used_percent \
  --dimensions Name=InstanceId,Value=$INSTANCE_ID \
  --statistic Average --period 300 --evaluation-periods 3 --datapoints-to-alarm 3 \
  --threshold 85 --comparison-operator GreaterThanThreshold \
  --treat-missing-data breaching \
  --alarm-actions $TOPIC_ARN --ok-actions $TOPIC_ARN
```

**Test it** without stressing the server: force the state, check your inbox, and watch it return to its real state at the next evaluation.

```bash
aws cloudwatch set-alarm-state --alarm-name cw-lab-high-cpu \
  --state-value ALARM --state-reason "Testing the email notification"

aws cloudwatch describe-alarms --alarm-names cw-lab-high-cpu cw-lab-high-memory \
  --query 'MetricAlarms[].[AlarmName,StateValue,StateReason]' --output table
aws cloudwatch describe-alarm-history --alarm-name cw-lab-high-cpu --history-item-type StateUpdate \
  --query 'AlarmHistoryItems[].[Timestamp,HistorySummary]' --output table
```

### Treat missing data: choose on purpose

| Option | Missing data points are… | Use it for |
|---|---|---|
| `missing` (default) | Ignored; if **all** are missing, the alarm goes to `INSUFFICIENT_DATA` | Most metrics that report all the time |
| `notBreaching` | Treated as **good** | Error counts that only report when errors happen (e.g. 5XX counts) |
| `breaching` | Treated as **bad** | "Heartbeat" metrics: no data means the sender is dead (agent, log shipper, batch job) |
| `ignore` | The current state is kept | Metrics that report rarely |

Alarm actions can also **stop, terminate, reboot or recover** an EC2 instance, or trigger an Auto Scaling policy. AWS recommends treating missing data as `missing` for alarms that take those EC2 actions.

### Composite alarms: fewer, smarter emails

A **composite alarm** combines other alarms with `AND`, `OR` and `NOT`. A common pattern: the child alarms have **no actions**, and only the composite one notifies.

**Console:** **Alarms** → tick `cw-lab-high-cpu` and `cw-lab-high-memory` → **Create composite alarm** → condition `ALARM(...) AND ALARM(...)` → notification to `cw-lab-alerts` → name `cw-lab-server-in-trouble` → **Create**.

```bash
aws cloudwatch put-composite-alarm --alarm-name cw-lab-server-in-trouble \
  --alarm-rule 'ALARM("cw-lab-high-cpu") AND ALARM("cw-lab-high-memory")' \
  --alarm-actions $TOPIC_ARN
```

### Useful alarms to start with

| Service | Metric (namespace) | Statistic and threshold idea | Why |
|---|---|---|---|
| EC2 | `CPUUtilization` (`AWS/EC2`) | Average >= 80% for 15 min | Server overloaded |
| EC2 | `StatusCheckFailed` (`AWS/EC2`) | Maximum >= 1 for 2 min | Hardware or OS problem; can trigger **recover** |
| EC2 | `mem_used_percent`, `disk_used_percent` (`CWAgent`) | Average > 85% / > 80% | Out of memory or disk is a classic outage |
| RDS | `CPUUtilization` (`AWS/RDS`) | Average >= 80% for 15 min | Slow queries or too small an instance |
| RDS | `FreeStorageSpace` | Minimum < 10% of allocated storage | A full disk stops the database |
| RDS / Aurora | `FreeableMemory` | Minimum < about 10% of RAM | Memory pressure, swapping |
| RDS / Aurora | `DatabaseConnections` | Maximum > 80% of `max_connections` | Connection leaks, app scaling too far |
| RDS replicas | `ReplicaLag` (seconds) | Maximum > 60 | Read replica serves old data |
| Aurora | `AuroraReplicaLag` (milliseconds) | Maximum > 1000 | Same, for Aurora readers |
| Aurora | `FreeLocalStorage` | Minimum low | Aurora has no `FreeStorageSpace` (the cluster volume grows by itself); local storage is per instance temp space |
| ALB | `HTTPCode_ELB_5XX_Count` and `HTTPCode_Target_5XX_Count` (`AWS/ApplicationELB`) | Sum > a small number per 5 min, missing = `notBreaching` | Users are getting errors |
| ALB | `TargetResponseTime` | p99 (or Average) > 1 second | The app is slow |
| ALB | `UnHealthyHostCount` (per target group) | **Minimum** >= 1 for 2+ data points | Targets failing health checks |
| ECS | `CPUUtilization`, `MemoryUtilization` (`AWS/ECS`, by `ClusterName` + `ServiceName`) | Average > 80% | Tasks too small, or scale out |
| ECS | `RunningTaskCount` (`ECS/ContainerInsights`) | Minimum < desired count | Tasks crashing; needs Container Insights |

**Container Insights** collects extra cluster, service, task and container metrics for ECS and EKS. Turn it on for an ECS cluster with `aws ecs update-cluster-settings --cluster my-cluster --settings name=containerInsights,value=enhanced` (or `enabled` for the basic version); it has its own charges. For application-level monitoring (request rate, latency, errors per service), CloudWatch also offers **Application Signals**.

AWS docs: [Using alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html) · [Missing data](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/alarms-and-missing-data.html) · [Composite alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Create_Composite_Alarm.html) · [Recommended alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Best_Practice_Recommended_Alarms_AWS_Services.html) · [RDS metrics](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-metrics.html) · [Aurora metrics](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.AuroraMonitoring.Metrics.html) · [ALB metrics](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-cloudwatch-metrics.html) · [ECS metrics](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/available-metrics.html) · [Container Insights](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ContainerInsights.html) · [Application Signals](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Application-Monitoring-Sections.html)

## Step 5: CloudWatch Logs: log groups, streams and retention

> **In simple words:** CloudWatch Logs is a big, searchable notebook. Each app or service gets its own **log group** (a folder), each source inside it writes to a **log stream** (a page per server or container), and **retention** decides when old pages are thrown away.

| Part | Example | Meaning |
|---|---|---|
| **Log group** | `/my-app/app`, `/aws/lambda/my-function` | One app or service. Retention, metric filters, permissions and encryption are set here |
| **Log stream** | `i-0abc…`, an ECS task ID | One source inside the group |
| **Log event** | `2026-11-08T10:00:01Z ERROR payment failed` | One line with a timestamp |
| **Retention** | 1 day … 10 years, or never expire | Older events are deleted automatically |

Many AWS services create log groups for you: Lambda (`/aws/lambda/<name>`), ECS tasks with the `awslogs` driver, VPC Flow Logs, EKS control plane logs, CloudTrail (if you send it to CloudWatch).

Send a few test lines (the agent ships `/var/log/my-app/app.log` the same way):

```bash
aws logs create-log-stream --log-group-name /my-app/app --log-stream-name manual-test

NOW=$(($(date +%s) * 1000))   # milliseconds since 1970
cat > events.json <<EOF
[
  {"timestamp": $NOW, "message": "INFO order 41 placed in 120 ms"},
  {"timestamp": $NOW, "message": "ERROR payment failed for order 42: card declined"},
  {"timestamp": $NOW, "message": "INFO order 43 placed in 95 ms"},
  {"timestamp": $NOW, "message": "ERROR payment failed for order 44: timeout"}
]
EOF
aws logs put-log-events --log-group-name /my-app/app --log-stream-name manual-test \
  --log-events file://events.json

aws logs tail /my-app/app --since 15m                       # print recent lines (add --follow to stream)
aws logs filter-log-events --log-group-name /my-app/app --filter-pattern ERROR \
  --query 'events[].message' --output text

# retention of every log group: "None" means never expire
aws logs describe-log-groups --query 'logGroups[].[logGroupName,retentionInDays,storedBytes]' --output table
```

**Console:** **CloudWatch → Logs → Log groups** → `/my-app/app` → open a stream to read it. **Live Tail** (button on the log group) streams new lines as they arrive.

### Why you should always set retention

| Without retention | With retention |
|---|---|
| Logs are kept **forever** | Old events are deleted automatically |
| Storage cost grows every month | Storage stays flat |
| You may keep personal data longer than your rules allow | You keep exactly what you need (e.g. 30 days, 1 year for audit logs) |

To change it: **Log groups** → the **Retention** column (shows **Never expire**) → choose a value → **Save**, or `aws logs put-retention-policy`. In Terraform, set `retention_in_days` on **every** `aws_cloudwatch_log_group`, and create the Lambda and ECS log groups yourself so they don't appear with "never expire". Deleted or expired logs **can't be recovered**; for long-term archives, export to S3.

AWS docs: [Log groups and streams](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/Working-with-log-groups-and-streams.html)

## Step 6: Search logs with Logs Insights

> **In simple words:** Logs Insights is a search box with a small query language. You pick log groups and a time range, write a query with pipes (`|`), and get a table or a graph. You pay only for the data scanned, so keep the time range short.

**Console:** **CloudWatch → Logs → Logs Insights** → select `/my-app/app` → time range **1h** → paste a query → **Run query**. Use the **Visualization** tab for `stats ... by bin()` queries.

**1. The latest errors**

```text
fields @timestamp, @message, @logStream
| filter @message like /ERROR/
| sort @timestamp desc
| limit 50
```

**2. Errors per 5 minutes (draws a graph)**

```text
filter @message like /ERROR/
| stats count(*) as errors by bin(5m)
```

**3. The most common error messages**

```text
filter @message like /ERROR/
| stats count(*) as hits by @message
| sort hits desc
| limit 10
```

**4. Lambda duration: average, worst and 95th percentile** (run it on a `/aws/lambda/...` log group)

```text
filter @type = "REPORT"
| stats avg(@duration), max(@duration), pct(@duration, 95) by bin(5m)
```

**CLI:** a query runs in the background; start it, then fetch the results.

```bash
QUERY_ID=$(aws logs start-query --log-group-name /my-app/app \
  --start-time $(($(date +%s) - 3600)) --end-time $(date +%s) \
  --query-string 'filter @message like /ERROR/ | stats count(*) as errors by bin(5m)' \
  --query queryId --output text)
sleep 5
aws logs get-query-results --query-id $QUERY_ID
```

| Part | Meaning |
|---|---|
| `fields` | Which fields to show. `@timestamp`, `@message`, `@logStream` always exist |
| `filter` | Keep only matching lines (`like /regex/`, `=`, `>`…) |
| `stats … by bin(5m)` | Count, sum, average per time bucket |
| `parse` | Pull values out of text: `parse @message "placed in * ms" as ms` |
| `sort`, `limit` | Order and cut the result |

AWS docs: [Logs Insights](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/AnalyzingLogData.html) · [Query syntax](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html)

## Step 7: Metric filters: alarm on ERROR lines

> **In simple words:** Logs Insights answers questions **when you ask**. A **metric filter** watches **all the time**: every log line that matches a pattern adds 1 to a metric. Put an alarm on that metric and you get an email when errors pile up.

**Console:** **Log groups** → `/my-app/app` → **Metric filters** tab → **Create metric filter** → Filter pattern `ERROR` → **Test pattern** → **Next** → Filter name `error-count`, Metric namespace `MyApp`, Metric name `ErrorCount`, Metric value `1`, Default value `0` → **Next** → **Create metric filter**. Then tick the filter → **Create alarm**.

**CLI:**

```bash
aws logs put-metric-filter --log-group-name /my-app/app --filter-name error-count \
  --filter-pattern "ERROR" \
  --metric-transformations metricName=ErrorCount,metricNamespace=MyApp,metricValue=1,defaultValue=0

aws cloudwatch put-metric-alarm --alarm-name cw-lab-app-errors \
  --alarm-description "5 or more ERROR lines in 5 minutes" \
  --namespace MyApp --metric-name ErrorCount \
  --statistic Sum --period 300 --evaluation-periods 1 \
  --threshold 5 --comparison-operator GreaterThanOrEqualToThreshold \
  --treat-missing-data notBreaching \
  --alarm-actions $TOPIC_ARN

# filters only count NEW lines: send the test events again (3 times = 6 errors)
for i in 1 2 3; do
  NOW=$(($(date +%s) * 1000))
  sed -E "s/\"timestamp\": [0-9]+/\"timestamp\": $NOW/" events.json > events-now.json
  aws logs put-log-events --log-group-name /my-app/app --log-stream-name manual-test \
    --log-events file://events-now.json
done
```

Within a few minutes the alarm goes to `ALARM` and you get an email.

| Filter pattern | Matches |
|---|---|
| `ERROR` | Lines containing the word `ERROR` (case-sensitive) |
| `?ERROR ?Exception` | Lines with `ERROR` **or** `Exception` |
| `"payment failed"` | The exact phrase |
| `{ $.level = "error" }` | JSON logs whose `level` field is `error` |

> **Warning:** Metric filters create **custom metrics** (paid). Don't add dimensions with many values (user IDs, IPs, request IDs): each value becomes a separate metric. A log group can have up to 100 metric filters, and filters never look at old log lines.

AWS docs: [Metric filters](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/MonitoringLogData.html)

## Step 8: Subscription filters: stream logs somewhere else (optional)

> **In simple words:** A metric filter **counts** lines. A **subscription filter** **forwards** the matching lines, in near real time, to another service: a Lambda function, Amazon Data Firehose, Kinesis Data Streams or OpenSearch. Use it to send logs to a search cluster, an archive in S3, or a tool that posts errors to chat.

| Destination | Typical use |
|---|---|
| **AWS Lambda** | Small custom actions, e.g. post each ERROR to a chat channel (see [Lambda and EventBridge](#/tool/aws-lambda)) |
| **Amazon Data Firehose** | Deliver logs to S3, OpenSearch or a third-party tool, in batches (see [Firehose and OpenSearch](#/tool/aws-opensearch)) |
| **Kinesis Data Streams** | Many consumers reading the same log stream |
| **OpenSearch Service** | Full-text search and log dashboards |

Each log group can have **up to 2** subscription filters. Lambda receives the data **gzip-compressed and base64-encoded** in the `awslogs.data` field. Example for an existing Lambda function called `my-log-processor`:

```bash
aws lambda add-permission --function-name my-log-processor --statement-id cwlogs-my-app \
  --principal logs.amazonaws.com --action lambda:InvokeFunction \
  --source-arn "arn:aws:logs:$AWS_REGION:$ACCOUNT_ID:log-group:/my-app/app:*"

aws logs put-subscription-filter --log-group-name /my-app/app --filter-name errors-to-lambda \
  --filter-pattern "ERROR" \
  --destination-arn "arn:aws:lambda:$AWS_REGION:$ACCOUNT_ID:function:my-log-processor"
```

For Firehose and Kinesis you also pass `--role-arn`: an IAM role that `logs.amazonaws.com` can assume, with permission to put records into the stream.

AWS docs: [Subscription filters](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/SubscriptionFilters.html)

## Step 9: Build a dashboard

> **In simple words:** A dashboard puts the graphs that matter on one page, so during an incident everyone looks at the same picture. Build it by clicking once, then save its JSON so it can be recreated with one command (or with Terraform).

**Console:** **CloudWatch → Dashboards → Create dashboard** → name `cw-lab` → **Create dashboard** → widget type **Line** → **Metrics** → **EC2 → Per-Instance Metrics** → `CPUUtilization` → **Create widget**. Add a **Number** widget for `MyApp → ErrorCount` and an **Alarm status** widget with your alarms → **Save**. To see the JSON: **Actions → View/edit source**.

**Automatic dashboards** (under **Dashboards → Automatic dashboards**) are free and ready-made for each AWS service you use: a good place to start.

**CLI:**

```bash
cat > dashboard.json <<EOF
{
  "widgets": [
    {"type": "metric", "x": 0, "y": 0, "width": 12, "height": 6,
     "properties": {"title": "EC2 CPU %", "region": "$AWS_REGION", "stat": "Average", "period": 300,
       "view": "timeSeries", "metrics": [["AWS/EC2", "CPUUtilization", "InstanceId", "$INSTANCE_ID"]]}},
    {"type": "metric", "x": 12, "y": 0, "width": 12, "height": 6,
     "properties": {"title": "Memory used %", "region": "$AWS_REGION", "stat": "Average", "period": 300,
       "view": "timeSeries", "metrics": [["CWAgent", "mem_used_percent", "InstanceId", "$INSTANCE_ID"]]}},
    {"type": "metric", "x": 0, "y": 6, "width": 12, "height": 6,
     "properties": {"title": "App errors (5 min)", "region": "$AWS_REGION", "stat": "Sum", "period": 300,
       "view": "singleValue", "metrics": [["MyApp", "ErrorCount"]]}},
    {"type": "alarm", "x": 12, "y": 6, "width": 12, "height": 6,
     "properties": {"title": "Alarms", "alarms": [
       "arn:aws:cloudwatch:$AWS_REGION:$ACCOUNT_ID:alarm:cw-lab-high-cpu",
       "arn:aws:cloudwatch:$AWS_REGION:$ACCOUNT_ID:alarm:cw-lab-high-memory",
       "arn:aws:cloudwatch:$AWS_REGION:$ACCOUNT_ID:alarm:cw-lab-app-errors"]}}
  ]
}
EOF
aws cloudwatch put-dashboard --dashboard-name cw-lab --dashboard-body file://dashboard.json
aws cloudwatch list-dashboards --query 'DashboardEntries[].DashboardName'
```

`put-dashboard` replaces the whole dashboard and prints `DashboardValidationMessages` if something is wrong. The grid is **24 units wide**; `x`, `y`, `width` and `height` place each widget.

> **Cost:** The first 3 dashboards (up to 50 metrics each) are free, then **$3 per dashboard per month**. Log-query widgets also run a Logs Insights query (and cost) every time the dashboard loads.

AWS docs: [Dashboards](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Dashboards.html) · [Dashboard body structure](https://docs.aws.amazon.com/AmazonCloudWatch/latest/APIReference/CloudWatch-Dashboard-Body-Structure.html)

## Step 10: React to AWS events with EventBridge

> **In simple words:** Metrics tell you **how much**; events tell you **that something happened**: an instance stopped, someone opened a port in a security group. **Amazon EventBridge** (formerly CloudWatch Events) matches those events with a **rule** and sends them to a **target**, here our SNS topic.

This is what an EC2 state-change event looks like. A rule's **event pattern** lists the fields and values to match:

```json
{
  "source": "aws.ec2",
  "detail-type": "EC2 Instance State-change Notification",
  "region": "us-east-1",
  "account": "111111111111",
  "resources": ["arn:aws:ec2:us-east-1:111111111111:instance/i-0123456789abcdef0"],
  "detail": { "instance-id": "i-0123456789abcdef0", "state": "stopped" }
}
```

### 10a. Allow EventBridge to publish to the topic

CloudWatch alarms can publish to the topic already, but EventBridge needs a statement in the **topic's access policy**. The console adds it for you when you pick an SNS target; with the CLI, add it yourself:

```bash
aws sns get-topic-attributes --topic-arn $TOPIC_ARN --query Attributes.Policy --output text > topic-policy.json
python3 - "$TOPIC_ARN" <<'EOF'
import json, sys
policy = json.load(open("topic-policy.json"))
policy["Statement"].append({
    "Sid": "AllowEventBridgePublish",
    "Effect": "Allow",
    "Principal": {"Service": "events.amazonaws.com"},
    "Action": "sns:Publish",
    "Resource": sys.argv[1],
})
json.dump(policy, open("topic-policy.json", "w"))
EOF
aws sns set-topic-attributes --topic-arn $TOPIC_ARN --attribute-name Policy \
  --attribute-value file://topic-policy.json
```

### 10b. Rule 1: tell me when an instance stops or terminates

**Console:** **EventBridge → Rules → Create rule** → Name `cw-lab-ec2-stopped`, Event bus **default**, **Rule with an event pattern** → **Next** → Event source **AWS events or EventBridge partner events** → **AWS service** `EC2`, **Event type** `EC2 Instance State-change Notification`, **Specific state(s)** `stopped`, `terminated` → **Next** → Target **AWS service → SNS topic** → `cw-lab-alerts` → **Next** → **Create rule**.

**CLI:**

```bash
aws events put-rule --name cw-lab-ec2-stopped \
  --event-pattern '{"source":["aws.ec2"],"detail-type":["EC2 Instance State-change Notification"],"detail":{"state":["stopped","terminated"]}}'
aws events put-targets --rule cw-lab-ec2-stopped --targets "Id=sns,Arn=$TOPIC_ARN"

# test: stop the instance, wait for the email, start it again
aws ec2 stop-instances --instance-ids $INSTANCE_ID
aws ec2 wait instance-stopped --instance-ids $INSTANCE_ID
aws ec2 start-instances --instance-ids $INSTANCE_ID
```

### 10c. Rule 2: tell me when a security group changes

Security group changes are **API calls**, which EventBridge receives from **CloudTrail** with the detail type `AWS API Call via CloudTrail`. This needs a **CloudTrail trail that is logging management events** in the account (create one under **CloudTrail → Trails** if you don't have one).

```bash
cat > sg-pattern.json <<'EOF'
{
  "source": ["aws.ec2"],
  "detail-type": ["AWS API Call via CloudTrail"],
  "detail": {
    "eventSource": ["ec2.amazonaws.com"],
    "eventName": ["AuthorizeSecurityGroupIngress", "RevokeSecurityGroupIngress",
                  "AuthorizeSecurityGroupEgress", "RevokeSecurityGroupEgress",
                  "ModifySecurityGroupRules"]
  }
}
EOF
aws events put-rule --name cw-lab-sg-changed --event-pattern file://sg-pattern.json
aws events put-targets --rule cw-lab-sg-changed --targets "Id=sns,Arn=$TOPIC_ARN"
```

The email contains the raw event JSON, including **who** made the change (`detail.userIdentity`) and **what** changed (`detail.requestParameters`). An **input transformer** on the target can turn it into a short sentence.

| Other useful rules | Event pattern idea |
|---|---|
| Root user signed in to the console | `detail-type`: `AWS Console Sign In via CloudTrail`, `detail.userIdentity.type`: `Root` |
| An alarm changed state | `source`: `aws.cloudwatch`, `detail-type`: `CloudWatch Alarm State Change` |
| An ECS task stopped | `source`: `aws.ecs`, `detail-type`: `ECS Task State Change`, `detail.lastStatus`: `STOPPED` |

AWS docs: [EC2 state change events](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/monitoring-instance-state-changes.html) · [Events delivered via CloudTrail](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-service-event-cloudtrail.html) · [EventBridge troubleshooting](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-troubleshooting.html)

## Troubleshooting

> **In simple words:** Most CloudWatch problems are a name that doesn't match exactly (namespace, metric, dimensions, Region), a missing permission, or an email subscription nobody confirmed.

| Problem | Likely cause | Fix |
|---|---|---|
| Alarm stuck in `INSUFFICIENT_DATA` | Dimensions don't match **exactly** (missing or extra dimension, typo, wrong instance ID); wrong namespace or Region; the period is shorter than the metric's interval (60 s on a 5-minute basic metric) | Copy the exact names from `aws cloudwatch list-metrics`; use a period of 300 s for basic monitoring |
| Error-count alarm always `INSUFFICIENT_DATA` | The metric only has data when errors happen | Set **treat missing data** to `notBreaching`, or give the metric filter `defaultValue=0` |
| No memory or disk metric | Not built in for EC2; agent not installed or not running; role lacks `CloudWatchAgentServerPolicy` | Install the agent (Step 2); run `amazon-cloudwatch-agent-ctl -a status`; read the agent log |
| Agent fails to load its config | Parameter name without the `AmazonCloudWatch-` prefix, wrong name, invalid JSON, or a different Region | Fix the parameter, then run **AmazonCloudWatch-ManageAgent** (configure) again |
| Agent metrics have extra dimensions | Default configs add `ImageId`, `InstanceType`, `AutoScalingGroupName` | The alarm must list **all** dimensions, or remove them from `append_dimensions` |
| No email from SNS | Subscription still `PendingConfirmation` (check spam); no action for that state; topic encrypted with a KMS key that CloudWatch or EventBridge may not use | Confirm the subscription; add `--alarm-actions`/`--ok-actions`; allow the service in the key policy |
| EventBridge rule matches but no email | Topic policy doesn't allow `events.amazonaws.com` | Add the statement from Step 10a; check the rule's `FailedInvocations` metric |
| Security-group rule never fires | No CloudTrail trail logging management events; the rule is in another Region | Create a trail; create the rule in the Region where the change happens |
| Log file not appearing | Wrong `file_path`; agent can't read the file; role lacks `logs:CreateLogStream`/`logs:PutLogEvents`; looking in another Region | Check the path and permissions; read the agent log |
| Old logs are gone | Retention deleted them (that's its job) | Choose a longer retention, or export to S3 for archives |
| Lambda has no logs | Execution role lacks the `AWSLambdaBasicExecutionRole` permissions | Attach the policy (see the [IAM guide](#/tool/aws-iam)) |
| Metric filter shows nothing | Filters only count lines **after** creation; the pattern is case-sensitive | Send new log lines; test the pattern in the console |
| Bill higher than expected | Debug logs ingested at $0.50/GB, never-expire log groups, high-cardinality custom metrics, Logs Insights over long ranges | Lower log levels, set retention, remove unneeded dimensions; check **Cost Explorer** by usage type |

AWS docs: [Troubleshooting the CloudWatch agent](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/troubleshooting-CloudWatch-Agent.html)

## Clean up

> **In simple words:** Delete everything in reverse order: rules, alarms (the composite one first), dashboard, filters and logs, the instance and its role, and the SNS topic last. Custom metrics can't be deleted, but they cost nothing once you stop sending data.

```bash
# EventBridge rules (targets first)
for RULE in cw-lab-ec2-stopped cw-lab-sg-changed; do
  aws events remove-targets --rule $RULE --ids sns
  aws events delete-rule --name $RULE
done

# alarms: the composite alarm before the alarms it uses
aws cloudwatch delete-alarms --alarm-names cw-lab-server-in-trouble
aws cloudwatch delete-alarms --alarm-names cw-lab-high-cpu cw-lab-high-memory cw-lab-app-errors

# dashboard, filters, log group, agent config
aws cloudwatch delete-dashboards --dashboard-names cw-lab
aws logs delete-subscription-filter --log-group-name /my-app/app --filter-name errors-to-lambda 2>/dev/null
aws logs delete-metric-filter --log-group-name /my-app/app --filter-name error-count
aws logs delete-log-group --log-group-name /my-app/app
aws ssm delete-parameter --name AmazonCloudWatch-linux-basic

# instance and its role
aws ec2 terminate-instances --instance-ids $INSTANCE_ID
aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID
aws iam remove-role-from-instance-profile --instance-profile-name cw-lab-ec2-role --role-name cw-lab-ec2-role
aws iam delete-instance-profile --instance-profile-name cw-lab-ec2-role
aws iam detach-role-policy --role-name cw-lab-ec2-role --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
aws iam detach-role-policy --role-name cw-lab-ec2-role --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
aws iam delete-role --role-name cw-lab-ec2-role

# SNS topic (also removes its subscriptions) and local files
aws sns delete-topic --topic-arn $TOPIC_ARN
rm -f ec2-trust.json cw-agent-config.json events.json events-now.json dashboard.json topic-policy.json sg-pattern.json
```

If you created a CloudTrail trail only for this lab, delete it under **CloudTrail → Trails** (and its S3 bucket). In real projects, define alarms, log groups (with retention), dashboards and rules in **Terraform** (`aws_cloudwatch_metric_alarm`, `aws_cloudwatch_log_group`, `aws_cloudwatch_dashboard`, `aws_cloudwatch_event_rule`). See the [Terraform guide](#/tool/terraform).

## Lab and cheat sheet

> **In simple words:** Practice time: collect metrics and logs from one server, alarm on them, break things on purpose, and check that every alert actually reaches you.

1. Create the SNS topic, confirm the email, and launch the lab instance with the agent role.
2. Install the CloudWatch agent with Systems Manager and find `mem_used_percent` and `disk_used_percent` in the `CWAgent` namespace.
3. Publish a custom metric `MyApp/QueueDepth` for 5 minutes and graph it with **Maximum** and **Average**.
4. Create the CPU alarm, force it into `ALARM` with `set-alarm-state`, and receive both the ALARM and the OK emails.
5. **Break it:** stop the agent in a Session Manager shell (`sudo systemctl stop amazon-cloudwatch-agent`). The memory alarm goes to `ALARM` because missing data is `breaching`. Start it again.
6. Write 4 Logs Insights queries: latest errors, errors per 5 minutes, top error messages, and one with `parse`.
7. Create the `ERROR` metric filter and alarm, send 6 error lines, and get the email.
8. Build the `cw-lab` dashboard with `put-dashboard`, then change one widget in the console and compare the JSON.
9. Create the EC2 state-change rule, stop the instance, and read the event in your inbox.
10. List all log groups with retention `None` (never expire) in your account and set a retention on each.
11. Clean up everything and check **Alarms**, **Dashboards** and **Log groups** are empty of `cw-lab` items.

### Cheat sheet

| Task | Command |
|---|---|
| List metrics | `aws cloudwatch list-metrics --namespace AWS/EC2` |
| Read a metric | `aws cloudwatch get-metric-statistics --namespace NS --metric-name M --dimensions Name=K,Value=V --start-time T1 --end-time T2 --period 300 --statistics Average` |
| Send a custom metric | `aws cloudwatch put-metric-data --namespace MyApp --metric-name M --value 5 --unit Count` |
| Detailed monitoring on | `aws ec2 monitor-instances --instance-ids I` |
| Create or update an alarm | `aws cloudwatch put-metric-alarm --alarm-name A --namespace NS --metric-name M --statistic Average --period 300 --evaluation-periods 3 --threshold 80 --comparison-operator GreaterThanThreshold --alarm-actions TOPIC` |
| Test an alarm | `aws cloudwatch set-alarm-state --alarm-name A --state-value ALARM --state-reason test` |
| Alarm states | `aws cloudwatch describe-alarms --state-value ALARM` |
| Composite alarm | `aws cloudwatch put-composite-alarm --alarm-name A --alarm-rule 'ALARM("x") AND ALARM("y")'` |
| Set log retention | `aws logs put-retention-policy --log-group-name G --retention-in-days 30` |
| Follow logs | `aws logs tail G --follow` |
| Search logs | `aws logs filter-log-events --log-group-name G --filter-pattern ERROR` |
| Logs Insights query | `aws logs start-query ...` then `aws logs get-query-results --query-id Q` |
| Metric filter | `aws logs put-metric-filter --log-group-name G --filter-name F --filter-pattern ERROR --metric-transformations metricName=ErrorCount,metricNamespace=MyApp,metricValue=1,defaultValue=0` |
| Dashboard | `aws cloudwatch put-dashboard --dashboard-name D --dashboard-body file://dashboard.json` |
| EventBridge rule | `aws events put-rule --name R --event-pattern file://pattern.json` + `aws events put-targets --rule R --targets Id=sns,Arn=TOPIC` |
| Agent status (on the server) | `sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a status` |

**Next:** send alerts to chat and email in the [SNS and SES guide](#/tool/aws-sns-ses), automate fixes with [Lambda and EventBridge](#/tool/aws-lambda), and add these alarms to your [RDS](#/tool/aws-rds), [load balancer](#/tool/aws-elb) and [ECS](#/tool/aws-ecs) setups.
