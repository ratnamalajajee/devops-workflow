# Multi-cloud runbook: AWS → Azure → GCP

Every NextGen platform service on AWS, Azure and Google Cloud, side by side. The page is served at `/multicloud/` and linked from the DevOps Launchpad sidebar as **AWS · Azure · GCP runbook**. For each of the 24 services it shows:

- Console steps and CLI for all three clouds, with **AWS / Azure / GCP** toggles to compare any combination.
- How it differs from AWS, and links to the official docs.
- A runnable script behind every CLI block. The path above each block opens the script.

## What's in this folder

```
multicloud/
├── index.html              the page (built: don't edit by hand)
├── aws/                    AWS CLI v2 scripts
│   ├── nextgen-aws.env     your values: profile, region, names (edit once)
│   ├── 00-foundation.sh … 25-cleanup.sh
│   └── terraform/backend.tf
├── azure/                  Azure CLI scripts, same layout (nextgen-azure.env)
├── gcp/                    gcloud scripts, same layout (nextgen-gcp.env)
├── runbook/
│   ├── template.html       layout, console steps, notes, doc links
│   └── build.py            template + scripts → index.html
└── run-step.sh             run one step for one cloud
```

Steps are numbered in dependency order: 00 foundation, 01–04 identity and security, 05–11 networking, 12–14 compute, 15–17 storage, 18–20 databases, 21–22 load balancing, 23 DNS, 24 monitoring, 25 clean up. Steps with two scripts use letters (`13a-aks.sh`, then `13b-aks-workload-identity.sh`).

## Run a step

Scripts are Bash. Use AWS CloudShell, Azure Cloud Shell, Google Cloud Shell, WSL or Git Bash.

```bash
cd multicloud
# 1. Put your values in the env file once: aws/nextgen-aws.env, azure/nextgen-azure.env or gcp/nextgen-gcp.env
bash run-step.sh azure 00     # 2. sign in and create the base
bash run-step.sh azure 05     # 3. then each step in order: 05, 06, 07 …
```

Each script loads its env file, stops at the first failing command (`set -euo pipefail`), and writes scratch files to `~/nextgen-work/<cloud>` instead of the repo. Set `WORK_DIR` to change that.

Before the first run, replace the placeholders: subscription ID, billing account, AWS profile, `SUFFIX`, the `example.com` domain and email addresses, `jane.doe` user names, the `PlatformAdmins` role in `aws/13a-eks.sh`, and the corporate range `203.0.113.0/24`.

> **Cost:** these scripts create billable resources: Kubernetes clusters, databases, NAT gateways and a Virtual WAN hub. Run step 25 to tear a test environment down.

## Change the page

| To change | Edit | Then |
|---|---|---|
| A command | the script, below its `# --- runbook commands` line | `python multicloud/runbook/build.py` |
| Console steps, notes, doc links, layout | `runbook/template.html` | `python multicloud/runbook/build.py` |
| Add a script | create it (copy the header from a neighbour) and add `<pre data-src="azure/NN-name.sh"><code></code></pre>` to the template | `python multicloud/runbook/build.py` |

- Commit the rebuilt `index.html` with your change. `python multicloud/runbook/build.py --check` fails if the committed page doesn't match the scripts.
- The script header (shebang, env loading, `set -euo pipefail`) isn't shown on the page, so the page stays copy-paste friendly.
- `build.py` lists any script that isn't on the page yet.
- The site itself still has no build step. Cloudflare Pages and the Docker image serve the committed `index.html` as a static file.

## Conventions

- Names: `{type}-{prefix}-{env}`, for example `vnet-nextgen-dev`. Globally unique names add `SUFFIX`.
- Address plans: AWS `10.40.0.0/16`, Azure `10.10.0.0/16`, GCP `10.20.0.0/16`, GCP private services `10.30.0.0/16`. They don't overlap, so the clouds can be connected later.
- Each script looks up the IDs it needs from earlier steps, so it can run in a fresh shell.
- Terraform state locking needs no database on Azure or GCP: see `*/terraform/backend.tf` and step 18 on the page.
