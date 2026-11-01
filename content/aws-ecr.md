# Amazon ECR: Container Registry

Amazon ECR (Elastic Container Registry) is AWS's private Docker registry. It stores your container images next to where they run (ECS, EKS, Lambda and EC2) with IAM permissions, vulnerability scanning, automatic cleanup and replication built in. This guide covers repositories, pushing and pulling, tags vs digests, scanning, lifecycle policies, permissions, caching public images and CI usage.

> **Note:** You need Docker and the AWS CLI configured. The examples use the **sample app** from [CI/CD Basics](#/tool/cicd-basics); any image works.

> **Cost:** Storage is about **$0.10 per GB-month**. Pulls from the same Region by AWS services are free; data transfer to the internet or other Regions is charged. Lifecycle policies keep storage small. See [ECR pricing](https://aws.amazon.com/ecr/pricing/).

## Start here: ECR in simple words

> **In simple words:** ECR is a **private Docker Hub inside your AWS account**. You push images to it from your laptop or CI, and your servers, ECS and Kubernetes pull them. Access is controlled by IAM, so there are no extra registry passwords to manage.

### How it fits

```text
 laptop / CI ──docker push──▶  ECR repository  ──pull──▶  ECS tasks / EKS pods / EC2 / Lambda
                               111122223333.dkr.ecr.us-east-1.amazonaws.com/hello-app:1.0.0
                               ├─ scan for vulnerabilities on push
                               ├─ lifecycle policy deletes old images
                               └─ replicate to another Region (optional)
```

### Key words

| Word | Simple meaning |
|---|---|
| **Registry** | Your account's ECR endpoint in one Region: `<account>.dkr.ecr.<region>.amazonaws.com` |
| **Repository** | One image name, such as `hello-app`, holding many versions |
| **Tag** | A human label on an image version, such as `1.0.0` or `sha-1a2b3c4` |
| **Digest** | The image's unique fingerprint, `sha256:…`. It never changes |
| **Image manifest** | The description of an image's layers; multi-arch images have a list of them |
| **Lifecycle policy** | Rules that delete old or untagged images automatically |
| **Pull-through cache** | ECR fetches and caches images from public registries for you |

### Check yourself

1. What's the difference between a tag and a digest?
2. How do you log Docker in to ECR without a password?
3. Why use a lifecycle policy?

> **Tip:** Answers: 1) A tag is a movable label; a digest is the fixed fingerprint of exact content. 2) `aws ecr get-login-password` creates a 12-hour token from your IAM credentials. 3) To delete old images automatically and keep storage costs down.

## Create a repository

> **In simple words:** One repository per application image. Turn on scan-on-push and immutable tags from day one.

```bash
export AWS_REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGISTRY=$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

aws ecr create-repository --repository-name hello-app \
  --image-tag-mutability IMMUTABLE \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256 \
  --tags Key=team,Value=platform

aws ecr describe-repositories --repository-names hello-app \
  --query 'repositories[0].[repositoryUri,imageTagMutability,imageScanningConfiguration.scanOnPush]' --output table
```

| Setting | Recommended | Why |
|---|---|---|
| **Tag immutability** | `IMMUTABLE` | Nobody can overwrite `1.0.0` with different content, so a tag always means the same image |
| **Scan on push** | On | Every new image is checked for known vulnerabilities |
| **Encryption** | `AES256`, or `KMS` with your own key | Images are encrypted at rest either way; KMS adds your own key policy and audit |

Repository names can contain slashes for organisation: `team-a/hello-app`, `team-b/worker`.

AWS docs: [What is Amazon ECR?](https://docs.aws.amazon.com/AmazonECR/latest/userguide/what-is-ecr.html)

## Log in, push and pull

> **In simple words:** Docker needs a login before it can push. ECR gives you a temporary 12-hour password generated from your IAM identity. Then you tag the image with the repository's full address and push.

```bash
# 1. Log Docker in (valid 12 hours)
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $REGISTRY

# 2. Build and tag with the full repository URI
cd ~/code/hello-app
docker build -t hello-app:1.0.0 .
docker tag hello-app:1.0.0 $REGISTRY/hello-app:1.0.0

# 3. Push
docker push $REGISTRY/hello-app:1.0.0

# 4. Pull (anywhere with ECR permissions)
docker pull $REGISTRY/hello-app:1.0.0

aws ecr list-images --repository-name hello-app
aws ecr describe-images --repository-name hello-app \
  --query 'imageDetails[].[imageTags[0],imageDigest,imageSizeInBytes,imagePushedAt]' --output table
```

> **Tip:** Building on an Apple Silicon Mac for x86 servers? Use `docker build --platform linux/amd64 …`, or build a multi-arch image with `docker buildx build --platform linux/amd64,linux/arm64 --push …`. Otherwise containers fail with `exec format error`.

> **Tip:** Tired of `docker login`? The **Amazon ECR Docker Credential Helper** (`amazon-ecr-credential-helper`) gets tokens automatically from your AWS credentials.

AWS docs: [Private registry authentication](https://docs.aws.amazon.com/AmazonECR/latest/userguide/registry_auth.html)

## Tags, digests and immutability

> **In simple words:** A tag is a sticky note that could move to a different image; a digest is the image's fingerprint and can't. With immutable tags, the sticky note can't move either, which makes deployments predictable.

```bash
# Try to overwrite an existing tag (fails with IMMUTABLE)
docker tag hello-app:1.0.0 $REGISTRY/hello-app:1.0.0 && docker push $REGISTRY/hello-app:1.0.0
# → tag invalid: The image tag '1.0.0' already exists … cannot be overwritten because the repository is immutable

# Pull by digest: guaranteed exact content
DIGEST=$(aws ecr describe-images --repository-name hello-app --image-ids imageTag=1.0.0 \
  --query 'imageDetails[0].imageDigest' --output text)
docker pull $REGISTRY/hello-app@$DIGEST
```

Good tagging scheme:

| Tag | Example | Purpose |
|---|---|---|
| Git SHA | `sha-1a2b3c4` | Traceable to the exact commit, set by CI |
| Semantic version | `1.4.2` | Human-friendly releases |
| Environment pointer | `prod`, `staging` | Only in **mutable** repos, or use a separate repo per environment |
| `latest` | `latest` | Convenient locally; **avoid in deployments** |

AWS docs: [Image tag mutability](https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-tag-mutability.html)

## Vulnerability scanning

> **In simple words:** ECR checks your images against databases of known security holes in operating system and language packages, and lists what it finds by severity.

| Mode | How | Covers |
|---|---|---|
| **Basic** | On push, or on demand | Operating system packages |
| **Enhanced** (Amazon Inspector) | **Continuous**: rescans when new vulnerabilities are published | OS **and** language packages (pip, npm, Maven…). Inspector charges apply |

```bash
aws ecr start-image-scan --repository-name hello-app --image-id imageTag=1.0.0    # manual scan
aws ecr wait image-scan-complete --repository-name hello-app --image-id imageTag=1.0.0
aws ecr describe-image-scan-findings --repository-name hello-app --image-id imageTag=1.0.0 \
  --query 'imageScanFindings.findingSeverityCounts'
aws ecr describe-image-scan-findings --repository-name hello-app --image-id imageTag=1.0.0 \
  --query 'imageScanFindings.findings[?severity==`HIGH`].[name,uri]' --output table

# Turn on enhanced (continuous) scanning for the whole registry
aws ecr put-registry-scanning-configuration --scan-type ENHANCED \
  --rules '[{"scanFrequency":"CONTINUOUS_SCAN","repositoryFilters":[{"filter":"*","filterType":"WILDCARD"}]}]'
```

How to reduce findings: use slim or distroless base images, rebuild regularly to pick up patched base images, and pin and update dependencies.

AWS docs: [Image scanning](https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-scanning.html)

## Lifecycle policies: automatic cleanup

> **In simple words:** Every CI build pushes a new image, and storage grows forever. A lifecycle policy deletes old images by rule, for example "keep the last 30 releases, delete untagged images after 7 days".

Save as `lifecycle.json`:

```json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Delete untagged images after 7 days",
      "selection": { "tagStatus": "untagged", "countType": "sinceImagePushed", "countUnit": "days", "countNumber": 7 },
      "action": { "type": "expire" }
    },
    {
      "rulePriority": 2,
      "description": "Keep only the last 30 CI builds",
      "selection": { "tagStatus": "tagged", "tagPrefixList": ["sha-"], "countType": "imageCountMoreThan", "countNumber": 30 },
      "action": { "type": "expire" }
    }
  ]
}
```

```bash
# Preview what WOULD be deleted, before applying
aws ecr start-lifecycle-policy-preview --repository-name hello-app --lifecycle-policy-text file://lifecycle.json
aws ecr get-lifecycle-policy-preview --repository-name hello-app --query 'previewResults[].[imageTags[0],action.type]'

aws ecr put-lifecycle-policy --repository-name hello-app --lifecycle-policy-text file://lifecycle.json
```

Release tags like `1.4.2` aren't matched by the rules above, so they're kept.

AWS docs: [Lifecycle policies](https://docs.aws.amazon.com/AmazonECR/latest/userguide/LifecyclePolicies.html)

## Permissions: IAM and repository policies

> **In simple words:** IAM decides what your own users and roles may do. A **repository policy** is attached to the repo itself and is mainly used to let **other AWS accounts** pull.

AWS managed policies you'll attach most often:

| Policy | Allows | Give it to |
|---|---|---|
| `AmazonEC2ContainerRegistryReadOnly` | Pull (and describe) | EKS nodes, EC2 servers |
| `AmazonEC2ContainerRegistryPullOnly` | Pull only | Workloads that only pull |
| `AmazonEC2ContainerRegistryPowerUser` | Push and pull, no delete or repo admin | CI pipelines |
| `AmazonECSTaskExecutionRolePolicy` | Pull plus write logs | ECS task execution role |

Repository policy letting another account pull, `repo-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowProdAccountPull",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::444455556666:root" },
      "Action": ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability"]
    }
  ]
}
```

```bash
aws ecr set-repository-policy --repository-name hello-app --policy-text file://repo-policy.json
aws ecr get-repository-policy --repository-name hello-app
```

The other account also needs an IAM policy allowing those actions plus `ecr:GetAuthorizationToken`.

AWS docs: [Repository policies](https://docs.aws.amazon.com/AmazonECR/latest/userguide/repository-policies.html)

## Pull-through cache and replication

> **In simple words:** **Pull-through cache** makes ECR fetch public images (from ECR Public, Docker Hub, Kubernetes registry…) once and keep a copy in your account. That's faster, avoids Docker Hub rate limits, and the copies get scanned. **Replication** copies your images to other Regions or accounts automatically.

```bash
# Cache images from ECR Public under the prefix "ecr-public"
aws ecr create-pull-through-cache-rule --ecr-repository-prefix ecr-public --upstream-registry-url public.ecr.aws

# Pull nginx through your cache (the repo is created automatically on first pull)
docker pull $REGISTRY/ecr-public/docker/library/nginx:latest
aws ecr describe-repositories --query "repositories[?starts_with(repositoryName,'ecr-public/')].repositoryName"
```

Docker Hub and GitHub Container Registry upstreams need credentials stored in **Secrets Manager** (name prefix `ecr-pullthroughcache/`).

Replicate every repository to another Region:

```bash
aws ecr put-replication-configuration --replication-configuration '{
  "rules": [{ "destinations": [{ "region": "us-west-2", "registryId": "'$ACCOUNT_ID'" }] }]
}'
```

AWS docs: [Pull-through cache](https://docs.aws.amazon.com/AmazonECR/latest/userguide/pull-through-cache.html) · [Replication](https://docs.aws.amazon.com/AmazonECR/latest/userguide/replication.html)

## Using ECR from CI, ECS and EKS

> **In simple words:** Each consumer just needs the right IAM permission. There are no registry passwords to distribute.

| Consumer | How it gets access |
|---|---|
| **GitHub Actions** | OIDC role with push rights, then `aws-actions/amazon-ecr-login`. See the [GitHub Actions guide](#/tool/github-actions) |
| **GitLab CI / Jenkins** | An IAM role (OIDC or instance role) with push rights, then `aws ecr get-login-password \| docker login …` |
| **ECS (Fargate/EC2)** | The **task execution role** pulls the image. See the [ECS guide](#/tool/aws-ecs) |
| **EKS nodes** | The node IAM role has `AmazonEC2ContainerRegistryReadOnly` (eksctl and EKS add it by default) |
| **EC2 server** | Instance role with pull rights, then `docker login` with `get-login-password` |

Kubernetes Deployments just use the full URI: `image: 111122223333.dkr.ecr.us-east-1.amazonaws.com/hello-app:1.0.0`.

## Troubleshooting

> **In simple words:** Most ECR errors are "not logged in", "no permission", "wrong Region or account in the URI" or "tag already exists".

| Error | Fix |
|---|---|
| `no basic auth credentials` | Run the `get-login-password \| docker login` command (tokens expire after 12 hours) |
| `denied: User … is not authorized to perform: ecr:InitiateLayerUpload` | The identity can't push. Attach PowerUser or a custom push policy |
| `name unknown: The repository … does not exist` | Create the repo first, or fix the Region or account ID in the URI |
| `tag invalid … cannot be overwritten` | The repo has immutable tags. Use a new tag |
| `manifest unknown` | That tag doesn't exist (`aws ecr list-images` to check) |
| `exec format error` when the container starts | Image built for the wrong CPU architecture. Rebuild with `--platform` |
| ECS: `CannotPullContainerError` | Task execution role missing, or the task has no route to ECR (no public IP and no NAT or VPC endpoints) |
| EKS: `ImagePullBackOff` with 403 | Node role lacks ECR read access, or a cross-account repo policy is missing |

## Clean up

> **In simple words:** Delete images and repositories you created. Storage keeps billing until they're gone.

```bash
aws ecr batch-delete-image --repository-name hello-app --image-ids imageTag=1.0.0
aws ecr delete-repository --repository-name hello-app --force          # --force deletes remaining images
aws ecr delete-pull-through-cache-rule --ecr-repository-prefix ecr-public
for r in $(aws ecr describe-repositories --query "repositories[?starts_with(repositoryName,'ecr-public/')].repositoryName" --output text); do
  aws ecr delete-repository --repository-name $r --force; done
aws ecr put-replication-configuration --replication-configuration '{"rules":[]}'
```

## Lab: a production-ready repository

> **In simple words:** Practice time: set up a repository the way a platform team would, and push to it from CI.

1. Create `hello-app` with **immutable tags** and **scan on push**.
2. Push `1.0.0` and `sha-<short-sha>` tags of the sample app; try to overwrite `1.0.0` and see it rejected.
3. Read the scan findings. Switch the base image to a newer slim version, push again, and compare the counts.
4. Add the lifecycle policy, preview it, then apply it.
5. Configure a pull-through cache for ECR Public and pull `nginx` through it.
6. From GitHub Actions (OIDC) or GitLab CI, push an image on every commit to `main`.
7. Run the image on ECS (next guide) or EKS straight from ECR.

### Cheat sheet

| Task | Command |
|---|---|
| Create repo | `aws ecr create-repository --repository-name app --image-tag-mutability IMMUTABLE --image-scanning-configuration scanOnPush=true` |
| Docker login | `aws ecr get-login-password \| docker login --username AWS --password-stdin ACCT.dkr.ecr.REGION.amazonaws.com` |
| Push | `docker tag app:1 URI:1 && docker push URI:1` |
| List images | `aws ecr describe-images --repository-name app` |
| Scan results | `aws ecr describe-image-scan-findings --repository-name app --image-id imageTag=1` |
| Lifecycle | `aws ecr put-lifecycle-policy --repository-name app --lifecycle-policy-text file://l.json` |
