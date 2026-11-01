# Capstone: End-to-End Delivery on AWS

This project ties every guide together into the workflow you'd find on a real platform team. When you finish, a `git push` to your app repo will build a container, publish it to ECR, and have Argo CD roll it out to an EKS cluster that Terraform created, with no manual `kubectl` in the delivery path.

> **Cost:** This project runs an EKS cluster, EC2 nodes and a load balancer. Expect a few dollars per day. Do it in a focused session or two, and **run the final cleanup step**.

## Start here: the big picture in simple words

> **In simple words:** This project connects everything you learned into one automatic "assembly line". A developer changes the code, and a few minutes later the new version is live on a real cloud server, with no manual steps.

### The journey of one code change

1. **A developer edits the app** on their laptop and pushes the change to GitHub. *(Git)*
2. **GitHub Actions** notices the push, builds a fresh Docker image and uploads it to AWS ECR. *(Docker, AWS)*
3. **CI writes the new image version** into the GitOps repository. *(Git)*
4. **Argo CD** sees the change in Git and tells Kubernetes to use the new image. *(Argo CD)*
5. **Kubernetes** swaps the old copies for new ones, one at a time, so users never see downtime. *(Kubernetes)*
6. **All of it runs** on AWS servers and networks that **Terraform** built from code. *(Terraform, AWS)*

**Think of it like this:** a car factory. Terraform builds the factory, Docker makes the standard boxes, GitHub Actions is the conveyor belt, Argo CD is the shift supervisor following the plan, and Kubernetes is the floor team doing the work.

### Before you start

- Finish the earlier guides, or at least their labs. This project assumes them.
- Work through the phases **in order**, and check each **Checkpoint** before moving on.
- This uses real AWS resources that cost money. Do it in one or two sittings and **always run the Cleanup step**.

## Target architecture

> **In simple words:** A map of what you're building and which tool is responsible for each part.

```text
 app repo ──push──▶ GitHub Actions ──build+push──▶ Amazon ECR
     │                    │
     │                    └──commit new image tag──▶ gitops repo
     │                                                   │
     │                         Argo CD (in EKS) ◀──pull──┘
     │                                │ sync
     ▼                                ▼
 Terraform ──creates──▶ VPC + EKS cluster + ECR + IAM (OIDC role for CI)
```

| Layer | Tool | Guide |
|---|---|---|
| Infrastructure | Terraform: VPC, EKS, ECR, IAM | Terraform, AWS |
| Packaging | Dockerfile, multi-stage, non-root | Docker |
| CI | GitHub Actions with AWS OIDC (no stored keys) | Terraform (CI step) |
| Runtime | Kubernetes Deployment, Service, Ingress, HPA | Kubernetes |
| CD | Argo CD app-of-apps, auto-sync | Argo CD |
| Ops skills | Logs, debugging, cleanup | Linux, all |

## Repositories

> **In simple words:** Three Git repositories with separate jobs: one for infrastructure, one for the app's code, and one describing what runs in the cluster.

Create three repos (or three folders in one monorepo):

```text
platform-infra/      # Terraform
  ├── bootstrap/     # state bucket
  └── envs/dev/      # vpc, eks, ecr, iam
hello-app/           # application source + Dockerfile + CI workflow
gitops/              # what runs in the cluster
  ├── apps/          # Argo CD Applications (app-of-apps)
  └── hello/         # Helm chart or Kustomize for hello-app
      ├── base/
      └── dev/
```

## Phase 1: Infrastructure with Terraform

> **In simple words:** Use Terraform to build the network, the Kubernetes cluster and the image store in AWS, all from code.

In `platform-infra/envs/dev`, use the community modules:

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name               = "capstone"
  cidr               = "10.20.0.0/16"
  azs                = ["us-east-1a", "us-east-1b"]
  private_subnets    = ["10.20.1.0/24", "10.20.2.0/24"]
  public_subnets     = ["10.20.101.0/24", "10.20.102.0/24"]
  enable_nat_gateway = true
  single_nat_gateway = true          # cheaper for non-prod

  public_subnet_tags  = { "kubernetes.io/role/elb" = 1 }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1 }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name                   = "capstone"
  kubernetes_version     = "1.33"
  endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.medium"]
      min_size       = 2
      max_size       = 3
      desired_size   = 2
    }
  }
}

resource "aws_ecr_repository" "hello" {
  name                 = "hello-app"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
}
```

> **Note:** Module input names change between major versions. Check the module's README on the Terraform Registry for the version you pin, and run `terraform validate` early. Use a Kubernetes version that EKS currently supports.

Then:

```bash
terraform init && terraform apply            # ~15-20 min
aws eks update-kubeconfig --name capstone --region us-east-1
kubectl get nodes
```

**Checkpoint:** two `Ready` nodes, and an empty ECR repo.

## Phase 2: CI with GitHub Actions and OIDC

> **In simple words:** Make GitHub build and upload a new image on every push. OIDC lets GitHub log into AWS safely without storing any passwords.

Let GitHub Actions assume an AWS role without any stored keys. Add this to Terraform:

```hcl
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "gha_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:<your-github-user>/hello-app:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "gha_ecr_push" {
  name               = "gha-hello-app-ecr-push"
  assume_role_policy = data.aws_iam_policy_document.gha_trust.json
}

resource "aws_iam_role_policy_attachment" "ecr_push" {
  role       = aws_iam_role.gha_ecr_push.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}
```

In `hello-app/.github/workflows/build.yaml`:

```yaml
name: build-and-release
on:
  push:
    branches: [main]
permissions:
  id-token: write
  contents: read
env:
  AWS_REGION: us-east-1
  ECR_REPO: hello-app
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::<ACCOUNT_ID>:role/gha-hello-app-ecr-push
          aws-region: ${{ env.AWS_REGION }}
      - id: ecr
        uses: aws-actions/amazon-ecr-login@v2
      - name: Build and push
        run: |
          IMAGE=${{ steps.ecr.outputs.registry }}/${{ env.ECR_REPO }}:${GITHUB_SHA::7}
          docker build -t $IMAGE .
          docker push $IMAGE
      - name: Bump tag in gitops repo
        env:
          GH_TOKEN: ${{ secrets.GITOPS_TOKEN }}   # fine-grained PAT with contents:write on gitops repo
        run: |
          git clone https://x-access-token:${GH_TOKEN}@github.com/<you>/gitops.git
          cd gitops/hello/dev
          kustomize edit set image hello-app=${{ steps.ecr.outputs.registry }}/${{ env.ECR_REPO }}:${GITHUB_SHA::7}
          git config user.name "ci-bot" && git config user.email "ci-bot@users.noreply.github.com"
          git commit -am "hello-app: deploy ${GITHUB_SHA::7}" && git push
```

**Checkpoint:** pushing to `hello-app` puts a new image in ECR and creates a commit in `gitops`.

## Phase 3: Kubernetes manifests

> **In simple words:** Write the files that tell Kubernetes how to run your app: how many copies, health checks, and how visitors reach it.

In `gitops/hello/base`, write a Deployment (3 replicas, requests and limits, readiness and liveness probes, non-root `securityContext`), a ClusterIP Service, and an HPA. In `gitops/hello/dev/kustomization.yaml`:

```yaml
resources:
  - ../base
namespace: hello-dev
images:
  - name: hello-app
    newName: <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/hello-app
    newTag: "initial"
```

Expose it with one of these:

- a Service of `type: LoadBalancer` (simplest: creates an AWS load balancer), or
- install the **AWS Load Balancer Controller** and use an Ingress with `ingressClassName: alb`.

> **Tip:** EKS nodes can pull from ECR in the same account out of the box, because the node role includes ECR read-only access. No image pull secret needed.

## Phase 4: Argo CD delivery

> **In simple words:** Connect Argo CD to your GitOps repository, so every new image version is deployed automatically.

1. Install Argo CD on EKS (Argo CD guide, install step), ideally with Helm.
2. In `gitops/apps/` create `hello-dev.yaml` pointing at `hello/dev`, with automated sync, prune and self-heal.
3. Create and apply the **root** app-of-apps pointing at `gitops/apps`.

```bash
kubectl apply -f gitops/apps/root.yaml
argocd app list
kubectl get svc -n hello-dev        # grab the load balancer hostname
curl http://<elb-hostname>/
```

**The full loop:** change the response message in `hello-app`, push to `main`, and watch:

1. GitHub Actions builds and pushes `hello-app:<sha>`.
2. CI commits the new tag to `gitops`.
3. Argo CD detects the change and syncs.
4. Kubernetes performs a rolling update.
5. `curl` returns the new message.

## Phase 5: Operate it

> **In simple words:** Practise real-life situations: a bad release, a traffic spike and a manual change, and see how the system reacts.

Prove you can run what you built:

- **Break it:** push an image whose `/health` returns 500. What happens to the rollout? Use `kubectl describe`, `kubectl logs` and the Argo CD UI to explain it, then fix it with `git revert`.
- **Scale it:** generate load (`kubectl run load --rm -it --image=busybox:1.36 -- sh -c "while true; do wget -qO- http://hello.hello-dev; done"`) and watch the HPA scale out.
- **Drift:** `kubectl edit` the deployment's replicas and watch self-heal revert it.
- **Observe:** check node and pod metrics with `kubectl top`, and the control plane logs in CloudWatch.
- **Document:** write a `README.md` in each repo explaining how to run, deploy and roll back. Explaining it in writing is what makes the knowledge stick.

## Cleanup

> **In simple words:** Delete everything in the right order so nothing is left running and costing money.

Delete in this order. Kubernetes-created load balancers must go **before** Terraform destroys the VPC, otherwise the destroy hangs on dependencies.

```bash
# 1. Remove apps (deletes the AWS load balancers they created)
kubectl delete -f gitops/apps/root.yaml
kubectl delete ns hello-dev
kubectl get svc -A | grep LoadBalancer      # should be empty

# 2. Remove images, then destroy infrastructure
aws ecr batch-delete-image --repository-name hello-app \
  --image-ids "$(aws ecr list-images --repository-name hello-app --query 'imageIds[*]' --output json)"
cd platform-infra/envs/dev && terraform destroy

# 3. Double-check nothing is left
aws eks list-clusters
aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName'
aws ec2 describe-nat-gateways --filter Name=state,Values=available --query 'NatGateways[].NatGatewayId'
```

### You're done

You have built and operated a production-shaped delivery platform. Good next topics:

- **Observability:** Prometheus, Grafana, Loki, OpenTelemetry
- **Security:** policy as code (Kyverno / OPA Gatekeeper), image signing (cosign), External Secrets
- **Progressive delivery:** Argo Rollouts for canary and blue-green releases
- **Scaling:** Karpenter for nodes, KEDA for event-driven pods
- **Certifications:** AWS Solutions Architect Associate, CKA / CKAD, Terraform Associate
