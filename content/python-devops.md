# Python for DevOps

Python is the DevOps engineer's second language after Bash. Use it when a script outgrows the shell: talking to cloud APIs with **boto3**, parsing JSON and YAML, calling REST APIs, automating Kubernetes and Docker, and writing tools your team can test and maintain. This guide covers what to learn, the basics with DevOps examples, the **modules you'll use every day**, **easy example programs**, free resources and **interview questions**.

> **Tip:** Two companion tabs: the [Python Basics & Module Cheat Sheet](#/tool/python-basics) for quick syntax and module look-ups, and [Python Interview Programs](#/tool/python-programs) with 18 interview-style programs and how to run them.

> **Note:** You need Python 3.10 or newer (`python3 --version`). Every example runs on Linux, WSL, macOS and the cloud lab machine in the [Practice lab](#/lab). AWS examples need the AWS CLI configured (see the [AWS guide](#/tool/aws)).

## Start here: Python in simple words

> **In simple words:** Python is a programming language that reads almost like English. For DevOps it's the tool for **automation that needs real logic**: loop over every AWS account, check hundreds of URLs, turn an API response into a report. It has ready-made libraries for nearly every service you use.

### What to learn, in order

| Stage | Topics | You can then… |
|---|---|---|
| 1. Basics | Variables, strings, lists, dicts, `if`, loops, functions, f-strings | Write small scripts |
| 2. Real scripts | Files, `pathlib`, `json`, `yaml`, `argparse`, `logging`, exceptions, `subprocess` | Replace long Bash scripts |
| 3. Tools | `venv`, `pip`, `requirements.txt`, `ruff`, `pytest` | Share and test your tools |
| 4. APIs & cloud | `requests`, **`boto3`**, `kubernetes`, `docker`, `paramiko` | Automate AWS, Kubernetes, servers |
| 5. Grown-up tooling | Packaging, CLI frameworks (`click`/`typer`), concurrency, `moto` for testing boto3 | Build team-wide tools |

### Check yourself

1. Give one task that suits Python better than Bash.
2. What does `pip` do?
3. What's boto3?

> **Tip:** Answers: 1) Listing all EC2 instances across regions and writing a CSV report, or anything that parses JSON heavily. 2) It installs Python packages. 3) The official AWS SDK for Python, which controls AWS services from code.

## Set up: venv, pip and your first script

> **In simple words:** A **virtual environment** (venv) is a private folder of packages for one project, so projects don't clash. Create one per project, install packages into it, and list them in `requirements.txt` so anyone can rebuild it.

```bash
mkdir -p ~/code/pyops && cd ~/code/pyops
python3 -m venv .venv
source .venv/bin/activate              # Windows PowerShell: .venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install requests boto3 pyyaml
pip freeze > requirements.txt          # pin exact versions
# later, on another machine:  pip install -r requirements.txt
deactivate                             # leave the venv
```

`hello.py`:

```python
#!/usr/bin/env python3
"""A tiny first script."""
import platform
import sys


def main() -> int:
    name = sys.argv[1] if len(sys.argv) > 1 else "DevOps"
    print(f"Hello, {name}! Python {platform.python_version()} on {platform.system()}")
    return 0


if __name__ == "__main__":       # run main() only when executed, not when imported
    sys.exit(main())
```

```bash
python hello.py Asha
```

> **Tip:** Add `.venv/` to `.gitignore`. Commit `requirements.txt`, never the venv folder.

## Python basics with DevOps examples

> **In simple words:** Five building blocks cover most scripts: **lists** (ordered items), **dicts** (key → value), **loops**, **functions** and **f-strings** for building text.

```python
# Variables and f-strings
env = "staging"
replicas = 3
print(f"Deploying to {env} with {replicas} replicas")

# Lists: ordered collections
servers = ["web-1", "web-2", "db-1"]
servers.append("cache-1")
web_servers = [s for s in servers if s.startswith("web")]   # list comprehension
print(web_servers, len(servers))

# Dicts: key → value, like JSON objects
service = {"name": "api", "port": 8080, "healthy": True}
service["version"] = "1.4.2"
for key, value in service.items():
    print(f"{key:>8}: {value}")
print(service.get("owner", "unknown"))     # default if the key is missing

# Conditions
cpu = 87
if cpu > 90:
    status = "critical"
elif cpu > 75:
    status = "warning"
else:
    status = "ok"
print(status)


# Functions with defaults and type hints
def scale(name: str, count: int = 2) -> str:
    return f"kubectl scale deploy/{name} --replicas={count}"


print(scale("api"), scale("worker", 5))

# Exceptions: handle expected failures instead of crashing
try:
    port = int("80a")
except ValueError as err:
    print(f"Invalid port: {err}")
```

## Files, JSON, YAML, environment variables and arguments

> **In simple words:** Real scripts read config files, read settings from environment variables, and take options from the command line. Python has a standard tool for each: `pathlib`, `json`, `yaml`, `os.environ` and `argparse`.

```python
import json
import os
from pathlib import Path

import yaml   # pip install pyyaml

# Files with pathlib
log_dir = Path("/var/log")
big_logs = [p for p in log_dir.glob("*.log") if p.stat().st_size > 10_000_000]
Path("report.txt").write_text("\n".join(str(p) for p in big_logs))

# Read a file line by line (memory-friendly for huge logs)
with open("/etc/hosts") as f:
    for line in f:
        if line.strip() and not line.startswith("#"):
            print(line.split())

# JSON
data = json.loads('{"service": "api", "replicas": 3}')
print(data["replicas"])
Path("out.json").write_text(json.dumps(data, indent=2))

# YAML (e.g. a Kubernetes manifest or app config)
manifest = yaml.safe_load(Path("deployment.yaml").read_text())  # safe_load, never yaml.load
print(manifest["spec"]["replicas"])

# Environment variables: settings and secrets come from the environment, not the code
region = os.environ.get("AWS_REGION", "us-east-1")
token = os.environ["API_TOKEN"]          # KeyError if missing: fail fast for required settings
```

Command-line arguments with `argparse`:

```python
import argparse

parser = argparse.ArgumentParser(description="Scale a deployment")
parser.add_argument("deployment")
parser.add_argument("--replicas", type=int, default=2)
parser.add_argument("--namespace", "-n", default="default")
parser.add_argument("--dry-run", action="store_true")
args = parser.parse_args()
print(args.deployment, args.replicas, args.namespace, args.dry_run)
# python scale.py api --replicas 5 -n prod --dry-run   (and --help for free)
```

## Running commands and logging

> **In simple words:** `subprocess.run` lets Python run shell commands (`kubectl`, `git`, `terraform`) and read their output safely. The `logging` module replaces `print` with timestamped messages you can filter by level.

```python
import logging
import shutil
import subprocess

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("ops")

# Run a command; check=True raises an error if it fails
result = subprocess.run(
    ["kubectl", "get", "pods", "-n", "kube-system", "-o", "name"],
    capture_output=True, text=True, check=True, timeout=30,
)
pods = result.stdout.splitlines()
log.info("Found %d pods", len(pods))

# Handle failure explicitly
try:
    subprocess.run(["git", "pull", "--ff-only"], check=True)
except subprocess.CalledProcessError as err:
    log.error("git pull failed with exit code %s", err.returncode)

# Check a tool exists before using it
if shutil.which("terraform") is None:
    log.warning("terraform is not installed")

# Disk usage without any extra package
total, used, free = shutil.disk_usage("/")
log.info("Disk: %.1f%% used", used / total * 100)
```

> **Warning:** Pass commands as a **list** (`["kubectl", "get", name]`). Avoid `shell=True` with user-provided input: it allows command injection.

## Essential modules for DevOps

> **In simple words:** You don't write everything yourself. These libraries are the toolbox, most of them one `pip install` away.

| Module | Install | Used for |
|---|---|---|
| `os`, `sys`, `pathlib`, `shutil` | built in | Files, paths, environment, disk usage |
| `subprocess` | built in | Run shell commands |
| `json`, `csv` | built in | Read and write data and reports |
| `argparse`, `logging` | built in | Command-line options, proper logs |
| `datetime`, `time`, `re` | built in | Timestamps, retries, regular expressions |
| `concurrent.futures` | built in | Run many checks in parallel (threads) |
| **`boto3`** | `pip install boto3` | **AWS**: EC2, S3, IAM, EKS, CloudWatch… |
| `requests` | `pip install requests` | HTTP APIs, health checks, webhooks |
| `pyyaml` | `pip install pyyaml` | YAML files (Kubernetes, Ansible, CI configs) |
| `kubernetes` | `pip install kubernetes` | The official Kubernetes API client |
| `docker` | `pip install docker` | Control Docker: containers, images |
| `paramiko` / `fabric` | `pip install paramiko fabric` | Run commands over SSH |
| `jinja2` | `pip install jinja2` | Templates (config files, manifests) |
| `psutil` | `pip install psutil` | CPU, memory, disk and process stats |
| `click` / `typer` | `pip install typer` | Polished command-line tools |
| `pytest` | `pip install pytest` | Testing your scripts |
| `moto` | `pip install moto` | Fake AWS for testing boto3 code without touching real AWS |
| `ruff` | `pip install ruff` | Fast linter and formatter |

## boto3: automate AWS with Python

> **In simple words:** boto3 is the official AWS SDK for Python. Anything the AWS CLI can do, boto3 can do from code, with loops, logic and error handling. It finds your credentials the same way the AWS CLI does, so if `aws sts get-caller-identity` works, boto3 works.

```bash
pip install boto3
aws sts get-caller-identity      # confirm credentials first
```

### Clients, sessions and credentials

```python
import boto3

# A client per service. Region from the argument, AWS_REGION, or your config.
s3 = boto3.client("s3")
ec2 = boto3.client("ec2", region_name="us-east-1")

# A named profile (e.g. an SSO profile from ~/.aws/config)
session = boto3.Session(profile_name="dev", region_name="us-east-1")
iam = session.client("iam")

print(boto3.client("sts").get_caller_identity()["Arn"])
```

**Where boto3 finds credentials:** values passed in code → environment variables → assume-role and web-identity providers (used by EKS IRSA and GitHub OIDC) → IAM Identity Center (SSO) → `~/.aws/credentials` and `~/.aws/config` → container credentials (ECS, EKS Pod Identity) → the EC2 instance role. **Never hard-code access keys.** On servers and in CI, use roles.

> **Note:** boto3 also has a higher-level **resource** interface (`boto3.resource("s3")`). AWS has said it won't add new features to resources, so prefer **clients** for new code.

### Example: list S3 buckets

```python
import boto3

s3 = boto3.client("s3")
for bucket in s3.list_buckets()["Buckets"]:
    print(bucket["Name"], bucket["CreationDate"].date())
```

### Example: EC2 inventory with pagination

AWS returns results in pages. A **paginator** fetches them all for you:

```python
import boto3

ec2 = boto3.client("ec2", region_name="us-east-1")
paginator = ec2.get_paginator("describe_instances")

for page in paginator.paginate(Filters=[{"Name": "instance-state-name", "Values": ["running"]}]):
    for reservation in page["Reservations"]:
        for inst in reservation["Instances"]:
            tags = {t["Key"]: t["Value"] for t in inst.get("Tags", [])}
            print(f'{inst["InstanceId"]:20} {inst["InstanceType"]:12} {tags.get("Name", "-"):25} {tags.get("env", "-")}')
```

### Example: stop dev instances safely (DryRun first)

```python
import boto3
from botocore.exceptions import ClientError

ec2 = boto3.client("ec2", region_name="us-east-1")
resp = ec2.describe_instances(Filters=[
    {"Name": "tag:env", "Values": ["dev"]},
    {"Name": "instance-state-name", "Values": ["running"]},
])
ids = [i["InstanceId"] for r in resp["Reservations"] for i in r["Instances"]]
print("Would stop:", ids)

if ids:
    try:
        ec2.stop_instances(InstanceIds=ids, DryRun=True)    # permission check only, changes nothing
    except ClientError as err:
        if err.response["Error"]["Code"] == "DryRunOperation":
            print("Permission OK. Set DryRun=False to really stop them.")
        else:
            raise
```

### Example: upload, download and share an S3 object

```python
import boto3

s3 = boto3.client("s3")
bucket = "my-team-artifacts"

s3.upload_file("report.csv", bucket, "reports/2026/report.csv")
s3.download_file(bucket, "reports/2026/report.csv", "copy.csv")
url = s3.generate_presigned_url("get_object", Params={"Bucket": bucket, "Key": "reports/2026/report.csv"}, ExpiresIn=3600)
print("Temporary link (1 hour):", url)
```

### Example: find unattached EBS volumes (wasted money)

```python
import boto3

ec2 = boto3.client("ec2", region_name="us-east-1")
total_gb = 0
for page in ec2.get_paginator("describe_volumes").paginate(Filters=[{"Name": "status", "Values": ["available"]}]):
    for vol in page["Volumes"]:
        total_gb += vol["Size"]
        print(vol["VolumeId"], f'{vol["Size"]} GiB', vol["CreateTime"].date())
print(f"Unattached: {total_gb} GiB")
```

### Example: every region at once

```python
import boto3

regions = [r["RegionName"] for r in boto3.client("ec2", region_name="us-east-1").describe_regions()["Regions"]]
for region in regions:
    ec2 = boto3.client("ec2", region_name=region)
    count = sum(len(r["Instances"]) for p in ec2.get_paginator("describe_instances").paginate() for r in p["Reservations"])
    if count:
        print(f"{region}: {count} instances")
```

### Handle errors and throttling

```python
import boto3
from botocore.config import Config
from botocore.exceptions import ClientError

# Built-in retries with backoff for throttling ("Rate exceeded")
cfg = Config(retries={"max_attempts": 10, "mode": "adaptive"})
s3 = boto3.client("s3", config=cfg)

try:
    s3.head_object(Bucket="my-bucket", Key="missing.txt")
except ClientError as err:
    code = err.response["Error"]["Code"]
    if code in ("404", "NoSuchKey"):
        print("Object not found")
    elif code in ("403", "AccessDenied"):
        print("No permission. Check IAM")
    else:
        raise
```

Docs: [boto3 documentation](https://boto3.amazonaws.com/v1/documentation/api/latest/index.html) · [Credentials](https://boto3.amazonaws.com/v1/documentation/api/latest/guide/credentials.html) · [Paginators](https://boto3.amazonaws.com/v1/documentation/api/latest/guide/paginators.html)

## Other DevOps libraries in action

> **In simple words:** The same pattern works for Kubernetes, Docker, SSH and HTTP: install the library, connect, and loop over what you get back.

### Kubernetes: list unhealthy pods

```python
from kubernetes import client, config   # pip install kubernetes

config.load_kube_config()               # uses ~/.kube/config (in a pod: config.load_incluster_config())
v1 = client.CoreV1Api()

for pod in v1.list_pod_for_all_namespaces().items:
    restarts = sum(cs.restart_count for cs in (pod.status.container_statuses or []))
    if pod.status.phase not in ("Running", "Succeeded") or restarts > 5:
        print(f"{pod.metadata.namespace}/{pod.metadata.name}: {pod.status.phase}, restarts={restarts}")
```

### Docker: list containers and remove old stopped ones

```python
import docker   # pip install docker

client = docker.from_env()
for c in client.containers.list(all=True):
    print(f"{c.short_id} {c.name:25} {c.status:10} {c.image.tags}")
client.containers.prune(filters={"until": "24h"})
```

### SSH: run a command on several servers

```python
import paramiko   # pip install paramiko

for host in ["web1.example.com", "web2.example.com"]:
    ssh = paramiko.SSHClient()
    ssh.load_system_host_keys()                   # trust only hosts in ~/.ssh/known_hosts
    ssh.connect(host, username="ubuntu", key_filename="/home/me/.ssh/id_ed25519", timeout=10)
    _, stdout, stderr = ssh.exec_command("uptime && df -h /")
    print(f"== {host}\n{stdout.read().decode()}{stderr.read().decode()}")
    ssh.close()
```

### HTTP: check many URLs in parallel

```python
from concurrent.futures import ThreadPoolExecutor

import requests   # pip install requests

URLS = ["https://example.com", "https://httpbin.org/status/500", "https://does-not-exist.invalid"]


def check(url: str) -> str:
    try:
        r = requests.get(url, timeout=5)
        return f"{r.status_code} {r.elapsed.total_seconds():.2f}s {url}"
    except requests.RequestException as err:
        return f"ERR  {type(err).__name__} {url}"


with ThreadPoolExecutor(max_workers=10) as pool:
    for line in pool.map(check, URLS):
        print(line)
```

## Example programs

> **In simple words:** Small, complete programs that solve everyday DevOps chores. Copy one, run it, then change it to fit your environment.

### 1. Log analyzer: status codes and top IPs

```python
#!/usr/bin/env python3
"""Usage: python log_report.py access.log"""
import sys
from collections import Counter

statuses, ips = Counter(), Counter()
with open(sys.argv[1]) as f:
    for line in f:
        parts = line.split()
        if len(parts) > 8:
            ips[parts[0]] += 1
            statuses[parts[8]] += 1

print("Status codes:", dict(statuses.most_common()))
print("Top 5 IPs:")
for ip, count in ips.most_common(5):
    print(f"  {ip:15} {count}")
```

### 2. System health check (exit code for monitoring and CI)

```python
#!/usr/bin/env python3
import shutil
import sys

import psutil   # pip install psutil

problems = []
disk = shutil.disk_usage("/")
if disk.used / disk.total > 0.80:
    problems.append(f"disk {disk.used / disk.total:.0%}")
if psutil.virtual_memory().percent > 90:
    problems.append(f"memory {psutil.virtual_memory().percent}%")
if psutil.cpu_percent(interval=1) > 95:
    problems.append("cpu > 95%")

print("UNHEALTHY: " + ", ".join(problems) if problems else "HEALTHY")
sys.exit(1 if problems else 0)
```

### 3. EC2 inventory to CSV

```python
#!/usr/bin/env python3
import csv

import boto3

ec2 = boto3.client("ec2")
with open("ec2_inventory.csv", "w", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(["InstanceId", "Name", "Type", "State", "PrivateIP", "LaunchTime"])
    for page in ec2.get_paginator("describe_instances").paginate():
        for r in page["Reservations"]:
            for i in r["Instances"]:
                name = next((t["Value"] for t in i.get("Tags", []) if t["Key"] == "Name"), "")
                writer.writerow([i["InstanceId"], name, i["InstanceType"], i["State"]["Name"],
                                 i.get("PrivateIpAddress", ""), i["LaunchTime"].isoformat()])
print("Wrote ec2_inventory.csv")
```

### 4. Delete S3 objects older than N days (dry run by default)

```python
#!/usr/bin/env python3
"""Usage: python s3_cleanup.py <bucket> <prefix> <days> [--apply]"""
import sys
from datetime import datetime, timedelta, timezone

import boto3

bucket, prefix, days = sys.argv[1], sys.argv[2], int(sys.argv[3])
apply = "--apply" in sys.argv
cutoff = datetime.now(timezone.utc) - timedelta(days=days)

s3 = boto3.client("s3")
old = [o["Key"] for page in s3.get_paginator("list_objects_v2").paginate(Bucket=bucket, Prefix=prefix)
       for o in page.get("Contents", []) if o["LastModified"] < cutoff]
print(f"{len(old)} objects older than {days} days under s3://{bucket}/{prefix}")

if apply:
    for i in range(0, len(old), 1000):                       # delete_objects takes up to 1000 keys
        s3.delete_objects(Bucket=bucket, Delete={"Objects": [{"Key": k} for k in old[i:i + 1000]]})
    print("Deleted.")
else:
    print("Dry run. Add --apply to delete.")
```

For permanent rules, an **S3 lifecycle policy** is better than a script (see the [S3 guide](#/tool/aws-s3)).

### 5. Render config files per environment with Jinja2

```python
#!/usr/bin/env python3
from jinja2 import Template   # pip install jinja2

template = Template("""\
server:
  env: {{ env }}
  replicas: {{ replicas }}
  log_level: {{ "debug" if env == "dev" else "info" }}
""")

for env, replicas in {"dev": 1, "staging": 2, "prod": 3}.items():
    with open(f"config-{env}.yaml", "w") as f:
        f.write(template.render(env=env, replicas=replicas))
    print(f"wrote config-{env}.yaml")
```

## Code quality and testing

> **In simple words:** A script that others depend on deserves the same care as application code: a linter to catch mistakes, tests to prove it works, and fake AWS (moto) so tests never touch real resources.

```bash
pip install ruff pytest moto
ruff check .          # find bugs and style problems
ruff format .         # format the code
pytest -q             # run the tests
```

Testing boto3 code against **fake AWS** with moto. `inventory.py`:

```python
import boto3


def bucket_names() -> list[str]:
    return sorted(b["Name"] for b in boto3.client("s3", region_name="us-east-1").list_buckets()["Buckets"])
```

`test_inventory.py`:

```python
import boto3
from moto import mock_aws

from inventory import bucket_names


@mock_aws
def test_bucket_names():
    s3 = boto3.client("s3", region_name="us-east-1")
    s3.create_bucket(Bucket="b-logs")
    s3.create_bucket(Bucket="a-data")
    assert bucket_names() == ["a-data", "b-logs"]
```

`pytest` runs it in milliseconds, with no AWS account or cost.

## Where to learn more (free)

> **In simple words:** Learn the basics from one tutorial, practise with small exercises, then move on to the library docs as you need them.

| Resource | What it's good for |
|---|---|
| [The Python Tutorial (official)](https://docs.python.org/3/tutorial/) | The reference introduction to the language |
| [Automate the Boring Stuff with Python](https://automatetheboringstuff.com/) | Free online book: practical automation for beginners |
| [learnpython.org](https://www.learnpython.org/) | Interactive basics in the browser |
| [Exercism Python track](https://exercism.org/tracks/python) | Free exercises with mentor feedback |
| [Real Python](https://realpython.com/) | Clear tutorials on almost every topic |
| [boto3 documentation](https://boto3.amazonaws.com/v1/documentation/api/latest/index.html) | Every AWS service and operation, with examples |
| [Requests](https://requests.readthedocs.io/) | HTTP for humans: API calls |
| [Kubernetes Python client](https://github.com/kubernetes-client/python) | Examples for every Kubernetes API |
| [Docker SDK for Python](https://docker-py.readthedocs.io/) | Control Docker from Python |
| [Paramiko](https://docs.paramiko.org/) | SSH from Python |
| [PyYAML](https://pyyaml.org/wiki/PyYAMLDocumentation) | Reading and writing YAML |
| [pytest](https://docs.pytest.org/) · [Moto](https://docs.getmoto.org/) | Testing, and mocking AWS in tests |
| [Ruff](https://docs.astral.sh/ruff/) | Linter and formatter |

## Interview questions

> **In simple words:** Python questions DevOps interviewers really ask, from basics to boto3, with short answers. Run the snippets yourself and explain them out loud.

### Python fundamentals

| Question | Short answer |
|---|---|
| List vs tuple? | Lists are mutable (`[]`); tuples are immutable (`()`), so they're hashable and usable as dict keys |
| List vs set vs dict? | Ordered sequence / unique unordered values with fast membership tests / key → value mapping |
| What's a list comprehension? | A compact loop that builds a list: `[s for s in servers if s.startswith("web")]` |
| What are `*args` and `**kwargs`? | Extra positional arguments as a tuple, and extra keyword arguments as a dict |
| Why is `def f(x=[])` a bug? | The default list is created **once** and shared between calls. Use `x=None`, then `x = x or []` |
| What does `with open(...)` do? | A context manager: it closes the file even if an error happens |
| What does `if __name__ == "__main__":` mean? | The code runs only when the file is executed directly, not when it's imported |
| `is` vs `==`? | `==` compares values; `is` checks whether two names point to the same object (use it for `None`) |
| Shallow vs deep copy? | `copy.copy` copies the outer object only; `copy.deepcopy` copies nested objects too |
| What's a generator? | A function using `yield` that produces items lazily, e.g. reading a huge log without loading it all |
| How do you handle errors? | `try` / `except SpecificError` / `finally`. Catch specific exceptions, not a bare `except:` |
| What's a decorator? | A function that wraps another to add behaviour (retries, timing, logging), applied with `@name` |

### Python for automation

| Question | Short answer |
|---|---|
| Why use a virtual environment? | It isolates each project's packages and versions; recreate it with `requirements.txt` |
| `subprocess.run` vs `os.system`? | `subprocess.run` captures output, gives the exit code, raises on failure with `check=True` and avoids the shell. `os.system` does none of that |
| How do you read a 10 GB log file? | Iterate line by line (`for line in f:`), never `f.read()` |
| How do you parse JSON and YAML? | `json.loads` / `json.load`; `yaml.safe_load` (never plain `yaml.load` on untrusted input) |
| Threads vs processes vs asyncio? | Threads or asyncio for I/O-bound work (HTTP, AWS calls); processes for CPU-bound work, because of the GIL |
| `logging` vs `print`? | `logging` has levels, timestamps, formats and outputs, and can be silenced or redirected |
| How do you pass secrets to a script? | Environment variables, or fetch them from AWS Secrets Manager or SSM at runtime. Never hard-code or commit them |
| How do you schedule a Python script? | cron or a systemd timer on a server; a Kubernetes CronJob; EventBridge Scheduler with Lambda |

### boto3 and AWS

| Question | Short answer |
|---|---|
| Client vs resource in boto3? | A client is a low-level 1:1 mapping of the AWS API (recommended); a resource is an object-oriented wrapper that gets no new features |
| How does boto3 find credentials? | Code parameters → env vars → assume-role / web identity → SSO → `~/.aws` files → container credentials → EC2 instance role |
| Why use paginators? | List calls return results in pages (e.g. 1,000 S3 keys). Paginators fetch every page |
| How do you handle throttling (`Rate exceeded`)? | `botocore.config.Config(retries={"mode": "adaptive", "max_attempts": 10})`, plus backoff in your own loops |
| How do you catch AWS errors? | `except ClientError as e: e.response["Error"]["Code"]` |
| How do you test boto3 code without AWS? | Mock AWS with `moto` (`@mock_aws`), or stub responses with `botocore.stub.Stubber` |
| What's `DryRun=True` for? | EC2 checks permissions and returns `DryRunOperation` without making changes |
| How do you work across accounts or regions? | `boto3.Session(profile_name=...)`, or `sts.assume_role` and build a session from the temporary credentials; loop over `describe_regions()` |
| What are waiters? | Helpers that poll until a state is reached: `ec2.get_waiter("instance_running").wait(InstanceIds=[...])` |

### Practice tasks

1. Write `ec2_report.py` that lists running instances in **every region** and saves a CSV with name, type, region and monthly cost estimate.
2. Write `url_checker.py` that reads URLs from a YAML file, checks them in parallel, and exits non-zero if any fail (ready for CI or cron).
3. Write `stale_branches.py` that uses the GitHub or GitLab API (`requests`) to list branches without commits in 90 days.
4. Write `k8s_restart_report.py` that prints pods with more than 5 restarts and their last termination reason.
5. Add `pytest` tests with `moto` for one boto3 script, and run `ruff check` until it's clean.

## Coding interview questions

> **In simple words:** Live-coding rounds for DevOps roles use short, practical problems: process a file, transform some text. Interviewers watch for **correct results**, **clean code**, **handling bad input**, and whether you think about **large data**. Solve each one yourself first, then compare.

### 1. Unique actions per user from a large CSV

**Question:** A CSV file has the columns `user_id,timestamp,action`. Write a function that returns a dictionary mapping each `user_id` to the **number of unique actions** they performed. The file can be very large: don't load it all into memory.

Example input:

```text
user_id,timestamp,action
u1,2026-11-08T10:00:00,login
u1,2026-11-08T10:01:00,view
u1,2026-11-08T10:02:00,login
u2,2026-11-08T10:03:00,login
u2,2026-11-08T10:05:00,logout
u3,2026-11-08T10:06:00,purchase
```

Expected result: `{"u1": 2, "u2": 2, "u3": 1}` (u1's second `login` doesn't count again).

**Solution** (`unique_actions.py`):

```python
#!/usr/bin/env python3
"""Count the unique actions each user performed in a CSV file.

The CSV has the columns user_id, timestamp, action. The file is read one row
at a time, so memory grows with the number of unique (user, action) pairs,
not with the size of the file.

Usage: python unique_actions.py events.csv
"""
import csv
import json
import sys
from collections import defaultdict


def unique_actions_per_user(path: str) -> dict[str, int]:
    """Return {user_id: number of distinct actions} for the CSV at `path`."""
    actions_by_user: dict[str, set[str]] = defaultdict(set)
    skipped = 0

    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)  # yields one row at a time; never reads the whole file
        missing = {"user_id", "action"} - set(reader.fieldnames or [])
        if missing:
            raise ValueError(f"CSV is missing column(s): {', '.join(sorted(missing))}")

        for row in reader:
            user = (row.get("user_id") or "").strip()
            action = (row.get("action") or "").strip()
            if not user or not action:
                skipped += 1  # blank or malformed row
                continue
            # intern(): repeated action names share one string object, saving memory
            actions_by_user[sys.intern(user)].add(sys.intern(action))

    if skipped:
        print(f"warning: skipped {skipped} malformed row(s)", file=sys.stderr)
    return {user: len(actions) for user, actions in actions_by_user.items()}


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} <file.csv>", file=sys.stderr)
        return 2
    try:
        result = unique_actions_per_user(sys.argv[1])
    except (OSError, ValueError) as err:
        print(f"error: {err}", file=sys.stderr)
        return 1
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

```bash
python unique_actions.py events.csv
```

**How it works:**

| Technique | Why it matters |
|---|---|
| `csv.DictReader` over an open file | **Streams** the file one row at a time. Memory doesn't grow with file size (never use `f.read()` or `readlines()` here) |
| `defaultdict(set)` | One set of actions per user; a **set ignores duplicates**, so repeated actions cost nothing |
| `len(actions)` at the end | Turns each set into the count the question asks for |
| Header check + skipping blank rows | Real data is messy: fail clearly on a wrong file, keep going on a bad row |
| `sys.intern()` | Repeated strings like `"login"` are stored once instead of millions of times |

**Complexity:** time **O(n)** for *n* rows (one pass); memory **O(unique user–action pairs)**, independent of the number of rows. Tested on a 1,000,000-row, 37 MB file with 5,000 users: correct counts, **peak memory about 4 MB**.

**Likely follow-up questions:**

- *"What if even the distinct pairs don't fit in memory?"* Load the file into SQLite or DuckDB and run `SELECT user_id, COUNT(DISTINCT action) FROM events GROUP BY user_id`; or split the file by a hash of `user_id` and process each part separately.
- *"What if the file is in S3?"* Stream it: `boto3.client("s3").get_object(...)["Body"].iter_lines()`, decode each line, and feed the lines to `csv.reader`, so nothing is downloaded to disk.
- *"How would you test it?"* With pytest, using a small CSV written to `tmp_path`, including duplicates, a blank row and a missing column.
- *"Can pandas do it?"* Yes: `pd.read_csv(path, usecols=["user_id", "action"], chunksize=500_000)`, and merge per-chunk sets. Pandas uses far more memory per row than the plain `csv` module, though.

### 2. Reverse a sentence and count its vowels

**Question:** Write a program that reverses a given sentence and finds the number of vowels in it.

"Reverse a sentence" can mean reversing the **word order** or the **characters**. Ask the interviewer, or show both.

**Solution** (`sentence_tools.py`):

```python
#!/usr/bin/env python3
"""Reverse a sentence and count the vowels in it.

Usage: python sentence_tools.py "DevOps is fun"
       python sentence_tools.py          (asks for a sentence)
"""
import sys

VOWELS = set("aeiouAEIOU")


def reverse_words(sentence: str) -> str:
    """'DevOps is fun' -> 'fun is DevOps'"""
    return " ".join(reversed(sentence.split()))


def reverse_characters(sentence: str) -> str:
    """'DevOps is fun' -> 'nuf si spOveD'"""
    return sentence[::-1]


def count_vowels(sentence: str) -> int:
    """Count a, e, i, o, u in either case."""
    return sum(1 for ch in sentence if ch in VOWELS)


def main() -> None:
    sentence = " ".join(sys.argv[1:]) or input("Enter a sentence: ")
    print(f"Original           : {sentence}")
    print(f"Words reversed     : {reverse_words(sentence)}")
    print(f"Characters reversed: {reverse_characters(sentence)}")
    print(f"Number of vowels   : {count_vowels(sentence)}")


if __name__ == "__main__":
    main()
```

Output:

```text
$ python sentence_tools.py "DevOps is fun and Kubernetes is powerful"
Original           : DevOps is fun and Kubernetes is powerful
Words reversed     : powerful is Kubernetes and fun is DevOps
Characters reversed: lufrewop si setenrebuK dna nuf si spOveD
Number of vowels   : 13
```

**How it works:**

| Piece | Explanation |
|---|---|
| `sentence.split()` | Splits on any whitespace and ignores extra spaces |
| `reversed(...)` + `" ".join(...)` | Puts the words back together in reverse order |
| `sentence[::-1]` | A slice with step −1, which reverses the string |
| `set("aeiouAEIOU")` | Fast membership check, covering both cases |
| `sum(1 for ch in … if …)` | Counts matches without building a list |

**Complexity:** O(n) time and O(n) memory for a sentence of length *n*.

**Likely follow-up questions:**

- *"Without built-ins?"* Loop from the end with an index (`for i in range(len(s) - 1, -1, -1)`), and collect words by scanning for spaces.
- *"Count each vowel separately?"* `collections.Counter(ch for ch in sentence.lower() if ch in "aeiou")`.
- *"Reverse each word but keep the word order?"* `" ".join(w[::-1] for w in sentence.split())`.
- *"Is 'y' a vowel?"* Clarify the rule with the interviewer. Asking about edge cases is part of what they're assessing.

### More practice problems

1. Read an nginx access log and print the **top 5 IP addresses** and the count of each HTTP status code.
2. Given a list of server names and a list of servers that answered a health check, return the servers that are **down**.
3. Parse a `.env` file (`KEY=value`, comments with `#`) into a dictionary, ignoring blank lines.
4. Find all files in a folder **larger than 100 MB and older than 30 days**, without listing the whole disk into memory (`os.scandir` / `pathlib.rglob`).
5. Merge two dictionaries of configuration where the second overrides the first, **including nested dictionaries**.
