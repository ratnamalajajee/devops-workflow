# What is DevOps and the Cloud?

Start here if you are new. This guide explains, in plain words and pictures, **what DevOps really is**, how a **real DevOps flow** takes a code change to users, what **the cloud** is, and why most companies moved from their own servers (**on-premises**) to the cloud. No commands yet, just the big picture that every other guide builds on.

## Start here: DevOps in simple words

> **In simple words:** **DevOps = Development + Operations working as one team.** Developers build new features; operations keep the app running for users. DevOps joins them with shared goals and **automation**, so changes reach users **quickly, safely and often**, and problems are spotted and fixed fast.

### A restaurant comparison

| In a restaurant | In software |
|---|---|
| Chefs create new dishes | **Developers** write new features |
| The service team serves customers and keeps the place running | **Operations** run the servers and keep the app online |
| Before: chefs and waiters blame each other when food arrives cold | Before DevOps: "it works on my machine" vs "your code broke the server" |
| After: one team, a fast conveyor from kitchen to table, customer comments go straight to the chefs | With DevOps: one team, an **automated pipeline** from code to users, **monitoring** feeds problems back to developers |

### Key words you will hear every day

| Word | Meaning |
|---|---|
| **Code repository (Git)** | The shared place where all code and config live, with full history |
| **Build** | Turning code into something that can run, e.g. a Docker image |
| **Pipeline (CI/CD)** | An automatic assembly line: build → test → scan → deploy |
| **Deployment** | Putting a new version onto the servers |
| **Environment** | A copy of the app: **dev** (for developers), **staging** (final test), **production** (real users) |
| **Infrastructure** | The servers, networks, databases and storage the app runs on |
| **Monitoring** | Watching the app's health: errors, speed, resource use |
| **Incident** | Something is broken for users and needs fixing now |

### Check yourself

1. What two teams does DevOps bring together?
2. Why does automation matter in DevOps?
3. What is "production"?

> **Tip:** Answers: 1) Development and operations. 2) Machines do the repeated steps (build, test, deploy) the same way every time, so releases are fast and mistakes are rare. 3) The environment real users use.

## Life before DevOps vs with DevOps

> **In simple words:** Before DevOps, developers "threw code over the wall" to operations a few times a year, and every release was a stressful, manual, weekend event. With DevOps, small changes flow through an automated pipeline many times a week, and both teams share responsibility for the result.

```compare
🧱 Before DevOps | 🚀 With DevOps
Developers and operations work in separate teams with different goals | One team with one goal: working software for users
Big releases every few months | Small releases every day or week
Manual steps from a long document, often at night or weekends | Automated pipeline, the same every time, during working hours
Servers set up by hand, each one slightly different | Servers created from code (Terraform), identical every time
Testing happens at the end, bugs found late | Tests and security scans run on every change
Problems found by angry users | Monitoring and alerts catch problems first
Blame: "your code" vs "your server" | Shared ownership and blameless reviews after incidents
```

The gap between the two teams used to be called **"the wall of confusion"**: developers wanted change, operations wanted stability, and neither could see the other's work. DevOps removes the wall by giving both teams the same tools, the same pipeline and the same goals.

## What DevOps exactly is

> **In simple words:** DevOps is **not just a tool and not just a job title**. It is a way of working made of three parts: a **culture** of shared responsibility, **practices** like automation and small frequent changes, and **tools** that make those practices easy.

AWS describes DevOps as *the combination of cultural philosophies, practices, and tools that increases an organization's ability to deliver applications and services at high velocity*.

| Part | What it means | Examples |
|---|---|---|
| **Culture** | Dev and Ops share goals and on-call duty; mistakes are learned from, not punished | Shared dashboards, blameless post-incident reviews |
| **Practices** | Small changes, automate everything you repeat, test early, measure everything | CI/CD, Infrastructure as Code, monitoring, code review |
| **Tools** | Software that makes the practices easy | Git, Jenkins, GitHub Actions, Docker, Kubernetes, Terraform, Argo CD, Prometheus |

### How do you know DevOps is working?

Google's DORA research measures software delivery with a few simple questions:

| Metric | The simple question | Good teams |
|---|---|---|
| **Deployment frequency** | How often do we release to users? | Often, even several times a day |
| **Change lead time** | How long from code commit to running in production? | Hours, not weeks |
| **Change fail rate** | How many releases cause a problem? | Few |
| **Recovery time** | How fast do we fix a failed release? | Minutes to hours |

### DevOps, SRE and platform engineering

| Role | Main focus |
|---|---|
| **DevOps engineer** | Pipelines, cloud infrastructure, automation, helping developers ship |
| **SRE (Site Reliability Engineer)** | Reliability: monitoring, alerts, incident response, performance |
| **Platform engineer** | Builds an internal "self-service" platform so developers can deploy on their own |

In many companies one person does a mix of all three. The skills on this site cover all of them.

AWS docs: [What is DevOps?](https://aws.amazon.com/devops/what-is-devops/) · Microsoft: [What is DevOps?](https://learn.microsoft.com/en-us/devops/what-is-devops) · [DORA metrics](https://dora.dev/guides/dora-metrics-four-keys/)

## The DevOps lifecycle (the infinity loop)

> **In simple words:** DevOps is usually drawn as an **infinity loop**, because it never ends. The **Dev** side plans and builds a change; the **Ops** side releases and runs it; what monitoring teaches you goes straight back into the next plan.

```svg The DevOps loop: the Dev side builds the change, the Ops side runs it, and what monitoring shows feeds the next plan
<svg viewBox="0 48 480 184" role="img" aria-label="DevOps infinity loop. Dev side: Plan, Code, Build, Test. Ops side: Release, Deploy, Operate, Monitor. Then back to Plan.">
  <path d="M240,140 C190,50 40,50 40,140 C40,230 190,230 240,140" fill="none" stroke="#6366f1" stroke-width="24" stroke-linecap="round"/>
  <path d="M240,140 C290,50 440,50 440,140 C440,230 290,230 240,140" fill="none" stroke="#10b981" stroke-width="24" stroke-linecap="round"/>
  <g fill="#fff">
    <polygon points="128,64 128,80 114,72"/>
    <polygon points="32,133 48,133 40,147"/>
    <polygon points="114,200 114,216 128,208"/>
    <polygon points="352,64 352,80 366,72"/>
    <polygon points="432,133 448,133 440,147"/>
    <polygon points="366,200 366,216 352,208"/>
  </g>
  <text x="130" y="141" text-anchor="middle" font-size="26" font-weight="900" fill="#6366f1">DEV</text>
  <text x="130" y="163" text-anchor="middle" font-size="14" class="dg-muted">build it</text>
  <text x="350" y="141" text-anchor="middle" font-size="26" font-weight="900" fill="#10b981">OPS</text>
  <text x="350" y="163" text-anchor="middle" font-size="14" class="dg-muted">run it</text>
  <g font-size="16" font-weight="800" text-anchor="middle">
    <rect x="140" y="72" width="96" height="34" rx="17" class="dg-pill" stroke="#6366f1" stroke-width="3"/><text x="188" y="95" class="dg-text">1 Plan</text>
    <rect x="16" y="72" width="96" height="34" rx="17" class="dg-pill" stroke="#6366f1" stroke-width="3"/><text x="64" y="95" class="dg-text">2 Code</text>
    <rect x="16" y="174" width="96" height="34" rx="17" class="dg-pill" stroke="#6366f1" stroke-width="3"/><text x="64" y="197" class="dg-text">3 Build</text>
    <rect x="140" y="174" width="96" height="34" rx="17" class="dg-pill" stroke="#6366f1" stroke-width="3"/><text x="188" y="197" class="dg-text">4 Test</text>
    <rect x="244" y="72" width="96" height="34" rx="17" class="dg-pill" stroke="#10b981" stroke-width="3"/><text x="292" y="95" class="dg-text">5 Release</text>
    <rect x="368" y="72" width="96" height="34" rx="17" class="dg-pill" stroke="#10b981" stroke-width="3"/><text x="416" y="95" class="dg-text">6 Deploy</text>
    <rect x="368" y="174" width="96" height="34" rx="17" class="dg-pill" stroke="#10b981" stroke-width="3"/><text x="416" y="197" class="dg-text">7 Operate</text>
    <rect x="244" y="174" width="96" height="34" rx="17" class="dg-pill" stroke="#10b981" stroke-width="3"/><text x="292" y="197" class="dg-text">8 Monitor</text>
  </g>
</svg>
```

| # | Phase | What happens | Typical tools | Learn it here |
|---|---|---|---|---|
| 1 | **Plan** | Decide what to build next, split it into small tasks | Jira, GitHub Issues | |
| 2 | **Code** | Write code and config, review each other's changes | Git, GitHub, GitLab, VS Code | [Workstation setup](#/tool/setup) |
| 3 | **Build** | Turn code into a runnable package, usually a container image | Docker, Maven, npm | [Docker](#/tool/docker) |
| 4 | **Test** | Automatic tests and security scans on every change | JUnit, pytest, SonarQube, Trivy | [DevSecOps pipeline](#/tool/jenkins-devsecops) |
| 5 | **Release** | Mark a tested version ready, store it in a registry | Git tags, Amazon ECR | [ECR](#/tool/aws-ecr) |
| 6 | **Deploy** | Roll the new version out to servers or Kubernetes | Argo CD, Helm, Jenkins | [Argo CD](#/tool/argocd) |
| 7 | **Operate** | Keep it running, scale it, patch it | Kubernetes, Terraform, AWS | [Kubernetes](#/tool/kubernetes) · [Terraform](#/tool/terraform) |
| 8 | **Monitor** | Watch errors, speed and cost; alert on problems | CloudWatch, Prometheus, Grafana | [CloudWatch](#/tool/aws-cloudwatch) |

## The real DevOps flow: from code to users

> **In simple words:** This is what actually happens in a modern company when a developer changes one line of code. Every box is automatic except writing the code and approving it. Each tool on this site has its place in this chain.

```flow
💡 | Plan | The team picks a small change from the backlog, e.g. a ticket "show the delivery date on the checkout page".
👩‍💻 | Code | A developer writes the code, tests it on a laptop, pushes a branch to **Git** (GitHub or GitLab) and opens a pull request. A teammate reviews it.
🔨 | Build (CI) | **Jenkins**, **GitHub Actions** or **GitLab CI** starts by itself, compiles the code and builds a **Docker image**.
🧪 | Test | Unit and integration tests run automatically. If one fails, the developer knows within minutes and nothing goes further.
🛡️ | Scan (DevSecOps) | **Gitleaks** looks for leaked passwords, **SonarQube** checks code quality, **Trivy** scans the image for known vulnerabilities.
📦 | Store | The image is pushed to a registry such as **Amazon ECR** with a version tag, e.g. `shop:1.4.2`.
🚀 | Deploy (CD) | The new tag is written to the deployment repo in Git. **Argo CD** notices and updates **Kubernetes** (EKS): staging first, then production.
🌍 | Operate | Kubernetes keeps the right number of copies running, replaces crashed ones and adds more when traffic grows.
📈 | Monitor | **CloudWatch**, **Prometheus** and **Grafana** watch errors, speed and cost. Alerts call someone only when users are affected.
↻ What monitoring shows (bugs, slow pages, user feedback) becomes the next task in **Plan**, and the loop starts again.
```

> **Tip:** To see every AWS service in this flow with a real use case, read [AWS services in a real deployment](#/tool/aws-real-deployment).

**Underneath all of it:** **Terraform** creates the VPC, the EKS cluster, the ECR repositories and the IAM roles from code, so the whole platform can be rebuilt or copied to a new region with one command. **Linux** and **scripting** glue every step together.

| Step | Guide on this site |
|---|---|
| Git, laptop setup | [Workstation setup](#/tool/setup) · [Linux](#/tool/linux) |
| Build and test (CI) | [CI/CD basics](#/tool/cicd-basics) · [Jenkins](#/tool/jenkins) · [GitHub Actions](#/tool/github-actions) · [GitLab CI](#/tool/gitlab-ci) |
| Container image | [Docker](#/tool/docker) · [ECR](#/tool/aws-ecr) |
| Security scans | [Jenkins DevSecOps pipeline](#/tool/jenkins-devsecops) |
| Deploy (CD, GitOps) | [Argo CD](#/tool/argocd) · [Helm per environment](#/tool/helm-environments) |
| Run it | [Kubernetes](#/tool/kubernetes) · [EKS cluster](#/tool/eks-cluster) · [Troubleshooting](#/tool/k8s-troubleshooting) |
| Platform as code | [Terraform](#/tool/terraform) · [VPC](#/tool/aws-vpc) · [IAM](#/tool/aws-iam) |
| The whole chain, hands-on | [Capstone project](#/tool/capstone) |

## Real-time example: one change, start to finish

> **In simple words:** Here is the flow above as a real working day. A small change goes from idea to real users before lunch, and a problem in the afternoon is undone in minutes, without anyone logging in to a server.

| Time | What happens | Who or what does it |
|---|---|---|
| 09:30 | The team picks the ticket "show the delivery date on checkout" | Team, Jira |
| 10:40 | The developer pushes a branch and opens a pull request | Developer, Git |
| 10:41 | CI starts: build, unit tests, SonarQube, Gitleaks. All green after 6 minutes | Jenkins or GitHub Actions |
| 10:55 | A teammate reviews and merges the pull request | Code review |
| 10:56 | CI builds the image, Trivy scans it, pushes `shop:1.4.2` to ECR, updates the tag in the deployment repo | CI |
| 10:58 | Argo CD deploys to **staging**; automatic smoke tests pass | Argo CD |
| 11:15 | The release is approved; Argo CD rolls it out to **production** pod by pod, with no downtime | Argo CD, Kubernetes |
| 11:20 | Dashboards show normal errors and speed | Grafana, CloudWatch |
| 14:05 | Alert: errors rising on the payment page | Prometheus alert |
| 14:08 | The team reverts the change in Git; Argo CD rolls back to `shop:1.4.1` | Git, Argo CD |
| 14:10 | Errors back to normal; the bug becomes a new ticket | Monitoring, Plan |

**Without DevOps**, the same change would wait for the monthly release, be copied to servers by hand on a Saturday night, and the rollback would mean hours of manual work.

## What a DevOps engineer does every day

> **In simple words:** A DevOps engineer builds and looks after the **roads** that code travels on (pipelines, cloud, Kubernetes, monitoring), so developers can ship safely and quickly, and fixes those roads when something breaks.

- Builds and improves **CI/CD pipelines** (Jenkins, GitHub Actions, GitLab CI, Argo CD).
- Creates and changes **cloud infrastructure with code** (Terraform).
- Runs **Kubernetes clusters**: deployments, upgrades, scaling, troubleshooting.
- Sets up **monitoring, dashboards and alerts**, and joins the **on-call** rota.
- **Automates** repeated tasks with Bash and Python.
- Keeps things **secure**: IAM permissions, secrets, scanning, patching.
- Keeps an eye on **cloud cost**.
- Helps developers with "it works on my machine" and failed builds.
- Leads or joins **incident** calls, then writes a short, blameless review.

The [roadmap](#/roadmap) shows the order to learn these skills.

## What is the cloud?

> **In simple words:** **The cloud is someone else's computers, in their data centers, that you rent over the internet.** Instead of buying servers, you ask for one with a click or a command, use it for as long as you need, and pay only for that time, like electricity: you don't build a power station, you plug in and pay for what you use.

```svg What the cloud is: data centers owned by a provider, which you rent over the internet, by the second
<svg viewBox="0 0 480 230" role="img" aria-label="You use a console, CLI or code over the internet to reach an AWS Region, which has several Availability Zones (groups of data centers) running services like EC2, S3, RDS and EKS.">
  <rect x="22" y="66" width="96" height="64" rx="7" class="dg-box" stroke="#6366f1" stroke-width="3"/>
  <rect x="31" y="75" width="78" height="46" rx="3" fill="#6366f1" opacity=".2"/>
  <path d="M8,138 H132 L120,150 H20 Z" fill="#6366f1"/>
  <text x="70" y="180" text-anchor="middle" font-size="19" class="dg-text dg-b">You</text>
  <text x="70" y="202" text-anchor="middle" font-size="14" class="dg-muted">console · CLI · code</text>
  <line x1="140" y1="104" x2="176" y2="104" stroke="#94a3b8" stroke-width="4" stroke-dasharray="6 5"/>
  <polygon points="176,96 191,104 176,112" fill="#94a3b8"/>
  <text x="163" y="88" text-anchor="middle" font-size="14" class="dg-muted">internet</text>
  <rect x="198" y="12" width="272" height="206" rx="18" class="dg-region"/>
  <text x="334" y="40" text-anchor="middle" font-size="17" class="dg-text dg-b">AWS Region, e.g. Mumbai</text>
  <g stroke="#f97316" stroke-width="2.5">
    <rect x="212" y="56" width="76" height="106" rx="10" class="dg-box"/>
    <rect x="296" y="56" width="76" height="106" rx="10" class="dg-box"/>
    <rect x="380" y="56" width="76" height="106" rx="10" class="dg-box"/>
  </g>
  <g fill="#f97316" opacity=".6">
    <rect x="226" y="70" width="48" height="10" rx="2"/><rect x="226" y="86" width="48" height="10" rx="2"/><rect x="226" y="102" width="48" height="10" rx="2"/>
    <rect x="310" y="70" width="48" height="10" rx="2"/><rect x="310" y="86" width="48" height="10" rx="2"/><rect x="310" y="102" width="48" height="10" rx="2"/>
    <rect x="394" y="70" width="48" height="10" rx="2"/><rect x="394" y="86" width="48" height="10" rx="2"/><rect x="394" y="102" width="48" height="10" rx="2"/>
  </g>
  <g font-size="16" text-anchor="middle" class="dg-text dg-b">
    <text x="250" y="145">AZ a</text><text x="334" y="145">AZ b</text><text x="418" y="145">AZ c</text>
  </g>
  <text x="334" y="197" text-anchor="middle" font-size="16" class="dg-text dg-b">EC2 · S3 · RDS · EKS · …</text>
</svg>
```

| Word | Meaning |
|---|---|
| **Cloud provider** | The company that owns the data centers: **AWS**, **Microsoft Azure**, **Google Cloud** |
| **Region** | A city or area with AWS data centers, e.g. Mumbai (`ap-south-1`), N. Virginia (`us-east-1`) |
| **Availability Zone (AZ)** | One or more separate data centers inside a region, with their own power and network. Using 2–3 AZs keeps you running if one fails |
| **On-demand** | Get resources the moment you ask, no waiting for hardware |
| **Pay-as-you-go** | Pay per second, hour or GB used; stop using it and the bill stops |
| **Managed service** | The provider runs the software for you, e.g. a database (RDS) or Kubernetes control plane (EKS) |

AWS: [What is cloud computing?](https://aws.amazon.com/what-is-cloud-computing/) · Azure: [What is cloud computing?](https://azure.microsoft.com/en-us/resources/cloud-computing-dictionary/what-is-cloud-computing)

## How the cloud works in real time

> **In simple words:** When you "launch a server" in the cloud, there is no person running to a rack. Software checks you are allowed, finds a free machine in the data center you chose, starts a virtual server on it from a template, and starts the billing clock, all in about a minute.

```flow
💻 | You ask | Click **Launch instance** in the AWS console, or run `aws ec2 run-instances`, or `terraform apply`.
🔐 | AWS checks you | **IAM** checks you are allowed to do this, in this account and region.
🏢 | AWS finds space | It picks a physical machine with free capacity in the **Availability Zone** you chose.
🖥️ | Your server starts | A **virtual machine** boots from the image (AMI) you picked, usually in under a minute.
🌐 | It joins your network | It gets IP addresses in your **VPC** and the firewall rules (security groups) you set.
💳 | You pay while it runs | Billing is per second. **Stop or terminate** it and the charges for it stop (storage still costs a little).
```

### Real-time story: an online shop's big sale

An online shop normally needs **4 servers**. During a 3-day festival sale, traffic is **10 times higher**.

| | On-premises | Cloud |
|---|---|---|
| Preparing | Order 36 more servers two months before; wait for delivery, racking, cabling | Set up **auto scaling** once: "keep CPU around 60%" |
| During the sale | 40 servers run; if traffic is even higher, the site slows down or crashes | Servers grow automatically from 4 to 40 (or more) as traffic rises |
| After the sale | 36 servers sit idle for the rest of the year, still using power and space | Servers shrink back to 4 automatically |
| Cost | Paid for 40 servers for years | Paid for 40 servers for about 3 days |

## On-premises vs cloud

> **In simple words:** **On-premises** ("on-prem") means your company owns the servers and runs them in its own building or rented data center. **Cloud** means you rent them from a provider. On-prem is like **buying a house**: full control, but every repair is yours. The cloud is like **renting a serviced apartment**: move in today, and the owner fixes the plumbing.

```compare
🏢 On-premises (your own data center) | ☁️ Cloud (rented from a provider)
Buy servers up front: a big one-time cost | No up-front cost: pay monthly for what you use
Weeks or months to get a new server | A new server in minutes
Must buy enough for the busiest day of the year | Scale up and down automatically with traffic
Your team replaces broken disks, power, cooling | The provider looks after hardware and buildings
Going to a new country means a new data center | Pick another region in a few clicks
Full control over hardware and where data sits | Less hardware control, but hundreds of ready-made services
Costs are predictable once hardware is bought | Costs can surprise you if you forget to delete things
```

### The six advantages of cloud computing (AWS)

| Advantage | In simple words | Real example |
|---|---|---|
| **Trade fixed expense for variable expense** | Don't buy servers up front; pay only for what you use | A startup launches with no hardware budget |
| **Benefit from massive economies of scale** | The provider buys hardware for millions of customers, so prices are lower | Storage costs a few cents per GB per month |
| **Stop guessing capacity** | No more buying "just in case"; add or remove capacity when needed | The festival sale example above |
| **Increase speed and agility** | New resources in minutes, so teams try ideas faster | A test environment created for one day, then deleted |
| **Stop spending money running data centers** | No racking, cabling, cooling or power bills | Engineers work on the product instead |
| **Go global in minutes** | Run close to users anywhere in the world | Serve customers in Europe from a Frankfurt region |

AWS whitepaper: [Six advantages of cloud computing](https://docs.aws.amazon.com/whitepapers/latest/aws-overview/six-advantages-of-cloud-computing.html)

## When on-premises or hybrid still makes sense

> **In simple words:** The cloud is not always the answer. Some companies keep part or all of their systems on-premises, or mix both (**hybrid**). Knowing the trade-offs is part of a DevOps engineer's job, and a common interview question.

| Reason to stay on-prem (or hybrid) | Example |
|---|---|
| Strict laws about where data lives | Some banks, governments and hospitals |
| Very steady, very large workloads | Running the same huge servers 24/7 for years can cost less on owned hardware |
| Ultra-low delay to local machines | A factory controlling robots on the shop floor |
| Big recent investment in hardware | A data center built 2 years ago still has years of life |
| Fear of lock-in or surprise bills | Data transfer out of the cloud and forgotten resources cost money |

### Cloud deployment models

| Model | Meaning | Example |
|---|---|---|
| **Public cloud** | Rent from a provider, shared hardware, isolated by software | Most startups on AWS |
| **Private cloud** | Cloud-style self-service, but on hardware only you use | A bank running OpenStack or VMware in its own data center |
| **Hybrid cloud** | On-prem and public cloud connected and working together | Old core system on-prem, new mobile app on AWS, linked by VPN or Direct Connect |
| **Multi-cloud** | Using more than one public cloud | Main app on AWS, analytics on Google Cloud |

AWS whitepaper: [Types of cloud computing](https://docs.aws.amazon.com/whitepapers/latest/aws-overview/types-of-cloud-computing.html)

## IaaS, PaaS and SaaS: how much the provider does

> **In simple words:** Cloud services differ in **how much the provider manages for you**. Think of getting around a city: **own a car** (on-prem), **rent a car** (IaaS), **take a taxi** (PaaS), or **buy a bus ticket** (SaaS). The further right, the less you manage, and the less you control.

| Model | Travel comparison | You manage | Examples |
|---|---|---|---|
| **On-premises** | Own a car: buy, insure, repair, fuel, drive | Everything | Your own servers |
| **IaaS** (Infrastructure as a Service) | Rent a car: the company owns and services it; you drive and fuel it | Operating system, runtime, app, data | Amazon EC2, Azure Virtual Machines |
| **PaaS** (Platform as a Service) | Taxi: you say where to go; the driver handles the car | Just your app and data | AWS Elastic Beanstalk, Azure App Service, Google App Engine |
| **SaaS** (Software as a Service) | Bus ticket: just ride | Only your data and users | Gmail, Microsoft 365, Jira Cloud |

### Who manages what

| Layer | On-premises | IaaS (EC2) | PaaS (Beanstalk) | SaaS (Gmail) |
|---|---|---|---|---|
| Your data and user access | 👤 You | 👤 You | 👤 You | 👤 You |
| Application | 👤 You | 👤 You | 👤 You | ☁️ Provider |
| Runtime (Java, Python, Node) | 👤 You | 👤 You | ☁️ Provider | ☁️ Provider |
| Operating system and patches | 👤 You | 👤 You | ☁️ Provider | ☁️ Provider |
| Virtual machines | 👤 You | ☁️ Provider | ☁️ Provider | ☁️ Provider |
| Physical servers, storage, network | 👤 You | ☁️ Provider | ☁️ Provider | ☁️ Provider |
| Building, power, cooling, guards | 👤 You | ☁️ Provider | ☁️ Provider | ☁️ Provider |

Containers sit in between: **EKS** and **AKS** run the Kubernetes control plane for you (closer to PaaS), while you still manage your apps and often the worker nodes (closer to IaaS).

## Shared responsibility: who keeps it secure

> **In simple words:** In the cloud, security is **shared**. AWS protects the **cloud itself** (buildings, hardware, the network). You protect **what you put in the cloud** (your data, who can log in, your server settings). Most cloud security incidents come from the customer side: a public S3 bucket, a leaked access key, a wide-open security group.

```compare
☁️ AWS: security OF the cloud | 👤 You: security IN the cloud
Data center buildings, guards and power | Your data, and whether it's encrypted (KMS)
Physical servers, storage and network cables | Who can log in and what they can do (IAM, MFA)
The virtualization layer that isolates customers | Patching the operating system on your EC2 servers
Running managed services (e.g. the EKS control plane) | Firewall rules: security groups and network ACLs
Hardware replacement and global infrastructure | App code, secrets and container images you deploy
```

AWS: [Shared responsibility model](https://aws.amazon.com/compliance/shared-responsibility-model/) · Learn the "you" side in the [IAM](#/tool/aws-iam), [KMS](#/tool/aws-kms) and [VPC](#/tool/aws-vpc) guides.

## AWS, Azure and Google Cloud: same ideas, different names

> **In simple words:** The three big clouds offer almost the same building blocks with different names. Learn the ideas properly on one cloud (this site uses AWS) and you can switch to another by learning the new names.

| What you need | AWS | Microsoft Azure | Google Cloud |
|---|---|---|---|
| Virtual servers | EC2 | Virtual Machines | Compute Engine |
| Object storage | S3 | Blob Storage | Cloud Storage |
| Private network | VPC | Virtual Network (VNet) | VPC |
| Users and permissions | IAM | Microsoft Entra ID + Azure RBAC | Cloud IAM |
| Managed Kubernetes | EKS | AKS | GKE |
| Container registry | ECR | Azure Container Registry | Artifact Registry |
| Managed SQL databases | RDS | Azure SQL Database, Azure Database for PostgreSQL | Cloud SQL |
| DNS | Route 53 | Azure DNS | Cloud DNS |
| Load balancing | Elastic Load Balancing | Load Balancer, Application Gateway | Cloud Load Balancing |
| Encryption keys | KMS | Key Vault | Cloud KMS |
| Serverless functions | Lambda | Azure Functions | Cloud Run functions |
| Monitoring and logs | CloudWatch | Azure Monitor | Cloud Monitoring, Cloud Logging |

Microsoft's own mapping: [Azure for AWS professionals](https://learn.microsoft.com/en-us/azure/architecture/aws-professional/)

## Where to go next

> **In simple words:** You now know the big picture: DevOps is one team plus automation, the flow goes Plan → Code → Build → Test → Deploy → Operate → Monitor and around again, and the cloud is rented infrastructure you control with code. Next, set up your laptop and start the hands-on path.

1. Open the **[roadmap](#/roadmap)** to see the order of skills and how long each takes.
2. Do **[Workstation setup](#/tool/setup)**, then **[Linux](#/tool/linux)**.
3. Come back to this page whenever a guide mentions a word you don't know.

### Check yourself

1. In your own words, what is DevOps? Name its three parts.
2. Draw the DevOps loop from memory, with all eight phases.
3. Name the tool used at each step of the real DevOps flow: build, scan, store, deploy, run, monitor.
4. Give three advantages of the cloud over on-premises, and one reason a company might stay on-premises.
5. Is patching the operating system on an EC2 server AWS's job or yours?
6. What is the difference between IaaS, PaaS and SaaS? Give one example of each.

> **Tip:** Answers: 1) One team (Dev + Ops) shipping small changes quickly and safely with automation; culture, practices, tools. 2) Plan, Code, Build, Test, Release, Deploy, Operate, Monitor, then back to Plan. 3) Jenkins or GitHub Actions; SonarQube, Trivy, Gitleaks; Amazon ECR; Argo CD; Kubernetes (EKS); CloudWatch, Prometheus, Grafana. 4) Pay as you go, servers in minutes, auto scaling, global reach, no data center to run; strict data laws, steady huge workloads or low latency to local machines. 5) Yours: it's "security in the cloud". 6) IaaS gives you servers (EC2); PaaS runs your code for you (Elastic Beanstalk); SaaS is finished software (Gmail).
