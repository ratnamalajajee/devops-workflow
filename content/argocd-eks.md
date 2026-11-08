# Argo CD on EKS: Installation Runbook

A step-by-step runbook for installing Argo CD on an existing Amazon EKS cluster, exposing it inside the company network, connecting a **Bitbucket** repository over SSH, and deploying a **Helm chart** as an Argo CD Application. Every command is meant to be copied in order. Replace the example values with your own once, in the first step.

> **Note:** This runbook assumes the EKS cluster already exists (see the [EKS Cluster Setup runbook](#/tool/eks-cluster), or your team's Terraform), and that you have `aws`, `kubectl` and cluster-admin access. For the concepts behind each step, see the [Argo CD guide](#/tool/argocd).

> **Warning:** Never write real passwords, tokens, private keys or internal IP addresses into runbooks, tickets or chat. Use the variables below, and keep secrets in a password manager or AWS Secrets Manager.

## Start here: the flow in simple words

> **In simple words:** You install Argo CD into the cluster, log in, give it read access to your Bitbucket repository, and then describe your app in one YAML file. From then on, Argo CD keeps the cluster matching what is in Git.

```text
 1. Install argocd CLI (your laptop / jump host)
 2. Connect kubectl to the EKS cluster
 3. Install Argo CD into namespace "argocd"
 4. Log in (port-forward) and change the admin password
 5. Expose the UI on an INTERNAL load balancer (company network / VPN only)
 6. Give Argo CD a read-only SSH key for Bitbucket
 7. Create the Application (Helm chart from Bitbucket → namespace in the cluster)
 8. Verify, operate, roll back
```

### Prerequisites

| Requirement | Check with |
|---|---|
| AWS CLI with access to the account | `aws sts get-caller-identity` |
| `kubectl` | `kubectl version --client` |
| Cluster-admin rights on the EKS cluster | `kubectl auth can-i '*' '*' --all-namespaces` |
| Network path to Bitbucket from the cluster (VPC → Bitbucket on port 7999) | Ask the network team if unsure |
| Permission to add an access key to the Bitbucket repository | Repository admin in Bitbucket |

### Set your values once

Edit these for your environment, paste them into your terminal, and every later command uses them:

```bash
export AWS_REGION=us-east-1
export CLUSTER_NAME=my-cluster                       # aws eks list-clusters
export ARGOCD_VERSION=v3.5.6                          # https://github.com/argoproj/argo-cd/releases
export BITBUCKET_HOST=bitbucket.example.internal      # Bitbucket Server hostname (prefer DNS over an IP)
export BITBUCKET_SSH_PORT=7999                        # Bitbucket Server default SSH port
export REPO_PREFIX="ssh://git@${BITBUCKET_HOST}:${BITBUCKET_SSH_PORT}/proj/"   # project path in Bitbucket
export CHART_REPO="${REPO_PREFIX}helm-charts.git"
```

## Install the Argo CD CLI

> **In simple words:** The `argocd` command lets you log in, add repositories and manage applications from the terminal. Install it once on your laptop or jump host.

```bash
curl -sSL -o argocd-linux-amd64 \
  https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

argocd version --client
```

Use the **same version** as the server you install in the next steps. On macOS, use `brew install argocd`; on ARM machines, download `argocd-linux-arm64`.

## Connect kubectl to the EKS cluster

> **In simple words:** Point `kubectl` at the right cluster before installing anything, and double-check you are on it. Installing into the wrong cluster is the most common mistake.

```bash
aws eks list-clusters --region $AWS_REGION
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

kubectl config current-context        # must show your cluster
kubectl get nodes                     # nodes should be Ready
```

## Install Argo CD

> **In simple words:** Create the `argocd` namespace and apply the official install manifest for a pinned version. Argo CD then runs as a few small pods inside the cluster.

```bash
kubectl create namespace argocd

kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml

kubectl -n argocd rollout status deploy/argocd-server --timeout=5m
kubectl get pods -n argocd
```

All pods (`argocd-server`, `argocd-repo-server`, `argocd-application-controller`, `argocd-redis`, `argocd-dex-server`, `argocd-applicationset-controller`, `argocd-notifications-controller`) should be `Running`.

| Why these choices | |
|---|---|
| **Pinned version** instead of `stable` | `stable` changes over time; pinning makes the install repeatable and upgrades deliberate |
| `--server-side --force-conflicts` | Argo CD's CRDs are too large for a normal client-side apply in recent versions |

For production with 3 or more nodes, use `manifests/ha/install.yaml`. See **Installation methods compared** in the [Argo CD guide](#/tool/argocd).

## Log in with the CLI and change the admin password

> **In simple words:** Open a private tunnel to Argo CD, read the one-time admin password, log in, set your own password, and then delete the one-time password.

Terminal 1, keep it running:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Terminal 2:

```bash
# 1. Read the initial admin password (generated at install time)
argocd admin initial-password -n argocd
# same thing with kubectl:
# kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

# 2. Log in. Type the password at the prompt, don't put it on the command line
argocd login 127.0.0.1:8080 --username admin --insecure

# 3. Set a new strong password (store it in your password manager)
argocd account update-password

# 4. Remove the one-time password secret
kubectl -n argocd delete secret argocd-initial-admin-secret
```

- `--insecure` is needed because the port-forward uses Argo CD's self-signed certificate.
- Passwords typed after `--password` end up in your **shell history** and in process lists. Let the CLI prompt you instead.
- Long term, connect Argo CD to company SSO and disable the `admin` user. See **Private repos, projects and access** in the Argo CD guide.

## Expose the UI on an internal load balancer

> **In simple words:** Port-forwarding only works on your machine. To give the team a URL, put Argo CD behind an **internal** AWS load balancer, reachable only from the company network or VPN, never from the internet.

**Order matters:** add the *internal* annotation **first**, then change the service type. If the service becomes a `LoadBalancer` first, AWS creates an **internet-facing** load balancer, and adding the annotation afterwards does not change it.

```bash
# 1. Mark the service as internal
kubectl annotate svc argocd-server -n argocd \
  service.beta.kubernetes.io/aws-load-balancer-internal="true" --overwrite

# 2. Turn the service into a LoadBalancer
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# 3. Wait for the address (EXTERNAL-IP shows a DNS name after 1–3 minutes)
kubectl get svc argocd-server -n argocd -w
```

Open `https://<EXTERNAL-IP DNS name>` from the company network and sign in as `admin` with the password you set. The browser warns about the self-signed certificate until you add a proper one.

> **Note:** If your cluster runs the **AWS Load Balancer Controller**, use its annotations instead, before patching the type: `service.beta.kubernetes.io/aws-load-balancer-type: external`, `service.beta.kubernetes.io/aws-load-balancer-scheme: internal` and `service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip`. For a proper HTTPS URL with a company certificate, use an internal **Ingress (ALB) with an ACM certificate** instead. See the [Load Balancers guide](#/tool/aws-elb).

Check that it really is internal:

```bash
LB_DNS=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
dig +short $LB_DNS        # should return private IPs only (10.x, 172.16–31.x, 192.168.x)
```

The port-forward from the previous step is no longer needed for the UI.

## Connect Bitbucket repositories over SSH

> **In simple words:** Argo CD needs to **read** your Git repositories. Create a dedicated SSH key just for Argo CD, add its public half to Bitbucket as a **read-only access key**, tell Argo CD to trust Bitbucket's host key, then give Argo CD the private half.

### 1. Create a dedicated key for Argo CD

Use a separate key, not your personal one. Personal keys stop working when people leave and usually have write access.

```bash
ssh-keygen -t ed25519 -a 100 -N "" -C "argocd@${CLUSTER_NAME}" -f ~/.ssh/argocd_bitbucket
cat ~/.ssh/argocd_bitbucket.pub
```

### 2. Add the public key to Bitbucket (read-only)

In Bitbucket Server / Data Center: **Repository (or Project) → Settings → Access keys → Add key**. Paste the contents of `argocd_bitbucket.pub` and choose **Read** permission. Adding it at **project** level lets the same key read every repository in the project.

### 3. Trust Bitbucket's SSH host key inside Argo CD

Argo CD keeps its own list of trusted SSH hosts, so your laptop's `~/.ssh/known_hosts` doesn't help it. Scan the host on the Bitbucket SSH port and load the result into Argo CD:

```bash
ssh-keyscan -p $BITBUCKET_SSH_PORT $BITBUCKET_HOST | argocd cert add-ssh --batch
argocd cert list --cert-type ssh
```

Compare the fingerprint with the one your Bitbucket admins publish before trusting it.

### 4. Give Argo CD the private key

A **credential template** applies one key to every repository under a URL prefix, so you don't need to add each repository separately:

```bash
argocd repocreds add "$REPO_PREFIX" --ssh-private-key-path ~/.ssh/argocd_bitbucket
argocd repocreds list

# optional: register the chart repo now so its status shows in the UI
argocd repo add "$CHART_REPO"
argocd repo list            # CONNECTION STATE should be "Successful"
```

> **Warning:** Avoid `--insecure-ignore-host-key`. It turns off the check that you're talking to the real Bitbucket server, which makes step 3 pointless and opens the door to man-in-the-middle attacks. Fix host-key errors by re-running step 3 instead.

Once Argo CD has the key, delete your local copy of the private key, or store it in your secrets manager.

## Create the Argo CD Application

> **In simple words:** One YAML file tells Argo CD **where** the chart is (repository, path, branch), **how** to render it (Helm values), **where** to deploy it (namespace), and **how** to keep it in sync.

Save as `argocd-app.yaml`, then change the values marked `# CHANGE`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp-prod                     # CHANGE: unique app name
  namespace: argocd                    # Applications always live in the argocd namespace
  labels:
    app.kubernetes.io/part-of: myapp
  finalizers:
    - resources-finalizer.argocd.argoproj.io   # deleting the app also deletes what it deployed
spec:
  project: default

  source:
    repoURL: ssh://git@bitbucket.example.internal:7999/proj/helm-charts.git   # CHANGE
    path: charts/myapp                 # CHANGE: folder that contains Chart.yaml
    targetRevision: main               # CHANGE: branch or tag (use main or a release tag for prod)
    helm:
      releaseName: myapp
      valueFiles:
        - values.yaml
        - values-prod.yaml             # CHANGE or remove: environment-specific overrides

  destination:
    server: https://kubernetes.default.svc   # the cluster Argo CD runs in
    namespace: myapp-prod                    # CHANGE: avoid "default" for real apps

  syncPolicy:
    automated:
      prune: true          # delete resources that were removed from Git
      selfHeal: true       # undo manual changes made directly in the cluster
      allowEmpty: false    # never sync an empty set (protects against a bad commit wiping the app)
    syncOptions:
      - CreateNamespace=true                # create the destination namespace if missing
      - PrunePropagationPolicy=foreground   # wait for dependents to be removed when pruning
      - PruneLast=true                      # prune only after everything else is synced and healthy
    retry:
      limit: 5             # retry failed syncs up to 5 times
      backoff:
        duration: 5s       # first wait
        factor: 2          # double the wait each time
        maxDuration: 3m    # never wait longer than this

  # Ignore fields that other controllers change, so the app doesn't look OutOfSync
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas   # replicas are managed by the HorizontalPodAutoscaler
    - group: "*"
      kind: "*"
      managedFieldsManagers:
        - kube-controller-manager

  revisionHistoryLimit: 10   # how many past syncs to keep for history and rollback
```

Create it, using **one** of these:

```bash
kubectl apply -n argocd -f argocd-app.yaml       # declarative (recommended: same file can live in Git)
# or
argocd app create -f argocd-app.yaml             # via the Argo CD API
```

Then watch it come up:

```bash
argocd app get myapp-prod
argocd app wait myapp-prod --health --timeout 300
kubectl get all -n myapp-prod
```

> **Tip:** Keep `argocd-app.yaml` itself in Git, for example in a `gitops` repository, and manage all Applications with an **App of Apps**. Then even the Argo CD configuration is versioned and reviewable. See **App of Apps and ApplicationSets** in the [Argo CD guide](#/tool/argocd).

## Verify and operate

> **In simple words:** The everyday commands to check status, see what would change, sync on demand and roll back.

```bash
argocd app list                          # all apps: SYNC STATUS and HEALTH
argocd app get myapp-prod                # details, resources, last sync
argocd app diff myapp-prod               # what differs between Git and the cluster
argocd app sync myapp-prod               # sync now (no need to wait for polling)
argocd app get myapp-prod --refresh      # re-read Git immediately
argocd app history myapp-prod            # past syncs with revisions
argocd app logs myapp-prod --tail 50     # logs from the app's pods
```

**Rolling back:** the GitOps way is to revert the commit in the chart repository, and Argo CD syncs the previous version. For an emergency, `argocd app rollback myapp-prod <history-id>` also works, but it requires **automated sync to be off**. Otherwise self-heal immediately re-applies what's in Git.

| What you see | Meaning |
|---|---|
| **Synced + Healthy** | Cluster matches Git and everything is running |
| **OutOfSync** | Git has changes not yet applied, or someone changed the cluster by hand |
| **Progressing** | New pods are starting |
| **Degraded** | Something is failing: check `kubectl describe` and logs of the failing pods |
| **Unknown / ComparisonError** | Argo CD can't read or render the source: repository access, path or Helm values |

## Troubleshooting

> **In simple words:** Most problems are one of three things: Argo CD can't reach or read the repository, the chart can't be rendered, or the workload itself is failing.

| Problem | Fix |
|---|---|
| `ssh: handshake failed: knownhosts: key is unknown` | Bitbucket's host key isn't trusted. Re-run `ssh-keyscan -p 7999 … \| argocd cert add-ssh --batch` |
| `ssh: unable to authenticate` / `permission denied (publickey)` | The access key isn't added in Bitbucket, has no Read permission, or the wrong private key was given. Check `argocd repocreds list` |
| Repository times out | No network path from the cluster to Bitbucket on port 7999 (security groups, firewall, VPN routing) |
| `ComparisonError: app path does not exist` | Wrong `path` or `targetRevision`; the path must contain `Chart.yaml` on that branch |
| `values-prod.yaml: no such file` | A file in `valueFiles` doesn't exist in that chart folder |
| App always `OutOfSync` on replicas | Add `ignoreDifferences` for `/spec/replicas` (already in the template) when an HPA manages them |
| `EXTERNAL-IP` stays `<pending>` | Subnets lack the `kubernetes.io/role/internal-elb` tag, or the load balancer controller isn't working. Check `kubectl describe svc argocd-server -n argocd` |
| Load balancer is internet-facing | The annotation was added after the type change. Patch the type back to `ClusterIP`, then annotate first and patch to `LoadBalancer` again |
| `argocd login` through the load balancer hangs | Add `--grpc-web` to the CLI command |
| `argocd-initial-admin-secret not found` | It was already deleted after the password change. Use your saved password, or reset it with `argocd admin` |

Logs that usually explain the problem:

```bash
kubectl logs -n argocd deploy/argocd-repo-server --tail 100            # Git and Helm rendering
kubectl logs -n argocd statefulset/argocd-application-controller --tail 100   # syncing
kubectl describe svc argocd-server -n argocd                           # load balancer events
```

## Quick reference

> **In simple words:** The whole runbook as one compact command list, for when you've done it before.

```bash
# 0. variables (see step 1)
# 1. CLI
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64 \
  && sudo install -m 555 argocd /usr/local/bin/argocd && rm argocd
# 2. cluster
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME && kubectl get nodes
# 3. install
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server
# 4. login (keep the port-forward in another terminal)
kubectl port-forward svc/argocd-server -n argocd 8080:443
argocd admin initial-password -n argocd
argocd login 127.0.0.1:8080 --username admin --insecure
argocd account update-password && kubectl -n argocd delete secret argocd-initial-admin-secret
# 5. internal load balancer (annotation FIRST)
kubectl annotate svc argocd-server -n argocd service.beta.kubernetes.io/aws-load-balancer-internal="true" --overwrite
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
# 6. Bitbucket access (public key added as a READ access key in Bitbucket)
ssh-keygen -t ed25519 -a 100 -N "" -f ~/.ssh/argocd_bitbucket
ssh-keyscan -p $BITBUCKET_SSH_PORT $BITBUCKET_HOST | argocd cert add-ssh --batch
argocd repocreds add "$REPO_PREFIX" --ssh-private-key-path ~/.ssh/argocd_bitbucket
# 7. application
kubectl apply -n argocd -f argocd-app.yaml && argocd app wait myapp-prod --health
```
