# Amazon ECS: Running Containers on AWS

Amazon ECS (Elastic Container Service) is AWS's own container orchestrator. It keeps your containers running, replaces failed ones, rolls out new versions and connects them to load balancers, without the complexity of Kubernetes. With **Fargate** there are no servers to manage at all. This guide deploys the sample app from ECR to ECS on Fargate behind an Application Load Balancer, then covers updates, rollbacks, auto scaling, logs, shell access and secrets.

> **Note:** Do the [ECR guide](#/tool/aws-ecr) first. This guide uses the `hello-app:1.0.0` image pushed there, which listens on port 8000 with a `/health` endpoint. Knowing the [Load Balancers](#/tool/aws-elb) and [IAM](#/tool/aws-iam) guides helps too.

> **Cost:** Fargate charges per vCPU-hour and GB-hour while tasks run. A small task (0.25 vCPU, 0.5 GB) costs roughly **1–2 cents per hour**, plus the ALB at about $0.0225/hour. Run the lab, then **clean up**. See [Fargate pricing](https://aws.amazon.com/fargate/pricing/).

## Start here: ECS in simple words

> **In simple words:** You give ECS a **recipe card** (the *task definition*: which image, how much CPU and memory, which port) and say "always keep 2 of these running" (the *service*). ECS starts them, watches them, replaces any that crash, and plugs them into the load balancer.

### A real-life comparison

Think of a **food truck company**:

| Food trucks | ECS |
|---|---|
| The recipe card for a dish | **Task definition**: image, CPU, memory, ports, environment |
| One cook making that dish right now | **Task**: a running copy of the task definition |
| "Always have 2 cooks on the burger stand" | **Service**: keeps N tasks running and replaces failed ones |
| The company running everything | **Cluster**: the logical group your services run in |
| Renting kitchen space by the hour vs owning trucks | **Fargate** (serverless) vs the **EC2** launch type (your own instances) |

### How the pieces fit

```text
 ECR image ──▶ Task definition (hello-app:3)  ──used by──▶  Service "hello" (desired: 2)
                                                              │ runs tasks on Fargate
                                                              ▼
 users ──▶ ALB ──▶ Target group (ip targets) ──▶ [task 10.0.1.12:8000] [task 10.0.2.40:8000]
                                                  logs ─▶ CloudWatch Logs
```

### Key words

| Word | Simple meaning |
|---|---|
| **Cluster** | A named group for your services and tasks |
| **Task definition** | A versioned JSON recipe: containers, image, CPU/memory, ports, env, logging, IAM roles |
| **Task** | A running instance of a task definition (one or more containers) |
| **Service** | Keeps a desired number of tasks running, handles deployments and the load balancer |
| **Fargate** | Serverless compute for containers: no EC2 instances to patch |
| **Task execution role** | The IAM role **ECS** uses to pull the image and write logs |
| **Task role** | The IAM role **your app** uses to call AWS (S3, DynamoDB…) |
| **awsvpc** | Network mode where each task gets its own IP and security group |

### ECS or EKS?

| | ECS | EKS (Kubernetes) |
|---|---|---|
| Learning curve | Gentle, AWS-native | Steeper |
| Portability | AWS only | Any cloud or on-premises |
| Control plane cost | **Free** | About $0.10/hour per cluster |
| Ecosystem | AWS integrations | Huge (Helm, Argo CD, operators…) |
| Good for | Teams all-in on AWS who want simplicity | Multi-cloud, platform teams, Kubernetes skills |

### Check yourself

1. What's the difference between a task definition and a task?
2. Which IAM role pulls the image from ECR: the task role or the task execution role?
3. What does a service do that a single task doesn't?

> **Tip:** Answers: 1) The task definition is the recipe; a task is one running copy of it. 2) The task **execution** role. 3) It keeps the desired number of tasks running, replaces failures, does rolling deployments and registers tasks with the load balancer.

## Set up: cluster, roles, network and logs

> **In simple words:** Before running anything, create an empty cluster, the IAM role ECS uses to pull images and write logs, security groups, and a log group.

```bash
export AWS_REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
IMAGE=$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/hello-app:1.0.0
VPC_ID=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)
read SUBNET_A SUBNET_B <<< $(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID Name=default-for-az,Values=true \
  --query 'Subnets[0:2].SubnetId' --output text)

# 1. Cluster (Fargate needs no instances)
aws ecs create-cluster --cluster-name demo

# 2. Task execution role: lets ECS pull from ECR and write logs
cat > ecs-tasks-trust.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [{ "Effect": "Allow", "Principal": { "Service": "ecs-tasks.amazonaws.com" }, "Action": "sts:AssumeRole" }]
}
EOF
aws iam create-role --role-name ecsTaskExecutionRole --assume-role-policy-document file://ecs-tasks-trust.json
aws iam attach-role-policy --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

# 3. Security groups: ALB open to the world, tasks open only to the ALB on 8000
ALB_SG=$(aws ec2 create-security-group --group-name ecs-alb-sg --description "ECS ALB" --vpc-id $VPC_ID --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id $ALB_SG --protocol tcp --port 80 --cidr 0.0.0.0/0
TASK_SG=$(aws ec2 create-security-group --group-name ecs-task-sg --description "ECS tasks" --vpc-id $VPC_ID --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id $TASK_SG --protocol tcp --port 8000 --source-group $ALB_SG

# 4. Log group for container output
aws logs create-log-group --log-group-name /ecs/hello-app
aws logs put-retention-policy --log-group-name /ecs/hello-app --retention-in-days 7
```

AWS docs: [What is Amazon ECS?](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/Welcome.html) · [Task execution IAM role](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html)

## Write and register a task definition

> **In simple words:** The task definition is the recipe card: image, CPU and memory, port, environment variables and where logs go. Every time you register it, you get a new numbered **revision**.

`taskdef.json`. Replace `ACCOUNT_ID` and the Region if needed:

```json
{
  "family": "hello-app",
  "requiresCompatibilities": ["FARGATE"],
  "networkMode": "awsvpc",
  "cpu": "256",
  "memory": "512",
  "runtimePlatform": { "operatingSystemFamily": "LINUX", "cpuArchitecture": "X86_64" },
  "executionRoleArn": "arn:aws:iam::ACCOUNT_ID:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "web",
      "image": "ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/hello-app:1.0.0",
      "essential": true,
      "portMappings": [{ "containerPort": 8000, "protocol": "tcp" }],
      "environment": [{ "name": "APP_VERSION", "value": "1.0.0" }],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/hello-app",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "web"
        }
      }
    }
  ]
}
```

```bash
sed -i "s/ACCOUNT_ID/$ACCOUNT_ID/g" taskdef.json
aws ecs register-task-definition --cli-input-json file://taskdef.json \
  --query 'taskDefinition.[family,revision,status]' --output text      # hello-app 1 ACTIVE
aws ecs list-task-definitions --family-prefix hello-app
```

Valid Fargate sizes pair CPU with memory, for example 256 (0.25 vCPU) with 512–2048 MB, or 512 with 1–4 GB. `cpuArchitecture` must match how the image was built (`X86_64` or `ARM64`).

AWS docs: [Task definitions](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definitions.html) · [Fargate](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html)

## Run a one-off task

> **In simple words:** Before building a full service, start a single task by hand to check that the image, roles and network are right. It's like a test cook before opening the stand.

```bash
# temporary rule: allow your IP straight to the task on 8000 for this test
MYIP=$(curl -s https://checkip.amazonaws.com)
aws ec2 authorize-security-group-ingress --group-id $TASK_SG --protocol tcp --port 8000 --cidr $MYIP/32

TASK_ARN=$(aws ecs run-task --cluster demo --launch-type FARGATE --task-definition hello-app \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_A],securityGroups=[$TASK_SG],assignPublicIp=ENABLED}" \
  --query 'tasks[0].taskArn' --output text)
aws ecs wait tasks-running --cluster demo --tasks $TASK_ARN

ENI=$(aws ecs describe-tasks --cluster demo --tasks $TASK_ARN \
  --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" --output text)
TASK_IP=$(aws ec2 describe-network-interfaces --network-interface-ids $ENI --query 'NetworkInterfaces[0].Association.PublicIp' --output text)
curl -s http://$TASK_IP:8000/ ; echo

aws ecs stop-task --cluster demo --task $TASK_ARN
aws ec2 revoke-security-group-ingress --group-id $TASK_SG --protocol tcp --port 8000 --cidr $MYIP/32
```

`assignPublicIp=ENABLED` lets the task reach ECR over the internet in the default VPC's public subnets. In private subnets you'd use a **NAT gateway** or **VPC endpoints** instead.

## Create a service behind a load balancer

> **In simple words:** Now the real thing: a **service** that keeps 2 tasks running across two AZs and registers them with an ALB, so users get one stable address and failed tasks are replaced automatically.

```bash
# Target group: target type "ip" (required for Fargate / awsvpc)
TG_ARN=$(aws elbv2 create-target-group --name ecs-hello-tg --protocol HTTP --port 8000 --vpc-id $VPC_ID \
  --target-type ip --health-check-path /health --health-check-interval-seconds 15 \
  --healthy-threshold-count 2 --query 'TargetGroups[0].TargetGroupArn' --output text)
aws elbv2 modify-target-group-attributes --target-group-arn $TG_ARN \
  --attributes Key=deregistration_delay.timeout_seconds,Value=30

read ALB_ARN ALB_DNS <<< $(aws elbv2 create-load-balancer --name ecs-hello-alb --type application \
  --subnets $SUBNET_A $SUBNET_B --security-groups $ALB_SG \
  --query 'LoadBalancers[0].[LoadBalancerArn,DNSName]' --output text)
aws elbv2 create-listener --load-balancer-arn $ALB_ARN --protocol HTTP --port 80 \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN

# The service
aws ecs create-service --cluster demo --service-name hello \
  --task-definition hello-app --desired-count 2 --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_A,$SUBNET_B],securityGroups=[$TASK_SG],assignPublicIp=ENABLED}" \
  --load-balancers "targetGroupArn=$TG_ARN,containerName=web,containerPort=8000" \
  --health-check-grace-period-seconds 30 \
  --deployment-configuration "deploymentCircuitBreaker={enable=true,rollback=true},maximumPercent=200,minimumHealthyPercent=100"

aws ecs wait services-stable --cluster demo --services hello     # a few minutes
for i in $(seq 6); do curl -s http://$ALB_DNS/; echo; done          # "host" alternates between tasks
```

Test self-healing: stop one task and watch the service start a replacement.

```bash
aws ecs stop-task --cluster demo --task $(aws ecs list-tasks --cluster demo --service-name hello --query 'taskArns[0]' --output text)
watch -n5 "aws ecs describe-services --cluster demo --services hello --query 'services[0].[runningCount,desiredCount]' --output text"
```

The console's **ECS → Clusters → demo → Services → Create** walks through the same fields.

AWS docs: [ECS services](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs_services.html)

## Deploy a new version and roll back

> **In simple words:** Register a new task definition revision with the new image, then point the service at it. ECS starts new tasks, waits until they're healthy behind the ALB, then stops the old ones. If the new version keeps failing, the **circuit breaker** rolls back automatically.

```bash
# Build and push 1.1.0 (see ECR guide), then:
sed -i 's/hello-app:1.0.0/hello-app:1.1.0/; s/"value": "1.0.0"/"value": "1.1.0"/' taskdef.json
aws ecs register-task-definition --cli-input-json file://taskdef.json --query 'taskDefinition.revision'

aws ecs update-service --cluster demo --service hello --task-definition hello-app     # latest revision
aws ecs describe-services --cluster demo --services hello \
  --query 'services[0].deployments[].[status,taskDefinition,runningCount,rolloutState]' --output table
aws ecs wait services-stable --cluster demo --services hello
```

**Manual rollback:** point the service back at the previous revision:

```bash
aws ecs update-service --cluster demo --service hello --task-definition hello-app:1
```

Restart all tasks with the same definition (for example to pick up a changed secret) with `aws ecs update-service --cluster demo --service hello --force-new-deployment`.

| Deployment strategy | How it works |
|---|---|
| **Rolling update** (default) | Replaces tasks gradually, controlled by `minimumHealthyPercent` and `maximumPercent` |
| **Blue/green** (built into ECS) | Starts the full new version next to the old one, shifts load balancer traffic (all at once, canary or linear), keeps both during a bake time, and rolls back on alarms |
| **Circuit breaker** | Detects deployments whose tasks never become healthy and rolls back automatically |

AWS docs: [Rolling deployments](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-type-ecs.html) · [Blue/green deployments](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-type-blue-green.html)

## Auto scaling

> **In simple words:** Let ECS add tasks when they get busy and remove them when it's quiet, for example "keep average CPU around 60%, with between 2 and 6 tasks".

```bash
aws application-autoscaling register-scalable-target --service-namespace ecs \
  --scalable-dimension ecs:service:DesiredCount --resource-id service/demo/hello \
  --min-capacity 2 --max-capacity 6

aws application-autoscaling put-scaling-policy --service-namespace ecs \
  --scalable-dimension ecs:service:DesiredCount --resource-id service/demo/hello \
  --policy-name cpu-60 --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration '{
    "TargetValue": 60.0,
    "PredefinedMetricSpecification": { "PredefinedMetricType": "ECSServiceAverageCPUUtilization" },
    "ScaleInCooldown": 120, "ScaleOutCooldown": 60
  }'

aws application-autoscaling describe-scaling-activities --service-namespace ecs --resource-id service/demo/hello
```

Other useful metrics: `ECSServiceAverageMemoryUtilization`, and `ALBRequestCountPerTarget` (scale by requests per task).

AWS docs: [Service auto scaling](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-auto-scaling.html)

## Logs, metrics and a shell inside a task (ECS Exec)

> **In simple words:** Container output goes to CloudWatch Logs. **ECS Exec** lets you open a shell inside a running container, like `docker exec`, without SSH or open ports.

### Logs and metrics

```bash
aws logs tail /ecs/hello-app --follow --since 10m
aws ecs describe-services --cluster demo --services hello --query 'services[0].events[0:5].[createdAt,message]' --output table
```

Turn on **Container Insights** for per-task CPU, memory and network dashboards:

```bash
aws ecs update-cluster-settings --cluster demo --settings name=containerInsights,value=enabled
```

### ECS Exec

1. Give the **task role** (your app's role) permission to open SSM channels:

```bash
aws iam create-role --role-name hello-app-task-role --assume-role-policy-document file://ecs-tasks-trust.json
aws iam put-role-policy --role-name hello-app-task-role --policy-name ecs-exec --policy-document '{
  "Version": "2012-10-17",
  "Statement": [{ "Effect": "Allow", "Resource": "*", "Action": [
    "ssmmessages:CreateControlChannel", "ssmmessages:CreateDataChannel",
    "ssmmessages:OpenControlChannel", "ssmmessages:OpenDataChannel" ] }]
}'
```

2. Add `"taskRoleArn": "arn:aws:iam::<ACCOUNT_ID>:role/hello-app-task-role"` to `taskdef.json`, register it, and enable exec on the service:

```bash
aws ecs register-task-definition --cli-input-json file://taskdef.json
aws ecs update-service --cluster demo --service hello --task-definition hello-app \
  --enable-execute-command --force-new-deployment
aws ecs wait services-stable --cluster demo --services hello
```

3. Install the **Session Manager plugin** for the AWS CLI on your machine, then:

```bash
TASK=$(aws ecs list-tasks --cluster demo --service-name hello --query 'taskArns[0]' --output text)
aws ecs execute-command --cluster demo --task $TASK --container web --interactive --command "/bin/sh"
# inside: env | grep APP_VERSION ; python -c "import urllib.request;print(urllib.request.urlopen('http://localhost:8000/health').read())"
```

AWS docs: [ECS Exec](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html) · [Task IAM role](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html)

## Configuration and secrets

> **In simple words:** Keep settings in `environment`, and passwords in **Secrets Manager** or **SSM Parameter Store**. ECS fetches secrets when a task starts and injects them as environment variables, so they never appear in the task definition.

```bash
aws secretsmanager create-secret --name hello-app/db-password --secret-string 'S3cr3t!'
SECRET_ARN=$(aws secretsmanager describe-secret --secret-id hello-app/db-password --query ARN --output text)

# the EXECUTION role fetches secrets at start-up
aws iam put-role-policy --role-name ecsTaskExecutionRole --policy-name read-app-secrets --policy-document "{
  \"Version\": \"2012-10-17\",
  \"Statement\": [{ \"Effect\": \"Allow\", \"Action\": \"secretsmanager:GetSecretValue\", \"Resource\": \"$SECRET_ARN\" }]
}"
```

Add to the container definition in `taskdef.json`, then register and update the service:

```json
"secrets": [
  { "name": "DB_PASSWORD", "valueFrom": "arn:aws:secretsmanager:us-east-1:111122223333:secret:hello-app/db-password-AbCdEf" }
]
```

If the secret is encrypted with your own KMS key, the execution role also needs `kms:Decrypt` on it (see the [KMS guide](#/tool/aws-kms)).

## Troubleshooting

> **In simple words:** When tasks won't stay up, ask ECS **why it stopped them**. The `stoppedReason` and the service **events** almost always name the problem.

```bash
aws ecs describe-services --cluster demo --services hello --query 'services[0].events[0:8].message'
aws ecs list-tasks --cluster demo --desired-status STOPPED --query 'taskArns[0:3]'
aws ecs describe-tasks --cluster demo --tasks <STOPPED_TASK_ARN> \
  --query 'tasks[0].[stoppedReason,containers[0].reason,containers[0].exitCode]'
aws logs tail /ecs/hello-app --since 30m
```

| Symptom | Likely cause / fix |
|---|---|
| `CannotPullContainerError` | Wrong image URI or tag; execution role missing ECR permissions; no route to ECR (enable a public IP, NAT or VPC endpoints) |
| `ResourceInitializationError: unable to retrieve secret` / logs | The execution role can't read the secret or KMS key, or the log group doesn't exist |
| Tasks start, then stop: `Task failed ELB health checks` | Wrong health check path or port, the app is slow to start (raise the grace period), or the task security group doesn't allow the ALB on 8000 |
| `exec format error` | Image architecture ≠ `cpuArchitecture` (ARM vs x86) |
| Exit code 137 | Out of memory. Raise the task's `memory` |
| `execute-command` fails | Exec not enabled on the service, missing task role permissions, or no Session Manager plugin locally |
| Deployment stuck "IN_PROGRESS" | New tasks never become healthy. The circuit breaker will roll back, so check the events |

## Clean up

> **In simple words:** Scale the service to zero, delete it, then remove the load balancer, cluster, roles, logs and security groups. Running tasks and the ALB bill every hour.

```bash
aws application-autoscaling deregister-scalable-target --service-namespace ecs \
  --scalable-dimension ecs:service:DesiredCount --resource-id service/demo/hello 2>/dev/null
aws ecs update-service --cluster demo --service hello --desired-count 0
aws ecs delete-service --cluster demo --service hello --force
aws ecs wait services-inactive --cluster demo --services hello

aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN
aws elbv2 wait load-balancers-deleted --load-balancer-arns $ALB_ARN
aws elbv2 delete-target-group --target-group-arn $TG_ARN

for rev in $(aws ecs list-task-definitions --family-prefix hello-app --query 'taskDefinitionArns[]' --output text); do
  aws ecs deregister-task-definition --task-definition $rev > /dev/null; done
aws ecs delete-cluster --cluster demo
aws logs delete-log-group --log-group-name /ecs/hello-app
aws secretsmanager delete-secret --secret-id hello-app/db-password --force-delete-without-recovery

sleep 30   # wait for task network interfaces to be released
aws ec2 delete-security-group --group-id $TASK_SG
aws ec2 delete-security-group --group-id $ALB_SG
```

Delete the IAM roles `ecsTaskExecutionRole` and `hello-app-task-role` too, if you don't need them for other labs (detach or delete their policies first).

## Lab: ship the sample app on Fargate

> **In simple words:** Practice time: run the sample app on ECS the way a team would, including a bad release that rolls itself back.

1. Push `hello-app:1.0.0` to ECR (ECR guide).
2. Create the cluster, execution role, security groups and log group.
3. Register the task definition and test with a one-off task.
4. Create the `hello` service with 2 tasks behind an ALB. `curl` the ALB and watch the hosts alternate.
5. Deploy `1.1.0` with a new message and verify the rolling update.
6. Deploy a **broken** image (for example one whose `/health` returns 500). Watch the circuit breaker roll back on its own.
7. Add CPU target-tracking auto scaling between 2 and 6 tasks.
8. Open a shell in a running task with **ECS Exec**.
9. Inject a secret from Secrets Manager and confirm it's visible inside the container (then delete it).
10. Clean up everything.

### Cheat sheet

| Task | Command |
|---|---|
| Create cluster | `aws ecs create-cluster --cluster-name demo` |
| Register task def | `aws ecs register-task-definition --cli-input-json file://taskdef.json` |
| Create service | `aws ecs create-service --cluster demo --service-name s --task-definition td --desired-count 2 --launch-type FARGATE …` |
| Deploy new revision | `aws ecs update-service --cluster demo --service s --task-definition td` |
| Restart tasks | `aws ecs update-service --cluster demo --service s --force-new-deployment` |
| Why did it stop? | `aws ecs describe-tasks --cluster demo --tasks T --query 'tasks[0].stoppedReason'` |
| Logs | `aws logs tail /ecs/hello-app --follow` |
| Shell in task | `aws ecs execute-command --cluster demo --task T --container web --interactive --command /bin/sh` |
