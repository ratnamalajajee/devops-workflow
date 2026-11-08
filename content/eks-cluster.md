# EKS Cluster Setup: Runbook

A step-by-step runbook for creating an Amazon EKS cluster in an **existing VPC** with `eksctl`, then installing the add-ons most platforms need: the **AWS Load Balancer Controller**, **EBS** block storage, **EFS** shared storage, and the **Istio** service mesh. Set your values once in the first step, then copy each block in order.

> **Note:** You need admin-level AWS access (or rights to create EKS, EC2, IAM, EFS and CloudFormation resources) and an existing VPC with private subnets. The [AWS](#/tool/aws), [IAM](#/tool/aws-iam) and [Kubernetes](#/tool/kubernetes) guides explain the concepts used here.

> **Cost:** The EKS control plane is **$0.10/hour** on a version in standard support, but **$0.60/hour** once the version reaches extended support. Nodes cost extra: a `c5.4xlarge` is about $0.68/hour on-demand in us-east-1, so two of them run around $1,000/month. Load balancers, EBS, EFS and NAT traffic come on top. See [EKS pricing](https://aws.amazon.com/eks/pricing/).

> **Warning:** Never paste real account IDs, VPC or subnet IDs, IP ranges or passwords into shared runbooks, tickets or chat. Keep environment values in your team's private configuration and use the variables below.

## Start here: the flow in simple words

> **In simple words:** `eksctl` reads one YAML file and builds the cluster and its worker nodes inside your VPC. Then you install a few add-ons, each with its own IAM role: one creates AWS load balancers, two give pods disks, and one adds a service mesh.

```text
 1. Install tools (aws, kubectl, eksctl, helm) and set variables
 2. Check the VPC: private subnets in 2+ AZs, outbound internet or VPC endpoints, subnet tags
 3. Write eks.yaml (cluster + managed node group)
 4. eksctl create cluster  →  ~20 minutes  →  kubectl get nodes
 5. AWS Load Balancer Controller   (Ingress → ALB, Service → NLB)
 6. EBS CSI driver + gp3 StorageClass   (one disk per pod)
 7. EFS file system + EFS CSI driver   (shared ReadWriteMany storage)
 8. Istio (base + istiod, optional ingress gateway)
 9. Verify everything
```

### Prerequisites

| Requirement | Check with |
|---|---|
| AWS CLI v2, logged in to the right account | `aws sts get-caller-identity` |
| An existing VPC with **private subnets in at least 2 AZs** | `aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID` |
| Outbound access from those subnets (NAT gateway, or VPC endpoints for ECR, S3, EC2, STS) | Ask the network team if unsure |
| Enough free IPs in each subnet (every pod gets a VPC IP) | `AvailableIpAddressCount` in the command above |

### Set your values once

```bash
export AWS_REGION=us-east-1
export AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
export CLUSTER_NAME=my-cluster                     # CHANGE
export K8S_VERSION=1.36                            # a version in EKS standard support (see below)
export VPC_ID=vpc-0123456789abcdef0                # CHANGE: existing VPC
export PRIVATE_SUBNETS="subnet-0aaaaaaaaaaaaaaaa subnet-0bbbbbbbbbbbbbbbb subnet-0cccccccccccccccc"   # CHANGE: one per AZ
export LBC_VERSION=v3.6.2                          # AWS Load Balancer Controller release
export ISTIO_VERSION=1.31.3                        # Istio release (check its supported Kubernetes versions)
```

**Pick a supported Kubernetes version.** EKS gives each version 14 months of standard support, then 12 months of more expensive extended support. For example, 1.33 left standard support on July 29, 2026. Always start new clusters on a recent version. AWS docs: [Kubernetes version lifecycle on EKS](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html)

## Install the tools

> **In simple words:** Four command-line tools do all the work: `aws` talks to AWS, `kubectl` to the cluster, `eksctl` builds the cluster, and `helm` installs add-ons. Install them once on your laptop or jump host.

`aws`, `kubectl` and `helm` are covered in [Workstation Setup](#/tool/setup). Install `eksctl`:

```bash
ARCH=amd64        # arm64 on ARM machines
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_${ARCH}.tar.gz"
tar -xzf eksctl_Linux_${ARCH}.tar.gz -C /tmp && rm eksctl_Linux_${ARCH}.tar.gz
sudo install -m 0755 /tmp/eksctl /usr/local/bin/eksctl

aws --version && kubectl version --client && eksctl version && helm version --short
```

## Check the VPC and tag the subnets

> **In simple words:** EKS builds the cluster *inside* your network, so the network must be ready first: private subnets in at least two Availability Zones, a way for nodes to reach AWS services, and tags that tell load balancers which subnets to use.

```bash
aws ec2 describe-subnets --subnet-ids $PRIVATE_SUBNETS --region $AWS_REGION \
  --query 'Subnets[].[SubnetId,AvailabilityZone,CidrBlock,AvailableIpAddressCount,MapPublicIpOnLaunch]' --output table
```

Check that each subnet is in a **different AZ**, has plenty of free IPs, and has `MapPublicIpOnLaunch = False`.

Tag the subnets so the Load Balancer Controller can find them:

```bash
# internal load balancers go into private subnets
aws ec2 create-tags --region $AWS_REGION --resources $PRIVATE_SUBNETS \
  --tags Key=kubernetes.io/role/internal-elb,Value=1

# only if you also want internet-facing load balancers, tag your PUBLIC subnets:
# aws ec2 create-tags --region $AWS_REGION --resources subnet-public-a subnet-public-b \
#   --tags Key=kubernetes.io/role/elb,Value=1
```

AWS docs: [EKS networking requirements](https://docs.aws.amazon.com/eks/latest/userguide/network-reqs.html) · [Load balancer subnet discovery](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/subnet_discovery/)

## Write the cluster config (eks.yaml)

> **In simple words:** One file describes the whole cluster: its name and version, which VPC and subnets to use, how the API endpoint is reachable, and the worker nodes. Keep this file in Git so the cluster can be rebuilt the same way.

Create `eks.yaml` and change the values marked `# CHANGE`:

```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: my-cluster                  # CHANGE: same as $CLUSTER_NAME
  region: us-east-1                 # CHANGE
  version: "1.36"                   # CHANGE: a version in standard support
  tags:
    team: platform
    environment: dev

iam:
  withOIDC: true                    # enables IAM roles for service accounts (used by every add-on below)

vpc:
  id: vpc-0123456789abcdef0         # CHANGE: existing VPC (its CIDR is read automatically)
  subnets:
    private:
      us-east-1a: { id: subnet-0aaaaaaaaaaaaaaaa }   # CHANGE: one private subnet per AZ
      us-east-1b: { id: subnet-0bbbbbbbbbbbbbbbb }
      us-east-1c: { id: subnet-0cccccccccccccccc }
  clusterEndpoints:
    privateAccess: true             # nodes and VPN users reach the API privately
    publicAccess: true              # set false for a private-only API (needs VPN or a bastion)

addons:                             # core EKS add-ons, managed by AWS
  - name: vpc-cni
  - name: coredns
  - name: kube-proxy

managedNodeGroups:
  - name: ng-general
    instanceType: c5.4xlarge        # CHANGE: size for your workloads
    minSize: 2
    desiredCapacity: 2
    maxSize: 4
    volumeSize: 100
    volumeType: gp3
    privateNetworking: true         # nodes get private IPs only
    labels:
      role: general

cloudWatch:
  clusterLogging:
    enableTypes: ["api", "audit", "authenticator"]   # control-plane logs to CloudWatch
```

| Setting | Why |
|---|---|
| `iam.withOIDC: true` | Creates the OIDC provider at cluster creation, so there's no separate `associate-iam-oidc-provider` step |
| No `vpc.cidr` | Not needed for an existing VPC: eksctl reads it from the VPC |
| `minSize` / `maxSize` | Lets an autoscaler (Cluster Autoscaler or Karpenter) grow and shrink the group later |
| `privateNetworking: true` | Nodes have no public IPs |
| `clusterLogging` | API and audit logs help with security reviews and troubleshooting |

## Create the cluster and connect

> **In simple words:** `eksctl` turns the file into CloudFormation stacks: first the control plane, then the nodes. It takes about 15–25 minutes. When it finishes, your `kubectl` is already pointed at the new cluster.

```bash
eksctl create cluster -f eks.yaml --dry-run | less    # optional: review the full expanded config
eksctl create cluster -f eks.yaml

aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION
kubectl config current-context
kubectl get nodes -o wide                  # 2 nodes, STATUS Ready, private IPs only
kubectl get pods -n kube-system            # aws-node, coredns, kube-proxy running
```

Progress can be followed in **CloudFormation** (stacks named `eksctl-<cluster>-cluster` and `eksctl-<cluster>-nodegroup-…`).

AWS docs: [What is eksctl?](https://docs.aws.amazon.com/eks/latest/eksctl/what-is-eksctl.html)

## Install the AWS Load Balancer Controller

> **In simple words:** This controller watches Kubernetes and creates real AWS load balancers: an **ALB** for every Ingress, and an **NLB** for every Service of type `LoadBalancer`. It needs an IAM role, and the role's policy must match the controller version you install.

```bash
# 1. IAM policy from the SAME release as the controller
curl -fsSL -o lbc-iam-policy.json \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/${LBC_VERSION}/docs/install/iam_policy.json
aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy-$CLUSTER_NAME \
  --policy-document file://lbc-iam-policy.json

# 2. IAM role + Kubernetes service account (IRSA)
eksctl create iamserviceaccount \
  --cluster $CLUSTER_NAME --region $AWS_REGION \
  --namespace kube-system --name aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole-$CLUSTER_NAME \
  --attach-policy-arn arn:aws:iam::${AWS_ACCOUNT}:policy/AWSLoadBalancerControllerIAMPolicy-$CLUSTER_NAME \
  --approve

# 3. Install the controller with Helm (chart version = controller version)
helm repo add eks https://aws.github.io/eks-charts && helm repo update eks
helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system \
  --version ${LBC_VERSION#v} \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=$AWS_REGION \
  --set vpcId=$VPC_ID

kubectl -n kube-system rollout status deploy/aws-load-balancer-controller
kubectl -n kube-system get deploy aws-load-balancer-controller      # READY 2/2
```

- Every multi-line command needs a `\` at the end of each line except the last. A missing `\` silently drops the flags after it (for example `--approve`).
- `region` and `vpcId` are set explicitly, so the controller doesn't depend on reading them from the instance metadata service.
- The chart's default image is pulled from Amazon ECR Public. In clusters with **no internet access**, mirror the image to your own ECR and set `image.repository`.
- From v2.5 on, the controller handles **all** new Services of type `LoadBalancer` (as NLBs, **internal by default**). Use the annotation `service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing` only when you really need a public one.

AWS docs: [AWS Load Balancer Controller](https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html) · [Installation guide](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/installation/)

## Install the EBS CSI driver (block storage)

> **In simple words:** Pods like databases need their own disk that survives restarts. The EBS CSI driver creates an EBS volume for each PersistentVolumeClaim and attaches it to whichever node the pod runs on.

```bash
# 1. IAM role for the driver (AWS managed policy)
eksctl create iamserviceaccount \
  --cluster $CLUSTER_NAME --region $AWS_REGION \
  --namespace kube-system --name ebs-csi-controller-sa \
  --role-name AmazonEKS_EBS_CSI_DriverRole-$CLUSTER_NAME --role-only \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve

# 2. Install the EKS add-on with that role
eksctl create addon --cluster $CLUSTER_NAME --region $AWS_REGION \
  --name aws-ebs-csi-driver \
  --service-account-role-arn arn:aws:iam::${AWS_ACCOUNT}:role/AmazonEKS_EBS_CSI_DriverRole-$CLUSTER_NAME \
  --force

kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver
```

Make an encrypted **gp3** class the default:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
parameters:
  type: gp3
  encrypted: "true"
EOF
kubectl annotate storageclass gp2 storageclass.kubernetes.io/is-default-class=false --overwrite 2>/dev/null || true
kubectl get storageclass                    # gp3 marked (default)
```

AWS docs: [Amazon EBS CSI driver](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html)

## Set up EFS (shared storage)

> **In simple words:** EFS is a network file system that **many pods on many nodes can read and write at the same time** (`ReadWriteMany`), which suits shared uploads, content and caches. You create the file system, let the nodes reach it on the NFS port, and install the EFS CSI driver.

### 1. IAM role and the EFS CSI add-on

```bash
EFS_ROLE=AmazonEKS_EFS_CSI_DriverRole-$CLUSTER_NAME
eksctl create iamserviceaccount \
  --cluster $CLUSTER_NAME --region $AWS_REGION \
  --namespace kube-system --name efs-csi-controller-sa \
  --role-name $EFS_ROLE --role-only \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy \
  --approve

# let both driver service accounts (controller and node) use the role
TRUST_POLICY=$(aws iam get-role --role-name $EFS_ROLE --query 'Role.AssumeRolePolicyDocument' --output json | \
  sed -e 's/efs-csi-controller-sa/efs-csi-*/' -e 's/StringEquals/StringLike/')
aws iam update-assume-role-policy --role-name $EFS_ROLE --policy-document "$TRUST_POLICY"

eksctl create addon --cluster $CLUSTER_NAME --region $AWS_REGION \
  --name aws-efs-csi-driver \
  --service-account-role-arn arn:aws:iam::${AWS_ACCOUNT}:role/$EFS_ROLE \
  --force
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-efs-csi-driver
```

### 2. Security group: allow NFS (port 2049) from the cluster only

```bash
CLUSTER_SG=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION \
  --query cluster.resourcesVpcConfig.clusterSecurityGroupId --output text)

EFS_SG=$(aws ec2 create-security-group --region $AWS_REGION --vpc-id $VPC_ID \
  --group-name efs-nfs-$CLUSTER_NAME --description "NFS from EKS nodes to EFS" \
  --query GroupId --output text)

aws ec2 authorize-security-group-ingress --region $AWS_REGION --group-id $EFS_SG \
  --protocol tcp --port 2049 --source-group $CLUSTER_SG

# only if other networks must mount this EFS (e.g. a VPN range), add them explicitly:
# aws ec2 authorize-security-group-ingress --region $AWS_REGION --group-id $EFS_SG --protocol tcp --port 2049 --cidr <OTHER_CIDR>
```

Allowing the **cluster security group** (which managed nodes use) is tighter than opening NFS to the whole VPC CIDR.

### 3. Create the file system and one mount target per AZ

```bash
EFS_ID=$(aws efs create-file-system --region $AWS_REGION --encrypted \
  --performance-mode generalPurpose --throughput-mode elastic \
  --tags Key=Name,Value=efs-$CLUSTER_NAME --query FileSystemId --output text)

until [ "$(aws efs describe-file-systems --region $AWS_REGION --file-system-id $EFS_ID \
  --query 'FileSystems[0].LifeCycleState' --output text)" = "available" ]; do sleep 5; done

for SUBNET in $PRIVATE_SUBNETS; do
  aws efs create-mount-target --region $AWS_REGION --file-system-id $EFS_ID \
    --subnet-id $SUBNET --security-groups $EFS_SG
done
aws efs describe-mount-targets --region $AWS_REGION --file-system-id $EFS_ID \
  --query 'MountTargets[].[SubnetId,AvailabilityZoneName,LifeCycleState]' --output table
echo "EFS_ID=$EFS_ID"
```

### 4. StorageClass for dynamic EFS volumes

```bash
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap          # each PVC gets its own EFS access point (directory)
  fileSystemId: ${EFS_ID}
  directoryPerms: "700"
  basePath: "/dynamic"
EOF
```

Workloads then request `storageClassName: efs-sc` with `accessModes: [ReadWriteMany]`.

AWS docs: [Amazon EFS CSI driver](https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html)

## Install Istio

> **In simple words:** Istio adds a **service mesh**: a small proxy next to each pod that handles encryption between services (mTLS), traffic routing, retries and detailed metrics, without changing application code. `istio-base` installs its CRDs, and `istiod` is the control plane.

```bash
helm repo add istio https://istio-release.storage.googleapis.com/charts && helm repo update istio
kubectl create namespace istio-system

helm install istio-base istio/base -n istio-system --version $ISTIO_VERSION \
  --set defaultRevision=default --wait

helm install istiod istio/istiod -n istio-system --version $ISTIO_VERSION \
  --set-json 'pilot.env={"PILOT_SCOPE_GATEWAY_TO_NAMESPACE":"true"}' --wait

kubectl get pods -n istio-system          # istiod Running
helm ls -n istio-system
```

| Setting | Meaning |
|---|---|
| Pinned `--version` on both charts | `istio-base` and `istiod` must be the **same** version. Check Istio's supported Kubernetes versions before upgrading either |
| `PILOT_SCOPE_GATEWAY_TO_NAMESPACE=true` | A `Gateway` resource only configures gateway pods **in its own namespace**, so one team's Gateway can't take over another team's ingress gateway |

Turn on sidecar injection for an application namespace. Existing pods only get the proxy after a restart:

```bash
kubectl label namespace my-app istio-injection=enabled --overwrite
kubectl rollout restart deployment -n my-app
kubectl get pods -n my-app            # READY 2/2 = app container + istio-proxy
```

Optional: an **internal** ingress gateway, exposed through an NLB by the Load Balancer Controller:

```bash
helm install istio-ingress istio/gateway -n istio-ingress --create-namespace --version $ISTIO_VERSION \
  --set service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"=internal \
  --set service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-nlb-target-type"=ip
kubectl get svc -n istio-ingress      # EXTERNAL-IP shows the internal NLB hostname
```

Because of `PILOT_SCOPE_GATEWAY_TO_NAMESPACE`, `Gateway` resources for this gateway must be created in the `istio-ingress` namespace.

Docs: [Install Istio with Helm](https://istio.io/latest/docs/setup/install/helm/) · [Istio supported releases](https://istio.io/latest/docs/releases/supported-releases/)

## Verify the whole cluster

> **In simple words:** A quick health check of every piece before handing the cluster to application teams.

```bash
kubectl get nodes -o wide                                            # all Ready
kubectl get pods -A | grep -v -E 'Running|Completed'                 # should print only the header
eksctl get addons --cluster $CLUSTER_NAME --region $AWS_REGION       # all ACTIVE
eksctl get iamserviceaccount --cluster $CLUSTER_NAME --region $AWS_REGION
kubectl -n kube-system get deploy aws-load-balancer-controller
kubectl get storageclass                                             # gp3 (default), efs-sc
kubectl get pods -n istio-system
```

Storage smoke test: one EBS volume and one shared EFS volume, mounted by a test pod:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: test-ebs }
spec: { accessModes: [ReadWriteOnce], storageClassName: gp3, resources: { requests: { storage: 1Gi } } }
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: test-efs }
spec: { accessModes: [ReadWriteMany], storageClassName: efs-sc, resources: { requests: { storage: 1Gi } } }
---
apiVersion: v1
kind: Pod
metadata: { name: storage-test }
spec:
  containers:
    - name: test
      image: busybox:1.36
      command: ["sh", "-c", "date | tee /ebs/ok /efs/ok && sleep 3600"]
      volumeMounts: [{ name: ebs, mountPath: /ebs }, { name: efs, mountPath: /efs }]
  volumes:
    - { name: ebs, persistentVolumeClaim: { claimName: test-ebs } }
    - { name: efs, persistentVolumeClaim: { claimName: test-efs } }
EOF
kubectl wait --for=condition=Ready pod/storage-test --timeout=180s
kubectl get pvc test-ebs test-efs              # both Bound
kubectl exec storage-test -- cat /ebs/ok /efs/ok
kubectl delete pod storage-test && kubectl delete pvc test-ebs test-efs
```

Next step: install Argo CD with the [Argo CD on EKS runbook](#/tool/argocd-eks).

## Troubleshooting

> **In simple words:** Cluster problems are usually network (nodes can't reach AWS), IAM (an add-on's role is missing or too old), or tags and security groups (load balancers or EFS can't find or reach things).

| Problem | Fix |
|---|---|
| `eksctl create cluster` fails or hangs | Open the failing **CloudFormation** stack's **Events** tab, or run `eksctl utils describe-stacks --cluster $CLUSTER_NAME --region $AWS_REGION` |
| Nodes never join / stay `NotReady` | Private subnets have no route out (NAT) and no VPC endpoints for ECR, S3, EC2 and STS, or the subnet is out of IPs |
| A version is "in extended support" | Upgrade the control plane, then the node group: `eksctl upgrade cluster`, then `eksctl upgrade nodegroup` |
| `--approve` ran as a separate command | A missing `\` at the end of the previous line. Re-run the whole command as one block |
| Policy ARN with an empty account ID (`arn:aws:iam:::policy/…`) | `AWS_ACCOUNT` wasn't set. Run the variables block again |
| Load Balancer Controller logs `AccessDenied` | The IAM policy is older than the controller. Download `iam_policy.json` for `$LBC_VERSION` and create a new policy version |
| Ingress or Service gets no load balancer | Subnets aren't tagged (`kubernetes.io/role/internal-elb` / `elb`). Check `kubectl logs -n kube-system deploy/aws-load-balancer-controller` |
| EBS PVC stays `Pending` | Normal with `WaitForFirstConsumer` until a pod uses it. Otherwise check the add-on's role: `kubectl describe pvc <name>` |
| EFS mount times out | Port 2049 not allowed from the nodes' security group, or no mount target in the node's AZ |
| `create-security-group` returns two values | Always add `--query GroupId` so only the ID is captured |
| Pods show `1/1` instead of `2/2` after enabling Istio | Namespace not labelled, or pods not restarted after labelling |
| `iamserviceaccount … already exists` | Add `--override-existing-serviceaccounts`, or delete it with `eksctl delete iamserviceaccount` first |

## Clean up

> **In simple words:** Delete in reverse order. Remove anything that created AWS resources from *inside* Kubernetes (load balancers, volumes) **before** the cluster, otherwise those resources are left behind and keep costing money.

```bash
# 1. Load balancers and volumes created by Kubernetes
kubectl get ingress -A; kubectl get svc -A | grep LoadBalancer      # delete these first
helm uninstall istio-ingress -n istio-ingress 2>/dev/null
helm uninstall istiod istio-base -n istio-system
kubectl get pvc -A                                                    # delete PVCs you no longer need
helm uninstall aws-load-balancer-controller -n kube-system

# 2. EFS (mount targets, then file system, then security group)
for MT in $(aws efs describe-mount-targets --region $AWS_REGION --file-system-id $EFS_ID --query 'MountTargets[].MountTargetId' --output text); do
  aws efs delete-mount-target --region $AWS_REGION --mount-target-id $MT; done
sleep 60
aws efs delete-file-system --region $AWS_REGION --file-system-id $EFS_ID
aws ec2 delete-security-group --region $AWS_REGION --group-id $EFS_SG

# 3. The cluster (also removes the IAM roles eksctl created for service accounts)
eksctl delete cluster -f eks.yaml --wait

# 4. The customer-managed policy
aws iam delete-policy --policy-arn arn:aws:iam::${AWS_ACCOUNT}:policy/AWSLoadBalancerControllerIAMPolicy-$CLUSTER_NAME
```

## Quick reference

> **In simple words:** The whole runbook as one compact list, for when you've done it before.

```bash
# variables: see step 1
eksctl create cluster -f eks.yaml && aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION
aws ec2 create-tags --region $AWS_REGION --resources $PRIVATE_SUBNETS --tags Key=kubernetes.io/role/internal-elb,Value=1

# Load Balancer Controller
curl -fsSL -o lbc-iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/${LBC_VERSION}/docs/install/iam_policy.json
aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy-$CLUSTER_NAME --policy-document file://lbc-iam-policy.json
eksctl create iamserviceaccount --cluster $CLUSTER_NAME --region $AWS_REGION --namespace kube-system --name aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole-$CLUSTER_NAME --attach-policy-arn arn:aws:iam::${AWS_ACCOUNT}:policy/AWSLoadBalancerControllerIAMPolicy-$CLUSTER_NAME --approve
helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --version ${LBC_VERSION#v} \
  --set clusterName=$CLUSTER_NAME --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller --set region=$AWS_REGION --set vpcId=$VPC_ID

# EBS
eksctl create iamserviceaccount --cluster $CLUSTER_NAME --region $AWS_REGION --namespace kube-system --name ebs-csi-controller-sa \
  --role-name AmazonEKS_EBS_CSI_DriverRole-$CLUSTER_NAME --role-only --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy --approve
eksctl create addon --cluster $CLUSTER_NAME --region $AWS_REGION --name aws-ebs-csi-driver \
  --service-account-role-arn arn:aws:iam::${AWS_ACCOUNT}:role/AmazonEKS_EBS_CSI_DriverRole-$CLUSTER_NAME --force

# EFS: role + add-on, security group, file system + mount targets, StorageClass (see step 8)

# Istio
helm install istio-base istio/base -n istio-system --create-namespace --version $ISTIO_VERSION --set defaultRevision=default --wait
helm install istiod istio/istiod -n istio-system --version $ISTIO_VERSION --set-json 'pilot.env={"PILOT_SCOPE_GATEWAY_TO_NAMESPACE":"true"}' --wait
```
