# Amazon EFS and FSx: Shared File Storage

Many servers often need the **same files** at the same time: uploaded images, shared config, build caches, home folders. This guide explains block, file and object storage in plain words, then builds an **Amazon EFS** file system step by step (mount targets, TLS mounts, access points, lifecycle, backups, ECS and EKS), and finally an **Amazon FSx for NetApp ONTAP** file system with a storage virtual machine and a volume mounted over NFS. Every step shows the **console clicks** and the matching **AWS CLI** commands.

> **Cost:** **EFS** has no minimum fee: Standard storage is about **$0.30 per GB-month**, Infrequent Access about $0.016 and Archive about $0.008 per GB-month, and with Elastic throughput you pay about **$0.03 per GB read and $0.06 per GB written** (us-east-1). A lab with a few MB costs cents. **FSx is different:** you pay **every hour for the capacity you provision, even when idle**. The smallest FSx for ONTAP file system (Single-AZ, 1,024 GiB SSD, 128 MBps) costs about **$0.30/hour (about $220/month)**, Multi-AZ almost double, and the smallest FSx for Windows File Server about $75/month. Delete FSx right after the lab. See [EFS pricing](https://aws.amazon.com/efs/pricing/), [FSx for ONTAP pricing](https://aws.amazon.com/fsx/netapp-ontap/pricing/) and [FSx for Windows pricing](https://aws.amazon.com/fsx/windows/pricing/).

## Start here: shared file storage in simple words

> **In simple words:** An **EBS** volume is a **disk plugged into one server**. **EFS** and **FSx** are a **shared network drive**: many servers mount the same folder at once and see each other's files instantly. **S3** is a huge **warehouse of objects** you reach over HTTP, not a folder you mount.

### Block, file and object storage

| Everyday life | AWS service | Storage type | How you use it |
|---|---|---|---|
| A USB disk plugged into one laptop | **Amazon EBS** | **Block**: raw disk you format | Attached to **one** EC2 instance (in one AZ); the OS sees `/dev/nvme1n1` |
| The shared "S:" drive in an office | **Amazon EFS**, **Amazon FSx** | **File**: folders and files over a network protocol | **Many** servers, containers and pods mount it at the same time |
| A warehouse where every box has a label | **Amazon S3** | **Object**: whole files with a key and metadata | Read and write over HTTPS with the API, SDK or `aws s3` |

### Which one should I use?

| You need | Use |
|---|---|
| A boot disk or a database disk for one server | **EBS** |
| A shared Linux folder for many EC2 instances, ECS tasks or EKS pods, with no size to manage | **EFS** |
| Windows file shares (SMB) with Active Directory | **FSx for Windows File Server** |
| NFS **and** SMB **and** iSCSI from one system, snapshots, SnapMirror, or a move from on-premises NetApp | **FSx for NetApp ONTAP** |
| Very fast scratch storage for HPC or ML training, linked to S3 | **FSx for Lustre** |
| A fast NFS server for Linux apps that used ZFS or a Linux file server | **FSx for OpenZFS** |
| Backups, logs, images, data lakes, static websites | **S3** (see the [S3 guide](#/tool/aws-s3)) |

### Key words

| Word | Simple meaning |
|---|---|
| **NFS** | Network File System: the protocol Linux uses to mount a remote folder. It uses **TCP port 2049** |
| **SMB** | Server Message Block: the protocol Windows uses for file shares (port 445) |
| **Mount** | Attach a remote file system to a local folder, for example `/mnt/efs` |
| **Mount target** | EFS's network card (an IP address) in one subnet of one AZ. Clients connect to it |
| **Access point** | An EFS entry door that forces a folder and a Linux user/group for everyone who uses it |
| **POSIX permissions** | Linux owner, group and `rwx` bits on files. NFS checks them with numeric user IDs (UID/GID) |
| **Throughput** | How many MB per second the file system can read and write |
| **SVM** | Storage virtual machine: a virtual file server inside an FSx for ONTAP file system |
| **Volume / junction path** | ONTAP's data container, and the path (like `/vol1`) where clients mount it |

### What we'll build

```text
            ┌───── EFS file system (Regional) ─────┐
            │   data stored across several AZs     │
            └─────┬─────────────────────────┬──────┘
                  │                         │
          mount target (AZ a)       mount target (AZ b)
          private subnet + SG       private subnet + SG
                  │ TCP 2049                │ TCP 2049
           ┌──────┴──────┐           ┌──────┴──────┐
           │ EC2 / ECS / │           │ EC2 / ECS / │
           │ EKS clients │           │ EKS clients │
           └──────┬──────┘           └─────────────┘
                  │ NFS
           ┌──────▼─────────────────────────┐
           │ FSx for ONTAP: SVM → /vol1     │
           └────────────────────────────────┘
```

### Check yourself

1. Can two EC2 instances in different AZs write to the same EBS volume and the same EFS file system?
2. Which port must the EFS security group allow, and from where?
3. Which FSx type would you pick for Windows home folders?

> **Tip:** Answers: 1) EBS: no, a normal volume belongs to one instance in one AZ. EFS: yes, that's its main job. 2) TCP **2049** (NFS), only from the **clients' security group**. 3) **FSx for Windows File Server** (or FSx for ONTAP if you also need NFS).

## Before you start: variables, network and a test server

> **In simple words:** EFS and FSx live **inside your VPC**, in private subnets. We reuse the VPC from the [VPC guide](#/tool/aws-vpc), create a security group for the clients, and launch one small Linux server to test the mounts.

You need the `demo-vpc` with private subnets `private-a` and `private-b` (with a NAT gateway, so the server can install packages), and the `ec2-ssm-lab-role` instance profile from the [EC2 lab](#/tool/ec2-website). Run these on your laptop (or AWS CloudShell):

```bash
export AWS_REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=demo-vpc --query 'Vpcs[0].VpcId' --output text)
PRIV1=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID Name=tag:Name,Values=private-a \
  --query 'Subnets[0].SubnetId' --output text)
PRIV2=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID Name=tag:Name,Values=private-b \
  --query 'Subnets[0].SubnetId' --output text)
echo "VPC=$VPC_ID PRIV1=$PRIV1 PRIV2=$PRIV2"

# security group for everything that mounts the file systems
CLIENT_SG=$(aws ec2 create-security-group --vpc-id $VPC_ID --group-name storage-clients-sg \
  --description "Clients of EFS and FSx" --query GroupId --output text)

# a small Amazon Linux 2023 test server in a private subnet (reached with Session Manager)
AMI_ID=$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query Parameter.Value --output text)
CLIENT_ID=$(aws ec2 run-instances --image-id $AMI_ID --instance-type t3.micro --subnet-id $PRIV1 \
  --security-group-ids $CLIENT_SG --iam-instance-profile Name=ec2-ssm-lab-role \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=storage-client}]' \
  --query 'Instances[0].InstanceId' --output text)
aws ec2 wait instance-status-ok --instance-ids $CLIENT_ID
echo "Client: $CLIENT_ID"
```

> **Note:** The VPC must have **DNS resolution** and **DNS hostnames** turned on (the VPC guide does this). EFS and FSx clients find the file system by its DNS name.

## Step 1: Create the EFS file system

> **In simple words:** Create the shared drive itself. It has no size: it grows and shrinks as you add and delete files. A **Regional** file system keeps your data in several AZs, so losing one AZ doesn't lose your files.

**Console:** **EFS** console → **Create file system** → **Customize**:
1. **Name:** `my-app-efs`. **File system type:** **Regional**.
2. **Automatic backups:** ticked. **Encryption:** **Enable encryption of data at rest** ticked (default key `aws/elasticfilesystem`, or your own KMS key from the [KMS guide](#/tool/aws-kms)).
3. **Lifecycle management:** keep the defaults (Infrequent Access after 30 days, Archive after 90 days).
4. **Throughput mode:** **Elastic** (the recommended default). **Performance mode:** **General Purpose**.
5. **Next** → network settings (Step 2) → **Next** → file system policy (Step 6, skip for now) → **Create**.

**CLI:**

```bash
FS_ID=$(aws efs create-file-system \
  --creation-token my-app-efs-001 \
  --performance-mode generalPurpose \
  --throughput-mode elastic \
  --encrypted \
  --backup \
  --tags Key=Name,Value=my-app-efs \
  --query FileSystemId --output text)

until [ "$(aws efs describe-file-systems --file-system-id $FS_ID \
  --query 'FileSystems[0].LifeCycleState' --output text)" = "available" ]; do sleep 5; done
echo "EFS ready: $FS_ID"
```

| Setting | Our choice | Why |
|---|---|---|
| `--creation-token` | any unique string | Makes the call safe to retry: the same token never creates a second file system |
| `--performance-mode` | `generalPurpose` | Lowest latency; AWS recommends it for all file systems. It can't be changed later |
| `--throughput-mode` | `elastic` | The console default, but **the CLI and API default is `bursting`**, so set it yourself |
| `--encrypted` | on | Encryption at rest can only be chosen **at creation** |
| `--backup` | on | Daily backups with AWS Backup. From the CLI they are **off** unless you ask (the console turns them on) |

AWS docs: [What is Amazon EFS?](https://docs.aws.amazon.com/efs/latest/ug/whatisefs.html)

## Step 2: Create mount targets, one per AZ

> **In simple words:** A **mount target** is the file system's network card in your VPC. Create **one in each AZ** where you have clients, in a **private subnet**, with a security group that allows **NFS (TCP 2049) only from your clients**. Clients automatically use the mount target in their own AZ.

**Console:** in the create wizard (or later: file system → **Network** tab → **Manage**): **VPC** `demo-vpc`; for each AZ choose the **private** subnet and the security group `efs-sg` (create it first, see below).

**CLI:**

```bash
EFS_SG=$(aws ec2 create-security-group --vpc-id $VPC_ID --group-name efs-sg \
  --description "EFS mount targets: NFS from clients only" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id $EFS_SG \
  --protocol tcp --port 2049 --source-group $CLIENT_SG

for SUBNET in $PRIV1 $PRIV2; do
  aws efs create-mount-target --file-system-id $FS_ID --subnet-id $SUBNET --security-groups $EFS_SG
done

# wait until both mount targets are available
until [ "$(aws efs describe-mount-targets --file-system-id $FS_ID \
  --query 'length(MountTargets[?LifeCycleState==`available`])')" = "2" ]; do sleep 10; done
aws efs describe-mount-targets --file-system-id $FS_ID \
  --query 'MountTargets[].[AvailabilityZoneName,SubnetId,IpAddress,LifeCycleState]' --output table
```

A file system can have only **one mount target per AZ**. A client using a mount target in **another** AZ works, but is slower and pays cross-AZ data transfer (about $0.01/GB each way).

```flow
🖥️ | Client | An EC2 instance, ECS task or EKS pod asks to mount the file system.
🔎 | DNS | The name `fs-….efs.us-east-1.amazonaws.com` points to the mount target in the client's own AZ.
🛡️ | Security group | The mount target's security group must allow TCP 2049 from the client.
🔐 | TLS and policy | The mount helper wraps NFS in TLS; the file system policy can require it.
📁 | Files | The client sees a normal folder, shared with every other client.
```

## Step 3: Mount EFS on EC2

> **In simple words:** Install the small **EFS mount helper** (`amazon-efs-utils`) on the server, then mount with the `tls` option so data is **encrypted on the network**. Add one line to `/etc/fstab` so the folder comes back after a reboot.

Connect to the test server with `aws ssm start-session --target $CLIENT_ID`, then run on the server:

```bash
FS_ID=fs-0123456789abcdef0        # replace with your file system ID

sudo dnf install -y amazon-efs-utils
sudo mkdir -p /mnt/efs
sudo mount -t efs -o tls $FS_ID:/ /mnt/efs

df -hT /mnt/efs                   # type nfs4; with TLS the source shows 127.0.0.1 (a local TLS proxy)
echo "hello from $(hostname)" | sudo tee /mnt/efs/hello.txt
ls -l /mnt/efs
```

Mount the same file system on a second server (in the other AZ) and you'll see `hello.txt` there immediately.

**Mount at every boot:**

```bash
echo "$FS_ID:/ /mnt/efs efs _netdev,noresvport,tls 0 0" | sudo tee -a /etc/fstab
sudo umount /mnt/efs
sudo mount -a && df -h /mnt/efs
```

> **Warning:** Always include `_netdev` in `/etc/fstab` for network file systems. Without it the server may try to mount before the network is up and **stop responding at boot**. Add `nofail` too if the server must boot even when EFS is unreachable.

**Alternative: plain NFS client (no mount helper, no TLS).** Useful on distributions without `amazon-efs-utils`. These are the mount options AWS recommends:

```bash
sudo dnf install -y nfs-utils
sudo mkdir -p /mnt/efs-nfs
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport \
  $FS_ID.efs.us-east-1.amazonaws.com:/ /mnt/efs-nfs
```

| Mount option | Meaning |
|---|---|
| `tls` / `iam` | Encrypt traffic (mount helper only) / identify the client with its IAM role for the file system policy |
| `hard`, `timeo=600`, `retrans=2` | Wait and retry instead of returning errors during short network problems |
| `noresvport` | Use a new source port when reconnecting, so recovery after a network blip is faster |

EFS can't be mounted from Windows instances; use FSx for Windows File Server or FSx for ONTAP (SMB) for Windows.

AWS docs: [EFS mount helper](https://docs.aws.amazon.com/efs/latest/ug/efs-mount-helper.html) · [Recommended NFS mount settings](https://docs.aws.amazon.com/efs/latest/ug/mounting-fs-nfs-mount-settings.html) · [Automatic mounting with /etc/fstab](https://docs.aws.amazon.com/efs/latest/ug/mount-fs-auto-mount-update-fstab.html)

## Step 4: Access points: a private folder per app

> **In simple words:** An **access point** is a labelled door into the file system. Whoever enters through it lands in **one folder** (for example `/my-app`) and acts as **one Linux user** (for example UID 1000), no matter who they are on their own server. It's the easiest way to share one EFS between several apps or containers safely.

**Console:** file system → **Access points** tab → **Create access point** → Name `my-app-ap`, **Root directory path** `/my-app`, **POSIX user** UID `1000`, GID `1000`, **Root directory creation permissions** owner UID `1000`, GID `1000`, permissions `750` → **Create**.

**CLI (on your laptop):**

```bash
AP_ID=$(aws efs create-access-point --file-system-id $FS_ID \
  --posix-user Uid=1000,Gid=1000 \
  --root-directory 'Path=/my-app,CreationInfo={OwnerUid=1000,OwnerGid=1000,Permissions=750}' \
  --tags Key=Name,Value=my-app-ap \
  --query AccessPointId --output text)
echo "Access point: $AP_ID"
```

**Mount through it (on the server):**

```bash
AP_ID=fsap-0123456789abcdef0      # replace with your access point ID
sudo mkdir -p /mnt/my-app
sudo mount -t efs -o tls,accesspoint=$AP_ID $FS_ID:/ /mnt/my-app
sudo touch /mnt/my-app/created-by-root
ls -ln /mnt/my-app                # owner shows 1000 1000, even though you used sudo
```

The client sees only `/my-app` (EFS creates it with the owner and permissions you gave, if it doesn't exist), and every file operation runs as UID/GID 1000. Give each app its own access point (`/app-a`, `/app-b`) on the same file system.

AWS docs: [Working with access points](https://docs.aws.amazon.com/efs/latest/ug/efs-access-points.html)

## Step 5: Throughput modes, storage classes and lifecycle

> **In simple words:** Two money-and-speed choices. **Throughput mode** decides how fast the file system can go and how you pay for that speed. **Storage classes** move files nobody has opened for a while to cheaper storage, automatically.

### Throughput modes

| Mode | How it works | Use it when |
|---|---|---|
| **Elastic** (recommended) | Scales up and down instantly; you pay per GB read and written | Spiky or unknown workloads: most apps |
| **Provisioned** | You choose a fixed MiB/s and pay for it every month (about $6 per MiB/s-month) | Steady, high and predictable throughput |
| **Bursting** (older) | Throughput grows with the data stored (about 50 MiB/s per TiB), plus burst credits | Large file systems with a steady, low load |

Change it later with `aws efs update-file-system --file-system-id $FS_ID --throughput-mode elastic` (some changes are limited to once every 24 hours).

### Storage classes and lifecycle management

| Class | For | Price (us-east-1, approx.) |
|---|---|---|
| **Standard** | Files used often; sub-millisecond latency | $0.30 per GB-month |
| **Infrequent Access (IA)** | Files used a few times a quarter | $0.016 per GB-month + $0.01 per GB read |
| **Archive** | Files used a few times a year or less (needs **Elastic** throughput) | $0.008 per GB-month + $0.03 per GB read |

Lifecycle policies are based on **when a file was last accessed**:

```bash
aws efs put-lifecycle-configuration --file-system-id $FS_ID --lifecycle-policies \
  '[{"TransitionToIA":"AFTER_30_DAYS"},{"TransitionToArchive":"AFTER_90_DAYS"},{"TransitionToPrimaryStorageClass":"AFTER_1_ACCESS"}]'
aws efs describe-lifecycle-configuration --file-system-id $FS_ID
```

`TransitionToPrimaryStorageClass=AFTER_1_ACCESS` moves a file **back to Standard** the first time someone reads it again, so busy files are fast again. IA and Archive bill each file as at least **128 KiB**, so millions of tiny files gain less.

> **Tip:** Watch the CloudWatch metrics `StorageBytes`, `MeteredIOBytes`, `ClientConnections` and (for Bursting) `BurstCreditBalance`. The [CloudWatch guide](#/tool/aws-cloudwatch) shows how to alarm on them.

AWS docs: [EFS performance](https://docs.aws.amazon.com/efs/latest/ug/performance.html) · [Managing storage lifecycle](https://docs.aws.amazon.com/efs/latest/ug/lifecycle-management-efs.html)

## Step 6: Encryption, file system policy and backups

> **In simple words:** Lock it down in three layers: data **encrypted on disk** (chosen at creation), a **file system policy** that refuses any client not using TLS, and **daily backups** so a deleted folder can be restored.

Who can mount is decided by three layers: **security groups** (network), the **file system policy** and IAM (identity), and **POSIX permissions** and access points (files).

**Console:** file system → **File system policy** tab → **Edit** → tick **Enforce in-transit encryption for all clients** → **Save**. (Other options: **Prevent root access by default**, **Enforce read-only access by default**, **Prevent anonymous access**.)

**CLI:** the same policy: allow mounts through mount targets, deny anything without TLS.

```bash
FS_ARN=$(aws efs describe-file-systems --file-system-id $FS_ID --query 'FileSystems[0].FileSystemArn' --output text)

cat > efs-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowMountThroughMountTargets",
      "Effect": "Allow",
      "Principal": {"AWS": "*"},
      "Action": ["elasticfilesystem:ClientMount", "elasticfilesystem:ClientWrite", "elasticfilesystem:ClientRootAccess"],
      "Resource": "$FS_ARN",
      "Condition": {"Bool": {"elasticfilesystem:AccessedViaMountTarget": "true"}}
    },
    {
      "Sid": "DenyWithoutTLS",
      "Effect": "Deny",
      "Principal": {"AWS": "*"},
      "Action": "*",
      "Resource": "$FS_ARN",
      "Condition": {"Bool": {"aws:SecureTransport": "false"}}
    }
  ]
}
EOF
aws efs put-file-system-policy --file-system-id $FS_ID --policy file://efs-policy.json
aws efs describe-file-system-policy --file-system-id $FS_ID
```

Now the plain NFS mount from Step 3 fails with **access denied**, while `-o tls` keeps working. That's the point.

**Backups:**

```bash
aws efs put-backup-policy --file-system-id $FS_ID --backup-policy Status=ENABLED
aws efs describe-backup-policy --file-system-id $FS_ID
# after the first daily backup has run:
aws backup list-recovery-points-by-resource --resource-arn $FS_ARN \
  --query 'RecoveryPoints[].[CreationDate,Status]' --output table
```

The default EFS backup plan runs **daily and keeps backups 35 days**. Restores can bring back the whole file system or single files and folders. For custom schedules, copies to another Region and moving data in with **DataSync**, see the [AWS Backup and DataSync guide](#/tool/aws-backup).

AWS docs: [Creating file system policies](https://docs.aws.amazon.com/efs/latest/ug/create-file-system-policy.html) · [Encrypting data in transit](https://docs.aws.amazon.com/efs/latest/ug/encryption-in-transit.html) · [Backing up EFS](https://docs.aws.amazon.com/efs/latest/ug/awsbackup.html)

## Step 7: EFS for containers: ECS and EKS

> **In simple words:** Containers lose their files when they stop. Mount EFS into them and the data **survives restarts and is shared** by every copy of the task or pod. Use **one access point per app** and **TLS**.

### ECS (EC2 or Fargate)

Add a `volumes` entry with `efsVolumeConfiguration` and a `mountPoints` entry in the container (see the [ECS guide](#/tool/aws-ecs) for the rest of the task definition):

```json
{
  "family": "my-app",
  "containerDefinitions": [
    {
      "name": "web",
      "image": "public.ecr.aws/nginx/nginx:latest",
      "essential": true,
      "mountPoints": [
        { "sourceVolume": "shared-data", "containerPath": "/usr/share/nginx/html", "readOnly": false }
      ]
    }
  ],
  "volumes": [
    {
      "name": "shared-data",
      "efsVolumeConfiguration": {
        "fileSystemId": "fs-0123456789abcdef0",
        "transitEncryption": "ENABLED",
        "authorizationConfig": { "accessPointId": "fsap-0123456789abcdef0", "iam": "ENABLED" }
      }
    }
  ]
}
```

| Rule | Why |
|---|---|
| With an access point, leave out `rootDirectory` (or set `/`) | The access point already decides the folder |
| `transitEncryption: ENABLED` | Required when you use an access point or `iam: ENABLED` |
| `iam: ENABLED` | The mount uses the **task role**. If your file system policy allows only specific roles, give that role `elasticfilesystem:ClientMount` and `elasticfilesystem:ClientWrite` |
| Security groups | The EFS security group must allow 2049 from the **task's** security group |

### EKS (EFS CSI driver, briefly)

The **Amazon EFS CSI driver** lets pods use EFS as a `PersistentVolume` with `ReadWriteMany` (many pods, many nodes). Install it as the EKS add-on `aws-efs-csi-driver`, and give its service account `efs-csi-controller-sa` (namespace `kube-system`) an IAM role with the AWS managed policy **`AmazonEFSCSIDriverPolicy`** (EKS Pod Identity is the suggested way):

```bash
CLUSTER=my-cluster
aws eks create-pod-identity-association --cluster-name $CLUSTER --namespace kube-system \
  --service-account efs-csi-controller-sa \
  --role-arn arn:aws:iam::$ACCOUNT_ID:role/AmazonEKS_EFS_CSI_DriverRole
aws eks create-addon --cluster-name $CLUSTER --addon-name aws-efs-csi-driver
```

The role must trust `pods.eks.amazonaws.com` and have `AmazonEFSCSIDriverPolicy` attached; the [IAM guide](#/tool/aws-iam) shows how to create roles.

With **dynamic provisioning**, every new claim gets its own access point (its own folder) on one shared file system:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: fs-0123456789abcdef0
  directoryPerms: "700"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-data
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: efs-sc
  resources:
    requests:
      storage: 5Gi        # required by Kubernetes, ignored by EFS (no size limit)
```

Allow TCP 2049 from the **node security group** to the EFS security group. Pods on **Fargate** mount EFS without installing the driver, but only with static provisioning. Cluster setup is in the [EKS guide](#/tool/eks-cluster).

AWS docs: [EFS in ECS task definitions](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/specify-efs-config.html) · [EFS CSI driver on EKS](https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html)

## The Amazon FSx family

> **In simple words:** EFS is one product with one protocol (NFS). **FSx** is a family of **well-known file systems run by AWS for you**: Windows, Lustre, NetApp ONTAP and OpenZFS. You pick the one whose features and protocols your app already expects.

| FSx type | Protocols | Typical use |
|---|---|---|
| **FSx for Windows File Server** | SMB | Windows apps, home folders and shared drives, joined to Active Directory |
| **FSx for Lustre** | Lustre client (Linux) | HPC, ML training, video rendering; can link to an S3 bucket |
| **FSx for NetApp ONTAP** | NFS, SMB, iSCSI, NVMe/TCP | Mixed Linux and Windows access, moving from on-premises NetApp, snapshots, clones and SnapMirror |
| **FSx for OpenZFS** | NFS | Moving Linux or ZFS file servers, very low latency, snapshots and clones |

```compare
📁 Amazon EFS | 🗄️ FSx for NetApp ONTAP
Serverless: no size to choose, grows and shrinks by itself | You provision SSD capacity and throughput up front
Pay for GB stored and data read and written | Pay every hour for provisioned SSD and throughput, even when idle
NFS only: Linux (and macOS) clients, not Windows | NFS, SMB, iSCSI and NVMe/TCP: Linux, Windows and macOS
Regional (multi-AZ) or One Zone | Single-AZ or Multi-AZ, first or second generation
Managed with AWS APIs only | AWS APIs plus the full NetApp ONTAP CLI and REST API
Lifecycle to IA and Archive classes | Tiering to an elastic capacity pool, plus dedupe and compression
```

AWS: [Help me choose an FSx file system](https://aws.amazon.com/fsx/when-to-choose-fsx/) · [FSx for Windows](https://docs.aws.amazon.com/fsx/latest/WindowsGuide/what-is.html) · [FSx for Lustre](https://docs.aws.amazon.com/fsx/latest/LustreGuide/what-is.html) · [FSx for OpenZFS](https://docs.aws.amazon.com/fsx/latest/OpenZFSGuide/what-is-fsx.html)

## FSx for NetApp ONTAP: the building blocks

> **In simple words:** Think of an ONTAP **file system** as a **storage building**, each **SVM** as a **company renting a floor** with its own address and admin, and each **volume** as a **room** on that floor. Clients reach a room by the SVM's address plus the room's **junction path**, like `svm-….fsx.us-east-1.amazonaws.com:/vol1`.

```text
 FSx for ONTAP file system  (SSD + throughput, admin: fsxadmin)
 ├── SVM "svm1"   (NFS/SMB/iSCSI endpoints, admin: vsadmin)
 │     ├── volume vol1   junction path /vol1
 │     └── volume logs   junction path /logs
 └── SVM "svm2"   (another team or app, separate admin)
       └── volume data   junction path /data
 Capacity pool: cold blocks move here automatically (cheap)
```

| Piece | What it is |
|---|---|
| **File system** | The HA pair of file servers, with **SSD storage capacity** (from 1,024 GiB per HA pair) and **throughput capacity** (MBps) |
| **Deployment type** | `SINGLE_AZ_1` / `MULTI_AZ_1` (first generation, 128 to 4,096 MBps); `SINGLE_AZ_2` (second generation, up to 12 HA pairs, from 1,536 MBps per pair) and `MULTI_AZ_2` (from 384 MBps) |
| **Multi-AZ** | A standby file server in a second AZ with automatic failover. Needs two subnets and the route tables of your clients |
| **SVM** | A virtual file server with its own endpoints, admin user (`vsadmin`) and optional Active Directory join for SMB |
| **Volume** | Where data lives. **FlexVol** (normal) or **FlexGroup** (spread over HA pairs). Type `RW` (read/write) or `DP` (SnapMirror target) |
| **Junction path** | The mount path of the volume inside the SVM, for example `/vol1` |
| **Security style** | `UNIX` (Linux permissions, for NFS), `NTFS` (Windows ACLs, for SMB) or `MIXED` |
| **Capacity pool** | Elastic, cheaper storage (about $0.022 per GB-month Single-AZ) where cold data is tiered |
| **Storage efficiency** | Deduplication, compression and compaction: you store less than you write |

### Admin users and passwords

| User | Scope | Password set by |
|---|---|---|
| `fsxadmin` | The whole file system (ONTAP CLI over SSH, REST API over HTTPS) | `FsxAdminPassword` when creating the file system |
| `vsadmin` | One SVM only | `SvmAdminPassword` when creating the SVM |

Both passwords are 8 to 50 characters. **Never type them in scripts or Terraform code:** generate them and keep them in **Secrets Manager**, as in [Step 1 of the Secrets Manager guide](#/tool/aws-secrets/step-1-create-a-secret).

> **Cost:** ONTAP charges for **SSD GB-months, throughput MBps-months, SSD IOPS above 3 per GB, capacity pool GB used and requests, and backups**. In us-east-1 the Single-AZ first-generation prices are about $0.125 per GB-month (SSD) and $0.72 per MBps-month; Multi-AZ about $0.25 and $1.20. Second-generation file systems start at much higher throughput, so they cost much more.

AWS docs: [What is FSx for ONTAP?](https://docs.aws.amazon.com/fsx/latest/ONTAPGuide/what-is-fsx-ontap.html) · [Deployment options](https://docs.aws.amazon.com/fsx/latest/ONTAPGuide/high-availability-AZ.html) · [Managing SVMs](https://docs.aws.amazon.com/fsx/latest/ONTAPGuide/managing-svms.html) · [Managing volumes](https://docs.aws.amazon.com/fsx/latest/ONTAPGuide/managing-volumes.html)

## Step 8: Create an FSx for ONTAP file system, SVM and volume

> **In simple words:** Store the two admin passwords, open the NFS ports to your clients, then create the three pieces in order: **file system → SVM → volume**. The file system takes the longest (often 20 minutes or more).

**Console:** **FSx** console → **Create file system** → **Amazon FSx for NetApp ONTAP** → **Standard create**:
1. **Name** `my-app-ontap`, **Deployment type** **Single-AZ** (first generation), **SSD storage capacity** `1024` GiB, **Provisioned SSD IOPS** automatic, **Throughput capacity** `128` MBps.
2. **Network:** `demo-vpc`, security group `fsx-ontap-sg`, subnet `private-a`.
3. **Security & encryption:** KMS key (default is fine), **File system administrative password**: paste the one from Secrets Manager.
4. **Default storage virtual machine:** name `svm1`, **SVM administrative password**, root volume security style **Unix (Linux)**.
5. **Default volume:** name `vol1`, junction path `/vol1`, size, **Storage efficiency** enabled, **Capacity pool tiering policy** **Auto**.
6. **Backup and maintenance:** keep daily backups (default 30 days) → **Next** → **Create file system**.

**CLI.** First the passwords and the security group (ports from the FSx for ONTAP docs: NFS plus SSH/HTTPS for administration):

```bash
FSX_ADMIN_PASS=$(aws secretsmanager get-random-password --password-length 20 \
  --exclude-punctuation --query RandomPassword --output text)
SVM_ADMIN_PASS=$(aws secretsmanager get-random-password --password-length 20 \
  --exclude-punctuation --query RandomPassword --output text)

aws secretsmanager create-secret --name my-app/fsx/fsxadmin \
  --secret-string "{\"username\":\"fsxadmin\",\"password\":\"$FSX_ADMIN_PASS\"}"
aws secretsmanager create-secret --name my-app/fsx/vsadmin \
  --secret-string "{\"username\":\"vsadmin\",\"password\":\"$SVM_ADMIN_PASS\"}"

FSX_SG=$(aws ec2 create-security-group --vpc-id $VPC_ID --group-name fsx-ontap-sg \
  --description "FSx for ONTAP: NFS and admin from clients" --query GroupId --output text)
for P in 111 635 2049 4045 4046; do      # portmapper, mount, nfs, lock, status
  aws ec2 authorize-security-group-ingress --group-id $FSX_SG --protocol tcp --port $P --source-group $CLIENT_SG
  aws ec2 authorize-security-group-ingress --group-id $FSX_SG --protocol udp --port $P --source-group $CLIENT_SG
done
aws ec2 authorize-security-group-ingress --group-id $FSX_SG --protocol udp --port 4049 --source-group $CLIENT_SG
for P in 22 443; do                      # ONTAP CLI (SSH) and REST API
  aws ec2 authorize-security-group-ingress --group-id $FSX_SG --protocol tcp --port $P --source-group $CLIENT_SG
done
```

Then the file system (the billing clock starts here):

```bash
FSX_ID=$(aws fsx create-file-system --file-system-type ONTAP \
  --storage-capacity 1024 --storage-type SSD \
  --subnet-ids $PRIV1 --security-group-ids $FSX_SG \
  --ontap-configuration "DeploymentType=SINGLE_AZ_1,ThroughputCapacity=128,FsxAdminPassword=$FSX_ADMIN_PASS,AutomaticBackupRetentionDays=7" \
  --tags Key=Name,Value=my-app-ontap \
  --query FileSystem.FileSystemId --output text)

until [ "$(aws fsx describe-file-systems --file-system-ids $FSX_ID \
  --query 'FileSystems[0].Lifecycle' --output text)" = "AVAILABLE" ]; do sleep 60; done
echo "File system ready: $FSX_ID"
```

The SVM, then the volume:

```bash
SVM_ID=$(aws fsx create-storage-virtual-machine --file-system-id $FSX_ID --name svm1 \
  --root-volume-security-style UNIX --svm-admin-password "$SVM_ADMIN_PASS" \
  --query StorageVirtualMachine.StorageVirtualMachineId --output text)
until [ "$(aws fsx describe-storage-virtual-machines --storage-virtual-machine-ids $SVM_ID \
  --query 'StorageVirtualMachines[0].Lifecycle' --output text)" = "CREATED" ]; do sleep 20; done

VOL_ID=$(aws fsx create-volume --volume-type ONTAP --name vol1 \
  --ontap-configuration "StorageVirtualMachineId=$SVM_ID,JunctionPath=/vol1,SizeInBytes=107374182400,SecurityStyle=UNIX,StorageEfficiencyEnabled=true,OntapVolumeType=RW,SnapshotPolicy=default,TieringPolicy={Name=AUTO,CoolingPeriod=31}" \
  --query Volume.VolumeId --output text)
until [ "$(aws fsx describe-volumes --volume-ids $VOL_ID \
  --query 'Volumes[0].Lifecycle' --output text)" = "CREATED" ]; do sleep 15; done

aws fsx describe-storage-virtual-machines --storage-virtual-machine-ids $SVM_ID \
  --query 'StorageVirtualMachines[0].Endpoints.Nfs.DNSName' --output text
aws fsx describe-file-systems --file-system-ids $FSX_ID \
  --query 'FileSystems[0].OntapConfiguration.Endpoints.Management.DNSName' --output text
unset FSX_ADMIN_PASS SVM_ADMIN_PASS
```

| Setting | Our choice | Note |
|---|---|---|
| `DeploymentType` | `SINGLE_AZ_1` | Cheapest. Production usually uses `MULTI_AZ_1` or `MULTI_AZ_2` (two subnets, `PreferredSubnetId`, `RouteTableIds`) |
| Storage / throughput | `1024` GiB / `128` MBps | The smallest first-generation values. SSD can be increased later, not decreased |
| Volume `--name` | `vol1` | Letters, numbers and `_` only (no `-`) |
| `SizeInBytes` | 100 GiB | The volume's size limit (thin: it uses SSD only for data written). The older `SizeInMegabytes` is deprecated |
| `TieringPolicy` | `AUTO`, 31 days | Console default is **Auto**; the **API default is `SNAPSHOT_ONLY`** |

AWS docs: [Creating volumes](https://docs.aws.amazon.com/fsx/latest/ONTAPGuide/creating-volumes.html) · [Security groups for FSx for ONTAP](https://docs.aws.amazon.com/fsx/latest/ONTAPGuide/limit-access-security-groups.html)

## Step 9: Mount the ONTAP volume over NFS

> **In simple words:** On the Linux server, mount **SVM NFS endpoint + junction path** onto a local folder. It works like any NFS server. Use the **DNS name**, not an IP, and keep the default `hard` mount so a failover just pauses I/O instead of breaking it.

On the test server (Session Manager), with the DNS name printed in Step 8:

```bash
SVM_DNS=svm-0123456789abcdef0.fs-0123456789abcdef0.fsx.us-east-1.amazonaws.com   # replace

sudo dnf install -y nfs-utils
sudo mkdir -p /fsx
sudo mount -t nfs $SVM_DNS:/vol1 /fsx
mount | grep /fsx                 # shows the NFS version that was negotiated
sudo mkdir /fsx/reports && echo "ok" | sudo tee /fsx/reports/test.txt
df -h /fsx

# mount at every boot
echo "$SVM_DNS:/vol1 /fsx nfs defaults,_netdev 0 0" | sudo tee -a /etc/fstab
```

**Look inside with the ONTAP CLI** (optional): from a host allowed on port 22, run `ssh fsxadmin@` followed by the management DNS name from Step 8, and type the `fsxadmin` password from Secrets Manager:

```text
::> volume show -vserver svm1 -fields junction-path,size,tiering-policy
::> vserver export-policy rule show -vserver svm1
::> volume snapshot create -vserver svm1 -volume vol1 -snapshot before-change
```

The **export policy** is ONTAP's list of which clients may mount the SVM's volumes over NFS. **SMB** (Windows) needs the SVM joined to Active Directory and port 445; **iSCSI** shows a LUN as a local disk (port 3260).

AWS docs: [Mounting volumes on Linux clients](https://docs.aws.amazon.com/fsx/latest/ONTAPGuide/attach-linux-client.html)

## Step 10: Snapshots, backups, tiering and SnapMirror

> **In simple words:** ONTAP protects data in layers. **Snapshots** are instant "photos" of a volume kept on the same file system (great for "I deleted a file 2 hours ago"). **Backups** are full copies stored separately by AWS. **Tiering** moves cold data to cheap storage. **SnapMirror** copies volumes to another file system, even in another Region.

| Feature | What it does | How |
|---|---|---|
| **Snapshots** | The `default` policy keeps up to 6 hourly, 2 daily and 2 weekly snapshots | Users restore files themselves from the hidden `.snapshot` folder: `ls /fsx/.snapshot/` |
| **Backups** | Daily automatic backups per volume (retention 0 to 90 days, default 30), plus on-demand | `aws fsx create-backup --volume-id $VOL_ID`, or AWS Backup plans |
| **Tiering policy** | `AUTO`: cold data after the cooling period (2 to 183 days); `SNAPSHOT_ONLY`; `ALL`; `NONE` | `aws fsx update-volume --volume-id $VOL_ID --ontap-configuration 'TieringPolicy={Name=AUTO,CoolingPeriod=14}'` |
| **SnapMirror** | Block-level replication of volumes to another ONTAP system (other Region, or on-premises NetApp) | ONTAP CLI: peer the clusters and SVMs, create a `DP` volume, create the SnapMirror relationship |

```bash
aws fsx create-backup --volume-id $VOL_ID --tags Key=Name,Value=vol1-manual
aws fsx describe-backups --filters Name=volume-id,Values=$VOL_ID \
  --query 'Backups[].[BackupId,Type,Lifecycle,CreationTime]' --output table
aws fsx describe-volumes --volume-ids $VOL_ID \
  --query 'Volumes[0].OntapConfiguration.[JunctionPath,TieringPolicy.Name,SnapshotPolicy]' --output table
```

> **Note:** The data in a deleted FSx file system can't be recovered. Automatic backups are deleted with it; **on-demand backups stay** (and keep costing) until you delete them.

AWS docs: [Snapshots](https://docs.aws.amazon.com/fsx/latest/ONTAPGuide/snapshots-ontap.html) · [Volume storage and tiering](https://docs.aws.amazon.com/fsx/latest/ONTAPGuide/volume-storage-capacity.html) · [SnapMirror replication](https://docs.aws.amazon.com/fsx/latest/ONTAPGuide/scheduled-replication.html)

## Troubleshooting

> **In simple words:** Almost every mount problem is **network** (security group, wrong subnet or AZ, DNS) or **permissions** (file system policy, POSIX owner, export policy). Check the network first, then who you are on the file system.

| Problem | Likely cause | Fix |
|---|---|---|
| EFS `mount` hangs, then "Connection timed out" | EFS security group doesn't allow TCP 2049 from the client's SG; network ACL blocks 2049; client in a different VPC | Add the 2049 rule from the client SG; check the NACL; use the same VPC (or peering plus the mount target IP) |
| "Failed to resolve server fs-….efs…" | VPC DNS hostnames/resolution off; **no mount target in the client's AZ**; mount target still creating | Turn on both VPC DNS settings; add a mount target in that AZ; wait for `available` |
| `unknown filesystem type 'efs'` | `amazon-efs-utils` not installed | `sudo dnf install -y amazon-efs-utils` |
| "access denied by server while mounting" (EFS) | File system policy requires TLS or IAM; access point or IAM role not allowed | Mount with `-o tls` (and `iam` if needed); check the policy and the role |
| "Permission denied" when writing | Files owned by another UID/GID; the app runs as a non-root user | Use an **access point** with a POSIX user, or `chown` the folder once to the app's UID |
| Server stuck at boot after editing `/etc/fstab` | `_netdev` missing | Add `_netdev` (and `nofail`); fix the file from the EC2 serial console or by detaching the root volume |
| ECS task fails with `ResourceInitializationError` mentioning EFS | Task SG can't reach 2049; no mount target in the task's subnet AZ; access point used without `transitEncryption` | Fix SG and mount targets; set `transitEncryption: ENABLED` |
| EKS PVC stays `Pending` | CSI driver missing IAM permissions; wrong `fileSystemId` | `kubectl describe pvc`; check the add-on's role has `AmazonEFSCSIDriverPolicy` |
| EFS slow after a few hours | **Bursting** mode out of burst credits | Switch to **Elastic** throughput |
| ONTAP mount hangs | `fsx-ontap-sg` missing NFS ports (111, 635, 2049…); Multi-AZ: client's route table not in `RouteTableIds` | Add the ports from Step 8; add the client subnets' route tables to the file system |
| ONTAP "No such file or directory" or "access denied" on mount | Wrong junction path; volume has no junction path (for example a `DP` volume); export policy doesn't include the client | `aws fsx describe-volumes` to check `JunctionPath`; ONTAP CLI `vserver export-policy rule show` |
| ONTAP volume full | Volume size limit reached, or SSD tier full | Increase `SizeInBytes`; increase SSD; use `AUTO` tiering |
| Can't delete EFS / FSx | EFS mount targets still exist / ONTAP volumes or SVMs still exist | Delete in the order shown in Clean up |

AWS docs: [Troubleshooting EFS mounts](https://docs.aws.amazon.com/efs/latest/ug/troubleshooting-efs-mounting.html) · [Troubleshooting FSx for ONTAP](https://docs.aws.amazon.com/fsx/latest/ONTAPGuide/troubleshooting.html)

## Clean up

> **In simple words:** Delete from the inside out. **EFS:** access points and mount targets first, then the file system. **FSx for ONTAP:** volumes, then the SVM, then the file system, and then any on-demand backups. Delete FSx first: it's the one billing by the hour.

On the test server, unmount first: `sudo umount /fsx /mnt/my-app /mnt/efs` and remove the lines you added to `/etc/fstab`. Then on your laptop:

```bash
# FSx for ONTAP: volume -> SVM -> file system -> on-demand backups
aws fsx delete-volume --volume-id $VOL_ID --ontap-configuration SkipFinalBackup=true
while aws fsx describe-volumes --volume-ids $VOL_ID >/dev/null 2>&1; do sleep 20; done
aws fsx delete-storage-virtual-machine --storage-virtual-machine-id $SVM_ID
while aws fsx describe-storage-virtual-machines --storage-virtual-machine-ids $SVM_ID >/dev/null 2>&1; do sleep 20; done
aws fsx delete-file-system --file-system-id $FSX_ID
for B in $(aws fsx describe-backups --filters Name=file-system-id,Values=$FSX_ID \
  --query 'Backups[?Type==`USER_INITIATED`].BackupId' --output text); do
  aws fsx delete-backup --backup-id $B
done
while aws fsx describe-file-systems --file-system-ids $FSX_ID >/dev/null 2>&1; do sleep 30; done

# EFS: access points and mount targets -> file system
aws efs delete-access-point --access-point-id $AP_ID
for MT in $(aws efs describe-mount-targets --file-system-id $FS_ID --query 'MountTargets[].MountTargetId' --output text); do
  aws efs delete-mount-target --mount-target-id $MT
done
while [ "$(aws efs describe-mount-targets --file-system-id $FS_ID --query 'length(MountTargets)')" != "0" ]; do sleep 10; done
aws efs delete-file-system --file-system-id $FS_ID

# secrets, test server, security groups
aws secretsmanager delete-secret --secret-id my-app/fsx/fsxadmin --force-delete-without-recovery
aws secretsmanager delete-secret --secret-id my-app/fsx/vsadmin --force-delete-without-recovery
aws ec2 terminate-instances --instance-ids $CLIENT_ID
aws ec2 wait instance-terminated --instance-ids $CLIENT_ID
for SG in $FSX_SG $EFS_SG $CLIENT_SG; do aws ec2 delete-security-group --group-id $SG; done
rm -f efs-policy.json
```

If EFS automatic backups already ran, the recovery points stay in the default EFS backup vault until they expire (35 days). That vault blocks deleting them by default; see the [AWS Backup guide](#/tool/aws-backup) if you want them gone sooner. In real projects, create all of this with **Terraform** (see the [Terraform guide](#/tool/terraform)) and keep the passwords in Secrets Manager.

## Lab and cheat sheet

> **In simple words:** Practice time: build a shared EFS folder, prove two servers see the same files, lock it down, then try FSx for ONTAP for one hour and delete it.

1. Create an EFS file system with **Elastic** throughput, encryption and backups, and mount targets in two private subnets.
2. Launch two servers in different AZs, mount EFS with `-o tls` on both, and write a file on one that you read on the other.
3. Add the `/etc/fstab` line, reboot one server, and check the folder is mounted again.
4. Create an access point for `/my-app` with UID 1000, mount through it, and check with `ls -ln` who owns new files.
5. Enforce TLS with the file system policy, then try the plain NFS mount: it must be denied.
6. **Break it:** remove the 2049 rule from `efs-sg` and watch a new mount hang. Put it back.
7. Set a lifecycle policy (IA after 30 days, Archive after 90) and read it back.
8. Create an FSx for ONTAP Single-AZ file system, an SVM with `UNIX` security style and a volume `/vol1`, mount it, and look at `/fsx/.snapshot` after an hour.
9. Clean up everything, FSx first, and confirm `aws fsx describe-file-systems` and `aws efs describe-file-systems` show nothing from the lab.

### Cheat sheet

| Task | Command |
|---|---|
| Create EFS | `aws efs create-file-system --creation-token T --throughput-mode elastic --encrypted --backup` |
| Mount target | `aws efs create-mount-target --file-system-id FS --subnet-id S --security-groups SG` |
| Mount with TLS | `sudo mount -t efs -o tls FS:/ /mnt/efs` |
| fstab line | `FS:/ /mnt/efs efs _netdev,noresvport,tls 0 0` |
| Access point | `aws efs create-access-point --file-system-id FS --posix-user Uid=1000,Gid=1000 --root-directory 'Path=/app'` |
| Change throughput mode | `aws efs update-file-system --file-system-id FS --throughput-mode elastic` |
| Lifecycle | `aws efs put-lifecycle-configuration --file-system-id FS --lifecycle-policies '[{"TransitionToIA":"AFTER_30_DAYS"}]'` |
| Enforce TLS | `aws efs put-file-system-policy --file-system-id FS --policy file://efs-policy.json` |
| Turn on backups | `aws efs put-backup-policy --file-system-id FS --backup-policy Status=ENABLED` |
| Create ONTAP file system | `aws fsx create-file-system --file-system-type ONTAP --storage-capacity 1024 --subnet-ids S --ontap-configuration DeploymentType=SINGLE_AZ_1,ThroughputCapacity=128` |
| Create SVM | `aws fsx create-storage-virtual-machine --file-system-id FSX --name svm1 --root-volume-security-style UNIX` |
| Create volume | `aws fsx create-volume --volume-type ONTAP --name vol1 --ontap-configuration StorageVirtualMachineId=SVM,JunctionPath=/vol1,SizeInBytes=N,StorageEfficiencyEnabled=true` |
| NFS endpoint | `aws fsx describe-storage-virtual-machines --query 'StorageVirtualMachines[].Endpoints.Nfs.DNSName'` |
| Mount ONTAP volume | `sudo mount -t nfs SVM_DNS:/vol1 /fsx` |
| On-demand backup | `aws fsx create-backup --volume-id VOL` |
| Delete ONTAP | `delete-volume` → `delete-storage-virtual-machine` → `delete-file-system` |
