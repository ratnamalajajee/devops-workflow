# Argo CD and GitOps

Argo CD is a **GitOps** continuous-delivery tool for Kubernetes. Instead of a pipeline running `kubectl apply`, you commit manifests to Git, and Argo CD, running *inside* the cluster, keeps the cluster in sync with what Git says. Git becomes the single source of truth, every change is a reviewed commit, and rollback is `git revert`.

> **Note:** You need a running cluster (the kind cluster from the Kubernetes guide is perfect) and a GitHub or GitLab account.

> **Tip:** No Docker or Kubernetes on your laptop? Use the **cloud lab machine** in the [Practice lab](#/lab). It has Docker, kind, kubectl, Helm, Terraform, the AWS CLI and the Argo CD CLI ready to go.

## GitOps concepts

```text
 Developer ──PR──▶ Git repo (desired state) ◀──watches/pulls── Argo CD (in cluster)
                                                                    │ applies + reports drift
                                                                    ▼
                                                             Kubernetes cluster
```

| Push-based CD (classic pipeline) | Pull-based GitOps (Argo CD) |
|---|---|
| CI holds cluster credentials | Credentials never leave the cluster |
| Manual `kubectl` changes go unnoticed | Drift is detected and can be auto-reverted |
| Hard to know what's deployed | Git history *is* the deployment history |
| Rollback means re-running an old pipeline | Rollback means `git revert` |

The four GitOps principles: **declarative**, **versioned and immutable** (in Git), **pulled automatically**, **continuously reconciled**.

Key Argo CD terms:

| Term | Meaning |
|---|---|
| **Application** | A CRD linking a Git *source* (repo + path + revision) to a *destination* (cluster + namespace) |
| **Sync** | Apply what's in Git to the cluster |
| **Sync status** | `Synced` or `OutOfSync`: does the cluster match Git? |
| **Health status** | `Healthy`, `Progressing` or `Degraded`: are the resources actually working? |
| **Project** | Groups apps and restricts which repos and destinations they may use |

## Install Argo CD

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl -n argocd rollout status deploy/argocd-server
kubectl get pods -n argocd
```

You should see the `argocd-server`, `argocd-repo-server`, `argocd-application-controller`, `argocd-redis` and `argocd-dex-server` pods running.

> **Tip:** For production, install with the official Helm chart (`helm repo add argo https://argoproj.github.io/argo-helm`, then `helm install argocd argo/argo-cd -n argocd`) so Argo CD's own config lives in Git too.

## Access the UI and CLI

```bash
# 1. Port-forward the API/UI (leave running in a separate terminal)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# 2. Get the initial admin password
argocd admin initial-password -n argocd

# 3. Log in with the CLI
argocd login localhost:8080 --username admin --insecure
argocd account update-password
```

Open **https://localhost:8080** (accept the self-signed certificate) and log in as `admin`.

> **Warning:** After changing the password, delete the bootstrap secret: `kubectl -n argocd delete secret argocd-initial-admin-secret`. In real environments, disable `admin` and use SSO.

## Prepare a GitOps repository

Create a new GitHub repository, for example `gitops-lab`, with this layout:

```text
gitops-lab/
├── apps/                     # Argo CD Application manifests
│   └── guestbook.yaml
├── guestbook/                # plain manifests for one app
│   ├── deployment.yaml
│   └── service.yaml
└── envs/                     # Kustomize overlays (later step)
```

```bash
git clone git@github.com:<you>/gitops-lab.git && cd gitops-lab
mkdir -p apps guestbook
```

`guestbook/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: guestbook
spec:
  replicas: 2
  selector:
    matchLabels:
      app: guestbook
  template:
    metadata:
      labels:
        app: guestbook
    spec:
      containers:
        - name: guestbook
          image: gcr.io/heptio-images/ks-guestbook-demo:0.2
          ports:
            - containerPort: 80
```

`guestbook/service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: guestbook
spec:
  selector:
    app: guestbook
  ports:
    - port: 80
      targetPort: 80
```

```bash
git add . && git commit -m "Add guestbook manifests" && git push
```

> **Tip:** Many companies keep **application source code** and **deployment manifests** in separate repos. CI builds the image, then commits the new image tag to the GitOps repo, and Argo CD deploys it.

## Your first Application

Define the Application declaratively, so it can live in Git as well. `apps/guestbook.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/<you>/gitops-lab.git
    targetRevision: main
    path: guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: guestbook
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
```

```bash
kubectl apply -f apps/guestbook.yaml
argocd app get guestbook          # Status: OutOfSync (nothing deployed yet)
argocd app sync guestbook         # deploy
argocd app wait guestbook --health
kubectl get all -n guestbook
```

Watch the resource tree appear in the UI. Now make a **GitOps change**: edit `replicas: 2` → `replicas: 4`, commit and push, then:

```bash
argocd app diff guestbook
argocd app sync guestbook
```

The CLI equivalent of the YAML, useful for quick experiments:

```bash
argocd app create guestbook --repo https://github.com/<you>/gitops-lab.git --path guestbook \
  --dest-server https://kubernetes.default.svc --dest-namespace guestbook --sync-option CreateNamespace=true
```

## Automated sync, prune and self-heal

Manual sync is good for learning. Real GitOps is automatic. Update `syncPolicy`:

```yaml
  syncPolicy:
    automated:
      prune: true      # delete resources removed from Git
      selfHeal: true   # revert manual changes made in the cluster
    syncOptions:
      - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 10s
        factor: 2
        maxDuration: 3m
```

```bash
kubectl apply -f apps/guestbook.yaml
```

Test self-heal by going around Git:

```bash
kubectl scale deploy guestbook -n guestbook --replicas=1
kubectl get deploy guestbook -n guestbook -w
# Argo CD sets it back to the Git value within seconds
```

> **Why:** Self-heal enforces "Git is the only way to change production". Manual hotfixes get reverted, so they have to go through a pull request.

Argo CD polls Git every ~3 minutes by default. Configure a **webhook** from GitHub to `https://<argocd>/api/webhook` for instant syncs.

## Helm and Kustomize sources

### Helm chart from a repository

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: redis
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://charts.bitnami.com/bitnami
    chart: redis
    targetRevision: 20.*            # chart version
    helm:
      valuesObject:
        architecture: standalone
        auth:
          enabled: false
  destination:
    server: https://kubernetes.default.svc
    namespace: data
  syncPolicy:
    automated: { prune: true, selfHeal: true }
    syncOptions: [CreateNamespace=true]
```

### Kustomize overlays per environment

Kustomize patches a shared **base** for each environment, without templates:

```text
envs/
├── base/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
├── dev/
│   └── kustomization.yaml
└── prod/
    └── kustomization.yaml
```

`envs/base/kustomization.yaml`:

```yaml
resources:
  - deployment.yaml
  - service.yaml
```

`envs/prod/kustomization.yaml`:

```yaml
resources:
  - ../base
namespace: guestbook-prod
replicas:
  - name: guestbook
    count: 5
images:
  - name: gcr.io/heptio-images/ks-guestbook-demo
    newTag: "0.2"
```

```bash
kubectl kustomize envs/prod     # preview the rendered output
```

Point an Application's `path` at `envs/prod`. Argo CD detects Kustomize automatically.

## App of Apps and ApplicationSets

Managing dozens of Application objects by hand doesn't scale.

### App of Apps

One "root" Application points at the `apps/` folder, which contains other Application manifests. Bootstrap the cluster once, and everything else comes from Git:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/<you>/gitops-lab.git
    targetRevision: main
    path: apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated: { prune: true, selfHeal: true }
```

### ApplicationSet

Generate Applications from a template, here one per environment folder:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: guestbook-envs
  namespace: argocd
spec:
  goTemplate: true
  generators:
    - git:
        repoURL: https://github.com/<you>/gitops-lab.git
        revision: main
        directories:
          - path: envs/*
          - path: envs/base
            exclude: true
  template:
    metadata:
      name: 'guestbook-{{.path.basename}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/<you>/gitops-lab.git
        targetRevision: main
        path: '{{.path.path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: 'guestbook-{{.path.basename}}'
      syncPolicy:
        automated: { prune: true, selfHeal: true }
        syncOptions: [CreateNamespace=true]
```

Add a new folder under `envs/`, and a new environment deploys automatically. Other generators: **list**, **cluster** (one app per registered cluster), **pull request** (preview environments).

## Private repos, projects and access

```bash
# Private Git repo over SSH
argocd repo add git@github.com:<org>/gitops-private.git --ssh-private-key-path ~/.ssh/argocd_deploy_key

# Register another cluster (e.g. EKS) - Argo CD installs a service account there
argocd cluster add <kube-context-name>
argocd cluster list
```

Restrict teams with an **AppProject**:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-a
  namespace: argocd
spec:
  description: Team A apps
  sourceRepos:
    - https://github.com/<org>/team-a-*
  destinations:
    - server: https://kubernetes.default.svc
      namespace: team-a-*
  clusterResourceWhitelist: []      # no cluster-scoped resources
```

Production checklist: SSO (OIDC with Okta, Entra ID or Google) via `argocd-cm`, RBAC in `argocd-rbac-cm`, admin disabled, TLS Ingress for the UI, and notifications (Slack/Teams) via **argocd-notifications**.

## Rollback and troubleshooting

### Rolling back

The GitOps way is to revert the commit:

```bash
git revert <bad-commit-sha> && git push   # Argo CD syncs the previous state
```

For an emergency (auto-sync must be disabled first, or self-heal undoes it):

```bash
argocd app history guestbook
argocd app rollback guestbook <history-id>
```

### Troubleshooting

| Symptom | Check |
|---|---|
| `OutOfSync` forever | `argocd app diff <app>`. Often a field mutated by a controller. Use `ignoreDifferences`. |
| `ComparisonError` / repo errors | Wrong `repoURL` or `path`, or private repo not added. `argocd repo list` |
| `Degraded` health | It's the workload: `kubectl describe` / `logs` the failing pods |
| Sync stuck on a resource | A finalizer or hook is waiting. Check the app's events in the UI |
| Changes not picked up | Polling delay. `argocd app get <app> --refresh` or add a webhook |

```bash
argocd app list
argocd app get guestbook --show-operation
kubectl logs -n argocd deploy/argocd-repo-server
kubectl logs -n argocd statefulset/argocd-application-controller
```

## Lab: full GitOps loop

1. Install Argo CD on your kind cluster and log in with the CLI.
2. In your GitOps repo, add your Helm chart from the Kubernetes lab, or plain manifests for your `hello-docker` image.
3. Create a **root app-of-apps** that deploys your app *and* Redis (Helm source).
4. Enable automated sync with prune and self-heal. Prove self-heal by deleting a Deployment by hand.
5. Add `envs/dev` and `envs/prod` Kustomize overlays and deploy both with an **ApplicationSet**.
6. Push a bad image tag, watch the app go `Degraded`, then fix it with `git revert`.
7. Bonus: write a GitHub Actions workflow that builds the image and commits the new tag to the GitOps repo.

### Cheat sheet

| Task | Command |
|---|---|
| Login | `argocd login localhost:8080 --insecure` |
| List apps | `argocd app list` |
| App details | `argocd app get <app>` |
| Diff vs Git | `argocd app diff <app>` |
| Sync now | `argocd app sync <app>` |
| Force refresh from Git | `argocd app get <app> --refresh` |
| History / rollback | `argocd app history <app>` / `argocd app rollback <app> <id>` |
