# Terraform

Terraform describes infrastructure in code (HCL), works out what needs to change, and makes it so. Instead of clicking through the console or writing long CLI scripts, you **declare** the end state ("a VPC with 4 subnets and an EKS cluster"). Terraform creates it, tracks it in **state**, and can rebuild or destroy it on demand.

> **Note:** You need the AWS CLI configured (`aws sts get-caller-identity` works) before starting. Terraform uses the same credentials.

> **Tip:** No Docker or Kubernetes on your laptop? Use the **cloud lab machine** in the [Practice lab](#/lab). It has Docker, kind, kubectl, Helm, Terraform, the AWS CLI and the Argo CD CLI ready to go.

## Start here: Terraform in simple words

> **In simple words:** Terraform lets you **write down** the cloud setup you want (servers, networks, databases) in a text file. Terraform then builds it for you, can show you every change before it happens, and can delete it all with one command.

### The problem Terraform solves

Building cloud infrastructure by clicking in the AWS console works once, but:

- Nobody remembers exactly which buttons were clicked.
- Building the same thing again for "test" and "production" gives slightly different results.
- Forgotten resources keep costing money.

With Terraform, the **file is the instructions**. Anyone can read it, review it, and rebuild exactly the same thing again.

### A real-life comparison

Clicking in the console is like **cooking without a recipe**: it might taste good, but you can't repeat it exactly. Terraform is **the written recipe**, and Terraform is also the chef who follows it perfectly every time.

It's **declarative**: you describe *what* you want ("2 servers and 1 network"), not *how* to build it step by step. It's like ordering in a restaurant: you say "pasta, please", not "boil water, add salt…".

### How it works

```text
  main.tf  ──terraform plan──▶  "Here's what I WILL do: +2 create, ~1 change"
 (your wish)                         │  you review it
                         terraform apply ▼
                         AWS builds the resources
                                     │
                         terraform.tfstate  ◀── Terraform's notebook of what it built
```

### Key words

| Word | Simple meaning |
|---|---|
| **HCL / `.tf` file** | The language and files where you write what you want |
| **Provider** | A plug-in that teaches Terraform to talk to a platform (AWS, Azure, GitHub…) |
| **Resource** | One thing to create, like a server or a bucket |
| **Variable** | A blank to fill in, so one file can be reused with different values |
| **Output** | A value printed at the end, like a server's IP address |
| **State** | Terraform's notebook listing what it created, so it knows what to change next time |
| **Plan** | A preview of changes. Nothing is built yet |
| **Apply** | Actually make the changes |
| **Destroy** | Delete everything this code created |
| **Module** | A reusable folder of Terraform code, like a recipe you share with others |

### The four commands you'll use 90% of the time

| Command | Meaning |
|---|---|
| `terraform init` | Get ready: download the plug-ins |
| `terraform plan` | Show me what would change |
| `terraform apply` | Do it |
| `terraform destroy` | Undo everything |

### Check yourself

1. What does `terraform plan` do, and does it change anything?
2. What is the state file for?
3. Why is Terraform better than clicking in the console for a team?

> **Tip:** Answers: 1) It previews the changes and changes nothing. 2) It's Terraform's record of what it built, so it knows what to update or delete. 3) The setup is written down, reviewable, repeatable and easy to delete.

## Why Infrastructure as Code

> **In simple words:** Infrastructure as Code means describing servers and networks in files instead of clicking, so the setup can be reviewed, repeated and undone.

| Click-ops | Infrastructure as Code |
|---|---|
| Undocumented, hard to repeat | The code *is* the documentation |
| Drift between environments | dev / staging / prod built from the same modules |
| No review | Changes go through pull requests, with `plan` output in review |
| Slow disaster recovery | `terraform apply` rebuilds everything |
| Forgotten resources cost money | `terraform destroy` removes everything it created |

Terraform is **declarative**: you describe *what*, not *how*. It builds a dependency graph and works out the order itself.

## Install and set up

> **In simple words:** Check Terraform is installed, and add the editor plug-in that colours and checks your `.tf` files.

Terraform was installed during **Workstation Setup**. Check it:

```bash
terraform -version
```

> **Tip:** Different projects often pin different Terraform versions. `tfenv` (`git clone https://github.com/tfutils/tfenv.git ~/.tfenv`) lets you switch with `tfenv use 1.x.y`. OpenTofu (`tofu`) is an open-source fork with the same workflow.

Install the **HashiCorp Terraform** VS Code extension for syntax highlighting, formatting and docs on hover.

## Core workflow: your first resource

> **In simple words:** Write a tiny file that creates one storage bucket, then go through init → plan → apply → destroy to see the whole cycle.

```bash
mkdir -p ~/code/tf-first && cd ~/code/tf-first
```

Create `main.tf`:

```hcl
terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      Project   = "devops-launchpad"
      ManagedBy = "terraform"
    }
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "demo" {
  bucket = "tf-first-${random_id.suffix.hex}"
}

resource "aws_s3_bucket_versioning" "demo" {
  bucket = aws_s3_bucket.demo.id
  versioning_configuration {
    status = "Enabled"
  }
}
```

Run the four core commands:

```bash
terraform init      # download providers, set up backend
terraform plan      # preview: + create, ~ update, - destroy
terraform apply     # make it real (type "yes")
terraform destroy   # tear it all down
```

Also useful:

```bash
terraform fmt -recursive   # format code
terraform validate         # syntax and type check
terraform state list       # what Terraform manages
terraform show             # current state in detail
terraform output           # print outputs
```

> **Why:** Always read the `plan`. A line saying `must be replaced` means *destroy and recreate*. For a database, that means data loss.

### Anatomy of a block

```hcl
resource "aws_s3_bucket" "demo" {   # resource "<TYPE>" "<LOCAL NAME>"
  bucket = "my-bucket"              # argument
}
# Reference it elsewhere as: aws_s3_bucket.demo.id / .arn / .bucket
```

## Variables, outputs and locals

> **In simple words:** Variables are blanks you fill in, outputs are answers Terraform prints at the end, and locals are short nicknames for values you reuse.

`variables.tf`:

```hcl
variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "allowed_ssh_cidrs" {
  type    = list(string)
  default = []
}
```

`locals.tf`:

```hcl
locals {
  name_prefix = "launchpad-${var.environment}"
  common_tags = {
    Environment = var.environment
    Owner       = "platform-team"
  }
}
```

`outputs.tf`:

```hcl
output "bucket_name" {
  value = aws_s3_bucket.demo.bucket
}
```

Set values in several ways (later sources override earlier ones):

```bash
terraform apply -var="environment=staging"
echo 'environment = "staging"' > staging.tfvars && terraform apply -var-file=staging.tfvars
export TF_VAR_environment=staging        # environment variable
# terraform.tfvars and *.auto.tfvars are loaded automatically
```

> **Warning:** Mark secrets `sensitive = true` and never commit `*.tfvars` files that contain them. Better still, read secrets from AWS Secrets Manager with a data source.

## State and remote backends

> **In simple words:** State is Terraform's notebook of what it built. Keeping it in a shared, locked S3 bucket stops teammates overwriting each other's work.

Terraform records what it created in **state** (`terraform.tfstate`). By default this is a local file. That's fine for learning, and dangerous for teams:

- It may contain secrets in plain text.
- Two people applying at once can corrupt it.
- Lose the file and Terraform forgets your infrastructure exists.

**Use a remote backend with locking.** On AWS that means S3. Terraform 1.10+ supports S3-native locking with `use_lockfile`, so no DynamoDB table is needed.

Create the state bucket once (bootstrap):

```bash
STATE_BUCKET=tfstate-$(aws sts get-caller-identity --query Account --output text)-us-east-1
aws s3api create-bucket --bucket $STATE_BUCKET --region us-east-1
aws s3api put-bucket-versioning --bucket $STATE_BUCKET --versioning-configuration Status=Enabled
echo $STATE_BUCKET
```

Then add a backend to your project and run `terraform init -migrate-state`:

```hcl
terraform {
  backend "s3" {
    bucket       = "tfstate-123456789012-us-east-1"   # your bucket
    key          = "launchpad/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

Useful state commands:

```bash
terraform state list
terraform state show aws_s3_bucket.demo
terraform state mv aws_s3_bucket.demo aws_s3_bucket.logs   # rename without recreating
terraform import aws_s3_bucket.existing my-existing-bucket # adopt existing resource
terraform plan -refresh-only                               # detect drift
```

> **Tip:** Add `.terraform/`, `*.tfstate*` and `*.tfvars` (when they hold secrets) to `.gitignore`. **Do** commit `.terraform.lock.hcl`, which pins provider versions.

## Data sources, count and for_each

> **In simple words:** Data sources **read** things that already exist. `count` and `for_each` create several similar things from one block, like a loop.

**Data sources** read existing information without managing it:

```hcl
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_caller_identity" "current" {}
```

**for_each** creates one resource per item in a map or set. Prefer it over `count`, because removing an item doesn't shift the others.

```hcl
variable "buckets" {
  type    = set(string)
  default = ["logs", "artifacts", "backups"]
}

resource "aws_s3_bucket" "this" {
  for_each = var.buckets
  bucket   = "${local.name_prefix}-${each.key}-${random_id.suffix.hex}"
}

output "bucket_arns" {
  value = { for k, b in aws_s3_bucket.this : k => b.arn }
}
```

**count** is good for on/off switches:

```hcl
resource "aws_eip" "nat" {
  count  = var.enable_nat ? 1 : 0
  domain = "vpc"
}
```

## Modules

> **In simple words:** A module is a reusable package of Terraform code, like a function, so you write a "web server" once and use it many times.

A **module** is a folder of `.tf` files with inputs (variables) and outputs. Modules are how you reuse code across environments and teams.

```text
tf-platform/
├── modules/
│   └── web-server/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── envs/
    ├── dev/
    │   ├── main.tf
    │   └── backend.tf
    └── prod/
        ├── main.tf
        └── backend.tf
```

`modules/web-server/main.tf`:

```hcl
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_security_group" "web" {
  name_prefix = "${var.name}-"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.web.id]
  user_data              = <<-EOF
    #!/bin/bash
    dnf install -y nginx
    echo "<h1>${var.name}</h1>" > /usr/share/nginx/html/index.html
    systemctl enable --now nginx
  EOF
  tags = { Name = var.name }
}
```

`modules/web-server/variables.tf` and `outputs.tf`:

```hcl
variable "name"          { type = string }
variable "vpc_id"        { type = string }
variable "subnet_id"     { type = string }
variable "instance_type" {
  type    = string
  default = "t3.micro"
}

output "public_ip" { value = aws_instance.web.public_ip }
```

Use it, along with a module from the public registry:

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name               = "launchpad-dev"
  cidr               = "10.0.0.0/16"
  azs                = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnets     = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets    = ["10.0.11.0/24", "10.0.12.0/24"]
  enable_nat_gateway = false       # NAT costs money; enable when you need it
  map_public_ip_on_launch = true
}

module "web" {
  source    = "../../modules/web-server"
  name      = "launchpad-dev-web"
  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.public_subnets[0]
}

output "web_url" { value = "http://${module.web.public_ip}" }
```

```bash
cd envs/dev
terraform init && terraform apply
curl $(terraform output -raw web_url)
terraform destroy
```

> **Tip:** Browse [registry.terraform.io](https://registry.terraform.io/) before writing your own module. The `terraform-aws-modules` collection (vpc, eks, rds, iam) is the de facto standard. Always pin `version`.

## Environments: dev, staging, prod

> **In simple words:** How to build separate copies of the same setup for testing and for real users, without them interfering with each other.

Two common approaches:

| Approach | How | When |
|---|---|---|
| **Directory per environment** | `envs/dev`, `envs/prod`, each with its own backend key and tfvars, all calling shared modules | Most teams, and the clearest isolation |
| **Workspaces** | `terraform workspace new staging`. Same code, separate state | Small, nearly identical environments |

```bash
terraform workspace list
terraform workspace new staging
terraform workspace select staging
# inside code: terraform.workspace == "staging"
```

> **Note:** For bigger estates, teams add tools like **Terragrunt** or **Atlantis** / **HCP Terraform** to keep code DRY and run plans automatically on pull requests.

## Best practices and CI

> **In simple words:** Good habits, plus running `terraform plan` automatically on every pull request so changes get reviewed before they're applied.

- **Small, focused state files.** Separate network, cluster and apps so a mistake can't destroy everything.
- **Pin versions:** `required_version`, provider `version`, module `version`.
- **Never edit state by hand.** Use `terraform state` commands.
- **Protect critical resources** with `lifecycle { prevent_destroy = true }`.
- **Lint and scan:** `tflint`, `trivy config .` or `checkov -d .`.
- **Plan in CI, apply after review.** Use OIDC so CI assumes an AWS role, with no long-lived keys.

A minimal GitHub Actions pipeline:

```yaml
name: terraform
on:
  pull_request:
  push:
    branches: [main]
permissions:
  id-token: write
  contents: read
jobs:
  plan:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: envs/dev
    steps:
      - uses: actions/checkout@v7
      - uses: hashicorp/setup-terraform@v4
      - uses: aws-actions/configure-aws-credentials@v6
        with:
          role-to-assume: arn:aws:iam::123456789012:role/github-terraform
          aws-region: us-east-1
      - run: terraform fmt -check -recursive
      - run: terraform init -input=false
      - run: terraform validate
      - run: terraform plan -input=false -out=tfplan
      - if: github.ref == 'refs/heads/main'
        run: terraform apply -input=false tfplan
```

## Troubleshooting

> **In simple words:** The common Terraform errors and how to fix each one.

| Problem | Fix |
|---|---|
| `Error acquiring the state lock` | Someone else is applying, or a run crashed. Wait, then if needed `terraform force-unlock <ID>` |
| `No valid credential sources found` | `aws sts get-caller-identity`, `aws sso login`, check `AWS_PROFILE` |
| Plan shows unexpected replace | Look for `# forces replacement`. Some arguments can't change in place. |
| Resource exists but not in state | `terraform import` (or an `import {}` block) |
| Drift from manual console changes | `terraform plan -refresh-only`, then fix the code or re-apply |
| Provider version conflicts | `terraform init -upgrade`, check `.terraform.lock.hcl` |

Turn on debug logging with `TF_LOG=DEBUG terraform plan`.

## Lab: your own network and web tier

> **In simple words:** Practice time: build a network and two web servers with your own module, then destroy it all.

1. Bootstrap a versioned S3 state bucket and configure a backend with `use_lockfile = true`.
2. Build a VPC across 2 AZs with the registry module (public and private subnets, NAT disabled).
3. Write your own `web-server` module and deploy **two** instances using `for_each` over a map like `{ blue = "t3.micro", green = "t3.micro" }`.
4. Output both URLs and `curl` them.
5. Change the page content in user-data, run `plan`, and explain why the instance is (or isn't) replaced. Hint: look up `user_data_replace_on_change`.
6. Create a `prod.tfvars` with different names, deploy to a second state key, then destroy both environments.

### Cheat sheet

| Task | Command |
|---|---|
| Initialize | `terraform init` |
| Preview | `terraform plan -out=tfplan` |
| Apply saved plan | `terraform apply tfplan` |
| Destroy | `terraform destroy` |
| Format / validate | `terraform fmt -recursive` / `terraform validate` |
| One output | `terraform output -raw name` |
| Target one resource | `terraform apply -target=module.web` (debugging only) |
