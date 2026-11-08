# Amazon RDS and Aurora: Managed Databases

Amazon **RDS** (Relational Database Service) runs databases such as **PostgreSQL**, **MySQL** and **SQL Server** for you: AWS installs, patches, backs up and fails over the server, and you look after your tables, users and queries. **Aurora** is AWS's own cloud-built engine, compatible with PostgreSQL and MySQL. This guide explains the choices (engines, Multi-AZ, read replicas, Aurora, Serverless), then builds a small, private and encrypted PostgreSQL database step by step, with the **console clicks** and the matching **AWS CLI** commands.

> **Cost:** A `db.t4g.micro` PostgreSQL instance costs about **$0.016/hour** (about $12/month) in us-east-1, **double for Multi-AZ**. gp3 storage is about **$0.115 per GB-month** (20 GB is about $2.30/month). Backup storage is **free up to the size of your database storage** in the Region, then about $0.095 per GB-month. A secret in Secrets Manager adds $0.40/month. New accounts get AWS credits (see [Create your AWS account](#/tool/aws-account)). See [RDS pricing](https://aws.amazon.com/rds/pricing/) and [Aurora pricing](https://aws.amazon.com/rds/aurora/pricing/).

## Start here: managed databases in simple words

> **In simple words:** Running a database yourself on a server is like **owning a house**: you fix the roof, the pipes and the locks. **RDS** is like a **serviced apartment**: the building staff handle repairs, security and the spare key, and you only arrange your own furniture (your data, tables and users).

### The apartment comparison

| Everyday life | Amazon RDS |
|---|---|
| A serviced apartment in a big building | A **DB instance**: one managed database server |
| The building staff who repair things at night | **Maintenance window**: AWS patches during a time you choose |
| A copy of your keys kept by the front desk | **Automated backups** and **snapshots** |
| A second, identical apartment ready if yours floods | **Multi-AZ** standby in another data center |
| Extra reading rooms that show the same newspaper | **Read replicas**: read-only copies |
| The building's private corridor (no street door) | A **private subnet** with no public access |
| The door lock that opens only for your staff | A **security group** allowing the app servers only |
| The safe where the master key lives | **Secrets Manager** holding the master password |

### Who does what

```compare
🏠 Database on EC2 (you run it) | 🏢 Amazon RDS (AWS runs it)
You install and patch the OS and the database | AWS installs and patches both, in your maintenance window
You script backups and test restores | Automated daily backups plus point-in-time restore to any second
You build replication and failover | Multi-AZ: one setting, automatic failover
You watch disks and grow them by hand | Storage autoscaling grows the disk for you
Full OS access, any version, any extension | No OS login; only supported versions and extensions
Good when you need full control | Good for most apps: less work, fewer 3 a.m. pages
```

Both ways, **you** still own the schema, users, permissions, queries, indexes and the size of the server.

### The journey in this guide

```flow
🧭 | Choose | Pick the engine, instance class, storage and high-availability option.
🔒 | Network | Private subnets, a DB subnet group, and a security group that only trusts the app.
🐘 | Create | A small encrypted PostgreSQL instance, password stored in Secrets Manager.
🔌 | Connect | From an EC2 instance, or from your laptop through Session Manager.
💾 | Protect | Backups, point-in-time restore, snapshots, copies to another Region.
📈 | Operate | Maintenance windows, upgrades, metrics, alarms and Database Insights.
🧹 | Clean up | Turn off deletion protection and delete everything you created.
```

### Key words

| Word | Simple meaning |
|---|---|
| **DB instance** | One managed database server (CPU, memory, disk) running one engine |
| **Engine** | The database software: PostgreSQL, MySQL, MariaDB, SQL Server, Oracle, Db2 |
| **Instance class** | The server size, e.g. `db.t4g.micro` or `db.r7g.large` |
| **Endpoint** | The DNS name your app connects to, e.g. `my-app-db.xxxx.us-east-1.rds.amazonaws.com` |
| **DB subnet group** | The list of subnets (in at least two AZs) where RDS may place the database |
| **Parameter group** | The database's settings file (`max_connections`, logging and so on) |
| **Multi-AZ** | A standby copy in another Availability Zone that takes over automatically |
| **Read replica** | A read-only copy that you send reporting or read traffic to |
| **Snapshot** | A saved copy of the whole database at one moment |
| **Aurora cluster** | Aurora's design: one writer, up to 15 readers, all sharing one storage volume |

### What we'll build

```text
 Laptop
   │ Session Manager port forwarding (no open ports)
   ▼
 VPC demo-vpc: private subnets only
 ┌──────────────────────────────────────────────────┐
 │ [ app EC2 ]  app-sg                              │
 │      │ TCP 5432, allowed only from app-sg        │
 │      ▼                                           │
 │ [ my-app-db ]  db-sg   PostgreSQL, gp3, encrypted│
 │ subnet group: private-a (AZ a), private-b (AZ b) │
 └──────────────────────────────────────────────────┘
   password: Secrets Manager    alarms: CloudWatch
```

### Check yourself

1. Name two jobs AWS does for you with RDS, and two jobs you still do.
2. Why should a database never be reachable from the internet?
3. What is the difference between Multi-AZ and a read replica?

> **Tip:** Answers: 1) AWS patches, backs up, fails over and replaces broken hardware; you design tables, manage users, tune queries and pick the size. 2) Anyone could try passwords or exploits against it; only your app servers need to reach it. 3) Multi-AZ is a **standby for failover** (you can't read from it on a Multi-AZ instance deployment); a read replica is a **readable copy** for extra read traffic.

## Engines, instance classes and storage

> **In simple words:** Three choices decide what you get and what you pay: the **engine** (which database software), the **instance class** (how much CPU and memory) and the **storage** (how much disk and how fast).

### Engines

| Engine | Default port | Good for |
|---|---|---|
| **RDS for PostgreSQL** | 5432 | Most new apps; rich SQL, JSON, extensions |
| **RDS for MySQL** | 3306 | Web apps and frameworks built around MySQL |
| **RDS for MariaDB** | 3306 | A community fork of MySQL |
| **RDS for SQL Server** | 1433 | .NET and Microsoft-based apps (licence included in the price) |
| **RDS for Oracle** | 1521 | Existing Oracle apps |
| **RDS for Db2** | 50000 | Existing IBM Db2 apps |
| **Aurora PostgreSQL / Aurora MySQL** | 5432 / 3306 | High availability and scale, cloud-native storage (see the Aurora section) |

> **Tip:** No strong reason to choose otherwise? Use **PostgreSQL** (on RDS or Aurora). It's open source, so there's no licence cost, and most tools support it.

### Instance classes

| Family | Example | Use it for |
|---|---|---|
| **Burstable** (`db.t4g`, `db.t3`) | `db.t4g.micro`, `db.t4g.medium` | Labs, dev and small apps. CPU can **burst** using credits; watch `CPUCreditBalance` |
| **General purpose** (`db.m7g`, ...) | `db.m7g.large` | Balanced production workloads |
| **Memory optimized** (`db.r7g`, ...) | `db.r7g.large` | Large databases that need lots of cache |
| **Aurora Serverless** | `db.serverless` | Aurora capacity that scales up and down by itself |

The `g` in `t4g`, `m7g` and `r7g` means **AWS Graviton** (ARM) processors, which are usually cheaper than the Intel/AMD equivalents. You can change the class later with a short restart.

### Storage

| Type | What you get | When |
|---|---|---|
| **gp3** (General Purpose SSD) | Baseline **3,000 IOPS and 125 MiB/s**; for PostgreSQL, MySQL, MariaDB and Db2, **12,000 IOPS and 500 MiB/s from 400 GiB** | The default for almost everything |
| **io2 Block Express** (Provisioned IOPS) | You choose (and pay for) a fixed IOPS number | Busy production databases that need steady, high I/O |
| **Aurora cluster volume** | Managed by Aurora; grows automatically | Only with Aurora |

**Storage autoscaling:** set a **maximum storage threshold** and RDS grows the disk when free space stays at or below **10%** for at least **5 minutes**. Each step adds the biggest of 10 GiB, 10% of current storage, or the growth predicted for the next 7 hours. After a storage change, the disk is "optimizing" and can't change again for **at least 6 hours**.

> **Warning:** RDS storage can **grow but never shrink**. Start small (20 GiB) and let autoscaling grow it.

AWS docs: [What is Amazon RDS?](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Welcome.html) · [DB instance storage](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Storage.html) · [Storage autoscaling](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PIOPS.Autoscaling.html)

## High availability: Multi-AZ vs read replicas

> **In simple words:** **Multi-AZ** keeps a spare copy in another data center so the database survives a failure (it's about **staying up**). **Read replicas** are extra copies you can **read from**, to share the load (they're about **scaling reads**). Production databases usually have Multi-AZ; some also add replicas.

| | **Multi-AZ DB instance** | **Multi-AZ DB cluster** | **Read replica** |
|---|---|---|---|
| Shape | 1 primary + 1 standby in another AZ | 1 writer + 2 readable standbys in 3 AZs | Separate copy (up to 15; 5 for Oracle and SQL Server, 3 for Db2) |
| Engines | All RDS engines | **RDS for MySQL and PostgreSQL only** | All RDS engines |
| Replication | Synchronous | Semi-synchronous (one reader must confirm) | Asynchronous (can lag behind) |
| Can you read from the copy? | **No** | Yes, through the reader endpoint | **Yes** |
| Failover | Automatic, typically **60–120 seconds** | Automatic, typically **under 35 seconds** | Manual: you **promote** it |
| Other Region | No | No | Yes (except SQL Server) |
| Cost | About 2x the instance | About 3x the instance | One more instance each |

During a Multi-AZ failover, RDS moves the **same endpoint name** to the standby, so the app reconnects without config changes. Make sure your app **retries** connections.

**Console:** select the database → **Modify** → **Availability and durability** → **Multi-AZ DB instance deployment** → **Continue** → **Apply immediately**. For a read replica: **Actions → Create read replica**.

**CLI** (uses the instance from Step 3; these double the cost, so try them briefly):

```bash
# turn on Multi-AZ, then test a failover by rebooting with --force-failover
aws rds modify-db-instance --db-instance-identifier my-app-db --multi-az --apply-immediately
aws rds wait db-instance-available --db-instance-identifier my-app-db
aws rds reboot-db-instance --db-instance-identifier my-app-db --force-failover
aws rds describe-events --source-type db-instance --source-identifier my-app-db --duration 60 \
  --query 'Events[].[Date,Message]' --output table

# a read replica in the same subnets and security group
aws rds create-db-instance-read-replica --db-instance-identifier my-app-db-replica \
  --source-db-instance-identifier my-app-db --db-instance-class db.t4g.micro \
  --vpc-security-group-ids $DB_SG --no-publicly-accessible
```

AWS docs: [Multi-AZ deployments](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZ.html) · [Multi-AZ DB clusters](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/multi-az-db-clusters-concepts.html) · [Read replicas](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ReadRepl.html)

## Amazon Aurora: clusters, endpoints and Serverless

> **In simple words:** Aurora splits the database in two: **compute** (the instances that run queries) and **one shared storage volume** that keeps **six copies of your data across three AZs**. Because readers share the writer's storage, adding a reader is fast and failover usually takes seconds, not minutes.

```text
       app writes                app reads
           │                         │
   cluster endpoint           reader endpoint
           │                  ┌──────┴──────┐
     ┌─────▼────┐       ┌─────▼────┐  ┌─────▼────┐
     │ writer   │       │ reader 1 │  │ reader 2 │
     │ AZ a     │       │ AZ b     │  │ AZ c     │
     └─────┬────┘       └─────┬────┘  └─────┬────┘
 ┌─────────┴──────────────────┴─────────────┴──────┐
 │  shared cluster volume: 6 copies across 3 AZs   │
 └─────────────────────────────────────────────────┘
```

| Endpoint | Points to | Use it for |
|---|---|---|
| **Cluster (writer) endpoint** | The current writer; follows it after failover | All writes, and reads that must be up to date |
| **Reader endpoint** | All readers, spread by DNS | Reports and read-heavy queries |
| **Instance endpoint** | One specific instance | Troubleshooting only |
| **Custom endpoint** | A group of instances you choose | E.g. big readers for analytics |

### Aurora Serverless

**Aurora Serverless** (called **Aurora Serverless v2** in older pages and in the CLI option names) sizes each instance automatically in **Aurora capacity units (ACUs)**. One ACU is about **2 GiB of memory** with matching CPU and networking. You set a minimum and a maximum, in steps of 0.5:

- **Minimum 0 ACU** turns on **automatic pause**: after a quiet period you choose (**5 minutes to 24 hours**, default 5 minutes) the instance pauses and you pay **no compute**, only storage. The first connection afterwards waits a few seconds while it resumes. Great for dev and test, not for busy production.
- **Minimum 0.5 ACU or more** keeps it always on. Only newer engine versions support 0; older ones start at 0.5.
- **Maximum** goes up to **256 ACUs** on recent versions (128 on older ones).

### Aurora Standard or Aurora I/O-Optimized

| | **Aurora Standard** | **Aurora I/O-Optimized** |
|---|---|---|
| I/O charges | Pay per million read/write requests | **None** |
| Instance and storage price | Lower | Higher |
| Choose it when | I/O is under 25% of your Aurora bill | I/O is **25% or more** of your Aurora bill |
| Switching | To I/O-Optimized once every 30 days | Back to Standard at any time |

**Try it (optional):** a tiny Aurora PostgreSQL cluster that pauses when idle. It reuses the subnet group and security group from Steps 1 and 3:

```bash
aws rds create-db-cluster --db-cluster-identifier my-app-aurora \
  --engine aurora-postgresql \
  --serverless-v2-scaling-configuration MinCapacity=0,MaxCapacity=2,SecondsUntilAutoPause=600 \
  --master-username postgres --manage-master-user-password \
  --db-subnet-group-name my-app-db-subnets --vpc-security-group-ids $DB_SG \
  --storage-encrypted --backup-retention-period 1 --storage-type aurora

# the cluster has no compute until you add an instance
aws rds create-db-instance --db-instance-identifier my-app-aurora-writer \
  --db-cluster-identifier my-app-aurora --engine aurora-postgresql --db-instance-class db.serverless
aws rds wait db-instance-available --db-instance-identifier my-app-aurora-writer

aws rds describe-db-clusters --db-cluster-identifier my-app-aurora \
  --query 'DBClusters[0].[Endpoint,ReaderEndpoint,StorageType]' --output table
```

Use `--storage-type aurora-iopt1` instead of `aurora` for I/O-Optimized.

AWS docs: [What is Aurora?](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/CHAP_AuroraOverview.html) · [Aurora endpoints](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.Overview.Endpoints.html) · [Aurora Serverless](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.html) · [Aurora storage](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.Overview.StorageReliability.html)

## Step 1: Network: subnet group and security groups

> **In simple words:** Tell RDS **where** it may live (a **DB subnet group** of private subnets in two AZs) and **who** may knock on its door (a **security group** that accepts the database port only from your app's security group). The database never gets a public IP.

This guide uses the `demo-vpc` with subnets `private-a` and `private-b` from the [VPC guide](#/tool/aws-vpc). Any VPC with two private subnets in different AZs works.

**Console:**
1. **EC2 → Security groups → Create security group**: `my-app-app-sg` in `demo-vpc`, no inbound rules. Create a second one, `my-app-db-sg`, with inbound **PostgreSQL (5432)**, source **`my-app-app-sg`** (pick the group, not an IP range).
2. **RDS console → Subnet groups → Create DB subnet group**: name `my-app-db-subnets`, VPC `demo-vpc`, choose the two AZs and the **private** subnets → **Create**.

**CLI:**

```bash
export AWS_REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=demo-vpc --query 'Vpcs[0].VpcId' --output text)
PRIV1=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=private-a --query 'Subnets[0].SubnetId' --output text)
PRIV2=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=private-b --query 'Subnets[0].SubnetId' --output text)

APP_SG=$(aws ec2 create-security-group --vpc-id $VPC_ID --group-name my-app-app-sg \
  --description "my-app servers" --query GroupId --output text)
DB_SG=$(aws ec2 create-security-group --vpc-id $VPC_ID --group-name my-app-db-sg \
  --description "my-app database" --query GroupId --output text)

# the ONLY way in: PostgreSQL port, from servers in the app security group
aws ec2 authorize-security-group-ingress --group-id $DB_SG --protocol tcp --port 5432 --source-group $APP_SG

aws rds create-db-subnet-group --db-subnet-group-name my-app-db-subnets \
  --db-subnet-group-description "private subnets for my-app" --subnet-ids $PRIV1 $PRIV2
```

| Engine | Port to open in `db-sg` |
|---|---|
| PostgreSQL / Aurora PostgreSQL | 5432 |
| MySQL, MariaDB / Aurora MySQL | 3306 |
| SQL Server | 1433 |

> **Warning:** Never add `0.0.0.0/0` to a database security group, and keep **Public access = No**. To reach the database from your laptop, use Session Manager (Step 4), a VPN, or a bastion, not a public endpoint.

AWS docs: [Working with a DB instance in a VPC](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_VPC.WorkingWithRDSInstanceinaVPC.html)

## Step 2: Create a parameter group

> **In simple words:** A **parameter group** is the database's settings file. Every instance uses the **default** one, which you can't edit, so create your own **before** you create the database and you can tune it any time later.

**Console:** RDS → **Parameter groups** → **Create parameter group** → Engine type **PostgreSQL**, Parameter group family (for example `postgres17`, matching your version), Type **DB Parameter Group**, name `my-app-pg` → **Create**. Open it → **Edit** → set `log_min_duration_statement` to `1000` → **Save changes**.

**CLI:**

```bash
# the current default PostgreSQL version and its parameter group family
PG_VERSION=$(aws rds describe-db-engine-versions --engine postgres --default-only \
  --query 'DBEngineVersions[0].EngineVersion' --output text)
PG_FAMILY=$(aws rds describe-db-engine-versions --engine postgres --default-only \
  --query 'DBEngineVersions[0].DBParameterGroupFamily' --output text)
echo "PostgreSQL $PG_VERSION, family $PG_FAMILY"

aws rds create-db-parameter-group --db-parameter-group-name my-app-pg \
  --db-parameter-group-family $PG_FAMILY --description "my-app PostgreSQL settings"

# log every query slower than 1 second, and refuse connections without TLS
aws rds modify-db-parameter-group --db-parameter-group-name my-app-pg --parameters \
  "ParameterName=log_min_duration_statement,ParameterValue=1000,ApplyMethod=immediate" \
  "ParameterName=rds.force_ssl,ParameterValue=1,ApplyMethod=pending-reboot"
```

| Parameter type | When a change takes effect |
|---|---|
| **Dynamic** | Right away (`ApplyMethod=immediate`) |
| **Static** | After the next **reboot** (`pending-reboot`). The instance shows `pending-reboot` until then |

Useful PostgreSQL parameters to know: `max_connections` (set from instance memory by default), `log_min_duration_statement` (slow query log), `rds.force_ssl` (require TLS; already `1` by default on PostgreSQL 15 and later), `work_mem`, and `shared_preload_libraries` (for extensions like `pg_stat_statements`).

AWS docs: [Parameter groups](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_WorkingWithParamGroups.html)

## Step 3: Create a PostgreSQL instance

> **In simple words:** Now create the database itself: small, private, encrypted, with automatic backups, and with the master password **generated and stored by RDS in Secrets Manager**, so nobody ever types or emails it.

**Console:**
1. RDS console → **Databases** → **Create database** → **Standard create**.
2. **Engine type:** PostgreSQL. **Version:** the default.
3. **Templates:** **Free tier** (Free plan accounts) or **Sandbox** (Paid plan accounts). The **Production** template preselects Multi-AZ, Provisioned IOPS storage and deletion protection.
4. **Settings:** DB instance identifier `my-app-db`, master username `postgres`, **Credentials management: Managed in AWS Secrets Manager**.
5. **Instance configuration:** Burstable classes → `db.t4g.micro`.
6. **Storage:** gp3, 20 GiB. Under storage autoscaling, tick **Enable storage autoscaling**, **Maximum storage threshold** 100 GiB.
7. **Availability and durability:** Single-AZ for the lab (Multi-AZ for production).
8. **Connectivity:** VPC `demo-vpc`, DB subnet group `my-app-db-subnets`, **Public access: No**, VPC security group: choose existing `my-app-db-sg` (remove `default`).
9. **Additional configuration:** Initial database name `appdb`, DB parameter group `my-app-pg`, backup retention **7 days**, **Enable encryption** (key `aws/rds`), **Enable auto minor version upgrade**, **Enable deletion protection**.
10. **Create database**. It takes about 5–10 minutes to become **Available**.

**CLI:**

```bash
aws rds create-db-instance \
  --db-instance-identifier my-app-db \
  --engine postgres --engine-version "$PG_VERSION" \
  --db-instance-class db.t4g.micro \
  --storage-type gp3 --allocated-storage 20 --max-allocated-storage 100 \
  --master-username postgres --manage-master-user-password \
  --db-name appdb \
  --db-subnet-group-name my-app-db-subnets \
  --vpc-security-group-ids $DB_SG \
  --no-publicly-accessible \
  --db-parameter-group-name my-app-pg \
  --storage-encrypted \
  --backup-retention-period 7 \
  --preferred-backup-window 03:00-03:30 \
  --preferred-maintenance-window sun:04:00-sun:04:30 \
  --auto-minor-version-upgrade \
  --copy-tags-to-snapshot \
  --deletion-protection \
  --tags Key=app,Value=my-app Key=env,Value=dev

aws rds wait db-instance-available --db-instance-identifier my-app-db

aws rds describe-db-instances --db-instance-identifier my-app-db --query 'DBInstances[0].{
  Status:DBInstanceStatus,Endpoint:Endpoint.Address,Port:Endpoint.Port,Public:PubliclyAccessible,
  Encrypted:StorageEncrypted,Secret:MasterUserSecret.SecretArn}' --output json
```

| Option | Why it matters |
|---|---|
| `--manage-master-user-password` | RDS creates the password, stores it in Secrets Manager and **rotates it every 7 days** by default |
| `--no-publicly-accessible` | No public IP, ever |
| `--storage-encrypted` | Encryption at rest with KMS. **Only possible at creation** |
| `--backup-retention-period 7` | The CLI default is only **1 day** (the console's is 7). 0 turns backups off: don't |
| `--max-allocated-storage 100` | Turns on storage autoscaling up to 100 GiB |
| `--deletion-protection` | Blocks accidental deletes until you turn it off |
| Backup and maintenance windows | Times in **UTC**; they must not overlap |

The secret RDS creates holds a small JSON document:

```json
{
  "username": "postgres",
  "password": "generated-and-rotated-by-rds"
}
```

> **Tip:** Using Terraform? The `aws_db_instance` resource has the same options, including `manage_master_user_password = true`. See the [Terraform guide](#/tool/terraform), and the [Secrets Manager guide](#/tool/aws-secrets) for how apps read the secret.

AWS docs: [Creating a DB instance](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_CreateDBInstance.html) · [Password management with Secrets Manager](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-secrets-manager.html)

## Step 4: Connect to the database

> **In simple words:** The database is private, so you connect **from inside the VPC**. Either log in to an EC2 instance in the app security group and run `psql` there, or use **Session Manager port forwarding**: a secure tunnel from your laptop through that EC2 instance, with no SSH keys and no open ports.

### Start a small app server

It needs the **Session Manager** role `ec2-ssm-lab-role` (with the `AmazonSSMManagedInstanceCore` policy) from the [EC2 lab](#/tool/ec2-website), and a way to reach the Systems Manager service (the VPC's NAT gateway, or VPC endpoints as in the [PrivateLink guide](#/tool/aws-privatelink)).

```bash
AMI_ID=$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query Parameter.Value --output text)

APP_VM=$(aws ec2 run-instances --image-id $AMI_ID --instance-type t3.micro --subnet-id $PRIV1 \
  --security-group-ids $APP_SG --iam-instance-profile Name=ec2-ssm-lab-role \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=my-app-client}]' \
  --query 'Instances[0].InstanceId' --output text)
aws ec2 wait instance-status-ok --instance-ids $APP_VM

DB_HOST=$(aws rds describe-db-instances --db-instance-identifier my-app-db \
  --query 'DBInstances[0].Endpoint.Address' --output text)
SECRET_ARN=$(aws rds describe-db-instances --db-instance-identifier my-app-db \
  --query 'DBInstances[0].MasterUserSecret.SecretArn' --output text)
echo "$DB_HOST"
```

### Option A: from your laptop with port forwarding

You need the AWS CLI and the **Session Manager plugin** on your laptop (see the [Systems Manager guide](#/tool/aws-ssm)), plus a `psql` client.

```bash
# terminal 1: open the tunnel  localhost:15432 -> app server -> database:5432
aws ssm start-session --target $APP_VM \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "{\"host\":[\"$DB_HOST\"],\"portNumber\":[\"5432\"],\"localPortNumber\":[\"15432\"]}"
```

```bash
# terminal 2: read the password from Secrets Manager and connect through the tunnel
SECRET_ARN=$(aws rds describe-db-instances --db-instance-identifier my-app-db \
  --query 'DBInstances[0].MasterUserSecret.SecretArn' --output text)
export PGPASSWORD=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ARN" \
  --query SecretString --output text | python3 -c 'import sys, json; print(json.load(sys.stdin)["password"])')

psql "host=localhost port=15432 dbname=appdb user=postgres sslmode=require" \
  -c "SELECT version();" \
  -c "SELECT ssl, version FROM pg_stat_ssl WHERE pid = pg_backend_pid();"
```

Through a tunnel the host name is `localhost`, so use `sslmode=require` (encrypted). `verify-full` would fail, because the certificate is issued for the RDS endpoint name.

### Option B: from the EC2 instance

```bash
aws ssm start-session --target $APP_VM
```

Then, inside the instance (paste your own endpoint, and the password from `aws secretsmanager get-secret-value` on your laptop):

```bash
sudo dnf install -y postgresql17          # or postgresql16; "dnf search postgresql" lists versions
curl -sO https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem

DB_HOST=my-app-db.abcdefghijkl.us-east-1.rds.amazonaws.com    # your endpoint from describe-db-instances
psql "host=$DB_HOST port=5432 dbname=appdb user=postgres sslmode=verify-full sslrootcert=global-bundle.pem"
```

`sslmode=verify-full` with the **RDS certificate bundle** checks that you really talk to your RDS endpoint. That's the safest setting for apps inside the VPC.

### Give the app its own user

Never let the app use the master user. Create a normal user with only the rights it needs:

```bash
APP_DB_PASSWORD=$(openssl rand -base64 24)
psql "host=localhost port=15432 dbname=appdb user=postgres sslmode=require" <<SQL
CREATE ROLE app_user LOGIN PASSWORD '$APP_DB_PASSWORD';
GRANT CONNECT ON DATABASE appdb TO app_user;
GRANT USAGE, CREATE ON SCHEMA public TO app_user;
SQL
# store APP_DB_PASSWORD in Secrets Manager for the app (see the Secrets Manager guide)
```

AWS docs: [Connecting to PostgreSQL](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ConnectToPostgreSQLInstance.html) · [Start a Session Manager session](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-sessions-start.html) · [SSL/TLS with RDS](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.SSL.html)

## Step 5: Backups, snapshots and restore

> **In simple words:** RDS backs up the database **every day** and saves its change logs every few minutes, so you can rewind to **any second** in the retention period. You can also take **manual snapshots** that stay until you delete them. Every restore creates a **new** database next to the old one: it never overwrites the original.

| | **Automated backups** | **Manual snapshots** |
|---|---|---|
| Who creates them | RDS, daily in the backup window, plus transaction logs | You (console, CLI, or AWS Backup) |
| Kept for | 1–35 days (your retention period) | Until you delete them |
| Point-in-time restore | **Yes**, to any second in the window | No, only the moment of the snapshot |
| Deleted with the instance | Yes, unless you choose to keep them | **No** |
| Use for | Undo mistakes from the last days | Before upgrades, monthly archives, DR copies |

**Console:** select `my-app-db` → **Actions → Take snapshot**. For a rewind: **Actions → Restore to point in time** → choose **Latest restorable time** or a custom time → new identifier `my-app-db-restored` → same subnet group and security group → **Restore**.

**CLI:**

```bash
# a manual snapshot
aws rds create-db-snapshot --db-instance-identifier my-app-db --db-snapshot-identifier my-app-db-manual-1
aws rds wait db-snapshot-available --db-snapshot-identifier my-app-db-manual-1

# how far back can we go?
aws rds describe-db-instances --db-instance-identifier my-app-db \
  --query 'DBInstances[0].[LatestRestorableTime,BackupRetentionPeriod]' --output text

# point-in-time restore: creates a NEW instance
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier my-app-db \
  --target-db-instance-identifier my-app-db-restored \
  --use-latest-restorable-time \
  --db-instance-class db.t4g.micro \
  --db-subnet-group-name my-app-db-subnets --vpc-security-group-ids $DB_SG \
  --db-parameter-group-name my-app-pg --no-publicly-accessible
# or: --restore-time 2026-11-08T09:30:00Z instead of --use-latest-restorable-time

# restore from a snapshot: also a NEW instance
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier my-app-db-from-snap --db-snapshot-identifier my-app-db-manual-1 \
  --db-instance-class db.t4g.micro \
  --db-subnet-group-name my-app-db-subnets --vpc-security-group-ids $DB_SG \
  --db-parameter-group-name my-app-pg --no-publicly-accessible
```

After a restore, check the data, then either point the app to the new endpoint, or copy the rows you need back into the original. If you can't log in to the copy, reset its master password with `aws rds modify-db-instance --db-instance-identifier my-app-db-restored --manage-master-user-password --apply-immediately`.

### Copy a snapshot to another Region and share it

A copy in a second Region protects you if a whole Region has problems (disaster recovery). Run the copy **in the destination Region**, and give a KMS key that lives there:

```bash
aws rds copy-db-snapshot --region us-west-2 --source-region us-east-1 \
  --source-db-snapshot-identifier arn:aws:rds:us-east-1:${ACCOUNT_ID}:snapshot:my-app-db-manual-1 \
  --target-db-snapshot-identifier my-app-db-manual-1-dr \
  --kms-key-id alias/aws/rds --copy-tags

# share a snapshot with another account (here 222222222222), e.g. a backup or test account
aws rds modify-db-snapshot-attribute --db-snapshot-identifier my-app-db-manual-1 \
  --attribute-name restore --values-to-add 222222222222
```

> **Note:** You **can't share a snapshot encrypted with the default `aws/rds` key**. For sharing, encrypt the database (or a snapshot copy) with a **customer managed KMS key** whose key policy allows the other account. See the [KMS guide](#/tool/aws-kms). For backup plans across many databases, accounts and Regions, see [AWS Backup](#/tool/aws-backup).

AWS docs: [Introduction to backups](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_WorkingWithAutomatedBackups.html) · [Point-in-time restore](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PIT.html) · [Copy a snapshot](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_CopySnapshot.html) · [Share a snapshot](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ShareSnapshot.html)

## Step 6: Maintenance and upgrades

> **In simple words:** AWS patches the database during your weekly **maintenance window** (30 minutes, a time you choose). **Minor** versions (17.4 → 17.5) are bug and security fixes and can be automatic. **Major** versions (16 → 17) can break things, so you plan, test and start them yourself.

| | Minor upgrade | Major upgrade |
|---|---|---|
| Example | 17.4 → 17.5 | 16.x → 17.x |
| Risk | Low: fixes only | Higher: behaviour and extensions can change |
| How | **Auto minor version upgrade** in the maintenance window, or by hand | By hand with `--allow-major-version-upgrade` |
| Downtime | A short restart (shorter with Multi-AZ) | Several minutes or more; take a snapshot first |
| Safer path | Test in dev first | Test on a restored copy, or use **Blue/Green Deployments** |

**Console:** select the database → **Maintenance & backups** tab → see **Pending maintenance**. To upgrade: **Modify** → **DB engine version** → **Continue** → choose **Apply during the next scheduled maintenance window** or **Apply immediately**.

**CLI:**

```bash
# anything waiting for the maintenance window?
aws rds describe-pending-maintenance-actions \
  --query 'PendingMaintenanceActions[].[ResourceIdentifier,PendingMaintenanceActionDetails[0].Action,PendingMaintenanceActionDetails[0].Description]' \
  --output table

# which versions can we upgrade to?
aws rds describe-db-engine-versions --engine postgres --engine-version "$PG_VERSION" \
  --query 'DBEngineVersions[0].ValidUpgradeTarget[].[EngineVersion,IsMajorVersionUpgrade]' --output table

# move the window (UTC), or apply a pending change now instead of waiting
aws rds modify-db-instance --db-instance-identifier my-app-db \
  --preferred-maintenance-window sun:04:00-sun:04:30
aws rds reboot-db-instance --db-instance-identifier my-app-db    # applies pending-reboot parameters

# a major upgrade (snapshot first; a new major version also needs a parameter group of the new family):
# aws rds modify-db-instance --db-instance-identifier my-app-db --engine-version 18.1 \
#   --allow-major-version-upgrade --db-parameter-group-name my-app-pg18 --apply-immediately
```

> **Tip:** **Blue/Green Deployments** build a full copy (green) that stays in sync with production (blue). You upgrade and test green, then switch over in about a minute.

AWS docs: [Maintaining a DB instance](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_UpgradeDBInstance.Maintenance.html) · [Upgrading the engine version](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_UpgradeDBInstance.Upgrading.html) · [Blue/Green Deployments](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/blue-green-deployments.html)

## Step 7: Monitoring and alarms

> **In simple words:** RDS sends health numbers (**metrics**) to CloudWatch every minute for free. Put **alarms** on the few that warn you early (CPU, disk, memory, connections, latency, replica lag), turn on **Enhanced Monitoring** to see inside the operating system, and use **Database Insights** to find the slow queries.

### Key alarms

| Metric (namespace `AWS/RDS`) | Unit | Alarm when | Usually means |
|---|---|---|---|
| `CPUUtilization` | Percent | > 80% for 10–15 minutes | Heavy or bad queries, or the class is too small |
| `CPUCreditBalance` (t classes) | Credits | Near 0 | Burst credits used up: the CPU will be throttled |
| `FreeStorageSpace` | Bytes | < 10% of allocated storage | Disk filling up (logs, data growth) |
| `FreeableMemory` | Bytes | < about 10% of instance memory | Too little cache: more disk reads, slower queries |
| `DatabaseConnections` | Count | > 80% of `max_connections` | Connection leak, or the app needs pooling |
| `ReadLatency` / `WriteLatency` | Seconds | Well above your normal level (e.g. > 0.02 s) | Storage is the bottleneck |
| `ReplicaLag` (RDS read replicas) | Seconds | > 60 | The replica can't keep up |
| `AuroraReplicaLag` (Aurora readers) | Milliseconds | > 1,000 | An Aurora reader is behind |

Aurora also has `ServerlessDatabaseCapacity` (alarm when it sits at your maximum ACUs), `FreeLocalStorage`, `Deadlocks` and `BufferCacheHitRatio`.

### Create an alarm

Send alarms to an SNS topic (see the [SNS and SES guide](#/tool/aws-sns-ses)). This one fires when free disk space stays under 2 GiB for 10 minutes:

```bash
TOPIC_ARN=$(aws sns create-topic --name my-app-db-alerts --query TopicArn --output text)
aws sns subscribe --topic-arn $TOPIC_ARN --protocol email --notification-endpoint ops@example.com

aws cloudwatch put-metric-alarm \
  --alarm-name my-app-db-low-storage \
  --namespace AWS/RDS --metric-name FreeStorageSpace \
  --dimensions Name=DBInstanceIdentifier,Value=my-app-db \
  --statistic Minimum --period 300 --evaluation-periods 2 \
  --threshold 2147483648 --comparison-operator LessThanThreshold \
  --treat-missing-data breaching \
  --alarm-actions $TOPIC_ARN --ok-actions $TOPIC_ARN

aws cloudwatch describe-alarms --alarm-names my-app-db-low-storage \
  --query 'MetricAlarms[0].[AlarmName,StateValue]' --output text
```

Copy the command for the other metrics in the table (`GreaterThanThreshold` for CPU, connections, latency and lag). The [CloudWatch guide](#/tool/aws-cloudwatch) explains alarms and dashboards in depth.

### Enhanced Monitoring and Database Insights

| Tool | What it shows | Cost |
|---|---|---|
| **CloudWatch metrics** | Instance-level numbers every minute | Free |
| **Enhanced Monitoring** | OS metrics (per-process CPU, memory, disk) every 1–60 seconds, stored in the `RDSOSMetrics` log group | CloudWatch Logs charges |
| **CloudWatch Database Insights, Standard mode** | Database load, wait events and top SQL (7 days of history free) | Free; longer history costs extra |
| **CloudWatch Database Insights, Advanced mode** | Adds fleet dashboards, execution plans, on-demand analysis, longer history | Extra charge |

**Performance Insights** has been retired: AWS ended its separate console in 2026 and moved its features into **CloudWatch Database Insights**. In the API and CLI, the switch is still called `--enable-performance-insights`.

```bash
# Enhanced Monitoring needs a role that RDS can use to write OS metrics to CloudWatch Logs
aws iam create-role --role-name rds-monitoring-role --assume-role-policy-document \
  '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"monitoring.rds.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
aws iam attach-role-policy --role-name rds-monitoring-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole

aws rds modify-db-instance --db-instance-identifier my-app-db \
  --monitoring-interval 60 --monitoring-role-arn arn:aws:iam::${ACCOUNT_ID}:role/rds-monitoring-role \
  --enable-performance-insights --database-insights-mode standard \
  --apply-immediately
```

**Console:** select the database → **Monitoring** tab for metrics, or open **CloudWatch → Insights → Database Insights** to see the load and the top SQL statements.

AWS docs: [CloudWatch metrics for RDS](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-metrics.html) · [Enhanced Monitoring](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_Monitoring.OS.html) · [CloudWatch Database Insights](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Database-Insights.html)

## Security: encryption, TLS and deletion protection

> **In simple words:** Lock the data three ways: **encrypt the disk** (at rest), **encrypt the connection** (in transit) and **protect against accidental deletion**. The first one can only be chosen when the database is created.

| Protection | How | Remember |
|---|---|---|
| **Encryption at rest** | `--storage-encrypted`, with the `aws/rds` key or your own KMS key (`--kms-key-id`) | **Only at creation.** To encrypt an existing database: snapshot → copy the snapshot with encryption → restore |
| Backups, snapshots, replicas | Encrypted automatically with the same key | Cross-Region copies need a key in the target Region |
| **Encryption in transit** | TLS; `rds.force_ssl = 1` makes it mandatory (default on PostgreSQL 15+) | Clients use `sslmode=verify-full` and the RDS CA bundle |
| **Passwords** | `--manage-master-user-password` (Secrets Manager) | Apps read the secret at runtime; nobody needs to know it |
| **Network** | Private subnets, `--no-publicly-accessible`, security group from the app only | Reach it with Session Manager or a VPN |
| **Deletion protection** | `--deletion-protection` | Must be turned off before deleting |
| **Final snapshot** | `--final-db-snapshot-identifier` when deleting | A last copy, kept after the database is gone |

For an existing unencrypted database, the path to encryption is:

```flow
📸 | Snapshot | Take a manual snapshot of the unencrypted instance.
🔐 | Encrypted copy | Copy the snapshot and tick Enable encryption, choosing a KMS key.
🆕 | Restore | Restore a new instance from the encrypted copy.
🔀 | Switch | Point the app at the new endpoint, then delete the old instance.
```

AWS docs: [Encrypting RDS resources](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Overview.Encryption.html) · [Deleting a DB instance](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_DeleteInstance.html)

## SQL Server: RDS or EC2?

> **In simple words:** **RDS for SQL Server** is the easy choice: AWS handles Windows, SQL Server patching, backups and Multi-AZ. Some teams still run **SQL Server on EC2** because they need things RDS doesn't allow, such as full control of the operating system or their own Always On setup.

| Need | RDS for SQL Server | SQL Server on EC2 |
|---|---|---|
| OS access (RDP, install agents, Windows settings) | **No** | Yes, full administrator |
| `sysadmin` role | No (the master user gets most, not all, rights) | Yes |
| High availability | Multi-AZ, managed by AWS (uses Always On or mirroring underneath; the standby can't be read) | **Always On availability groups** you design: readable secondaries, your own listeners and Windows failover cluster |
| SSIS packages | Supported, with limits (project deployment only, files only in `D:\S3`, a list of supported tasks) | Anything, including third-party components and file shares |
| Backups and patching | Automatic, point-in-time restore | You script and test them (or use AWS Backup) |
| Licence | Included in the hourly price | Licence-included AMIs, or bring your own where allowed |
| Effort | Low | High: you're the DBA and the Windows admin |

Choose **RDS** unless a requirement in the right-hand column forces EC2. Teams on EC2 usually automate the build with Terraform plus Systems Manager documents (disk layout, domain join, SQL Server configuration).

AWS docs: [RDS for SQL Server](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_SQLServer.html) · [SSIS on RDS for SQL Server](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Appendix.SQLServer.Options.SSIS.html)

## What you pay for

> **In simple words:** An RDS bill has three main parts: the **server per hour**, the **disk per GB-month**, and **backups beyond the free amount**. Multi-AZ roughly doubles the server and disk. Aurora adds I/O charges (Standard) or bundles them (I/O-Optimized).

| Item | Example price (us-east-1) | Tip |
|---|---|---|
| Instance hours | `db.t4g.micro` PostgreSQL: $0.016/hour Single-AZ, $0.032/hour Multi-AZ | Right-size; Graviton classes are cheaper |
| gp3 storage | $0.115 per GB-month ($0.23 Multi-AZ) | Start at 20 GiB with autoscaling |
| Backup storage | Free up to your total database storage in the Region, then $0.095 per GB-month | Don't keep old manual snapshots forever |
| Snapshot copies in another Region | Storage there, plus data transfer | Keep only what your DR plan needs |
| Aurora | Instance hours or ACU-hours, storage, and I/O (Standard only) | Serverless with minimum 0 ACU for idle dev databases |
| Secrets Manager | $0.40 per secret per month | One secret per database user |
| Database Insights / Enhanced Monitoring | Standard mode free; Advanced mode and logs cost extra | Turn on Advanced for production only |

**Save money in labs:** **stop** an instance you don't need (`aws rds stop-db-instance`). Storage is still charged, and RDS **starts it again automatically after 7 days**. For steady production databases, **Reserved Instances** lower the hourly price.

## Troubleshooting

> **In simple words:** Most problems are one of four things: the app **can't reach** the database (network), it **can't log in** (password or TLS), the database is **full** (disk or connections), or it's **slow** (queries or size). Check them in that order.

| Problem | Likely cause | Fix |
|---|---|---|
| Connection **times out** | `db-sg` doesn't allow the port from the client's security group; client outside the VPC; wrong port | Allow 5432 from `app-sg`; connect from inside the VPC or through Session Manager |
| Laptop can't resolve or reach the endpoint | **Public access = No** (correct!) | Use port forwarding to `localhost`, or a VPN. Don't make the database public |
| `no pg_hba.conf entry ... SSL off` | `rds.force_ssl = 1` and the client didn't use TLS | Add `sslmode=require` (or `verify-full` with the CA bundle) |
| `password authentication failed` | The managed secret was rotated; old password cached; wrong user | Read the secret again; apps should fetch it at runtime and retry |
| Session Manager: `TargetNotConnected` | The EC2 instance has no SSM role, or no route to Systems Manager | Attach `AmazonSSMManagedInstanceCore`; add a NAT gateway or VPC endpoints; check the plugin on your laptop |
| Status **storage-full**, writes fail | Disk full; autoscaling off or at its maximum | Raise allocated or maximum storage; find big tables and logs; alarm on `FreeStorageSpace` |
| Can't change storage again | Less than 6 hours since the last change, or still optimizing | Wait; plan size changes ahead |
| `remaining connection slots are reserved` / too many connections | Connection leaks, no pooling, class too small (`max_connections` comes from memory) | Use a pool (or **RDS Proxy**), close idle sessions, size up |
| Slow queries | Missing indexes, CPU credits used up, too little memory | Database Insights top SQL, `log_min_duration_statement`, `EXPLAIN ANALYZE`; check `CPUCreditBalance`; bigger class |
| High `ReplicaLag` | Replica smaller than the source, or heavy writes | Same size replica; spread big write jobs |
| Parameter change "doesn't work" | Static parameter, status `pending-reboot` | Reboot the instance (in a quiet time) |
| `InvalidParameterCombination` on create | Class or version not available for that engine or Region | `aws rds describe-orderable-db-instance-options --engine postgres --db-instance-class db.t4g.micro` |
| Delete fails | **Deletion protection** is on | `modify-db-instance --no-deletion-protection --apply-immediately`, then delete |
| Can't share a snapshot | Encrypted with the default `aws/rds` key | Copy it with a customer managed KMS key, then share the copy |

Check **Events** (RDS console → Events, or `aws rds describe-events`) and the **Logs & events** tab first: failovers, reboots, storage changes and errors are all listed there.

AWS docs: [Troubleshooting for RDS](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Troubleshooting.html) · [RDS Proxy](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-proxy.html)

## Clean up

> **In simple words:** Delete in reverse order: the test copies and replicas, then the main database (turn off deletion protection first), then snapshots, then the small supporting pieces. A stopped or forgotten database keeps costing money.

```bash
# extra copies (ignore "not found" errors for things you didn't create)
for DB in my-app-db-replica my-app-db-restored my-app-db-from-snap; do
  aws rds delete-db-instance --db-instance-identifier $DB --skip-final-snapshot --delete-automated-backups
done

# the main database: protection off, then delete
# (production: use --final-db-snapshot-identifier my-app-db-final instead of --skip-final-snapshot)
aws rds modify-db-instance --db-instance-identifier my-app-db --no-deletion-protection --apply-immediately
aws rds delete-db-instance --db-instance-identifier my-app-db --skip-final-snapshot --delete-automated-backups

# Aurora (if you tried it): instances first, then the cluster
aws rds delete-db-instance --db-instance-identifier my-app-aurora-writer
aws rds wait db-instance-deleted --db-instance-identifier my-app-aurora-writer
aws rds delete-db-cluster --db-cluster-identifier my-app-aurora --skip-final-snapshot

aws rds wait db-instance-deleted --db-instance-identifier my-app-db

# snapshots (manual snapshots are NOT deleted with the instance)
aws rds delete-db-snapshot --db-snapshot-identifier my-app-db-manual-1
aws rds delete-db-snapshot --region us-west-2 --db-snapshot-identifier my-app-db-manual-1-dr

# settings and network pieces
aws rds delete-db-parameter-group --db-parameter-group-name my-app-pg
aws rds delete-db-subnet-group --db-subnet-group-name my-app-db-subnets
aws ec2 terminate-instances --instance-ids $APP_VM
aws ec2 wait instance-terminated --instance-ids $APP_VM
aws ec2 delete-security-group --group-id $DB_SG
aws ec2 delete-security-group --group-id $APP_SG

# monitoring
aws cloudwatch delete-alarms --alarm-names my-app-db-low-storage
aws sns delete-topic --topic-arn $TOPIC_ARN
aws iam detach-role-policy --role-name rds-monitoring-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole
aws iam delete-role --role-name rds-monitoring-role

# anything left?
aws rds describe-db-instances --query 'DBInstances[].DBInstanceIdentifier'
aws rds describe-db-snapshots --snapshot-type manual --query 'DBSnapshots[].DBSnapshotIdentifier'
```

The secret that RDS created for the master password is **deleted automatically** with the instance. If you followed the [VPC guide](#/tool/aws-vpc), run its clean-up too (the NAT gateway costs money every hour).

## Lab and cheat sheet

> **In simple words:** Practice time: build a private database, connect to it safely, break it on purpose, restore it, and set up alarms. Then delete everything.

1. Create the subnet group, the two security groups and the parameter group (Steps 1 and 2) with the CLI.
2. Create `my-app-db` with `--manage-master-user-password`, and find its secret in the **Secrets Manager** console.
3. Connect from your laptop through **Session Manager port forwarding** and run `SELECT version();`. Check that `pg_stat_ssl` shows `ssl = t`.
4. Try to connect **without** TLS (`sslmode=disable`) and read the error. Explain which parameter caused it.
5. Create a table, insert a few rows, note the time, then **drop** the table. Restore to the time before the drop with **point-in-time restore** and find your rows in `my-app-db-restored`.
6. Take a manual snapshot and copy it to `us-west-2`.
7. Create the `FreeStorageSpace` alarm and a `CPUUtilization` alarm, and confirm the SNS email subscription.
8. Turn on Multi-AZ, force a failover with `reboot-db-instance --force-failover`, and read the events. Turn Multi-AZ off again.
9. Bonus: create an Aurora Serverless cluster with minimum **0 ACU**, wait for it to pause, then connect and watch it resume.
10. Clean up everything and confirm that no instances or manual snapshots are left.

### Cheat sheet

| Task | Command |
|---|---|
| List databases | `aws rds describe-db-instances --query 'DBInstances[].[DBInstanceIdentifier,DBInstanceStatus,Engine]'` |
| Default engine version | `aws rds describe-db-engine-versions --engine postgres --default-only` |
| Subnet group | `aws rds create-db-subnet-group --db-subnet-group-name N --db-subnet-group-description D --subnet-ids S1 S2` |
| Create instance | `aws rds create-db-instance --db-instance-identifier N --engine postgres --db-instance-class db.t4g.micro --manage-master-user-password ...` |
| Wait until ready | `aws rds wait db-instance-available --db-instance-identifier N` |
| Endpoint | `aws rds describe-db-instances --db-instance-identifier N --query 'DBInstances[0].Endpoint.Address'` |
| Master secret ARN | `aws rds describe-db-instances --db-instance-identifier N --query 'DBInstances[0].MasterUserSecret.SecretArn'` |
| Tunnel from laptop | `aws ssm start-session --target I --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters ...` |
| Change class or settings | `aws rds modify-db-instance --db-instance-identifier N --db-instance-class db.t4g.small --apply-immediately` |
| Turn on Multi-AZ | `aws rds modify-db-instance --db-instance-identifier N --multi-az --apply-immediately` |
| Read replica | `aws rds create-db-instance-read-replica --db-instance-identifier R --source-db-instance-identifier N` |
| Manual snapshot | `aws rds create-db-snapshot --db-instance-identifier N --db-snapshot-identifier S` |
| Point-in-time restore | `aws rds restore-db-instance-to-point-in-time --source-db-instance-identifier N --target-db-instance-identifier T --use-latest-restorable-time` |
| Copy to another Region | `aws rds copy-db-snapshot --region us-west-2 --source-region us-east-1 --source-db-snapshot-identifier ARN --target-db-snapshot-identifier S` |
| Pending maintenance | `aws rds describe-pending-maintenance-actions` |
| Recent events | `aws rds describe-events --source-type db-instance --source-identifier N --duration 1440` |
| Stop for up to 7 days | `aws rds stop-db-instance --db-instance-identifier N` |
| Delete | `aws rds delete-db-instance --db-instance-identifier N --final-db-snapshot-identifier F` |
