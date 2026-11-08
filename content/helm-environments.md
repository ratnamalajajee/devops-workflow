# Helm: Deploy an App per Environment

Real applications run in several environments (dev, staging, production) that need the **same app with different settings**: more replicas in prod, debug logging in dev, a different hostname everywhere. With Helm you write the Kubernetes manifests **once** as a chart, and keep one small **values file per environment**. This guide builds a complete chart for the sample app, deploys it to three environments, and covers upgrades, rollbacks, secrets, Argo CD and publishing the chart to ECR.

> **Note:** You need a Kubernetes cluster (the kind cluster from the [Kubernetes guide](#/tool/kubernetes), with ingress-nginx), `kubectl`, `helm` (version 3 or 4), and the **sample app** image from [CI/CD Basics](#/tool/cicd-basics).

## Start here: Helm and environment config in simple words

> **In simple words:** A Helm **chart** is a set of Kubernetes YAML files with blanks in them. A **values file** fills in the blanks. Use the same chart for every environment, and give each environment its own values file with only the settings that differ.

### How the pieces fit

```text
                    charts/hello-app/
 templates/*.yaml   (Deployment, Service, Ingress, ConfigMap, HPA … with {{ .Values.x }} blanks)
        +
 values.yaml        (defaults shared by every environment)
        +
 values-dev.yaml  │ values-staging.yaml │ values-prod.yaml   (only what differs)
        │                  │                     │
   helm upgrade       helm upgrade          helm upgrade
        ▼                  ▼                     ▼
  namespace hello-dev  hello-staging         hello-prod
  1 replica, debug     2 replicas, info      3–10 replicas (HPA), warn, secret, TLS
```

### A real-life comparison

Think of a **form letter**: one letter template with blanks such as *Dear ___, your order ___*. Each customer gets the same letter with different details filled in. The chart is the template, and each environment's values file holds the details.

### Key words

| Word | Simple meaning |
|---|---|
| **Chart** | A folder with `Chart.yaml`, `values.yaml` and `templates/`, describing one app |
| **Template** | A Kubernetes YAML file with placeholders like `{{ .Values.replicaCount }}` |
| **Values** | The settings that fill the placeholders |
| **Release** | One installed copy of a chart, with a name, in a namespace (e.g. `hello-app` in `hello-prod`) |
| **Revision** | Each install or upgrade of a release gets a number, which makes rollback possible |
| **Override** | A later values file (or `--set`) replacing a setting from an earlier one |

### Check yourself

1. Why not copy the YAML files once per environment instead?
2. If `values.yaml` says `replicaCount: 1` and `values-prod.yaml` says `3`, which wins in prod?
3. What is a release?

> **Tip:** Answers: 1) Copies drift apart. A fix made in one copy gets forgotten in the others, and with a chart every environment shares the same templates. 2) `values-prod.yaml`, because later files override earlier ones. 3) One installed instance of a chart, in a namespace, with its own revision history.

## Chart layout

> **In simple words:** One folder holds everything: the chart description, the shared defaults, one file per environment, and the templates.

```text
charts/hello-app/
├── Chart.yaml                 name, chart version, app version
├── values.yaml                defaults for ALL environments
├── values-dev.yaml            dev overrides
├── values-staging.yaml        staging overrides
├── values-prod.yaml           prod overrides
└── templates/
    ├── _helpers.tpl           reusable snippets: names and labels
    ├── configmap.yaml         non-secret settings → environment variables
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml           only if ingress.enabled
    ├── hpa.yaml               only if autoscaling.enabled
    ├── serviceaccount.yaml
    └── NOTES.txt              message printed after install
```

```bash
mkdir -p ~/code/hello-app/charts/hello-app/templates && cd ~/code/hello-app
```

> **Tip:** `helm create hello-app` generates a similar skeleton. Writing the files yourself (below) means you understand every line before you rely on it.

## Write the chart: Chart.yaml and default values

> **In simple words:** `Chart.yaml` names the chart and its versions. `values.yaml` holds the safe defaults every environment starts from, so environment files stay short.

`charts/hello-app/Chart.yaml`:

```yaml
apiVersion: v2
name: hello-app
description: Sample web app deployed with environment-specific values
type: application
version: 0.1.0          # chart version: bump when templates change
appVersion: "1.0.0"     # app version: the default image tag
```

`charts/hello-app/values.yaml`:

```yaml
# Defaults shared by every environment. Environment files override only what differs.
environment: base

replicaCount: 1

image:
  repository: hello-app
  tag: ""                       # empty = use appVersion from Chart.yaml
  pullPolicy: IfNotPresent

imagePullSecrets: []
nameOverride: ""
fullnameOverride: ""

serviceAccount:
  create: true
  name: ""
  annotations: {}               # e.g. eks.amazonaws.com/role-arn for IRSA

containerPort: 8000

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: false
  className: nginx
  host: ""
  annotations: {}
  tls: []                       # e.g. [{ secretName: hello-tls, hosts: [hello.example.com] }]

# Non-secret settings: rendered into a ConfigMap and exposed as environment variables
config:
  LOG_LEVEL: info
  FEATURE_NEW_UI: "false"

# Name of a Secret created OUTSIDE the chart; its keys become environment variables
existingSecret: ""

resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    memory: 128Mi

autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 70

probes:
  path: /health

podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000               # the sample image's non-root user

podAnnotations: {}
nodeSelector: {}
tolerations: []
affinity: {}
```

## Write the chart: templates

> **In simple words:** Templates are ordinary Kubernetes YAML with `{{ }}` placeholders. `_helpers.tpl` defines names and labels once, so every template uses the same ones.

`charts/hello-app/templates/_helpers.tpl`:

```text
{{- define "hello-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "hello-app.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "hello-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "hello-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "hello-app.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{ include "hello-app.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.image.tag | default .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
environment: {{ .Values.environment }}
{{- end }}

{{- define "hello-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "hello-app.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
```

`charts/hello-app/templates/configmap.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "hello-app.fullname" . }}
  labels:
    {{- include "hello-app.labels" . | nindent 4 }}
data:
  APP_ENV: {{ .Values.environment | quote }}
  {{- range $key, $value := .Values.config }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
```

`charts/hello-app/templates/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "hello-app.fullname" . }}
  labels:
    {{- include "hello-app.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "hello-app.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "hello-app.selectorLabels" . | nindent 8 }}
      annotations:
        # restart pods automatically when the config changes
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
        {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      serviceAccountName: {{ include "hello-app.serviceAccountName" . }}
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.containerPort }}
          env:
            - name: APP_VERSION
              value: {{ .Values.image.tag | default .Chart.AppVersion | quote }}
          envFrom:
            - configMapRef:
                name: {{ include "hello-app.fullname" . }}
            {{- if .Values.existingSecret }}
            - secretRef:
                name: {{ .Values.existingSecret }}
            {{- end }}
          readinessProbe:
            httpGet:
              path: {{ .Values.probes.path }}
              port: http
          livenessProbe:
            httpGet:
              path: {{ .Values.probes.path }}
              port: http
            initialDelaySeconds: 10
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          securityContext:
            allowPrivilegeEscalation: false
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
```

`charts/hello-app/templates/service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "hello-app.fullname" . }}
  labels:
    {{- include "hello-app.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  selector:
    {{- include "hello-app.selectorLabels" . | nindent 4 }}
  ports:
    - name: http
      port: {{ .Values.service.port }}
      targetPort: http
```

`charts/hello-app/templates/ingress.yaml`:

```yaml
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "hello-app.fullname" . }}
  labels:
    {{- include "hello-app.labels" . | nindent 4 }}
  {{- with .Values.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  ingressClassName: {{ .Values.ingress.className }}
  {{- with .Values.ingress.tls }}
  tls:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  rules:
    - host: {{ required "ingress.host is required when ingress.enabled is true" .Values.ingress.host | quote }}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{ include "hello-app.fullname" . }}
                port:
                  name: http
{{- end }}
```

`charts/hello-app/templates/hpa.yaml`:

```yaml
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "hello-app.fullname" . }}
  labels:
    {{- include "hello-app.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "hello-app.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
{{- end }}
```

`charts/hello-app/templates/serviceaccount.yaml`:

```yaml
{{- if .Values.serviceAccount.create }}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "hello-app.serviceAccountName" . }}
  labels:
    {{- include "hello-app.labels" . | nindent 4 }}
  {{- with .Values.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
```

`charts/hello-app/templates/NOTES.txt`:

```text
{{ .Chart.Name }} {{ .Values.image.tag | default .Chart.AppVersion }} is deployed to namespace {{ .Release.Namespace }} ({{ .Values.environment }}).

Try it:
  kubectl -n {{ .Release.Namespace }} port-forward svc/{{ include "hello-app.fullname" . }} 8080:{{ .Values.service.port }}
  curl http://localhost:8080/
{{- if .Values.ingress.enabled }}
  or open http://{{ .Values.ingress.host }}/
{{- end }}
```

| Template trick | What it does |
|---|---|
| `{{- include "hello-app.labels" . \| nindent 4 }}` | Reuses the label block, indented 4 spaces |
| `{{- if .Values.ingress.enabled }}` | Creates the resource only when switched on |
| `{{ .Values.image.tag \| default .Chart.AppVersion }}` | Falls back to the chart's app version when no tag is given |
| `required "…" .Values.ingress.host` | Stops with a clear error if a mandatory value is missing |
| `checksum/config` annotation | Changes when the ConfigMap changes, so pods restart and pick up new settings |
| `{{- with .Values.x }} … {{- end }}` | Adds a block only if the value isn't empty |

## Environment-specific values

> **In simple words:** Each environment file lists only the settings that differ from the defaults. Reading three short files tells you exactly how the environments differ.

`charts/hello-app/values-dev.yaml`:

```yaml
environment: dev
replicaCount: 1
image:
  tag: "1.0.0"
config:
  LOG_LEVEL: debug
  FEATURE_NEW_UI: "true"        # try new features in dev first
resources:
  requests:
    cpu: 25m
    memory: 64Mi
ingress:
  enabled: true
  host: hello-dev.localtest.me
```

`charts/hello-app/values-staging.yaml`:

```yaml
environment: staging
replicaCount: 2
image:
  tag: "1.0.0"
config:
  LOG_LEVEL: info
  FEATURE_NEW_UI: "true"
ingress:
  enabled: true
  host: hello-staging.localtest.me
```

`charts/hello-app/values-prod.yaml`:

```yaml
environment: prod
image:
  tag: "1.0.0"                   # promoted only after staging passes
config:
  LOG_LEVEL: warn
  FEATURE_NEW_UI: "false"        # not released to production yet
existingSecret: hello-secrets    # created separately, never stored in Git
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    memory: 256Mi
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
affinity:
  podAntiAffinity:               # spread pods across nodes
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          topologyKey: kubernetes.io/hostname
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: hello-app
ingress:
  enabled: true
  host: hello.localtest.me
  # on EKS with a real domain, for example:
  # className: alb
  # host: hello.example.com
  # annotations:
  #   alb.ingress.kubernetes.io/scheme: internal
  #   alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:...
```

How the environments end up different:

| Setting | dev | staging | prod |
|---|---|---|---|
| Replicas | 1 | 2 | 3–10 (autoscaled) |
| `LOG_LEVEL` | debug | info | warn |
| `FEATURE_NEW_UI` | true | true | false |
| CPU / memory request | 25m / 64Mi | 50m / 64Mi (default) | 100m / 128Mi |
| Secret | none | none | `hello-secrets` |
| Spread across nodes | no | no | yes |
| Host | hello-dev.localtest.me | hello-staging.localtest.me | hello.localtest.me |

**How Helm merges values:** files are applied left to right (`-f values.yaml -f values-prod.yaml`), and later files win. **Maps merge** key by key (the `config` map in prod keeps keys it doesn't mention). **Lists are replaced** whole. `--set key=value` beats every file. `values.yaml` inside the chart is always loaded first, automatically.

## Render and lint before deploying

> **In simple words:** Helm can show you the final YAML for any environment **without touching the cluster**. Always look at it before deploying. Most mistakes are visible right there.

```bash
cd ~/code/hello-app
CHART=charts/hello-app

helm lint $CHART -f $CHART/values-dev.yaml
helm lint $CHART -f $CHART/values-prod.yaml

# full rendered output for one environment
helm template hello-app $CHART -n hello-prod -f $CHART/values-prod.yaml | less

# exactly what differs between dev and prod
diff <(helm template hello-app $CHART -f $CHART/values-dev.yaml) \
     <(helm template hello-app $CHART -f $CHART/values-prod.yaml)

# just the effective values for an environment
helm template hello-app $CHART -f $CHART/values-prod.yaml --show-only templates/configmap.yaml
```

> **Tip:** The **helm-diff** plugin (`helm plugin install https://github.com/databus23/helm-diff`) shows what an upgrade *would* change in the cluster: `helm diff upgrade hello-app $CHART -n hello-prod -f $CHART/values-prod.yaml`.

## Deploy to dev, staging and prod

> **In simple words:** The same command deploys every environment. Only the namespace and the values file change. `upgrade --install` installs the first time and upgrades after that.

Load the sample image into kind (built in [CI/CD Basics](#/tool/cicd-basics) as `hello-app:local`):

```bash
docker tag hello-app:local hello-app:1.0.0
kind load docker-image hello-app:1.0.0 --name lab
```

Prod expects a Secret. Create it outside the chart, so it never lands in Git:

```bash
kubectl create namespace hello-prod
kubectl create secret generic hello-secrets -n hello-prod --from-literal=DB_PASSWORD='change-me'
```

Deploy all three. In Helm 4, use `--rollback-on-failure`; in Helm 3 the same flag is called `--atomic`:

```bash
for ENV in dev staging prod; do
  helm upgrade --install hello-app $CHART \
    --namespace hello-$ENV --create-namespace \
    -f $CHART/values-$ENV.yaml \
    --wait --timeout 5m --rollback-on-failure
done

helm list -A
kubectl get deploy,hpa,ingress -n hello-prod
```

Check that each environment really got its own settings:

```bash
for ENV in dev staging prod; do
  echo "== $ENV"
  kubectl -n hello-$ENV exec deploy/hello-app -- sh -c 'echo "APP_ENV=$APP_ENV LOG_LEVEL=$LOG_LEVEL FEATURE_NEW_UI=$FEATURE_NEW_UI"'
  HOST=$([ "$ENV" = prod ] && echo hello.localtest.me || echo "hello-$ENV.localtest.me")
  curl -s "http://$HOST/"; echo
done
kubectl -n hello-prod exec deploy/hello-app -- sh -c 'test -n "$DB_PASSWORD" && echo "secret mounted"'
```

The prod URL is `hello.localtest.me`; dev and staging use `hello-dev.` and `hello-staging.`. `*.localtest.me` resolves to `127.0.0.1`, so with kind's port 80 mapping all three open in your browser.

## Upgrade, history and rollback

> **In simple words:** Every `helm upgrade` creates a new numbered revision. If a release goes wrong, Helm can roll back to any earlier revision with one command.

Release a new version to dev only, without editing files:

```bash
docker tag hello-app:local hello-app:1.1.0 && kind load docker-image hello-app:1.1.0 --name lab

helm upgrade hello-app $CHART -n hello-dev -f $CHART/values-dev.yaml \
  --set image.tag=1.1.0 --wait --rollback-on-failure

helm history hello-app -n hello-dev
helm get values hello-app -n hello-dev            # the values in effect (including --set)
helm get manifest hello-app -n hello-dev | head -40
```

Roll back:

```bash
helm rollback hello-app 1 -n hello-dev --wait      # back to revision 1
helm history hello-app -n hello-dev               # rollback is recorded as a NEW revision
```

**Change config only:** edit `LOG_LEVEL` in `values-staging.yaml` and run the same `helm upgrade`. The `checksum/config` annotation changes, so the pods restart with the new value, with no image change needed.

| Flag | Why |
|---|---|
| `--wait` | Don't report success until pods are actually ready |
| `--timeout 5m` | How long `--wait` may take |
| `--rollback-on-failure` (Helm 3: `--atomic`) | If the upgrade fails or times out, return to the previous revision automatically |
| `--set image.tag=…` | One-off override, ideal for CI deploying a fresh build to dev |

## Secrets per environment

> **In simple words:** Never put passwords in values files: they end up in Git. The chart only **names** a Secret (`existingSecret`), and each environment's Secret is created separately: by hand, by a secrets operator, or by your pipeline.

| Option | How | Good for |
|---|---|---|
| `kubectl create secret` | As in the deploy step, per namespace | Learning, small teams |
| **External Secrets Operator** | An `ExternalSecret` resource pulls values from AWS Secrets Manager or SSM into a Kubernetes Secret | Production on AWS (recommended) |
| **Sealed Secrets** / **SOPS** | Encrypted secrets that *are* safe to commit | GitOps without an external vault |

Example `ExternalSecret` that creates `hello-secrets` in prod from AWS Secrets Manager (with the operator installed and a `ClusterSecretStore` named `aws-secrets-manager`):

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: hello-secrets
  namespace: hello-prod
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: aws-secrets-manager
  target:
    name: hello-secrets
  data:
    - secretKey: DB_PASSWORD
      remoteRef:
        key: prod/hello-app
        property: db_password
```

## Deploy every environment with Argo CD

> **In simple words:** Instead of running `helm upgrade` by hand, put the chart in Git and let Argo CD deploy one Application per environment, each using its own values file. An **ApplicationSet** creates all three from one definition.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: hello-app
  namespace: argocd
spec:
  goTemplate: true
  generators:
    - list:
        elements:
          - env: dev
          - env: staging
          - env: prod
  template:
    metadata:
      name: 'hello-app-{{.env}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/your-org/gitops.git     # CHANGE: repo containing charts/hello-app
        targetRevision: main
        path: charts/hello-app
        helm:
          releaseName: hello-app
          valueFiles:
            - values.yaml
            - 'values-{{.env}}.yaml'
      destination:
        server: https://kubernetes.default.svc
        namespace: 'hello-{{.env}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

**Promotion becomes a pull request:** CI (or a developer) changes `image.tag` in `values-staging.yaml`; after testing, the same tag is copied into `values-prod.yaml`. Argo CD deploys each change, and Git records who promoted what and when.

Many teams keep production on **manual sync**. Use a separate Application for prod, or the ApplicationSet `templatePatch` field to drop `automated` for the `prod` element. See the [Argo CD guide](#/tool/argocd) and the [Argo CD on EKS runbook](#/tool/argocd-eks).

## Package and publish the chart to ECR

> **In simple words:** Charts can be stored in a registry just like Docker images. Amazon ECR supports Helm charts (OCI format), so other teams and Argo CD can install a specific chart version without cloning your repo.

```bash
export AWS_REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGISTRY=$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

aws ecr create-repository --repository-name charts/hello-app --region $AWS_REGION
aws ecr get-login-password --region $AWS_REGION | helm registry login --username AWS --password-stdin $REGISTRY

helm package charts/hello-app                      # → hello-app-0.1.0.tgz (version from Chart.yaml)
helm push hello-app-0.1.0.tgz oci://$REGISTRY/charts

# install straight from the registry, still with an environment file
helm upgrade --install hello-app oci://$REGISTRY/charts/hello-app --version 0.1.0 \
  -n hello-staging -f charts/hello-app/values-staging.yaml --wait
```

Bump `version` in `Chart.yaml` every time the templates change. Chart versions should be immutable, just like image tags.

## Troubleshooting

> **In simple words:** Render the chart first (`helm template`), then compare what's running (`helm get values` / `helm get manifest`). Most problems are a value that didn't apply the way you expected.

| Problem | Fix |
|---|---|
| `Error: INSTALLATION FAILED: … context deadline exceeded` | Pods never became ready within `--timeout`. Check `kubectl describe pod` and logs. With `--rollback-on-failure`, Helm has already rolled back |
| `UPGRADE FAILED: another operation … is in progress` | A previous release is stuck `pending-upgrade`. Run `helm history`, then `helm rollback <release> <last-good-revision>` |
| A value "doesn't apply" | Wrong file order, or an indentation mistake in the values file. Check with `helm get values <release> -n <ns> --all` |
| `nil pointer evaluating interface {}` | A template reads a nested value that doesn't exist. Add it to `values.yaml` with a default |
| `ingress.host is required…` | That's the `required` check working. Set the host in that environment's file |
| `CreateContainerConfigError` | Missing ConfigMap or Secret (e.g. `hello-secrets` not created in that namespace), or `runAsNonRoot` with an image whose user isn't numeric |
| Config changed but pods didn't restart | The `checksum/config` annotation is missing from the Deployment template |
| HPA shows `<unknown>` targets | `metrics-server` isn't installed, or the container has no CPU request |
| `helm push` → `401 Unauthorized` | The `helm registry login` token expired (12 hours). Log in again |

```bash
helm status hello-app -n hello-prod
helm get values hello-app -n hello-prod --all
helm template hello-app $CHART -f $CHART/values-prod.yaml --debug | less
```

## Clean up, lab and cheat sheet

> **In simple words:** Remove the releases and namespaces, then practise building and promoting a change through all three environments yourself.

```bash
for ENV in dev staging prod; do helm uninstall hello-app -n hello-$ENV; kubectl delete namespace hello-$ENV; done
```

### Lab: promote a change through every environment

1. Create the chart and the three values files, and confirm `helm lint` passes for each environment.
2. Show the differences between dev and prod with `helm template` and `diff`.
3. Deploy all three environments and verify `APP_ENV`, `LOG_LEVEL` and the replica counts.
4. Add a new setting `CACHE_TTL` (default `60`, prod `300`). Deploy it and check that the pods restarted on their own.
5. Release image `1.1.0` to dev with `--set`, then to staging by editing its values file, then to prod.
6. Roll prod back to the previous revision and confirm the old version is serving.
7. Package the chart, push it to ECR, and deploy staging from the registry.
8. Bonus: replace the manual commands with the Argo CD ApplicationSet.

### Cheat sheet

| Task | Command |
|---|---|
| Lint for an environment | `helm lint CHART -f CHART/values-prod.yaml` |
| See final YAML | `helm template REL CHART -f CHART/values-prod.yaml` |
| Install or upgrade | `helm upgrade --install REL CHART -n NS --create-namespace -f values-ENV.yaml --wait` |
| One-off override | `--set image.tag=1.1.0` |
| What's deployed | `helm list -A` / `helm get values REL -n NS --all` |
| History / rollback | `helm history REL -n NS` / `helm rollback REL N -n NS` |
| Remove | `helm uninstall REL -n NS` |
| Publish to ECR | `helm package CHART && helm push CHART-x.y.z.tgz oci://REGISTRY/charts` |
