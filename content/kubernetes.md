# Kubernetes

Kubernetes (K8s) runs containers across many machines. It keeps the right number of copies running, replaces failed ones, rolls out new versions with zero downtime, and routes traffic to them. You describe the **desired state** in YAML, and Kubernetes continuously works to make reality match.

> **Note:** Learn on a free local cluster with **kind** first. Every command here works the same on EKS later.

> **Tip:** No Docker or Kubernetes on your laptop? Use the **cloud lab machine** in the [Practice lab](#/lab). It has Docker, kind, kubectl, Helm, Terraform, the AWS CLI and the Argo CD CLI ready to go.

## Architecture

```text
                ┌─────────────────── Control plane ───────────────────┐
 kubectl ─────▶ │ kube-apiserver ◀─▶ etcd (cluster state)             │
                │ scheduler (places pods)  controller-manager (loops) │
                └───────────────────────┬─────────────────────────────┘
                                        │
        ┌───────────── Worker node ─────┴──────┐   ┌──── Worker node ────┐
        │ kubelet  kube-proxy  container runtime│   │        ...          │
        │  [pod] [pod] [pod]                    │   │  [pod] [pod]        │
        └───────────────────────────────────────┘   └─────────────────────┘
```

| Component | Job |
|---|---|
| **API server** | The front door. Everything (kubectl, controllers, kubelets) talks to it. |
| **etcd** | Key-value store holding all cluster state |
| **Scheduler** | Picks a node for each new pod |
| **Controller manager** | Control loops: "desired 3 replicas, have 2, create 1" |
| **kubelet** | Agent on each node that starts and monitors pods |
| **kube-proxy** | Programs node networking for Services |

On EKS, AWS runs the control plane for you. You manage only the worker nodes and workloads.

## Create a local cluster with kind

kind runs Kubernetes nodes as Docker containers. Create a multi-node cluster with ports mapped for Ingress later:

```bash
mkdir -p ~/code/k8s-lab && cd ~/code/k8s-lab
cat > kind-config.yaml <<'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
      - containerPort: 443
        hostPort: 443
  - role: worker
  - role: worker
EOF

kind create cluster --name lab --config kind-config.yaml
kubectl cluster-info --context kind-lab
kubectl get nodes -o wide
```

Delete it any time with `kind delete cluster --name lab`.

> **Tip:** Alternatives: **minikube** (`minikube start`), **k3d**, or Docker Desktop's built-in Kubernetes. Any of them works for this guide.

## kubectl essentials

```bash
kubectl get nodes                       # list nodes
kubectl get pods -A                     # pods in all namespaces
kubectl get all -n kube-system
kubectl describe node <name>            # detailed info + events
kubectl explain deployment.spec         # built-in API docs
kubectl api-resources                   # every resource type
kubectl config get-contexts             # clusters you can talk to
kubectl config use-context kind-lab     # switch cluster
```

Imperative vs declarative:

```bash
kubectl create deployment web --image=nginx:1.27      # imperative: quick experiments
kubectl apply -f deployment.yaml                      # declarative: the real way, kept in Git
kubectl create deployment web --image=nginx --dry-run=client -o yaml > web.yaml   # generate YAML
```

> **Tip:** With the `k` alias from setup, `k get po`, `k get svc`, and `k get deploy` save a lot of typing. Also try `kubectx` / `kubens` and **k9s** (a terminal UI).

## Pods

A **Pod** is the smallest deployable unit: one or more containers that share network (same IP) and storage. You rarely create pods directly, but you need to understand them.

`pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hello
  labels:
    app: hello
spec:
  containers:
    - name: hello
      image: nginx:1.27
      ports:
        - containerPort: 80
```

```bash
kubectl apply -f pod.yaml
kubectl get pods -o wide
kubectl logs hello
kubectl exec -it hello -- sh
kubectl port-forward pod/hello 8080:80     # then curl localhost:8080
kubectl delete -f pod.yaml
```

Every manifest has the same shape: `apiVersion`, `kind`, `metadata` (name, labels), `spec` (desired state). Kubernetes adds `status` (actual state).

## Deployments, rollouts and rollbacks

A **Deployment** manages a **ReplicaSet**, which keeps N identical pods running. This is how you run stateless apps.

`deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  labels:
    app: web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: web
          image: hashicorp/http-echo:1.0
          args: ["-text=hello v1", "-listen=:8080"]
          ports:
            - containerPort: 8080
```

```bash
kubectl apply -f deployment.yaml
kubectl get deploy,rs,pods -l app=web

# Self-healing: delete a pod and watch a replacement appear
kubectl delete pod -l app=web --wait=false && kubectl get pods -l app=web -w

# Scale
kubectl scale deployment web --replicas=5

# Rolling update: change args to "hello v2" in the file, then:
kubectl apply -f deployment.yaml
kubectl rollout status deployment/web
kubectl rollout history deployment/web

# Roll back
kubectl rollout undo deployment/web
```

> **Note:** Other workload types: **StatefulSet** (stable identity and storage, for databases), **DaemonSet** (one pod per node, for log or monitoring agents), **Job / CronJob** (run to completion, or on a schedule).

## Services: stable networking

Pods come and go, and their IPs change. A **Service** gives a stable name and IP and load-balances across the pods whose labels match its `selector`.

`service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  type: ClusterIP
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 8080
```

```bash
kubectl apply -f service.yaml
kubectl get svc web
kubectl get endpointslices -l kubernetes.io/service-name=web   # which pods back it

# Test from inside the cluster: DNS name is <svc>.<namespace>.svc.cluster.local
kubectl run tmp --rm -it --image=curlimages/curl --restart=Never -- curl -s http://web
```

| Type | Reachable from | Use |
|---|---|---|
| `ClusterIP` (default) | Inside the cluster only | Internal services |
| `NodePort` | `<any-node-ip>:30000-32767` | Testing, simple setups |
| `LoadBalancer` | Cloud load balancer (NLB/ALB on AWS) | Exposing directly on EKS |
| Headless (`clusterIP: None`) | Direct pod IPs via DNS | StatefulSets |

## ConfigMaps and Secrets

Keep configuration out of images.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-config
data:
  APP_MODE: "production"
  LOG_LEVEL: "info"
---
apiVersion: v1
kind: Secret
metadata:
  name: web-secret
type: Opaque
stringData:
  DB_PASSWORD: "change-me"
```

Use them in a container spec:

```yaml
          envFrom:
            - configMapRef:
                name: web-config
            - secretRef:
                name: web-secret
```

```bash
kubectl create secret generic db --from-literal=password=s3cr3t --dry-run=client -o yaml
kubectl get secret web-secret -o jsonpath='{.data.DB_PASSWORD}' | base64 -d
```

> **Warning:** Kubernetes Secrets are only **base64-encoded**, not encrypted, and anyone with read access to them can decode them. Never commit them to Git in plain text. In production use **External Secrets Operator** with AWS Secrets Manager, or **Sealed Secrets** / **SOPS**.

## Namespaces, resources and probes

### Namespaces

```bash
kubectl create namespace team-a
kubectl apply -f deployment.yaml -n team-a
kubectl config set-context --current --namespace=team-a   # default ns for this context
```

### Requests and limits

**Requests** are what the scheduler reserves. **Limits** are the hard cap: a container that exceeds its memory limit is OOMKilled, and one that exceeds its CPU limit is throttled.

### Health probes

| Probe | Question | On failure |
|---|---|---|
| `readinessProbe` | Ready for traffic? | Removed from Service endpoints |
| `livenessProbe` | Still alive? | Container restarted |
| `startupProbe` | Finished starting? | Holds off the other probes |

A production-ready container block:

```yaml
      containers:
        - name: web
          image: myrepo/web:1.4.2
          ports:
            - containerPort: 8000
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              memory: 256Mi
          readinessProbe:
            httpGet:
              path: /health
              port: 8000
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /health
              port: 8000
            initialDelaySeconds: 10
            periodSeconds: 10
          securityContext:
            runAsNonRoot: true
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
```

Autoscale on CPU with a HorizontalPodAutoscaler (needs metrics-server):

```bash
kubectl autoscale deployment web --cpu-percent=70 --min=2 --max=10
kubectl get hpa
```

## Storage: volumes and PVCs

A **PersistentVolumeClaim** asks for storage. A **StorageClass** provisions it dynamically: on kind it's a local path, on EKS an EBS volume.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: writer
spec:
  containers:
    - name: writer
      image: busybox:1.36
      command: ["sh", "-c", "date >> /data/log.txt; sleep 3600"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: data
```

```bash
kubectl apply -f pvc.yaml
kubectl get pvc,pv
kubectl get storageclass
kubectl delete pod writer && kubectl apply -f pvc.yaml
kubectl exec writer -- cat /data/log.txt     # two lines: data persisted
```

## Ingress: HTTP routing

An **Ingress** routes HTTP(S) by host and path to Services through a single entry point. It needs an **Ingress controller**. Install ingress-nginx for kind:

```bash
kubectl apply -f https://kind.sigs.k8s.io/examples/ingress/deploy-ingress-nginx.yaml
kubectl wait -n ingress-nginx --for=condition=ready pod -l app.kubernetes.io/component=controller --timeout=180s
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
spec:
  ingressClassName: nginx
  rules:
    - host: web.localtest.me
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web
                port:
                  number: 80
```

```bash
kubectl apply -f ingress.yaml
curl http://web.localtest.me      # *.localtest.me resolves to 127.0.0.1
```

> **Note:** The upstream ingress-nginx project is being retired, and the community is moving to the **Gateway API** (`Gateway` + `HTTPRoute`). Ingress concepts carry over directly. Check which one your company uses. On EKS, the **AWS Load Balancer Controller** turns Ingress into an ALB.

## Helm: the package manager

Helm packages a set of templated manifests as a **chart**, so you can install complex apps with one command and configure them with values.

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm search repo redis

helm install cache bitnami/redis -n data --create-namespace --set architecture=standalone
helm list -A
helm get values cache -n data
helm upgrade cache bitnami/redis -n data -f my-values.yaml
helm rollback cache 1 -n data
helm uninstall cache -n data
```

Create your own chart:

```bash
helm create mychart
tree mychart            # Chart.yaml, values.yaml, templates/
helm template mychart   # render YAML locally, without installing
helm lint mychart
helm install demo ./mychart --set replicaCount=2
```

Inside templates, values are referenced like `{{ .Values.image.repository }}:{{ .Values.image.tag }}`.

## Debugging workflow

When something is wrong, work from the outside in:

```bash
kubectl get pods                         # STATUS and RESTARTS columns
kubectl describe pod <pod>               # read the Events at the bottom
kubectl logs <pod>                       # app logs
kubectl logs <pod> --previous            # logs from the crashed container
kubectl logs deploy/web -c web -f        # follow a deployment's container
kubectl get events --sort-by=.lastTimestamp
kubectl exec -it <pod> -- sh
kubectl debug -it <pod> --image=busybox:1.36 --target=<container>   # for distroless images
kubectl top pods                         # needs metrics-server
```

| Status | Usual cause |
|---|---|
| `Pending` | No node has enough CPU or memory, or the PVC isn't bound. Check `describe` events. |
| `ImagePullBackOff` | Wrong image name or tag, or a private registry without credentials |
| `CrashLoopBackOff` | The app starts then exits. Check `logs --previous`. |
| `OOMKilled` | Memory limit too low, or a memory leak |
| Running but no traffic | Service `selector` doesn't match pod labels, or the readiness probe is failing. Check endpoints. |
| `CreateContainerConfigError` | A referenced ConfigMap or Secret is missing |

## Lab: deploy your own app

Use the image you built in the Docker lab.

1. Load it into kind: `kind load docker-image hello-docker:1.0.0 --name lab`.
2. Create a namespace `hello` and a Deployment with 3 replicas, resource requests and limits, and readiness and liveness probes on `/health`.
3. Put `APP_VERSION` in a ConfigMap and inject it as an env var.
4. Expose it with a ClusterIP Service and an Ingress at `hello.localtest.me`.
5. Build `1.1.0`, load it, roll it out, and watch with `kubectl rollout status`. Then roll back.
6. Break it on purpose: wrong image tag, wrong probe path, wrong Service selector. Diagnose each one using only `get`, `describe` and `logs`.
7. Package everything as a Helm chart with the image tag and replicas in `values.yaml`.

### Cheat sheet

| Task | Command |
|---|---|
| Apply a folder | `kubectl apply -f k8s/` |
| Watch pods | `kubectl get pods -w` |
| Why isn't it running? | `kubectl describe pod <p>` |
| Logs of crashed container | `kubectl logs <p> --previous` |
| Shell in | `kubectl exec -it <p> -- sh` |
| Port-forward | `kubectl port-forward svc/web 8080:80` |
| Restart deployment | `kubectl rollout restart deploy/web` |
| Roll back | `kubectl rollout undo deploy/web` |
