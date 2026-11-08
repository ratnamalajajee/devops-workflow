# Python Interview Programs for DevOps & SRE

Practical Python programs that DevOps and SRE interviews ask for, organised by level: **basics** (logs, disks, files, URLs), **intermediate** (CPU and memory, processes, ports, commands, live logs), **AWS with boto3**, **Kubernetes**, and **advanced SRE scenarios**. Every program comes with how to run it, sample input, expected output, its real-world use, and the follow-up questions interviewers ask.

> **Note:** For the syntax and module details behind these programs, keep the [Python Basics & Module Cheat Sheet](#/tool/python-basics) open. Two more coding questions with full explanations (unique actions per user in a large CSV, and reversing a sentence and counting vowels) are in [Python for DevOps → Coding interview questions](#/tool/python-devops/coding-interview-questions).

## Start here: how to run these programs

> **In simple words:** Save each program as a `.py` file, run it with `python3 file.py`, and install the few extra packages some of them need. Create the small sample files shown, so you can see the expected output on your own machine.

### One-time setup

```bash
mkdir -p ~/code/py-interview && cd ~/code/py-interview
python3 -m venv .venv
source .venv/bin/activate                 # Windows PowerShell: .venv\Scripts\Activate.ps1
pip install requests psutil boto3 kubernetes
```

| Programs | Extra package | Also needs |
|---|---|---|
| 1–4, 8–10 | none (standard library) | |
| 5 | `requests` | Internet access |
| 6, 7 | `psutil` | |
| 11–13, 17, 18 | `boto3` | AWS credentials: `aws sts get-caller-identity` must work |
| 14–16 | `kubernetes` | A cluster in `~/.kube/config`: `kubectl get pods` must work |

### Running a program

```bash
nano find_duplicate_ips.py               # or create the file in VS Code; paste the program
python3 find_duplicate_ips.py            # run it
python3 disk_usage.py / 80               # programs that take arguments
echo $?                                  # exit code: 0 = OK, 1 = problem found (useful for cron and CI)
```

Run a monitoring program every 5 minutes with cron (use absolute paths):

```bash
*/5 * * * * /home/ops/code/py-interview/.venv/bin/python /home/ops/code/py-interview/disk_usage.py / 80 >> /var/log/disk_check.log 2>&1
```

### How to answer in an interview

1. **Repeat the problem** and ask about edge cases: an empty file, huge input, a missing host, permissions.
2. **Write the simple working version first**, then improve it.
3. **Handle errors**: missing files, timeouts, bad input. Return a non-zero exit code on failure.
4. **Mention scale**: read files line by line, use pagination for AWS, add timeouts on the network.
5. **Say how you'd run it in production**: cron or a Kubernetes CronJob, logging, alerting, IAM roles instead of keys.

## Level 1: basics

> **In simple words:** Five short programs on files, logs, disk and HTTP. These are the most common warm-up questions, and every one of them is a real task in day-to-day operations.

### 1. Find duplicate IP addresses

**Scenario:** You have a list of IP addresses from application logs. Identify the duplicates.

`find_duplicate_ips.py`:

```python
from collections import Counter

ips = ["10.0.0.1", "10.0.0.2", "10.0.0.1", "10.0.0.3", "10.0.0.2"]

# Approach 1: two sets. O(n) time
seen = set()
duplicates = set()
for ip in ips:
    if ip in seen:
        duplicates.add(ip)
    else:
        seen.add(ip)
print("Duplicate IPs:", sorted(duplicates))

# Approach 2: Counter, which also tells you HOW MANY times each appears
counts = Counter(ips)
print("Repeat counts:", {ip: n for ip, n in counts.items() if n > 1})
```

**Run:** `python3 find_duplicate_ips.py`

**Expected output:**

```text
Duplicate IPs: ['10.0.0.1', '10.0.0.2']
Repeat counts: {'10.0.0.1': 2, '10.0.0.2': 2}
```

**DevOps use:** spotting repeated client IPs, analysing network logs, detecting suspicious traffic such as brute-force attempts.

**Follow-ups:** *"Read the IPs from a 10 GB access log?"* Loop over the file line by line and take `line.split()[0]`. *"Why `sorted()`?"* Sets have no order, so sorting makes the output predictable.

### 2. Count ERROR and WARNING messages in a log

**Scenario:** The application is failing. Count the errors and warnings in its log.

`count_log_levels.py`:

```python
import sys

log_file = sys.argv[1] if len(sys.argv) > 1 else "application.log"
error_count = 0
warning_count = 0

try:
    with open(log_file) as file:
        for line in file:                   # line by line: works for huge files
            if "ERROR" in line:
                error_count += 1
            elif "WARNING" in line:
                warning_count += 1
except FileNotFoundError:
    sys.exit(f"Log file not found: {log_file}")

print("Errors:", error_count)
print("Warnings:", warning_count)
```

**Run:**

```bash
cat > application.log <<'EOF'
INFO Application started
ERROR Database connection failed
WARNING CPU usage is high
ERROR API request failed
INFO Application recovered
EOF
python3 count_log_levels.py application.log
```

**Expected output:**

```text
Errors: 2
Warnings: 1
```

**DevOps use:** automated log analysis, finding failures after a deployment, alerting when errors exceed a threshold.

**Follow-ups:** *"A message text contains the word ERROR but the level is INFO?"* Match the level field only: `line.split()[0] == "ERROR"`, or a regex such as `r"^\S+ \S+ (ERROR|WARNING)"` for timestamped logs. *"Count every level?"* `Counter(line.split()[0] for line in file if line.strip())`.

### 3. Check disk utilization

**Scenario:** Monitor a Linux server's disk usage and warn above a threshold.

`disk_usage.py`:

```python
import shutil
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "/"
threshold = float(sys.argv[2]) if len(sys.argv) > 2 else 80

total, used, free = shutil.disk_usage(path)
usage = used / total * 100
print(f"Disk usage on {path}: {usage:.2f}% (free {free / 2**30:.1f} GiB)")

if usage > threshold:
    print(f"WARNING: disk usage is above {threshold:.0f}%")
    sys.exit(1)                 # non-zero exit code lets cron, CI or monitoring react
print("Disk usage is normal")
```

**Run:** `python3 disk_usage.py / 80`

**Expected output** (numbers vary):

```text
Disk usage on /: 43.17% (free 52.3 GiB)
Disk usage is normal
```

**DevOps use:** server monitoring, disk alerts, preventing "disk full" incidents.

**Follow-ups:** *"Check every mounted filesystem?"* `psutil.disk_partitions()`, then `psutil.disk_usage(p.mountpoint)` for each. *"Send an alert?"* POST to a Slack or Teams webhook with `requests`.

### 4. Find files older than 7 days

**Scenario:** Application logs are filling the disk. Find old log files.

`old_files.py`:

```python
import sys
import time
from pathlib import Path

directory = Path(sys.argv[1] if len(sys.argv) > 1 else "/var/log/myapp")
days = int(sys.argv[2]) if len(sys.argv) > 2 else 7
cutoff = time.time() - days * 24 * 60 * 60

if not directory.is_dir():
    sys.exit(f"Not a directory: {directory}")

total = 0
for path in directory.iterdir():
    if path.is_file() and path.stat().st_mtime < cutoff:
        size = path.stat().st_size
        total += size
        print(f"Old file: {path}  ({size / 1024:.1f} KiB)")
print(f"Total reclaimable: {total / 2**20:.2f} MiB")
```

**Run:**

```bash
mkdir -p demo_logs && echo old > demo_logs/app-1.log && echo new > demo_logs/app-2.log
touch -d '10 days ago' demo_logs/app-1.log          # make one file look old
python3 old_files.py demo_logs 7
```

**Expected output:**

```text
Old file: demo_logs/app-1.log  (0.0 KiB)
Total reclaimable: 0.00 MiB
```

**DevOps use:** log clean-up automation, finding old backups, storage management.

**Follow-ups:** *"Search subfolders too?"* `directory.rglob("*")`. *"Delete them safely?"* Add a `--delete` flag that's off by default (dry run first), then `path.unlink()`. For log rotation itself, `logrotate` is the standard tool.

### 5. Check whether a website is available

**Scenario:** Check whether your application endpoint is responding.

`website_check.py`:

```python
import sys

import requests       # pip install requests

url = sys.argv[1] if len(sys.argv) > 1 else "https://example.com"

try:
    response = requests.get(url, timeout=5)
    if response.status_code == 200:
        print(f"Application is UP ({response.elapsed.total_seconds():.2f}s)")
    else:
        print("Application returned:", response.status_code)
        sys.exit(1)
except requests.RequestException as e:
    print("Application is DOWN:", e)
    sys.exit(2)
```

**Run:** `python3 website_check.py https://example.com`

**Expected output:** `Application is UP (0.21s)`

**DevOps use:** application health checks, endpoint monitoring, smoke tests after a deployment.

**Follow-ups:** *"Check 100 URLs quickly?"* Use a `ThreadPoolExecutor` (see the cheat sheet). *"Retry before declaring it down?"* Loop 3 times with `time.sleep(2)`, or use `urllib3.util.Retry` with a `requests` session.

## Level 2: intermediate automation

> **In simple words:** Programs that look at the live system: resources, processes, network ports, shell commands and logs as they're written. These show you can troubleshoot real servers from code.

### 6. Monitor CPU and memory utilization

`cpu_memory.py`:

```python
import sys

import psutil      # pip install psutil

cpu = psutil.cpu_percent(interval=1)          # average over 1 second
memory = psutil.virtual_memory().percent

print(f"CPU usage: {cpu}%")
print(f"Memory usage: {memory}%")

alerts = []
if cpu > 80:
    alerts.append("ALERT: high CPU utilization")
if memory > 85:
    alerts.append("ALERT: high memory utilization")
for a in alerts:
    print(a)
sys.exit(1 if alerts else 0)
```

**Run:** `python3 cpu_memory.py`

**Expected output:** `CPU usage: 7.5%` and `Memory usage: 41.2%`, plus alert lines if over the limits.

**DevOps use:** EC2 and server monitoring, troubleshooting slow servers, resource reports.

**Follow-ups:** *"Which processes use the most memory?"* Sort `psutil.process_iter(["name", "memory_percent"])` by `memory_percent`. *"Why `interval=1`?"* CPU usage is measured over a period; with `interval=None`, the first call returns a meaningless 0.0.

### 7. Check whether a process is running

**Scenario:** Nginx or another critical process stops unexpectedly.

`process_check.py`:

```python
import sys

import psutil      # pip install psutil

process_name = sys.argv[1] if len(sys.argv) > 1 else "nginx"

running = any(p.info["name"] == process_name for p in psutil.process_iter(["name"]))

if running:
    print(f"{process_name} is running")
else:
    print(f"ALERT: {process_name} is not running")
    sys.exit(1)
```

**Run:** `python3 process_check.py nginx`

**Expected output:** `nginx is running`, or `ALERT: nginx is not running` (exit code 1).

**DevOps use:** process monitoring, service availability checks, automated incident detection.

**Follow-ups:** *"Restart it automatically?"* `subprocess.run(["sudo", "systemctl", "restart", process_name], check=True)`. Better still, let systemd do it with `Restart=on-failure`. *"`any()`?"* It stops at the first match, like the `break` in a manual loop.

### 8. Check port connectivity

**Scenario:** The application can't connect to PostgreSQL on port 5432.

`port_check.py`:

```python
import socket
import sys

host = sys.argv[1] if len(sys.argv) > 1 else "10.0.1.50"
port = int(sys.argv[2]) if len(sys.argv) > 2 else 5432

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
    sock.settimeout(5)
    result = sock.connect_ex((host, port))     # 0 = connected, otherwise an error number

if result == 0:
    print(f"{host}:{port} is OPEN")
else:
    print(f"{host}:{port} is CLOSED or unreachable (error {result})")
    sys.exit(1)
```

**Run:** `python3 port_check.py localhost 22`

**Expected output:** `localhost:22 is OPEN` (if SSH runs locally), otherwise CLOSED with exit code 1.

**DevOps use:** EC2-to-RDS connectivity, app-to-database troubleshooting, checking security groups and firewalls.

**Follow-ups:** *"OPEN, but the app still fails?"* The network is fine, so check credentials, TLS, the database name, `pg_hba.conf`. *"The hostname doesn't resolve?"* `socket.gethostbyname(host)` raises `socket.gaierror`, which points to a DNS problem.

### 9. Run Linux commands from Python

**Scenario:** Automate `df -h`, `free -m` and `uptime` into one health report.

`run_commands.py`:

```python
import subprocess

commands = [
    ["df", "-h", "/"],
    ["free", "-m"],
    ["uptime"],
]

for command in commands:
    print(f"$ {' '.join(command)}")
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=30)
    except FileNotFoundError:
        print(f"command not found: {command[0]}\n")
        continue
    if result.returncode == 0:
        print(result.stdout)
    else:
        print(f"failed (exit {result.returncode}): {result.stderr}")
```

**Run:** `python3 run_commands.py` (on Linux; `free` doesn't exist on macOS)

**Expected output:** the disk, memory and uptime output, each under a `$ command` line.

**DevOps use:** Linux automation, server diagnostics, infrastructure health reports.

**Follow-ups:** *"Why a list instead of a string?"* No shell is involved, so there's no command injection and no quoting problems. *"Run it on 50 servers?"* AWS SSM Run Command (program 18), or SSH with `paramiko` / `fabric`.

### 10. Monitor a log continuously (like `tail -f`)

**Scenario:** Watch an application log and report errors as they appear.

`tail_errors.py`:

```python
import os
import sys
import time

log_file = sys.argv[1] if len(sys.argv) > 1 else "/var/log/myapp/application.log"


def follow(path):
    """Yield new lines as they're written; reopen the file if it's rotated or truncated."""
    f = open(path)
    f.seek(0, os.SEEK_END)                 # start at the end, like tail -f
    inode = os.fstat(f.fileno()).st_ino
    while True:
        line = f.readline()
        if line:
            yield line
            continue
        time.sleep(1)
        try:
            st = os.stat(path)
            if st.st_ino != inode or st.st_size < f.tell():   # rotated or truncated
                f.close()
                f = open(path)
                inode = os.fstat(f.fileno()).st_ino
        except FileNotFoundError:
            pass                           # mid-rotation: try again next second


try:
    for line in follow(log_file):
        if "ERROR" in line:
            print("ALERT:", line.strip(), flush=True)
except KeyboardInterrupt:
    print("\nstopped")
```

**Run:** in terminal 1, `python3 tail_errors.py application.log`. In terminal 2, `echo "ERROR payment timeout" >> application.log`.

**Expected output** (terminal 1): `ALERT: ERROR payment timeout`

**DevOps use:** real-time error detection, simple alerting, watching a deployment.

**Follow-ups:** *"Why check the inode?"* `logrotate` moves the old file away and creates a new one, and without reopening you'd keep watching the old file forever. *"Production alternative?"* Ship logs to CloudWatch Logs, Loki or OpenSearch and alert there.

## Level 3: AWS automation with boto3

> **In simple words:** boto3 is how Python talks to AWS. These programs list and inspect resources the way you'd do for inventory, cost clean-up and monitoring. They use your existing AWS CLI credentials, and in production, an IAM role.

Before running: `aws sts get-caller-identity` must work. Run the programs with a **read-only** role while learning.

### 11. List all EC2 instances

`list_ec2.py`:

```python
import boto3

ec2 = boto3.client("ec2", region_name="us-east-1")
paginator = ec2.get_paginator("describe_instances")      # all pages, not just the first

for page in paginator.paginate():
    for reservation in page["Reservations"]:
        for instance in reservation["Instances"]:
            name = next((t["Value"] for t in instance.get("Tags", []) if t["Key"] == "Name"), "-")
            print(f'{instance["InstanceId"]:20} {instance["State"]["Name"]:10} '
                  f'{instance["InstanceType"]:12} {name}')
```

**Run:** `python3 list_ec2.py`

**Expected output:** `i-0abc123def4567890  running    t3.micro     web-1`, one line per instance.

**DevOps use:** EC2 inventory, infrastructure reports, audits.

**Follow-ups:** *"Why the paginator?"* `describe_instances` returns results in pages, so a single call can miss instances in big accounts. *"All regions?"* Loop over `ec2.describe_regions()["Regions"]` and create a client per region.

### 12. Find stopped EC2 instances

`stopped_ec2.py`:

```python
import boto3

ec2 = boto3.client("ec2", region_name="us-east-1")
filters = [{"Name": "instance-state-name", "Values": ["stopped"]}]

count = 0
for page in ec2.get_paginator("describe_instances").paginate(Filters=filters):
    for reservation in page["Reservations"]:
        for instance in reservation["Instances"]:
            count += 1
            # StateTransitionReason includes when it was stopped, e.g. "User initiated (2026-10-01 …)"
            print("Stopped EC2:", instance["InstanceId"], instance["InstanceType"],
                  instance.get("StateTransitionReason", ""))
print(f"{count} stopped instance(s)")
```

**Run:** `python3 stopped_ec2.py`

**DevOps use:** finding unused infrastructure. Stopped instances still pay for their **EBS volumes** and any Elastic IPs.

**Follow-ups:** *"Stop forgotten dev instances at night?"* Filter on `tag:env = dev` and `running`, call `stop_instances` with `DryRun=True` first, and schedule it with EventBridge and Lambda or cron.

### 13. List S3 buckets

`list_s3.py`:

```python
import boto3

s3 = boto3.client("s3")
for bucket in s3.list_buckets()["Buckets"]:
    region = s3.get_bucket_location(Bucket=bucket["Name"])["LocationConstraint"] or "us-east-1"
    print(f'{bucket["Name"]:45} {region:15} created {bucket["CreationDate"]:%Y-%m-%d}')
```

**Run:** `python3 list_s3.py`

**DevOps use:** S3 inventory, cloud resource reports, storage automation.

**Follow-ups:** *"Why `or "us-east-1"`?"* Buckets in us-east-1 return `None` as their location. *"Total size of a bucket?"* Use the CloudWatch metric `BucketSizeBytes`, or S3 Storage Lens, rather than listing millions of objects.

> **Warning:** Never hard-code AWS keys in scripts. On EC2, Lambda, ECS or EKS, attach an **IAM role**; on laptops, use SSO profiles. boto3 finds both automatically.

### 17. EC2 CPU above 80% (CloudWatch)

**Scenario:** Find running instances whose average CPU in the last 15 minutes is above 80%.

`ec2_high_cpu.py`:

```python
from datetime import datetime, timedelta, timezone

import boto3

REGION, THRESHOLD = "us-east-1", 80.0
ec2 = boto3.client("ec2", region_name=REGION)
cw = boto3.client("cloudwatch", region_name=REGION)
end = datetime.now(timezone.utc)
start = end - timedelta(minutes=15)

running = [{"Name": "instance-state-name", "Values": ["running"]}]
for page in ec2.get_paginator("describe_instances").paginate(Filters=running):
    for r in page["Reservations"]:
        for inst in r["Instances"]:
            iid = inst["InstanceId"]
            stats = cw.get_metric_statistics(
                Namespace="AWS/EC2", MetricName="CPUUtilization",
                Dimensions=[{"Name": "InstanceId", "Value": iid}],
                StartTime=start, EndTime=end, Period=300, Statistics=["Average"],
            )["Datapoints"]
            if not stats:
                print(f"{iid}: no data yet")
                continue
            avg = sum(d["Average"] for d in stats) / len(stats)
            flag = "  <-- HIGH CPU" if avg > THRESHOLD else ""
            print(f"{iid}: {avg:.1f}%{flag}")
```

**Run:** `python3 ec2_high_cpu.py`

**DevOps use:** capacity checks, finding noisy or stuck instances, input for right-sizing.

**Follow-ups:** *"Production alerting?"* A **CloudWatch alarm** on `CPUUtilization` with SNS notification. The script is for ad-hoc checks and reports. *"Many instances?"* `get_metric_data` fetches many metrics in one call.

### 18. Health-check many servers with SSM (no SSH)

**Scenario:** Run `uptime` and `df -h` on every `env=dev` instance without opening SSH.

`ssm_health_check.py`:

```python
import time

import boto3

ssm = boto3.client("ssm", region_name="us-east-1")
resp = ssm.send_command(
    Targets=[{"Key": "tag:env", "Values": ["dev"]}],
    DocumentName="AWS-RunShellScript",
    Parameters={"commands": ["hostname", "uptime", "df -h /"]},
    TimeoutSeconds=60,
)
command_id = resp["Command"]["CommandId"]

while True:                                    # wait until every instance has finished
    time.sleep(3)
    invocations = ssm.list_command_invocations(CommandId=command_id, Details=True)["CommandInvocations"]
    if invocations and all(i["Status"] not in ("Pending", "InProgress", "Delayed") for i in invocations):
        break

for inv in invocations:
    print(f'== {inv["InstanceId"]}: {inv["Status"]}')
    for plugin in inv["CommandPlugins"]:
        print(plugin.get("Output", "").strip())
```

**Run:** `python3 ssm_health_check.py` (instances need the SSM agent and the `AmazonSSMManagedInstanceCore` role)

**DevOps use:** fleet-wide checks and fixes without SSH keys or open port 22, with every command logged in AWS.

**Follow-ups:** *"Why SSM over SSH?"* No inbound ports, no key distribution, IAM-controlled, and auditable in CloudTrail. Docs: [SSM Run Command](https://docs.aws.amazon.com/systems-manager/latest/userguide/run-command.html).

## Level 4: Kubernetes automation

> **In simple words:** The official `kubernetes` package talks to the cluster API, just like `kubectl` does. These programs inventory pods and find the unhealthy ones, which is the scripted version of troubleshooting.

Before running: `kubectl get pods` must work (the programs reuse `~/.kube/config`).

### 14. List all pods in a namespace

`list_pods.py`:

```python
import sys

from kubernetes import client, config     # pip install kubernetes

namespace = sys.argv[1] if len(sys.argv) > 1 else "default"
config.load_kube_config()                  # inside a pod: config.load_incluster_config()
v1 = client.CoreV1Api()

for pod in v1.list_namespaced_pod(namespace=namespace).items:
    print(f"{pod.metadata.name:50} {pod.status.phase:10} node={pod.spec.node_name}")
```

**Run:** `python3 list_pods.py kube-system`

**DevOps use:** resource inventory, health reports, scripted checks after deployments.

### 15. Find failed and stuck pods

**Scenario:** List pods that are failing, including **CrashLoopBackOff**. Those report the phase `Running`, so checking only `phase == "Failed"` misses them.

`failed_pods.py`:

```python
from kubernetes import client, config

BAD_REASONS = {"CrashLoopBackOff", "ImagePullBackOff", "ErrImagePull",
               "CreateContainerConfigError", "CreateContainerError"}

config.load_kube_config()
v1 = client.CoreV1Api()

for pod in v1.list_pod_for_all_namespaces().items:
    name = f"{pod.metadata.namespace}/{pod.metadata.name}"
    if pod.status.phase in ("Failed", "Unknown"):
        print(f"{name}: phase {pod.status.phase} ({pod.status.reason or ''})")
        continue
    if pod.status.phase == "Pending":
        print(f"{name}: Pending (check events: kubectl describe pod)")
    for cs in pod.status.container_statuses or []:
        waiting = cs.state.waiting
        if waiting and waiting.reason in BAD_REASONS:
            print(f"{name}: container {cs.name} is {waiting.reason}")
```

**Run:** `python3 failed_pods.py`

**DevOps use:** cluster health reports, detecting broken deployments, feeding alerts or chat notifications.

**Follow-ups:** *"Why doesn't CrashLoopBackOff show as Failed?"* The pod is still scheduled and Kubernetes keeps restarting the container; the reason lives in `container_statuses[].state.waiting.reason`. See [Kubernetes Troubleshooting](#/tool/k8s-troubleshooting).

### 16. Find pods that keep restarting

`restarting_pods.py`:

```python
from kubernetes import client, config

THRESHOLD = 3
config.load_kube_config()
v1 = client.CoreV1Api()

for pod in v1.list_pod_for_all_namespaces().items:
    for container in pod.status.container_statuses or []:
        if container.restart_count > THRESHOLD:
            last = container.last_state.terminated if container.last_state else None
            reason = f"{last.reason} (exit {last.exit_code})" if last else "unknown"
            print(f"{pod.metadata.namespace}/{pod.metadata.name} container={container.name} "
                  f"restarts={container.restart_count} last={reason}")
```

**Run:** `python3 restarting_pods.py`

**Expected output:** `prod/api-7d9c6b8f5d-x2kqp container=api restarts=7 last=OOMKilled (exit 137)`

**DevOps use:** finding unstable workloads, investigating CrashLoopBackOff, spotting memory limits that are too low (`OOMKilled`).

## Advanced SRE scenarios

> **In simple words:** Senior interviews describe a production symptom and ask how you'd automate the check. This table maps each scenario to the program or guide that solves it.

| Scenario | Python approach | Program / guide |
|---|---|---|
| EC2 CPU is above 80% | CloudWatch metrics with boto3 (and a CloudWatch alarm in production) | **17** |
| Application is unavailable | HTTP health check with `requests`, retries and exit codes | **5** |
| RDS connection fails | TCP check with `socket`, then credentials, TLS, security groups | **8** |
| Disk reaches 90% | `shutil.disk_usage` / `psutil`, alert via webhook | **3** |
| Kubernetes pod keeps restarting | Kubernetes API: restart counts and last termination reason | **15**, **16** |
| Application logs contain errors | Log analyzer and live tail with rotation handling | **2**, **10** |
| Old S3 backups exist | boto3 listing with age filter (dry run), or better an S3 lifecycle rule | [Python for DevOps → S3 clean-up](#/tool/python-devops) |
| Multiple servers need checking | SSM Run Command (no SSH), or `paramiko` / `fabric` | **18** |
| AWS resources are unused | boto3 inventory: stopped instances, unattached EBS volumes, idle load balancers | **12**, [Python for DevOps → unattached EBS](#/tool/python-devops) |
| Deployment fails | Parse CI logs or the CI API; check rollout status via the Kubernetes API | [CI/CD Troubleshooting](#/tool/cicd-troubleshooting) |

## Most important modules and next steps

> **In simple words:** About a dozen modules cover nearly every program above. Learn these well, then practise by extending the programs: add arguments, logging, alerts and tests.

| Module | Why you need it | Used in |
|---|---|---|
| `os` | Environment variables, directories, files | 10 |
| `sys` | Command-line arguments, exit codes | most programs |
| `subprocess` | Execute Linux commands | 9 |
| `time` | Waiting, file ages | 4, 10, 18 |
| `datetime` | Timestamps and time windows | 17 |
| `json` | API responses and configuration | Cheat sheet |
| `re` | Log parsing and pattern matching | 2 (follow-up) |
| `requests` | API calls and health checks | 5 |
| `socket` | Network connectivity | 8 |
| `psutil` | CPU, memory and process monitoring | 6, 7 |
| `boto3` | AWS automation | 11–13, 17, 18 |
| `kubernetes` | Kubernetes automation | 14–16 |
| `logging` | Logs from your automation | Cheat sheet |

Syntax and examples for each: [Python Basics & Module Cheat Sheet](#/tool/python-basics).

### Practice: level each program up

1. Add `argparse` options and `--help` to programs 3, 4 and 8.
2. Replace `print` with `logging`, and send a Slack or Teams webhook alert from program 6 when a threshold is crossed.
3. Make program 4 delete files only with `--delete`, and write a `pytest` test for it using a temporary folder.
4. Make program 11 cover **all regions** and write a CSV report.
5. Run program 15 as a **Kubernetes CronJob** with a service account that can only `list` pods.
