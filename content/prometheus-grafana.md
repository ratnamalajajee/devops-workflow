# Prometheus and Grafana: Monitoring from Scratch

Learn **how monitoring really works**, in simple words, then install **Prometheus** (collects and stores metrics, fires alerts) and **Grafana** (beautiful dashboards) three ways: on your **laptop with Docker Compose**, on a **Linux server (EC2)**, and on **Kubernetes with Helm**, the way most companies run it. You'll also write **PromQL** queries, build dashboards, monitor your own app and send **alerts to Slack**.

> **Cost:** Prometheus and Grafana are **free and open source**. You only pay for where they run: on your laptop it's free; on EC2 a `t3.small` is about $0.02/hour plus its disk; on Kubernetes they use part of your cluster plus EBS volumes for stored data (about $0.08 per GB-month for gp3 in us-east-1). Stop or delete what you create after practising.

## Start here: monitoring in simple words

> **In simple words:** Think of a **car dashboard**. **Sensors** measure speed, fuel and engine heat. The car's **computer** records the readings every second. The **dashboard** shows them as dials, and a **warning light** comes on when something is wrong. Prometheus is the computer that records readings, exporters are the sensors, Grafana is the dashboard, and Alertmanager is the warning light that also phones you.

| In a car | In monitoring |
|---|---|
| Sensors (speed, fuel, temperature) | **Exporters** and apps that expose metrics |
| The computer recording readings every second | **Prometheus** (scrapes and stores metrics) |
| The dashboard with dials | **Grafana** |
| Warning light: "engine hot" | **Alert rule** in Prometheus |
| The service centre calling you | **Alertmanager** (sends to Slack, email, phone) |

### Key words

| Word | Meaning |
|---|---|
| **Metric** | A number that changes over time, e.g. CPU usage or requests per second |
| **Time series** | One metric's values over time, for one set of labels |
| **Label** | A tag on a metric, e.g. `instance="web-1"`, `method="GET"` |
| **Target** | Something Prometheus collects from, e.g. `web-1:9100` |
| **Scrape** | Prometheus calling a target's `/metrics` page to read the numbers |
| **Exporter** | A small program that turns a system's stats into metrics (e.g. node_exporter for Linux) |
| **PromQL** | The query language to ask questions like "average CPU of all web servers" |
| **Alert rule** | A PromQL condition that fires an alert, e.g. "disk < 10% for 5 minutes" |
| **Data source** | Where Grafana reads data from (here, Prometheus) |

### Check yourself

1. Which tool **stores** the metrics, and which one **shows** them?
2. What is an exporter?
3. Who sends the alert to Slack: Prometheus or Alertmanager?

> **Tip:** Answers: 1) Prometheus stores them; Grafana shows them. 2) A small program that reads a system's stats and publishes them as metrics on a `/metrics` page. 3) Prometheus decides an alert is firing; **Alertmanager** groups it and sends the notification.

## How Prometheus works

> **In simple words:** Prometheus **pulls**: every 15 seconds it visits each target's `/metrics` page, reads the numbers and stores them with a timestamp. It also checks your **alert rules** and passes firing alerts to Alertmanager. Grafana asks Prometheus questions in PromQL and draws the answers.

```flow
📟 | Expose | Each app or exporter shows its numbers on an HTTP page, e.g. `http://web-1:9100/metrics`.
🧲 | Scrape | Every 15 seconds Prometheus fetches each target's page (it **pulls** the data).
🗃️ | Store | Prometheus saves each value with a timestamp in its own time series database on disk.
🚨 | Evaluate rules | Every 15 seconds it checks alert rules, e.g. "CPU above 85% for 10 minutes".
📣 | Notify | Firing alerts go to **Alertmanager**, which groups them and sends them to Slack, email or a pager.
📊 | Visualise | **Grafana** sends PromQL queries to Prometheus and draws graphs and dashboards.
```

```text
  node_exporter   your app    kube-state-metrics
   :9100/metrics  /metrics    :8080/metrics
        ▲             ▲             ▲
        └──── scrape (pull) every 15s ────┐
                                          │
                              ┌───────────┴──────────┐
                              │  Prometheus :9090    │
                              │  storage + rules     │
                              └──────┬────────┬──────┘
                       firing alerts │        │ PromQL
                                     ▼        ▼
                       Alertmanager :9093   Grafana :3000
                        Slack, email         dashboards
```

```compare
🧲 Pull (Prometheus) | 📤 Push (many other tools)
The monitoring server fetches metrics from targets | Each target sends its metrics to a server
If a target stops answering, you know at once (up = 0) | A silent target might just be quiet, or might be dead
Targets don't need to know where Prometheus is | Every target must be configured with the server address
Short batch jobs need the Pushgateway | Natural fit for short jobs
```

| Part | Job | Default port |
|---|---|---|
| **Prometheus** | Scrapes, stores, queries, evaluates rules | 9090 |
| **node_exporter** | Linux host metrics: CPU, memory, disk, network | 9100 |
| **Alertmanager** | Groups, silences and sends alerts | 9093 |
| **Grafana** | Dashboards and visual exploration | 3000 |
| **Pushgateway** (optional) | Holds metrics pushed by short batch jobs | 9091 |

## Metrics explained: types and labels

> **In simple words:** A metric is just a **name, some labels and a number**. There are four kinds: counters only go up, gauges go up and down, and histograms and summaries describe how long things take.

Open any `/metrics` page and you'll see plain text like this:

```text
# HELP http_requests_total Total HTTP requests handled.
# TYPE http_requests_total counter
http_requests_total{method="GET",code="200"} 10452
http_requests_total{method="POST",code="500"} 7
# HELP node_memory_MemAvailable_bytes Memory available in bytes.
# TYPE node_memory_MemAvailable_bytes gauge
node_memory_MemAvailable_bytes 1.73e+09
```

| Type | Behaves like | Example | How you usually query it |
|---|---|---|---|
| **Counter** | A car's odometer: only goes up (resets to 0 on restart) | `http_requests_total` | `rate(...[5m])` = per-second speed |
| **Gauge** | A fuel gauge: up and down | `node_memory_MemAvailable_bytes`, temperature | Use the value directly, or `avg`, `max` |
| **Histogram** | Buckets counting how many requests took < 0.1 s, < 0.5 s, < 1 s… | `http_request_duration_seconds_bucket` | `histogram_quantile(0.95, ...)` = 95th percentile |
| **Summary** | Like a histogram, but percentiles are calculated in the app | `rpc_duration_seconds` | Read the quantiles; can't be combined across servers |

**Labels** turn one metric into many time series: `http_requests_total{code="200"}` and `{code="500"}` are separate lines on a graph.

> **Warning:** Never put values with **endless variety** in labels, like user IDs, emails or full URLs. Every new value creates a new time series, and Prometheus can run out of memory. This is called **high cardinality**.

## Which installation should I use?

> **In simple words:** Learn on your **laptop**, monitor **servers** with a Prometheus on a VM, and monitor **Kubernetes** with the `kube-prometheus-stack` Helm chart. Big companies often add a managed or long-term store later.

| Option | Best for | Effort |
|---|---|---|
| **1. Docker Compose** | Learning and testing on your laptop | 10 minutes |
| **2. Linux server (EC2)** | Monitoring a fleet of VMs | 30–45 minutes |
| **3. Kubernetes with Helm** | Monitoring EKS clusters and the apps on them (most common in companies) | 20–30 minutes |
| Managed: Amazon Managed Service for Prometheus + Amazon Managed Grafana | Teams who don't want to run the servers themselves | Varies |

Versions used in this guide (November 2026): **Prometheus 3.16.0**, **node_exporter 1.12.1**, **Alertmanager 0.34.2**, **Grafana 13.3.0**, **kube-prometheus-stack chart 93.0.0**. Check the release pages for newer versions before you install.

## Option 1: Try it on your laptop with Docker Compose

> **In simple words:** Four containers (Prometheus, node_exporter, Alertmanager and Grafana) started with one command. Perfect for playing with PromQL, dashboards and alerts without touching any server.

You need [Docker](#/tool/docker) with Compose. Create a folder `monitoring-lab` with these five files.

`docker-compose.yml`:

```yaml
services:
  prometheus:
    image: prom/prometheus:v3.16.0
    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --storage.tsdb.path=/prometheus
      - --storage.tsdb.retention.time=7d
    ports: ["9090:9090"]
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./rules.yml:/etc/prometheus/rules.yml:ro
      - prom-data:/prometheus
  node-exporter:
    image: prom/node-exporter:v1.12.1
    ports: ["9100:9100"]
  alertmanager:
    image: prom/alertmanager:v0.34.2
    ports: ["9093:9093"]
    volumes:
      - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
  grafana:
    image: grafana/grafana:13.3.0
    ports: ["3000:3000"]
    environment:
      GF_SECURITY_ADMIN_PASSWORD: change-me-please
    volumes:
      - ./grafana-datasource.yml:/etc/grafana/provisioning/datasources/datasource.yml:ro
      - grafana-data:/var/lib/grafana
volumes:
  prom-data:
  grafana-data:
```

`prometheus.yml` (what to scrape and where to send alerts):

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - /etc/prometheus/rules.yml

alerting:
  alertmanagers:
    - static_configs:
        - targets: ["alertmanager:9093"]

scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ["localhost:9090"]
  - job_name: node
    static_configs:
      - targets: ["node-exporter:9100"]
```

`rules.yml` (three alerts every server should have):

```yaml
groups:
  - name: basic-host-alerts
    rules:
      - alert: InstanceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "{{ $labels.instance }} is down"
          description: "Job {{ $labels.job }} target {{ $labels.instance }} has not answered for 1 minute."
      - alert: HighCpu
        expr: 100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 85
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "CPU above 85% on {{ $labels.instance }} for 10 minutes"
      - alert: DiskAlmostFull
        expr: node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"} / node_filesystem_size_bytes{fstype!~"tmpfs|overlay"} * 100 < 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Less than 10% disk left on {{ $labels.instance }} {{ $labels.mountpoint }}"
```

`alertmanager.yml` (for the lab, alerts just show in the Alertmanager page; Slack comes later):

```yaml
route:
  receiver: lab-default
  group_by: [alertname, instance]
receivers:
  - name: lab-default
```

`grafana-datasource.yml` (tells Grafana where Prometheus is, so you don't have to click it in):

```yaml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
```

Start everything and check it:

```bash
cd monitoring-lab
docker compose up -d
docker compose ps                      # all four should be "running"
curl -s localhost:9100/metrics | head  # raw metrics from node_exporter
```

| Open | What you'll see |
|---|---|
| http://localhost:9090/targets | Both targets **UP** (green) |
| http://localhost:9090/alerts | Your three alert rules, **inactive** |
| http://localhost:9093 | Alertmanager (empty until an alert fires) |
| http://localhost:3000 | Grafana: log in as `admin` / `change-me-please` |

> **Note:** On Docker Desktop (Windows or macOS), node_exporter reports the small Linux VM that runs Docker, not your laptop. That's fine for learning.

Stop it with `docker compose down` (add `-v` to delete the stored data).

## Option 2: Install on a Linux server (EC2)

> **In simple words:** On a real server you install the programs as **system services** that start on boot and restart if they crash. One "monitoring" server runs Prometheus, Grafana and Alertmanager; every server you want to watch runs node_exporter.

Use an Amazon Linux 2023 instance (a `t3.small` is enough to start), reached with [Session Manager](#/tool/aws-ssm). Commands below are for Amazon Linux/RHEL; on Ubuntu use `apt` where the steps say `dnf`.

### Step 2a: Prometheus as a service

```bash
PROM_VERSION=3.16.0
sudo useradd --system --no-create-home --shell /sbin/nologin prometheus

cd /tmp
curl -sLO "https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz"
curl -sLO "https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/sha256sums.txt"
sha256sum --check --ignore-missing sha256sums.txt        # must print: OK

tar -xzf "prometheus-${PROM_VERSION}.linux-amd64.tar.gz"
sudo install -m 0755 "prometheus-${PROM_VERSION}.linux-amd64/prometheus" "prometheus-${PROM_VERSION}.linux-amd64/promtool" /usr/local/bin/
sudo mkdir -p /etc/prometheus /var/lib/prometheus
sudo chown -R prometheus:prometheus /var/lib/prometheus
prometheus --version
```

Create `/etc/prometheus/prometheus.yml` (same idea as the lab, but everything on `localhost`) and the rules file:

```bash
sudo tee /etc/prometheus/prometheus.yml > /dev/null <<'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
rule_files:
  - /etc/prometheus/rules.yml
alerting:
  alertmanagers:
    - static_configs:
        - targets: ["localhost:9093"]
scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ["localhost:9090"]
  - job_name: node
    static_configs:
      - targets: ["localhost:9100"]
EOF
# copy rules.yml from Option 1 to /etc/prometheus/rules.yml, then:
sudo promtool check config /etc/prometheus/prometheus.yml    # validates config AND rules
```

Run it as a systemd service:

```bash
sudo tee /etc/systemd/system/prometheus.service > /dev/null <<'EOF'
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --storage.tsdb.retention.time=15d
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now prometheus
systemctl status prometheus --no-pager
curl -s localhost:9090/-/healthy       # Prometheus Server is Healthy.
```

After editing the config later, reload without a restart: `sudo systemctl reload prometheus`.

### Step 2b: node_exporter on every server you want to watch

```bash
NE_VERSION=1.12.1
sudo useradd --system --no-create-home --shell /sbin/nologin node_exporter
cd /tmp
curl -sLO "https://github.com/prometheus/node_exporter/releases/download/v${NE_VERSION}/node_exporter-${NE_VERSION}.linux-amd64.tar.gz"
tar -xzf "node_exporter-${NE_VERSION}.linux-amd64.tar.gz"
sudo install -m 0755 "node_exporter-${NE_VERSION}.linux-amd64/node_exporter" /usr/local/bin/

sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<'EOF'
[Unit]
Description=Prometheus node_exporter
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
ExecStart=/usr/local/bin/node_exporter
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter
curl -s localhost:9100/metrics | grep -c '^node_'     # hundreds of node_ metrics
```

> **Tip:** To install node_exporter on **many** servers at once, use a Systems Manager **State Manager association** (see the [Systems Manager guide](#/tool/aws-ssm)) instead of logging in to each one.

### Step 2c: Grafana from the official package repository

```bash
wget -q -O gpg.key https://rpm.grafana.com/gpg.key
sudo rpm --import gpg.key
sudo tee /etc/yum.repos.d/grafana.repo > /dev/null <<'EOF'
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
EOF
sudo dnf install -y grafana
sudo systemctl enable --now grafana-server
curl -s localhost:3000/api/health      # {"database": "ok", ...}
```

Log in at port 3000 as `admin` / `admin`; Grafana asks you to set a new password straight away. Then add the data source: **Connections → Data sources → Add data source → Prometheus**, URL `http://localhost:9090`, **Save & test**.

### Step 2d: Reach the web pages safely

Don't open ports 9090, 9093 or 3000 to the internet: Prometheus and Alertmanager have **no login page** by default. Two safe options:

| Option | How |
|---|---|
| **Session Manager port forwarding** (no open ports at all) | `aws ssm start-session --target "$INSTANCE_ID" --document-name AWS-StartPortForwardingSession --parameters '{"portNumber":["3000"],"localPortNumber":["3000"]}'`, then open http://localhost:3000 |
| **Security group** limited to your office or VPN | Allow 3000 from your office CIDR only; allow 9100 on the monitored servers **only from the Prometheus server's security group** |

### Step 2e: Find EC2 servers automatically

Typing every server's IP into `prometheus.yml` doesn't scale. With **EC2 service discovery**, Prometheus asks AWS for all instances with a tag, and new servers are monitored automatically:

```yaml
  - job_name: ec2-nodes
    ec2_sd_configs:
      - region: ap-south-1
        port: 9100
        filters:
          - name: tag:monitoring
            values: ["node-exporter"]
    relabel_configs:
      - source_labels: [__meta_ec2_tag_Name]
        target_label: instance_name
      - source_labels: [__meta_ec2_availability_zone]
        target_label: az
```

Add this under `scrape_configs`. The Prometheus server's IAM role needs `ec2:DescribeInstances` (and optionally `ec2:DescribeAvailabilityZones`). Tag servers `monitoring=node-exporter` and they appear on the Targets page within a minute.

## Option 3: Install on Kubernetes with kube-prometheus-stack

> **In simple words:** One Helm chart installs the **whole monitoring kit** into your cluster: Prometheus, Alertmanager, Grafana with ready-made dashboards, node_exporter on every node, kube-state-metrics, and dozens of alert rules for Kubernetes. It also adds the **Prometheus Operator**, which lets you describe "what to scrape" and "what to alert on" as Kubernetes YAML.

| Installed piece | What it does |
|---|---|
| **Prometheus Operator** | Manages Prometheus and Alertmanager from Kubernetes resources (ServiceMonitor, PrometheusRule) |
| **Prometheus** | Scrapes the cluster, nodes and your apps |
| **Alertmanager** | Sends alerts |
| **Grafana** | Dashboards, with Kubernetes dashboards pre-installed |
| **node-exporter** (DaemonSet) | Host metrics from every node |
| **kube-state-metrics** | The state of Kubernetes objects: pods, deployments, restarts |

You need a cluster (see [EKS cluster setup](#/tool/eks-cluster)), `kubectl`, [Helm](#/tool/helm-environments) 3.8 or later, and a storage class for EBS volumes (`kubectl get storageclass`).

### Step 3a: Admin password as a Kubernetes secret

```bash
kubectl create namespace monitoring
kubectl -n monitoring create secret generic grafana-admin \
  --from-literal=admin-user=admin \
  --from-literal=admin-password="$(openssl rand -base64 18)"
```

### Step 3b: A values file for a real cluster

`kps-values.yaml`:

```yaml
grafana:
  admin:
    existingSecret: grafana-admin
    userKey: admin-user
    passwordKey: admin-password
  persistence:
    enabled: true
    size: 10Gi

prometheus:
  prometheusSpec:
    retention: 15d
    retentionSize: 40GiB
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: gp3
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi

alertmanager:
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: gp3
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 5Gi

# On EKS, AWS runs the control plane: these can't be scraped and would
# only cause "target down" alerts, so switch them off.
kubeEtcd:
  enabled: false
kubeControllerManager:
  enabled: false
kubeScheduler:
  enabled: false
```

| Setting | Why |
|---|---|
| `existingSecret` | The Grafana password comes from your secret, not from a file in Git |
| `persistence` / `storageSpec` | Dashboards and metrics survive pod restarts (without them, data is lost on every restart) |
| `retention` / `retentionSize` | Keep 15 days, and never more than 40 GiB, whichever comes first (the chart default is 10 days) |
| `kubeEtcd`, `kubeControllerManager`, `kubeScheduler` off | Managed control planes like EKS don't expose these |

Change `gp3` to your cluster's storage class name.

### Step 3c: Install and open the UIs

```bash
helm upgrade --install kps oci://ghcr.io/prometheus-community/charts/kube-prometheus-stack \
  --version 93.0.0 --namespace monitoring -f kps-values.yaml --wait --timeout 10m

kubectl -n monitoring get pods     # prometheus, alertmanager, grafana, operator, node-exporter, kube-state-metrics
kubectl -n monitoring get svc      # service names start with the release name "kps"

kubectl -n monitoring port-forward svc/kps-grafana 3000:80 &
kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090:9090 &
kubectl -n monitoring get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

Open http://localhost:3000, log in as `admin` with that password, and go to **Dashboards**: you'll find ready-made ones such as **Kubernetes / Compute Resources / Namespace (Pods)** and **Node Exporter / Nodes**. Prometheus's **Targets** page at http://localhost:9090/targets should show everything **UP**.

## Monitor your own application

> **In simple words:** Your app shows its own numbers on a `/metrics` page (most languages have a Prometheus client library). On Kubernetes, a small **ServiceMonitor** object tells Prometheus "scrape this service". On a VM, you add the app to `scrape_configs`.

Your app's Kubernetes Service must have a **named port**, for example:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app
  namespace: my-app
  labels:
    app: my-app
spec:
  selector:
    app: my-app
  ports:
    - name: http-metrics
      port: 8080
      targetPort: 8080
```

Then the ServiceMonitor:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app
  namespace: my-app
  labels:
    release: kps            # IMPORTANT: Prometheus only picks up monitors with this label
spec:
  selector:
    matchLabels:
      app: my-app
  endpoints:
    - port: http-metrics    # the Service port NAME, not the number
      path: /metrics
      interval: 30s
```

```bash
kubectl apply -f service.yaml -f servicemonitor.yaml
# within a minute, Prometheus Targets shows serviceMonitor/my-app/my-app/0 as UP
```

> **Warning:** The two most common mistakes: the ServiceMonitor is missing the `release: kps` label (with this chart's default settings, Prometheus ignores it), or `port:` uses a number instead of the Service port's **name**.

## PromQL in simple words

> **In simple words:** PromQL is how you **ask questions** about your metrics: "How busy is the CPU?", "How many errors per second?", "How slow are the slowest 5% of requests?". Paste these into Prometheus's **Query** page or a Grafana panel.

| Question | PromQL |
|---|---|
| Which targets are down? | `up == 0` |
| CPU used, % per server | `100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)` |
| Memory used, % | `(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100` |
| Root disk used, % | `100 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} * 100` |
| Requests per second, per service | `sum by (job) (rate(http_requests_total[5m]))` |
| Error percentage | `sum(rate(http_requests_total{code=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100` |
| 95th percentile response time | `histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))` |
| Pods restarted in the last hour | `increase(kube_pod_container_status_restarts_total[1h]) > 0` |
| Pods not ready | `kube_pod_status_ready{condition="false"} == 1` |

| Piece | Meaning |
|---|---|
| `{mode="idle"}` | Filter by label |
| `[5m]` | "Look at the last 5 minutes" (a range) |
| `rate(...)` | Per-second speed of a **counter**. Use it for anything ending in `_total` |
| `sum by (job)` / `avg by (instance)` | Add up or average, keeping one line per `job` or `instance` |
| `increase(...[1h])` | How much a counter grew in the last hour |

## Grafana: data sources and dashboards

> **In simple words:** Grafana doesn't store metrics: it **asks** Prometheus and draws the answer. You can import a ready-made dashboard in one minute, or build your own panel from a PromQL query.

**Import a community dashboard** (the famous "Node Exporter Full"):

1. **Dashboards → New → Import**.
2. Enter ID **1860** → **Load**.
3. Choose the **Prometheus** data source → **Import**.

**Build your own panel:**

1. **Dashboards → New → New dashboard → Add visualization** → choose **Prometheus**.
2. Paste the CPU query from the PromQL table. Set **Legend** to `{{instance}}` and **Unit** to *Percent (0-100)*.
3. Add a **threshold** at 85 (red), give the panel a title, and **Save dashboard**.
4. Add a **variable** (*Dashboard settings → Variables → New*, type *Query*, query `label_values(up, instance)`) and use `instance=~"$instance"` in your queries, so viewers can pick a server from a drop-down.

| Good habit | Why |
|---|---|
| Put dashboards in **folders** per team | Easy to find, easy to give permissions |
| Keep important dashboards **as code** (JSON in Git) | Survives rebuilds. On Kubernetes, a ConfigMap labelled `grafana_dashboard: "1"` is loaded automatically by this chart |
| Show the **4 golden signals** first: traffic, errors, latency, saturation | Answers "is the service OK?" at a glance |

## Alerts: rules and Alertmanager

> **In simple words:** **Prometheus** decides *when* something is wrong (alert rules). **Alertmanager** decides *who hears about it and how*: it groups related alerts into one message, routes them (critical to the pager, warnings to Slack), and lets you **silence** alerts during planned work.

An alert goes through three states:

| State | Meaning |
|---|---|
| **Inactive** | The condition is false: all good |
| **Pending** | The condition is true, but not yet for the whole `for:` time (avoids alerts for short spikes) |
| **Firing** | True for the whole `for:` time: sent to Alertmanager |

### On Kubernetes: your own alert rule

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: my-app-alerts
  namespace: my-app
  labels:
    release: kps
spec:
  groups:
    - name: my-app
      rules:
        - alert: MyAppHighErrorRate
          expr: sum(rate(http_requests_total{job="my-app",code=~"5.."}[5m])) / sum(rate(http_requests_total{job="my-app"}[5m])) > 0.05
          for: 10m
          labels:
            severity: critical
          annotations:
            summary: "More than 5% of my-app requests are failing"
```

### Send alerts to Slack

> **Note:** With this chart's default settings, Alertmanager sends every alert to a receiver called `null`, which means **nobody is notified** until you add a real receiver like the one below.

Create a Slack **incoming webhook** for your channel, store it as a secret, and add this to `kps-values.yaml`:

```bash
kubectl -n monitoring create secret generic alertmanager-slack --from-literal=webhook-url="$SLACK_WEBHOOK_URL"
```

```yaml
alertmanager:
  alertmanagerSpec:
    secrets: [alertmanager-slack]     # mounted under /etc/alertmanager/secrets/alertmanager-slack/
  config:
    route:
      receiver: slack
      group_by: [alertname, namespace]
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 4h
      routes:
        - receiver: "null"
          matchers: ['alertname = "Watchdog"']   # a test alert that always fires; keep it quiet
    receivers:
      - name: "null"
      - name: slack
        slack_configs:
          - api_url_file: /etc/alertmanager/secrets/alertmanager-slack/webhook-url
            channel: "#alerts"
            send_resolved: true
            title: '{{ .CommonAnnotations.summary }}'
```

Run the same `helm upgrade --install` command again to apply it. For the VM install, put the `route` and `receivers` part in `/etc/alertmanager/alertmanager.yml`.

| Alertmanager word | Simple meaning |
|---|---|
| **Grouping** | 20 pods failing becomes **one** message, not 20 |
| **Routing** | Different alerts go to different people or channels |
| **Inhibition** | If the whole server is down, don't also send "disk full" for it |
| **Silence** | Mute matching alerts for a planned window, e.g. during an upgrade |

## Production tips

> **In simple words:** A lab works with one of everything. In production, plan for **storage**, **high availability**, **long-term history** and **security** from the start.

| Topic | What to do |
|---|---|
| **Storage size** | Roughly: number of series × bytes per sample × samples per day × days. Start with 50 GB, watch `prometheus_tsdb_storage_blocks_bytes`, and set `retentionSize` so the disk never fills |
| **High availability** | Run **2 Prometheus replicas** (`prometheusSpec.replicas: 2`) and **3 Alertmanagers**; Alertmanager removes duplicate alerts |
| **Long-term history** | Prometheus keeps days or weeks. For months or years, `remote_write` to **Thanos**, **Grafana Mimir** or **Amazon Managed Service for Prometheus** |
| **Security** | Never expose Prometheus or Alertmanager publicly (no login by default). Put Grafana behind SSO and HTTPS |
| **Cardinality** | Watch the top series count (`topk(10, count by (__name__)({__name__=~".+"}))`) and drop noisy labels |
| **Recording rules** | Pre-calculate heavy queries every minute, so dashboards load fast |
| **Alert on symptoms** | "Customers see errors" is better than "CPU is high". Every alert needs a clear action |

## Troubleshooting

> **In simple words:** Start at the **Targets** page: if a target is DOWN, Prometheus shows the exact error next to it. Most problems are network, a wrong port, or a missing label.

| Problem | Likely cause | Fix |
|---|---|---|
| Target **DOWN**: `connection refused` | Exporter not running, or wrong port | `systemctl status node_exporter`; check the port in the config |
| Target **DOWN**: `context deadline exceeded` | Firewall or security group blocks the port | Allow 9100 from the Prometheus server's security group |
| ServiceMonitor never appears in Targets | Missing `release: kps` label, or port name doesn't match the Service | Add the label; use the Service port **name** |
| Grafana panel says **No data** | Wrong data source URL, wrong time range, or a metric name typo | Test the query on Prometheus's Query page first; in Docker use `http://prometheus:9090`, not `localhost` |
| Forgot the Grafana admin password | | VM: `sudo grafana cli --homepath /usr/share/grafana --config /etc/grafana/grafana.ini admin reset-admin-password NEW_PASSWORD`. Kubernetes: read the `grafana-admin` secret |
| Prometheus uses lots of memory or gets OOMKilled | Too many time series (high cardinality) | Find the biggest metrics and drop labels with `metric_relabel_configs`; give it more memory |
| Disk full | Retention too long for the volume | Set `retentionSize`, or grow the volume |
| Alerts fire but nothing reaches Slack | Route doesn't match, wrong webhook, or still the default `null` receiver | Check Alertmanager's page and logs: `kubectl -n monitoring logs statefulset/alertmanager-kps-kube-prometheus-stack-alertmanager` |
| Prometheus pod **Pending** | PVC can't be created | Check the storage class exists and the EBS CSI driver is installed |
| Constant `TargetDown` alerts for etcd, scheduler or controller manager on EKS | Managed control plane can't be scraped | Disable them in values (Step 3b) |

## Clean up

> **In simple words:** Remove what you installed so nothing keeps running (or costing money).

```bash
# Option 1 (laptop)
docker compose down -v

# Option 2 (EC2): terminate the instance, or stop the services
sudo systemctl disable --now prometheus node_exporter grafana-server

# Option 3 (Kubernetes)
helm uninstall kps -n monitoring
kubectl -n monitoring delete pvc --all          # deletes stored metrics and dashboards
kubectl delete namespace monitoring
# The chart's CRDs stay installed; remove them only if nothing else uses them:
kubectl get crd -o name | grep monitoring.coreos.com
```

## Lab and cheat sheet

> **In simple words:** Practise until you can answer "is it healthy, and if not, why?" from Grafana alone, and get an alert before anyone else notices.

1. Run Option 1. In Prometheus, run `up` and the CPU query from the PromQL table.
2. Import dashboard **1860** in Grafana and find your memory and disk usage.
3. Stop node_exporter (`docker compose stop node-exporter`). Watch `InstanceDown` go **Pending**, then **Firing**, and appear in Alertmanager. Start it again and watch it resolve.
4. Build your own dashboard with CPU, memory and disk panels and an `instance` variable.
5. On a Kubernetes cluster, install the chart with your values file and open **Kubernetes / Compute Resources / Namespace (Pods)**.
6. Deploy any app that exposes `/metrics`, add a ServiceMonitor, and see it in Targets.
7. Add a `PrometheusRule` and send its alert to a Slack test channel.

### Cheat sheet

| Task | Command or query |
|---|---|
| Check config and rules | `promtool check config /etc/prometheus/prometheus.yml` |
| Reload Prometheus config | `sudo systemctl reload prometheus` (or `curl -X POST localhost:9090/-/reload` if started with `--web.enable-lifecycle`) |
| Is Prometheus healthy? | `curl localhost:9090/-/healthy` |
| See raw metrics | `curl -s localhost:9100/metrics \| head` |
| Install the stack | `helm upgrade --install kps oci://ghcr.io/prometheus-community/charts/kube-prometheus-stack -n monitoring -f kps-values.yaml` |
| Open Grafana (Kubernetes) | `kubectl -n monitoring port-forward svc/kps-grafana 3000:80` |
| Open Prometheus (Kubernetes) | `kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090:9090` |
| What's down? | `up == 0` |
| CPU % | `100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)` |
| Requests per second | `sum by (job) (rate(http_requests_total[5m]))` |

Official docs: [Prometheus overview](https://prometheus.io/docs/introduction/overview/) · [Metric types](https://prometheus.io/docs/concepts/metric_types/) · [Querying basics](https://prometheus.io/docs/prometheus/latest/querying/basics/) · [Configuration](https://prometheus.io/docs/prometheus/latest/configuration/configuration/) · [Alertmanager](https://prometheus.io/docs/alerting/latest/alertmanager/) · [Grafana docs](https://grafana.com/docs/grafana/latest/) · [kube-prometheus-stack chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) · [Node Exporter Full dashboard](https://grafana.com/grafana/dashboards/1860-node-exporter-full/)

For monitoring AWS services themselves (load balancers, databases, Lambda), see [CloudWatch](#/tool/aws-cloudwatch); for searching logs, see [Firehose and OpenSearch](#/tool/aws-opensearch).
