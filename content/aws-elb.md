# AWS Load Balancers and Their Types

Elastic Load Balancing (ELB) spreads incoming traffic across several servers, containers or IPs, so that no single machine is overloaded, unhealthy targets are skipped, and you can add or remove servers without users noticing. This guide compares the four types (**ALB, NLB, GWLB, Classic**), then builds an Application Load Balancer with path routing and HTTPS, and a Network Load Balancer, step by step.

> **Cost:** A load balancer is billed **per hour** (about $0.0225/hour for an ALB or NLB in us-east-1, roughly $16/month) plus a small usage charge (LCU/NLCU). The lab's EC2 instances add their own cost. **Delete everything at the end.** See [ELB pricing](https://aws.amazon.com/elasticloadbalancing/pricing/).

## Start here: load balancers in simple words

> **In simple words:** A load balancer is the **receptionist** at the front door. Visitors talk only to the receptionist, who sends each one to a free, healthy staff member behind the scenes. If someone goes home sick, the receptionist simply stops sending people to them.

### What it gives you

```text
                 users
                   │  one address: my-alb-123.us-east-1.elb.amazonaws.com
                   ▼
          ┌──────────────────┐
          │  Load balancer   │   listener :80 / :443  →  rules  →  target group
          └───┬─────────┬────┘
   healthy ✓  │         │  ✓ healthy         ✗ unhealthy (skipped)
          ┌───▼───┐ ┌───▼───┐            ┌───────┐
          │ web-1 │ │ web-2 │            │ web-3 │
          │ AZ a  │ │ AZ b  │            │ AZ a  │
          └───────┘ └───────┘            └───────┘
```

- **High availability:** targets spread across Availability Zones, so one data center failing doesn't take the app down.
- **Health checks:** broken targets get no traffic.
- **Scaling:** add targets (by hand or with Auto Scaling) behind the same address.
- **Security:** only the load balancer is public; servers stay private, and HTTPS can be handled once at the load balancer.

### Key words

| Word | Simple meaning |
|---|---|
| **Listener** | The port and protocol the load balancer listens on, such as HTTP 80 or HTTPS 443 |
| **Rule** | "If the path is `/api/*`, send to the API servers" (ALB only) |
| **Target group** | A list of destinations plus a health check |
| **Target** | One destination: an EC2 instance, an IP address, a Lambda function, or another ALB |
| **Health check** | A regular test request; failing targets are taken out of rotation |
| **Internet-facing / internal** | Reachable from the internet, or only inside the VPC |
| **Layer 7 / Layer 4** | Understands HTTP (URLs, headers) / only sees TCP/UDP connections |

### Check yourself

1. Why don't users connect to the servers directly?
2. What happens to a target whose health check fails?
3. Which load balancer type understands URLs and paths?

> **Tip:** Answers: 1) One stable address, automatic failover, scaling and better security. 2) It stops receiving traffic until it's healthy again. 3) The Application Load Balancer (Layer 7).

## The four types compared

> **In simple words:** **ALB** for websites and APIs, **NLB** for raw speed, fixed IPs or non-HTTP traffic, **GWLB** for firewall appliances, and **Classic** only for old setups you haven't migrated yet.

| | **Application LB (ALB)** | **Network LB (NLB)** | **Gateway LB (GWLB)** | **Classic LB (CLB)** |
|---|---|---|---|---|
| Layer | 7 (HTTP/HTTPS, gRPC, WebSocket) | 4 (TCP, UDP, TLS) | 3 (IP packets, GENEVE) | 4 and 7 (basic) |
| Routing by path, host, header, query | **Yes** | No | No | No |
| Static IP / Elastic IP per AZ | No (DNS name only) | **Yes** | n/a | No |
| Keeps the client's source IP | Via the `X-Forwarded-For` header | **Yes**, by default for instance targets | Yes | Via proxy protocol |
| Performance | Very high | **Extreme**, millions of requests/sec, very low latency | High | Legacy |
| TLS / HTTPS termination | Yes | Yes (TLS listener) | No | Yes |
| Targets | Instances, IPs, Lambda | Instances, IPs, ALB | Appliance instances or IPs | Instances |
| Typical use | Websites, REST APIs, microservices, Kubernetes Ingress | Games, IoT, databases, gRPC/TCP services, needs a fixed IP, PrivateLink | Third-party firewalls and inspection appliances | Old EC2-Classic-era apps. **Avoid for new work** |

**How to choose:**

```text
 Is it HTTP/HTTPS and you want path/host routing or Lambda targets?   → ALB
 Need TCP/UDP, a static IP, extreme throughput, or PrivateLink?        → NLB
 Inserting a firewall / IDS appliance into network traffic?            → GWLB
 Building something new?                                               → never Classic
```

AWS docs: [What is Elastic Load Balancing?](https://docs.aws.amazon.com/elasticloadbalancing/latest/userguide/what-is-load-balancing.html) · [ALB](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html) · [NLB](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/introduction.html) · [GWLB](https://docs.aws.amazon.com/elasticloadbalancing/latest/gateway/introduction.html) · [Classic](https://docs.aws.amazon.com/elasticloadbalancing/latest/classic/introduction.html)

## Prepare two web servers in two AZs

> **In simple words:** A load balancer needs something to balance. Launch two small web servers in different Availability Zones, each showing its own name, so you can see the traffic alternate.

```bash
export AWS_REGION=us-east-1
VPC_ID=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)
read SUBNET_A SUBNET_B <<< $(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID Name=default-for-az,Values=true \
  --query 'Subnets[0:2].SubnetId' --output text)

# Security groups: the ALB accepts the internet; instances accept ONLY the ALB
ALB_SG=$(aws ec2 create-security-group --group-name lab-alb-sg --description "ALB" --vpc-id $VPC_ID --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id $ALB_SG --protocol tcp --port 80  --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $ALB_SG --protocol tcp --port 443 --cidr 0.0.0.0/0

WEB_SG=$(aws ec2 create-security-group --group-name lab-web-sg --description "web behind ALB" --vpc-id $VPC_ID --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id $WEB_SG --protocol tcp --port 80 --source-group $ALB_SG

cat > web-user-data.sh <<'EOF'
#!/bin/bash
dnf install -y nginx
TOKEN=$(curl -sX PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
md() { curl -sH "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/$1; }
echo "<h1>Hello from $(md instance-id) in $(md placement/availability-zone)</h1>" > /usr/share/nginx/html/index.html
mkdir -p /usr/share/nginx/html/api && echo '{"service":"api","host":"'$(md instance-id)'"}' > /usr/share/nginx/html/api/index.html
systemctl enable --now nginx
EOF

AMI_ID=$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 --query Parameter.Value --output text)
for SUBNET in $SUBNET_A $SUBNET_B; do
  aws ec2 run-instances --image-id $AMI_ID --instance-type t3.micro --subnet-id $SUBNET \
    --security-group-ids $WEB_SG --user-data file://web-user-data.sh \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=lb-lab-web}]' \
    --query 'Instances[0].InstanceId' --output text
done
INSTANCES=$(aws ec2 describe-instances --filters Name=tag:Name,Values=lb-lab-web Name=instance-state-name,Values=pending,running \
  --query 'Reservations[].Instances[].InstanceId' --output text)
aws ec2 wait instance-running --instance-ids $INSTANCES
echo $INSTANCES
```

Notice the web servers' security group only allows port 80 **from the ALB's security group**. Nobody can bypass the load balancer.

## Build an Application Load Balancer

> **In simple words:** Four pieces, in order: a **target group** (who receives traffic and how to health-check them), the **load balancer** itself, a **listener** (which port to listen on), and the **targets** registered in the group.

```bash
# 1. Target group with a health check
TG_ARN=$(aws elbv2 create-target-group --name lab-web-tg --protocol HTTP --port 80 --vpc-id $VPC_ID \
  --target-type instance --health-check-path / --health-check-interval-seconds 15 \
  --healthy-threshold-count 2 --unhealthy-threshold-count 2 \
  --query 'TargetGroups[0].TargetGroupArn' --output text)

# 2. Register the instances
aws elbv2 register-targets --target-group-arn $TG_ARN \
  --targets $(for i in $INSTANCES; do printf "Id=%s " $i; done)

# 3. The load balancer (internet-facing, two AZs)
read ALB_ARN ALB_DNS <<< $(aws elbv2 create-load-balancer --name web-alb --type application --scheme internet-facing \
  --subnets $SUBNET_A $SUBNET_B --security-groups $ALB_SG \
  --query 'LoadBalancers[0].[LoadBalancerArn,DNSName]' --output text)

# 4. Listener: HTTP 80 → forward to the target group
HTTP_LISTENER=$(aws elbv2 create-listener --load-balancer-arn $ALB_ARN --protocol HTTP --port 80 \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN --query 'Listeners[0].ListenerArn' --output text)

aws elbv2 wait load-balancer-available --load-balancer-arns $ALB_ARN
aws elbv2 describe-target-health --target-group-arn $TG_ARN \
  --query 'TargetHealthDescriptions[].[Target.Id,TargetHealth.State,TargetHealth.Reason]' --output table
```

When both targets show `healthy`:

```bash
for i in $(seq 6); do curl -s http://$ALB_DNS/; echo; done
# Hello from i-0aaa… in us-east-1a
# Hello from i-0bbb… in us-east-1b   ← requests alternate between servers
```

Now stop nginx on one instance (Session Manager: `sudo systemctl stop nginx`). Within about 30 seconds it turns `unhealthy`, and **all** traffic goes to the other server. Start it again, and it rejoins.

In the console, the same thing is **EC2 → Load Balancers → Create → Application Load Balancer**, filling in the same four pieces.

AWS docs: [Target groups](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html) · [Listeners](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-listeners.html)

## Path-based and host-based routing

> **In simple words:** One ALB can serve many apps. Rules look at the request (path `/api/*`, host `admin.example.com`, a header…) and send it to a different target group. Rules are checked in priority order, and the listener's **default action** handles everything else.

```bash
# A second target group for the "API" (here the same instances, serving /api/)
API_TG=$(aws elbv2 create-target-group --name lab-api-tg --protocol HTTP --port 80 --vpc-id $VPC_ID \
  --health-check-path /api/ --query 'TargetGroups[0].TargetGroupArn' --output text)
aws elbv2 register-targets --target-group-arn $API_TG --targets $(for i in $INSTANCES; do printf "Id=%s " $i; done)

# Path rule: /api/* → API target group
aws elbv2 create-rule --listener-arn $HTTP_LISTENER --priority 10 \
  --conditions Field=path-pattern,Values='/api/*' \
  --actions Type=forward,TargetGroupArn=$API_TG

# Host rule: admin.example.com → fixed response (handy for maintenance pages)
aws elbv2 create-rule --listener-arn $HTTP_LISTENER --priority 20 \
  --conditions Field=host-header,Values='admin.example.com' \
  --actions '[{"Type":"fixed-response","FixedResponseConfig":{"StatusCode":"503","ContentType":"text/plain","MessageBody":"Admin is under maintenance"}}]'

curl -s http://$ALB_DNS/api/
curl -s -H "Host: admin.example.com" http://$ALB_DNS/
aws elbv2 describe-rules --listener-arn $HTTP_LISTENER --query 'Rules[].[Priority,Conditions[0].Field,Actions[0].Type]' --output table
```

| Condition | Example |
|---|---|
| `path-pattern` | `/api/*`, `/images/*` |
| `host-header` | `api.example.com`, `*.example.com` |
| `http-header` | `X-Canary: true` |
| `query-string` | `?version=2` |
| `http-request-method` | `POST` |
| `source-ip` | `203.0.113.0/24` |

| Action | Does |
|---|---|
| `forward` | Send to one target group, or **weighted** across several (canary releases) |
| `redirect` | Return 301/302 to another URL (e.g. HTTP → HTTPS) |
| `fixed-response` | Return a static status and body |
| `authenticate-oidc` / `authenticate-cognito` | Make users log in before reaching the app |

## HTTPS with a free ACM certificate

> **In simple words:** Add a port 443 listener with a certificate, and redirect plain HTTP to HTTPS. The servers behind the ALB can keep speaking plain HTTP inside the VPC.

You need a domain and an **issued ACM certificate in the same Region**. See the [Route 53 guide](#/tool/aws-route53), step "HTTPS certificates with ACM".

```bash
CERT_ARN=arn:aws:acm:us-east-1:111122223333:certificate/xxxx   # your issued certificate

HTTPS_LISTENER=$(aws elbv2 create-listener --load-balancer-arn $ALB_ARN --protocol HTTPS --port 443 \
  --certificates CertificateArn=$CERT_ARN --ssl-policy ELBSecurityPolicy-TLS13-1-2-2021-06 \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN --query 'Listeners[0].ListenerArn' --output text)

# Redirect all HTTP to HTTPS
aws elbv2 modify-listener --listener-arn $HTTP_LISTENER --default-actions \
  '[{"Type":"redirect","RedirectConfig":{"Protocol":"HTTPS","Port":"443","StatusCode":"HTTP_301"}}]'
```

Then point your domain at the ALB with a Route 53 **alias** record, and open `https://your-domain`.

## Network Load Balancer example

> **In simple words:** An NLB passes TCP connections straight through, extremely fast, with **one fixed IP per AZ** that never changes. That's handy when a partner must allow-list your IP, or for non-HTTP protocols.

```bash
NLB_TG=$(aws elbv2 create-target-group --name lab-nlb-tg --protocol TCP --port 80 --vpc-id $VPC_ID \
  --target-type instance --query 'TargetGroups[0].TargetGroupArn' --output text)
aws elbv2 register-targets --target-group-arn $NLB_TG --targets $(for i in $INSTANCES; do printf "Id=%s " $i; done)

NLB_SG=$(aws ec2 create-security-group --group-name lab-nlb-sg --description "NLB" --vpc-id $VPC_ID --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id $NLB_SG --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $WEB_SG --protocol tcp --port 80 --source-group $NLB_SG

read NLB_ARN NLB_DNS <<< $(aws elbv2 create-load-balancer --name web-nlb --type network --scheme internet-facing \
  --subnets $SUBNET_A $SUBNET_B --security-groups $NLB_SG \
  --query 'LoadBalancers[0].[LoadBalancerArn,DNSName]' --output text)
aws elbv2 create-listener --load-balancer-arn $NLB_ARN --protocol TCP --port 80 \
  --default-actions Type=forward,TargetGroupArn=$NLB_TG
aws elbv2 wait load-balancer-available --load-balancer-arns $NLB_ARN

dig $NLB_DNS +short          # one static IP per AZ
curl -s http://$NLB_DNS/
```

- Use `--subnet-mappings SubnetId=…,AllocationId=eipalloc-…` to give each AZ **your own Elastic IP**.
- NLBs keep the **client's real IP** for instance targets. The server sees the user's address, not the load balancer's.
- A **TLS listener** on an NLB can terminate HTTPS too, without HTTP-level routing.

AWS docs: [NLB security groups](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/load-balancer-security-groups.html)

## Health checks, stickiness and other settings

> **In simple words:** A few target group settings decide how quickly bad servers are removed, whether a user keeps hitting the same server, and how gently servers are taken out during deployments.

| Setting | What it does | Good default |
|---|---|---|
| Health check path / port / codes | What "healthy" means, e.g. `GET /health` → `200` | A cheap endpoint that also checks dependencies lightly |
| Interval and thresholds | How fast unhealthy targets are detected | 15s interval, 2 healthy / 2 unhealthy |
| **Deregistration delay** | Time to finish in-flight requests before a target is removed | 30–60s (default 300s is often too slow for deployments) |
| **Stickiness** | Sends the same user to the same target (cookie) | Off, unless the app keeps session state in memory |
| **Cross-zone load balancing** | Spreads evenly across all targets in all AZs | On (always on for ALB; optional for NLB) |
| **Slow start** | Ramps traffic gradually to new targets | 30–60s for apps with cold caches |
| **Access logs** | Every request written to S3 | On in production |

```bash
aws elbv2 modify-target-group --target-group-arn $TG_ARN --health-check-path /health --matcher HttpCode=200
aws elbv2 modify-target-group-attributes --target-group-arn $TG_ARN --attributes \
  Key=deregistration_delay.timeout_seconds,Value=30 \
  Key=stickiness.enabled,Value=true Key=stickiness.type,Value=lb_cookie
```

AWS docs: [Health checks](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-health-checks.html)

## Load balancers with Auto Scaling, ECS and Kubernetes

> **In simple words:** In real setups you rarely register servers by hand. Auto Scaling groups, ECS services and Kubernetes controllers add and remove targets for you automatically.

| Platform | How targets get registered |
|---|---|
| **EC2 Auto Scaling group** | Pass `--target-group-arns` when creating the ASG. New instances join automatically, and failing ones are replaced |
| **ECS service** | `--load-balancers targetGroupArn=…,containerName=…,containerPort=…` (target type `ip` for Fargate). See the [ECS guide](#/tool/aws-ecs) |
| **EKS (Kubernetes)** | The **AWS Load Balancer Controller** creates an **ALB for each Ingress** and an **NLB for each Service** of `type: LoadBalancer` |

Kubernetes Ingress that becomes an ALB (with the controller installed):

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:111122223333:certificate/xxxx
    alb.ingress.kubernetes.io/ssl-redirect: "443"
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web
                port:
                  number: 80
```

And a Service that becomes an NLB:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: tcp-app
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: external
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
spec:
  type: LoadBalancer
  selector:
    app: tcp-app
  ports:
    - port: 80
      targetPort: 8080
```

The controller needs AWS permissions through **Pod Identity or IRSA** (see the [IAM guide](#/tool/aws-iam)).

AWS docs: [AWS Load Balancer Controller](https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html)

## Troubleshooting

> **In simple words:** The HTTP error code tells you where to look. **502/503/504** errors come from the load balancer and mean the problem is between it and your servers. Unhealthy targets explain most of them.

| Symptom | Meaning / fix |
|---|---|
| **503 Service Unavailable** | No healthy targets in the group, or no targets at all. Check `describe-target-health` |
| **502 Bad Gateway** | The target closed the connection or sent an invalid response. Check app logs, keep-alive timeouts and crashes |
| **504 Gateway Timeout** | The target didn't answer in time. A slow app or a blocked security group (ALB → target port) |
| Targets stuck `unhealthy` | Health check path returns non-200, the wrong port, or the **target's security group doesn't allow the LB** |
| `Target.Timeout` in health reason | Security group or NACL blocking. Allow the LB's security group on the target port |
| Can't reach the ALB at all | Its security group doesn't allow 80/443 from the internet, or it's `internal` |
| HTTPS listener fails to create | Certificate in a different Region, or not yet issued |
| Users lose their session | The app keeps sessions in memory. Enable stickiness, or better, store sessions in Redis or DynamoDB |

```bash
aws elbv2 describe-target-health --target-group-arn $TG_ARN --output table
aws elbv2 describe-load-balancers --names web-alb --query 'LoadBalancers[0].State'
aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name HTTPCode_ELB_5XX_Count \
  --dimensions Name=LoadBalancer,Value=$(echo $ALB_ARN | cut -d/ -f2-) \
  --start-time $(date -u -d '-1 hour' +%FT%TZ) --end-time $(date -u +%FT%TZ) --period 300 --statistics Sum
```

## Clean up

> **In simple words:** Delete in reverse order: load balancers (listeners and rules go with them), then target groups, instances and security groups. Load balancers bill every hour they exist.

```bash
aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN
aws elbv2 delete-load-balancer --load-balancer-arn $NLB_ARN
aws elbv2 wait load-balancers-deleted --load-balancer-arns $ALB_ARN $NLB_ARN
for tg in $TG_ARN $API_TG $NLB_TG; do aws elbv2 delete-target-group --target-group-arn $tg; done

aws ec2 terminate-instances --instance-ids $INSTANCES
aws ec2 wait instance-terminated --instance-ids $INSTANCES
for sg in $WEB_SG $ALB_SG $NLB_SG; do aws ec2 delete-security-group --group-id $sg; done

aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName'   # should be empty
```

If a security group refuses to delete, wait a minute: the load balancer's network interfaces take a little while to disappear.

## Lab: highly available website

> **In simple words:** Practice time: build a two-AZ website behind an ALB with HTTPS, routing rules and a failure test.

1. Launch two web servers in two AZs whose security group allows port 80 **only** from the ALB.
2. Create an ALB with a target group and a health check on `/`. Refresh the DNS name and watch it alternate between servers.
3. Add a rule sending `/api/*` to a second target group.
4. Stop nginx on one server: it goes unhealthy and users see no errors. Start it again.
5. With a domain: request an ACM certificate, add an HTTPS listener, redirect HTTP → HTTPS, and create a Route 53 alias record.
6. Create an NLB for the same servers and note its static IPs with `dig`.
7. Explain in your own words when you'd choose ALB vs NLB vs GWLB.
8. Clean up everything.

### Cheat sheet

| Task | Command |
|---|---|
| Create target group | `aws elbv2 create-target-group --name tg --protocol HTTP --port 80 --vpc-id vpc` |
| Register targets | `aws elbv2 register-targets --target-group-arn TG --targets Id=i-1 Id=i-2` |
| Create ALB / NLB | `aws elbv2 create-load-balancer --name n --type application\|network --subnets s1 s2` |
| Listener | `aws elbv2 create-listener --load-balancer-arn LB --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=TG` |
| Path rule | `aws elbv2 create-rule --listener-arn L --priority 10 --conditions Field=path-pattern,Values='/api/*' --actions Type=forward,TargetGroupArn=TG2` |
| Target health | `aws elbv2 describe-target-health --target-group-arn TG` |
