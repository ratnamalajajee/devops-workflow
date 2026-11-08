# Kubernetes Troubleshooting

When something breaks in Kubernetes, the cluster almost always tells you why. You just need to know where to look. This guide gives you one repeatable method, then walks through the problems you'll meet most: **CrashLoopBackOff**, **Pending**, **ImagePullBackOff**, **timeouts**, **OOMKilled**, config errors, failing probes, stuck deletions, node problems and stuck rollouts. Each comes with what it means, how to diagnose it, and the usual fixes. The last step is a lab of broken manifests to practise on.

> **Note:** Every command works on any cluster: kind, minikube or EKS. Set your namespace once with `kubectl config set-context --current --namespace=<ns>`, or add `-n <ns>` to each command.

## Start here: the troubleshooting method

> **In simple words:** Don't guess. Ask Kubernetes in a fixed order: **what is the status?**, **what happened (events)?**, and **what did the app say (logs)?** Nine times out of ten, the answer is in the events at the bottom of `kubectl describe`.

### The 3 commands that solve most problems

```bash
kubectl get pods -o wide                 # 1. STATUS, RESTARTS, READY, which node
kubectl describe pod <pod>               # 2. Events at the bottom: the "why"
kubectl logs <pod> --previous            # 3. what the app printed before it last crashed
```

### Work from the outside in

```text
 Is the pod Running and READY?  ── no ──▶  Pending?            → scheduling (resources, PVC, taints)
        │                                   ImagePullBackOff?   → image name / registry access
        │                                   CrashLoopBackOff?   → app crashes: logs --previous, exit code
        │                                   ConfigError?        → missing ConfigMap / Secret
        yes
        ▼
 Does the Service have endpoints?  ── no ──▶  selector / labels / readiness probe
        │ yes
        ▼
 Can another pod reach it?  ── no ──▶  targetPort, app listening address, NetworkPolicy, DNS
        │ yes
        ▼
 Does the Ingress / load balancer work?  ── no ──▶  ingress class, host/path rules, LB health checks
```

### Your toolkit

| Command | Use |
|---|---|
| `kubectl get pods -A \| grep -vE 'Running\|Completed'` | Everything unhealthy in the whole cluster |
| `kubectl get events --sort-by=.lastTimestamp` | Recent events in the namespace, oldest first |
| `kubectl get events --field-selector type=Warning -A` | Only warnings, across all namespaces |
| `kubectl describe pod <pod>` | Spec, state, last termination reason, events |
| `kubectl logs <pod> -c <container> --previous` | Logs from the crashed container instance |
| `kubectl get pod <pod> -o yaml` | Full spec and status, including exit codes |
| `kubectl top pods` / `kubectl top nodes` | CPU and memory usage (needs metrics-server) |
| `kubectl debug -it <pod> --image=busybox:1.36 --target=<container>` | A debugging shell next to a running container |
| `kubectl run tmp --rm -it --image=nicolaka/netshoot -- bash` | A throwaway pod full of network tools (curl, dig, nc, tcpdump) |

### Check yourself

1. Where do you usually find the reason a pod is failing?
2. Why use `--previous` with `kubectl logs`?
3. A pod is `Running` but users get errors. What do you check next?

> **Tip:** Answers: 1) In the **Events** at the bottom of `kubectl describe pod`. 2) It shows the logs of the container that crashed, not the fresh one that just started. 3) Whether it's READY, whether the Service has endpoints, and whether another pod can reach it.

## Pod status cheat sheet

> **In simple words:** The STATUS column is a one-word summary of what's wrong. Learn what each word means, and you know where to look next.

| STATUS | Meaning | First thing to check |
|---|---|---|
| `Pending` | Not scheduled onto a node yet | `describe` → events: `Insufficient cpu/memory`, taints, PVC |
| `ContainerCreating` (for minutes) | Scheduled, but can't start: volume mount, CNI/IP, image pull | `describe` → events |
| `ImagePullBackOff` / `ErrImagePull` | Can't download the image | Image name and tag, registry login, network |
| `CrashLoopBackOff` | Container starts, then exits, again and again | `logs --previous`, exit code |
| `CreateContainerConfigError` | A referenced ConfigMap, Secret or key doesn't exist | `describe` → which one is missing |
| `CreateContainerError` / `RunContainerError` | Runtime can't create or start it: bad command, mount, security setting | `describe` → message |
| `OOMKilled` (in last state) | Used more memory than its limit | Memory limit vs real usage |
| `Running` but READY `0/1` | Started, but the readiness probe fails | Probe path and port, app logs |
| `Init:CrashLoopBackOff` / `Init:Error` | An init container is failing | `logs <pod> -c <init-container>` |
| `Completed` | The process finished with exit code 0 | Normal for Jobs. For Deployments, the command exits instead of running |
| `Evicted` | Node ran out of memory or disk and removed the pod | `describe node`, resource requests |
| `Terminating` (forever) | Deletion is blocked: finalizer, unreachable node | Finalizers, node status |
| `Unknown` / `NodeLost` | The node stopped reporting | `kubectl get nodes` |

## CrashLoopBackOff

> **In simple words:** The container **starts, crashes, and Kubernetes restarts it**, waiting a bit longer each time (10s, 20s, 40s… up to 5 minutes). Kubernetes is fine; your **app** is exiting. The logs of the *previous* run and its **exit code** tell you why.

What you see:

```text
NAME                     READY   STATUS             RESTARTS      AGE
api-7d9c6b8f5d-x2kqp     0/1     CrashLoopBackOff   6 (2m ago)    9m
```

### Diagnose

```bash
kubectl logs <pod> --previous                       # the crash message
kubectl describe pod <pod> | grep -A8 "Last State"  # Reason and Exit Code
kubectl get pod <pod> -o jsonpath='{.status.containerStatuses[0].lastState.terminated}{"\n"}'
```

### Read the exit code

| Exit code | Meaning | Typical cause |
|---|---|---|
| `0` | Process finished successfully | The command isn't long-running (a script that ends, wrong `CMD`) |
| `1` | General application error | Exception at start-up: bad config, can't reach the database, missing env var |
| `2` | Misuse of a shell command or bad arguments | Wrong `args` in the manifest |
| `126` | Command found but not executable | Missing `chmod +x`, wrong file |
| `127` | Command not found | Typo in `command`, binary missing from the image |
| `137` | Killed with SIGKILL | **OOMKilled** (memory limit), or a failed liveness probe followed by a forced kill |
| `139` | Segmentation fault | Native crash, wrong CPU architecture or library |
| `143` | Terminated with SIGTERM | Stopped by Kubernetes (liveness probe, deployment), or the app doesn't handle shutdown |

### Common causes and fixes

| Cause | How you spot it | Fix |
|---|---|---|
| App error at start-up | Stack trace in `logs --previous` | Fix the code or config |
| Missing or wrong environment variable / config | `KeyError`, `undefined`, "property not set" in logs | Check the ConfigMap/Secret values and `env` in the spec |
| Dependency not reachable (DB, API) | "connection refused", "timeout" in logs | Check the dependency's Service, credentials, security groups; add retries or an init container |
| Liveness probe kills a healthy but slow app | Events: `Liveness probe failed`, then `Killing`; exit 137/143 | Add a `startupProbe`, raise `initialDelaySeconds` / `failureThreshold`, check the probe path |
| Out of memory | `Last State: Terminated, Reason: OOMKilled`, exit 137 | Raise the memory limit, or reduce usage (see the OOMKilled step) |
| Command exits immediately | Exit code 0, status `Completed` then CrashLoop | The container's main process must keep running (don't run it in the background) |
| Permission problems | "permission denied", read-only file system | Fix file ownership in the image, use writable `emptyDir` volumes for temp dirs |
| Wrong CPU architecture | `exec format error` | Build for the node's architecture (`--platform linux/amd64` or multi-arch) |

### Get a shell in a crashing container

A crashing container exits too fast to `exec` into it. Start a **copy** of the pod with the command replaced by a shell:

```bash
kubectl debug <pod> -it --copy-to=<pod>-debug --container=<container> -- sh
# inside: inspect files and env, then run the real start command by hand and watch it fail
kubectl delete pod <pod>-debug          # clean up afterwards
```

Or run the image locally with the same settings: `docker run --rm -it --entrypoint sh <image>`.

## Pending

> **In simple words:** The pod is waiting for a **seat**. The scheduler can't find a node that fits it, because of not enough CPU or memory, rules that exclude nodes (selectors, taints), or a disk (PVC) that isn't ready. The events say exactly which.

What you see in `kubectl describe pod`:

```text
Events:
  Warning  FailedScheduling  default-scheduler
  0/3 nodes are available: 1 node(s) had untolerated taint {dedicated: gpu},
  2 Insufficient memory. preemption: 0/3 nodes are available: 3 No preemption victims found.
```

### Diagnose

```bash
kubectl describe pod <pod> | sed -n '/Events/,$p'
kubectl describe nodes | grep -A8 "Allocated resources"   # how much is already requested per node
kubectl top nodes                                         # real usage
kubectl get pvc                                           # STATUS Bound?
kubectl get nodes --show-labels                           # for nodeSelector / affinity
kubectl describe node <node> | grep -i taints
```

### Common causes and fixes

| Event message | Cause | Fix |
|---|---|---|
| `Insufficient cpu` / `Insufficient memory` | The pod's **requests** are bigger than any node's free capacity | Lower requests to realistic values, add nodes, or let the cluster autoscaler or Karpenter add them |
| `node(s) didn't match Pod's node affinity/selector` | `nodeSelector` or affinity points at labels no node has | Fix the label in the spec, or label a node: `kubectl label node <n> key=value` |
| `had untolerated taint {…}` | Nodes are reserved (taints) and the pod has no matching toleration | Add the toleration, or schedule onto other nodes |
| `pod has unbound immediate PersistentVolumeClaims` | The PVC can't be provisioned | `kubectl describe pvc`: missing StorageClass, CSI driver not installed, quota |
| `volume node affinity conflict` | An EBS volume lives in one AZ and no node is in that AZ | Run nodes in that AZ, or use `WaitForFirstConsumer` StorageClasses |
| `Too many pods` | Node reached its maximum pod count | More or bigger nodes. On EKS, enable VPC CNI prefix delegation |
| `didn't match pod topology spread constraints` / anti-affinity | Rules require spreading, and there aren't enough nodes or zones | Relax the rule (`preferred…` instead of `required…`), or add nodes |
| No events at all | No scheduler ran, or the pod isn't actually created | Check `kubectl get rs` / `describe deploy` for quota errors (`exceeded quota`) |

> **Tip:** `requests` reserve capacity even if the app never uses it. Pods with huge requests sit Pending on clusters that look half empty in `kubectl top nodes`.

## ImagePullBackOff and ErrImagePull

> **In simple words:** The node **can't download the image**. Either the name or tag is wrong, the registry wants a login the node doesn't have, or the node can't reach the registry at all. The event message tells you which of the three.

### Diagnose

```bash
kubectl describe pod <pod> | grep -A3 -E "Failed|Back-off"
kubectl get pod <pod> -o jsonpath='{.spec.containers[*].image}{"\n"}'   # the exact image string
```

### Read the message

| Message contains | Cause | Fix |
|---|---|---|
| `not found` / `manifest unknown` | Wrong repository name or tag (typo, tag never pushed) | Check the registry: `aws ecr list-images --repository-name x`, `docker manifest inspect <image>` |
| `unauthorized` / `no basic auth credentials` / `403 Forbidden` / `denied` | Private registry and no valid credentials | Create an `imagePullSecret` (below), or give the **node role** ECR read access on EKS |
| `toomanyrequests` | Docker Hub pull rate limit | Log in to Docker Hub, use a mirror or ECR pull-through cache |
| `i/o timeout` / `dial tcp … connect: connection refused` / `no such host` | The node can't reach the registry: no NAT or VPC endpoints, proxy, DNS | Fix egress: NAT gateway, or ECR/S3 VPC endpoints for private subnets |
| `no match for platform in manifest` | Image built only for another CPU architecture | Build multi-arch, or use nodes of the matching architecture |
| `x509: certificate signed by unknown authority` | Private registry with a self-signed certificate | Trust the CA on the nodes, or use a registry with a valid certificate |

### Credentials for a private registry

```bash
kubectl create secret docker-registry regcred \
  --docker-server=registry.example.com --docker-username=<user> --docker-password=<token>
```

```yaml
spec:
  imagePullSecrets:
    - name: regcred
  containers:
    - name: app
      image: registry.example.com/team/app:1.4.2
```

On **EKS with ECR** in the same account, no pull secret is needed: the node IAM role needs `AmazonEC2ContainerRegistryReadOnly`. See the [ECR guide](#/tool/aws-ecr).

## Timeouts and "can't connect"

> **In simple words:** The pods are Running, but requests hang or fail. Work along the path a request travels: **pod → Service → (DNS) → caller → Ingress/load balancer**, and test each hop from *inside* the cluster to find where it breaks.

### Step 1: does the Service point at any pods?

```bash
kubectl get svc <svc> -o wide
kubectl get endpointslices -l kubernetes.io/service-name=<svc>     # ENDPOINTS empty = problem
kubectl get pods -l <key>=<value> --show-labels                    # do pod labels match the selector?
```

**Empty endpoints** mean the Service selector doesn't match the pod labels, or the pods aren't **ready** (readiness probe failing).

### Step 2: test from inside the cluster, hop by hop

```bash
kubectl run tmp --rm -it --image=nicolaka/netshoot -- bash
# inside the debug pod:
curl -sv http://<pod-ip>:<containerPort>/health     # straight to the pod: is the app answering?
curl -sv http://<svc>.<namespace>:<port>/health      # through the Service
dig <svc>.<namespace>.svc.cluster.local              # DNS
nc -vz <db-host> 5432                                # an external dependency
```

| Pod IP works? | Service works? | Likely cause |
|---|---|---|
| No | No | The app isn't listening on that port, or listens on `127.0.0.1` instead of `0.0.0.0` |
| Yes | No | Wrong `targetPort`, selector mismatch, or a NetworkPolicy |
| Yes | Yes, but slow or intermittent | Some pods unhealthy, CPU throttling, the app's own timeouts |
| Yes | Name doesn't resolve | DNS: check CoreDNS (`kubectl -n kube-system get pods -l k8s-app=kube-dns`), or a typo in the namespace |

### Common timeout situations

| Symptom | Cause | Fix |
|---|---|---|
| `connection refused` | Nothing listening on that IP and port | Check `containerPort` / `targetPort`, and that the app binds to `0.0.0.0` |
| Hangs, then times out | Traffic is dropped: NetworkPolicy, security group, wrong IP | `kubectl get networkpolicy`; on EKS check security groups (pod → RDS on 5432, for example) |
| Ingress returns **502** | The backend closed the connection or returned garbage | App crashing or the wrong port. Check backend pod logs |
| Ingress returns **503** | No ready backends | Service has no endpoints (see step 1) |
| Ingress returns **504** | The backend is too slow | Slow app or DB, or raise the ingress or load balancer timeout |
| `kubectl …: dial tcp … i/o timeout` / `context deadline exceeded` | Your laptop can't reach the API server | VPN off, private-only EKS endpoint, wrong kubeconfig context |
| `helm upgrade … --wait`: `timed out waiting for the condition` | Pods never became ready within `--timeout` | It's a pod problem. Diagnose with the steps above |
| Requests slow under load, CPU limits set | **CPU throttling**: the container hits its CPU limit | Raise or remove CPU limits (keep requests), and check `kubectl top pods` |

> **Tip:** `kubectl port-forward pod/<pod> 8080:<port>` and then `kubectl port-forward svc/<svc> 8080:<port>` is a quick way to tell an app problem from a Service problem.

## OOMKilled and resource problems

> **In simple words:** Each container has a **memory limit**. Use more, and the kernel kills it instantly (exit code **137**, reason **OOMKilled**). CPU works differently: going over the CPU limit doesn't kill the container, it **slows it down** (throttling).

```bash
kubectl describe pod <pod> | grep -A5 "Last State"     # Reason: OOMKilled, Exit Code: 137
kubectl top pod <pod> --containers                    # current usage vs limits
kubectl get pod <pod> -o jsonpath='{.spec.containers[*].resources}{"\n"}'
```

| Problem | Fix |
|---|---|
| OOMKilled at start-up | The limit is lower than the app needs to start. Raise it. For Java, set `-XX:MaxRAMPercentage=75` so the JVM respects the container limit |
| OOMKilled after hours or days | Probably a memory leak. Monitor memory over time, and fix the leak rather than raising the limit forever |
| `Evicted` pods | The **node** ran low on memory or disk. Set realistic requests, and check `kubectl describe node` for `MemoryPressure` / `DiskPressure` |
| Slow responses, timeouts | CPU throttling. Raise the CPU limit, or remove CPU limits and keep requests |

```yaml
resources:
  requests:            # what the scheduler reserves: base it on normal usage
    cpu: 100m
    memory: 256Mi
  limits:
    memory: 512Mi      # hard cap; going over = OOMKilled
```

Clean up evicted pods with `kubectl delete pods --field-selector=status.phase=Failed -A`.

## Configuration errors

> **In simple words:** The pod refers to something that isn't there (a ConfigMap, a Secret, a key, a volume) or asks for something the runtime refuses. Kubernetes won't start the container until it's fixed, and `describe` names the missing piece.

| Status / event | Cause | Fix |
|---|---|---|
| `CreateContainerConfigError`: `configmap "app-config" not found` | ConfigMap missing in **this namespace** | Create it (ConfigMaps and Secrets are per namespace) |
| `couldn't find key DB_PASSWORD in Secret …` | The Secret exists but that key doesn't | `kubectl get secret <s> -o jsonpath='{.data}'` to see the keys |
| `container has runAsNonRoot and image has non-numeric user` | `runAsNonRoot: true` and the image's `USER` is a name | Set `runAsUser: <uid>` in the securityContext, or use a numeric `USER` in the Dockerfile |
| `CreateContainerError`: `executable file not found` | `command` points at a binary that isn't in the image | Fix the command or the image |
| `MountVolume.SetUp failed` | Secret or ConfigMap volume missing, or the PVC can't attach | `describe pod` events, `kubectl get pvc` |
| `Error: failed to create containerd task … read-only file system` | The app writes to a path that is read-only | Mount an `emptyDir` at that path |

```bash
kubectl get configmap,secret                 # what exists in this namespace
kubectl describe pod <pod> | grep -i -A2 "not found\|couldn't find"
```

## Probe failures: Running but not Ready

> **In simple words:** **Readiness** decides whether a pod gets traffic. **Liveness** decides whether it gets restarted. A wrong probe can keep a healthy app out of the Service (0/1 READY) or restart it in a loop.

```bash
kubectl describe pod <pod> | grep -E "Readiness|Liveness|Startup|Unhealthy"
kubectl exec <pod> -- wget -qO- http://localhost:<port>/health    # does the probe URL work from inside?
```

| Symptom | Cause | Fix |
|---|---|---|
| READY `0/1`, `Readiness probe failed: HTTP probe failed with statuscode: 404` | Wrong probe path | Point it at a real health endpoint |
| `connect: connection refused` in probe events | Wrong port, or the app is still starting | Fix the port. Add a `startupProbe` for slow starters |
| Restarts every few minutes, no app error | The liveness probe times out under load (default timeout is **1 second**) | Raise `timeoutSeconds` and `failureThreshold`, and keep liveness checks cheap |
| A dependency outage restarts every pod | The liveness probe checks the database | Liveness should check only the process itself. Check dependencies in readiness |

```yaml
startupProbe:            # gives slow apps up to 5 minutes to start
  httpGet: { path: /health, port: http }
  failureThreshold: 30
  periodSeconds: 10
readinessProbe:
  httpGet: { path: /ready, port: http }
  periodSeconds: 5
livenessProbe:
  httpGet: { path: /health, port: http }
  timeoutSeconds: 3
  failureThreshold: 3
```

## Stuck Terminating: pods, namespaces, volumes

> **In simple words:** Deleting something waits for clean-up steps called **finalizers**. If the controller that should finish them is gone, or the node is unreachable, the object hangs in `Terminating`.

```bash
kubectl get pod <pod> -o jsonpath='{.metadata.finalizers}{"\n"}'
kubectl get namespace <ns> -o jsonpath='{.status.conditions}' | jq .      # what's blocking it
kubectl api-resources --verbs=list --namespaced -o name \
  | xargs -n1 kubectl get -n <ns> --ignore-not-found --show-kind 2>/dev/null   # what's left inside
```

| Stuck object | Usual cause | Fix |
|---|---|---|
| Pod | Its node is down or unreachable | If the node is really gone: `kubectl delete pod <pod> --grace-period=0 --force` |
| Namespace | A resource inside still has a finalizer (often a custom resource whose operator was uninstalled) | Reinstall the operator to finish clean-up, or remove that resource's finalizer |
| PVC | Still used by a pod (`kubernetes.io/pvc-protection`) | Delete the pod using it first |

> **Warning:** Force-deleting or stripping finalizers skips clean-up, so AWS load balancers, volumes or DNS records can be left behind and keep costing money. Find out what the finalizer protects first.

## Node problems

> **In simple words:** Sometimes the pod is fine but its **node** isn't. A NotReady node stops running new pods, and nodes under memory or disk pressure start evicting pods.

```bash
kubectl get nodes -o wide
kubectl describe node <node> | sed -n '/Conditions/,/Addresses/p'    # MemoryPressure, DiskPressure, PIDPressure, Ready
kubectl get pods -A -o wide --field-selector spec.nodeName=<node>
kubectl debug node/<node> -it --image=busybox:1.36    # shell on the node; host files under /host
```

| Condition | Meaning | Fix |
|---|---|---|
| `Ready=False` / `Unknown` | kubelet stopped or lost contact | Check the instance; on EKS, a managed node group replaces unhealthy nodes |
| `DiskPressure=True` | Disk almost full (images, logs) | Clean unused images, bigger root volume, log rotation |
| `MemoryPressure=True` | Node memory nearly exhausted | Set requests and limits so the scheduler doesn't overpack nodes |
| Pods stuck `ContainerCreating` on EKS: `failed to assign an IP address` | VPC CNI ran out of IPs in the subnet | Bigger subnets, or prefix delegation |

Take a node out safely for maintenance:

```bash
kubectl cordon <node>                                           # no new pods
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data # move pods away
kubectl uncordon <node>                                         # back in service
```

## Deployments and rollouts that won't finish

> **In simple words:** A rollout is stuck when the **new** pods never become ready, so the old ones keep serving. That's actually Kubernetes protecting you. Find out why the new pods fail, then fix forward or roll back.

```bash
kubectl rollout status deploy/<name> --timeout=2m
kubectl describe deploy <name> | grep -A3 Conditions      # ProgressDeadlineExceeded?
kubectl get rs -l app=<label>                             # old vs new ReplicaSet, ready counts
kubectl rollout history deploy/<name>
kubectl rollout undo deploy/<name>                        # back to the previous version
```

| Symptom | Cause | Fix |
|---|---|---|
| `ProgressDeadlineExceeded` | New pods never became ready within `progressDeadlineSeconds` | Diagnose the new pods (CrashLoop, ImagePull, probes), then fix or `rollout undo` |
| Old and new pods running side by side for a long time | `maxUnavailable: 0` and the new pods aren't ready | Same as above |
| `exceeded quota` in ReplicaSet events | A ResourceQuota blocks the extra pods | Raise the quota, or set requests and limits that fit |
| HPA shows `<unknown>/70%` | metrics-server missing, or no CPU **requests** on the container | Install metrics-server, and set requests |
| Changes to a ConfigMap don't show up | Pods read env vars only at start-up | `kubectl rollout restart deploy/<name>` (or use a config checksum annotation, as in the Helm guide) |

## EKS-specific issues

> **In simple words:** On EKS, some problems come from the AWS side: IAM, VPC networking and AWS-managed add-ons. These are the ones you'll meet most.

| Symptom | Cause | Fix |
|---|---|---|
| `kubectl`: `error: You must be logged in to the server (Unauthorized)` | Your IAM identity has no access entry on the cluster, or the wrong AWS profile | `aws sts get-caller-identity`; add an access entry ([IAM guide](#/tool/aws-iam)) |
| Pods `ContainerCreating`: `failed to assign an IP address to container` | Subnet out of IPs (VPC CNI gives every pod a VPC IP) | Bigger subnets, prefix delegation, or a secondary CIDR |
| Pod uses the **node** role instead of its own | Pod Identity association or IRSA annotation missing, or the pod started before it existed | Fix the association, then restart the pod |
| Ingress has no ADDRESS | Load Balancer Controller not running, or subnets not tagged | `kubectl logs -n kube-system deploy/aws-load-balancer-controller` ([EKS runbook](#/tool/eks-cluster)) |
| PVC Pending: `failed to provision volume` | EBS CSI driver missing or its IAM role wrong | Install the `aws-ebs-csi-driver` add-on with its role |
| `ImagePullBackOff` from ECR with 403 | Node role lacks ECR read access, or a cross-account repository policy is missing | Attach `AmazonEC2ContainerRegistryReadOnly`, or fix the repository policy |
| Timeouts from pods to RDS or ElastiCache | Security group doesn't allow the cluster or node security group | Add an inbound rule from the cluster security group on the DB port |

## Practice lab: break it, then fix it

> **In simple words:** The fastest way to learn troubleshooting is to cause each problem on purpose. Apply each broken manifest, diagnose it **using only** `get`, `describe`, `logs` and `events`, then fix it.

```bash
kubectl create namespace trouble
kubectl config set-context --current --namespace=trouble
```

Save as `broken.yaml` and apply it with `kubectl apply -f broken.yaml`:

```yaml
# 1. ImagePullBackOff: the tag doesn't exist
apiVersion: v1
kind: Pod
metadata: { name: bad-image }
spec:
  containers:
    - name: web
      image: nginx:9.99.99
---
# 2. CrashLoopBackOff: the command exits with an error
apiVersion: v1
kind: Pod
metadata: { name: crasher }
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "echo 'connecting to database...'; sleep 3; echo 'ERROR: DB_HOST not set'; exit 1"]
---
# 3. Pending: asks for more CPU than any node has
apiVersion: v1
kind: Pod
metadata: { name: too-big }
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sleep", "3600"]
      resources:
        requests: { cpu: "64", memory: 1Gi }
---
# 4. CreateContainerConfigError: the ConfigMap doesn't exist
apiVersion: v1
kind: Pod
metadata: { name: missing-config }
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sleep", "3600"]
      envFrom:
        - configMapRef: { name: app-config }
---
# 5. OOMKilled: keeps eating memory past a 32Mi limit
apiVersion: v1
kind: Pod
metadata: { name: memory-hog }
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "tail /dev/zero"]
      resources:
        limits: { memory: 32Mi }
---
# 6. Running but not Ready: the readiness probe checks a path that doesn't exist
apiVersion: v1
kind: Pod
metadata:
  name: never-ready
  labels: { app: web }
spec:
  containers:
    - name: web
      image: nginx:1.27
      readinessProbe:
        httpGet: { path: /healthz, port: 80 }
        periodSeconds: 5
---
# 7. Service with no endpoints: the selector doesn't match any pod
apiVersion: v1
kind: Service
metadata: { name: web }
spec:
  selector: { app: website }
  ports:
    - port: 80
      targetPort: 80
```

Your tasks:

1. Run `kubectl get pods` and write down the STATUS of each pod.
2. For each one, find the **exact** reason in `describe`, `logs --previous` or events.
3. Fix each, without looking back at this guide:
   - `bad-image`: use `nginx:1.27`
   - `crasher`: make the command run forever, or explain the exit code
   - `too-big`: realistic requests
   - `missing-config`: create `app-config`
   - `memory-hog`: explain exit code 137
   - `never-ready`: probe path `/`
   - `web` Service: selector `app: web`, and check its endpoints
4. Bonus: from a `netshoot` pod, `curl http://web` before and after fixing the Service selector.
5. Clean up: `kubectl delete namespace trouble`.

### Cheat sheet

| Situation | Command |
|---|---|
| What's broken, cluster-wide | `kubectl get pods -A \| grep -vE 'Running\|Completed'` |
| Why is this pod failing | `kubectl describe pod <pod>` (read Events) |
| Logs of the crashed run | `kubectl logs <pod> --previous` |
| Most restarted pods | `kubectl get pods -A --sort-by='.status.containerStatuses[0].restartCount'` |
| Recent warnings | `kubectl get events -A --field-selector type=Warning --sort-by=.lastTimestamp` |
| Does the Service have pods | `kubectl get endpointslices -l kubernetes.io/service-name=<svc>` |
| Network test pod | `kubectl run tmp --rm -it --image=nicolaka/netshoot -- bash` |
| Shell in a crashing container | `kubectl debug <pod> -it --copy-to=<pod>-debug --container=<c> -- sh` |
| Roll back a bad deploy | `kubectl rollout undo deploy/<name>` |
