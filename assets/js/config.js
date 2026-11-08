// Learning path. Order here = order on the roadmap and in the sidebar.
// `section` groups guides under a heading; consecutive guides with the same section share it.
// To add a new tool: create content/<id>.md and add an entry below.
window.DEVOPS_CONFIG = {
  // Shown as the author on the home page, every guide and the footer.
  author: {
    name: 'Ratnamala Prabhu'
  },
  // GitHub repo (owner/name) used for the "Open lab machine" Codespaces button.
  repo: 'ratnamalajajee/devops-workflow',
  // Colour and icon for each section heading (sidebar + roadmap); `short` is the sidebar label if the name is long.
  sections: {
    'Foundations': { color: '#f59e0b', icon: '🧱' },
    'Scripting': { color: '#22c55e', icon: '📜' },
    'AWS': { color: '#f97316', icon: '☁️' },
    'Infrastructure as Code': { color: '#8b5cf6', icon: '🏗️', short: 'Infra as Code' },
    'Kubernetes': { color: '#3b82f6', icon: '☸️' },
    'CI/CD': { color: '#10b981', icon: '🔁' },
    'Final project': { color: '#a855f7', icon: '🏆' }
  },
  tools: [
    {
      id: 'devops-intro',
      section: 'Foundations',
      title: 'What is DevOps and the Cloud?',
      badge: '101',
      color: '#6366f1',
      level: 'Start here',
      hours: 2,
      desc: 'The big picture with diagrams: the DevOps loop, a real code-to-production flow, what the cloud is, and cloud vs on-premises.'
    },
    {
      id: 'setup',
      section: 'Foundations',
      title: 'Workstation Setup',
      badge: '00',
      color: '#db2777',
      level: 'Start here',
      hours: 2,
      desc: 'WSL2 / macOS, VS Code, Git, SSH keys and every CLI you will need.'
    },
    {
      id: 'linux',
      section: 'Foundations',
      title: 'Linux',
      badge: 'LX',
      color: '#eab308',
      level: 'Beginner',
      hours: 10,
      desc: 'Filesystem, permissions, processes, systemd, networking, SSH and Bash scripting.'
    },
    {
      id: 'docker',
      section: 'Foundations',
      title: 'Docker',
      badge: 'DK',
      color: '#2496ed',
      level: 'Beginner',
      hours: 8,
      desc: 'Images, containers, Dockerfiles, volumes, networks, Compose and registries.'
    },
    {
      id: 'bash-scripting',
      section: 'Scripting',
      title: 'Bash Scripting for DevOps',
      badge: 'SH',
      color: '#4eaa25',
      level: 'Beginner',
      hours: 6,
      desc: 'What to learn, scripts from first line to robust automation, 8 example programs, resources and interview questions.'
    },
    {
      id: 'python-basics',
      section: 'Scripting',
      title: 'Python Basics & Modules',
      badge: 'REF',
      color: '#306998',
      level: 'Beginner',
      hours: 3,
      desc: 'Syntax cheat sheet plus how to use os, subprocess, json, re, logging, socket, requests, psutil, boto3 and more, with official docs.'
    },
    {
      id: 'python-devops',
      section: 'Scripting',
      title: 'Python for DevOps',
      badge: 'PY',
      color: '#3776ab',
      level: 'Beginner',
      hours: 8,
      desc: 'Python basics for automation, boto3 and other key modules, example programs, testing with moto, interview questions.'
    },
    {
      id: 'python-programs',
      section: 'Scripting',
      title: 'Python Interview Programs',
      badge: 'Q&A',
      color: '#f59f00',
      level: 'Intermediate',
      hours: 4,
      desc: '18 interview-style programs: logs, disk, ports, processes, boto3, Kubernetes, SRE scenarios, with how to run each one.'
    },
    {
      id: 'aws-account',
      section: 'AWS',
      title: 'Create Your AWS Account',
      badge: 'ACC',
      color: '#d97706',
      level: 'Beginner',
      hours: 1,
      desc: 'Sign up step by step: new vs advanced sign-up, Free vs Paid plan, card, phone and India checks, then root MFA, a budget alert, an admin user and aws login.'
    },
    {
      id: 'aws',
      section: 'AWS',
      title: 'AWS',
      badge: 'AWS',
      color: '#ff9900',
      level: 'Intermediate',
      hours: 12,
      desc: 'Secure account, IAM, CLI, VPC, EC2, S3, ECR, EKS and cost control.'
    },
    {
      id: 'aws-real-deployment',
      section: 'AWS',
      title: 'AWS Services in a Real Deployment',
      badge: 'LIVE',
      color: '#f43f5e',
      level: 'Beginner',
      hours: 2,
      desc: 'Every AWS service explained with one real online shop: what it is for, how the shop uses it, what breaks without it, plus a live release, a sale day and a 2 a.m. incident.'
    },
    {
      id: 'aws-iam',
      section: 'AWS',
      title: 'AWS IAM',
      badge: 'IAM',
      color: '#e11d48',
      level: 'Beginner',
      hours: 4,
      desc: 'Users, groups, roles and policies by hand, plus EKS service account permissions with Pod Identity and IRSA.'
    },
    {
      id: 'aws-vpc',
      section: 'AWS',
      title: 'AWS VPC: Step-by-Step',
      badge: 'VPC',
      color: '#0284c7',
      level: 'Beginner',
      hours: 3,
      desc: 'Choose a CIDR, build a VPC with public and private subnets, IGW, NAT and route tables, then connect VPCs with a Transit Gateway.'
    },
    {
      id: 'aws-privatelink',
      section: 'AWS',
      title: 'VPC Endpoints and PrivateLink',
      badge: 'PVL',
      color: '#0369a1',
      level: 'Intermediate',
      hours: 3,
      desc: 'Reach AWS services and services owned by other teams privately: free S3/DynamoDB gateway endpoints, interface endpoints, private DNS, and PrivateLink sharing.'
    },
    {
      id: 'ec2-website',
      section: 'AWS',
      title: 'AWS Lab: Website on EC2',
      badge: 'EC2',
      color: '#d45b07',
      level: 'Beginner lab',
      hours: 3,
      desc: 'Launch an EC2 server, install a web page with user data, open it by URL, and learn every service involved.'
    },
    {
      id: 'aws-ssm',
      section: 'AWS',
      title: 'AWS Systems Manager',
      badge: 'SSM',
      color: '#15803d',
      level: 'Intermediate',
      hours: 3,
      desc: 'Manage EC2 servers without SSH: Session Manager, Run Command, custom documents, State Manager, Automation runbooks, Parameter Store and Patch Manager.'
    },
    {
      id: 'aws-s3',
      section: 'AWS',
      title: 'Amazon S3',
      badge: 'S3',
      color: '#3f8624',
      level: 'Beginner',
      hours: 3,
      desc: 'Buckets, storage classes, lifecycle, versioning, bucket policies, encryption, presigned URLs, static sites.'
    },
    {
      id: 'aws-efs-fsx',
      section: 'AWS',
      title: 'Amazon EFS and FSx',
      badge: 'EFS',
      color: '#0e7490',
      level: 'Intermediate',
      hours: 3,
      desc: 'Block vs file vs object storage, then Amazon EFS (mount targets, TLS, access points, lifecycle, ECS and EKS) and FSx for NetApp ONTAP step by step.'
    },
    {
      id: 'aws-backup',
      section: 'AWS',
      title: 'AWS Backup and DataSync',
      badge: 'BAK',
      color: '#4d7c0f',
      level: 'Intermediate',
      hours: 3,
      desc: 'Protect AWS data with backup vaults, plans, restores, cross-Region copies and Vault Lock, then move files between S3, EFS and on-premises with DataSync.'
    },
    {
      id: 'aws-kms',
      section: 'AWS',
      title: 'AWS KMS',
      badge: 'KMS',
      color: '#0891b2',
      level: 'Intermediate',
      hours: 2,
      desc: 'Encryption keys: key types, encrypt/decrypt, envelope encryption, key policies, rotation, safe deletion.'
    },
    {
      id: 'aws-secrets',
      section: 'AWS',
      title: 'AWS Secrets Manager',
      badge: 'SM',
      color: '#9d174d',
      level: 'Beginner',
      hours: 3,
      desc: 'Keep passwords and API keys out of code: create, read and rotate secrets, KMS encryption, IAM and cross-account access, ECS, Lambda and EKS.'
    },
    {
      id: 'aws-route53',
      section: 'AWS',
      title: 'Amazon Route 53',
      badge: 'R53',
      color: '#7c3aed',
      level: 'Beginner',
      hours: 3,
      desc: 'DNS basics, hosted zones, records and aliases, routing policies, health checks, ACM certificates.'
    },
    {
      id: 'aws-elb',
      section: 'AWS',
      title: 'Load Balancers',
      badge: 'ELB',
      color: '#c026d3',
      level: 'Intermediate',
      hours: 3,
      desc: 'ALB vs NLB vs GWLB vs Classic, then build an ALB with path routing and HTTPS, and an NLB.'
    },
    {
      id: 'aws-rds',
      section: 'AWS',
      title: 'Amazon RDS and Aurora',
      badge: 'RDS',
      color: '#c2410c',
      level: 'Intermediate',
      hours: 4,
      desc: 'Managed databases: create PostgreSQL with Secrets Manager credentials, connect privately, Multi-AZ, replicas, Aurora, backups, alarms.'
    },
    {
      id: 'aws-ecr',
      section: 'AWS',
      title: 'Amazon ECR',
      badge: 'ECR',
      color: '#2563eb',
      level: 'Beginner',
      hours: 2,
      desc: 'Private container registry: push/pull, immutable tags, scanning, lifecycle policies, caching.'
    },
    {
      id: 'aws-ecs',
      section: 'AWS',
      title: 'Amazon ECS',
      badge: 'ECS',
      color: '#ea580c',
      level: 'Intermediate',
      hours: 4,
      desc: 'Run containers on Fargate behind an ALB: task definitions, services, deployments, scaling, ECS Exec.'
    },
    {
      id: 'aws-lambda',
      section: 'AWS',
      title: 'AWS Lambda and EventBridge',
      badge: 'λ',
      color: '#7e22ce',
      level: 'Intermediate',
      hours: 3,
      desc: 'Serverless automation: build and test a Python function, then stop tagged EC2 on Friday and start it on Monday with EventBridge Scheduler.'
    },
    {
      id: 'aws-cloudwatch',
      section: 'AWS',
      title: 'Amazon CloudWatch',
      badge: 'CW',
      color: '#047857',
      level: 'Beginner',
      hours: 4,
      desc: 'Metrics, the CloudWatch agent, alarms to SNS, log groups, Logs Insights, metric filters, dashboards and EventBridge rules.'
    },
    {
      id: 'aws-sns-ses',
      section: 'AWS',
      title: 'Amazon SNS and SES',
      badge: 'SNS',
      color: '#a21caf',
      level: 'Intermediate',
      hours: 3,
      desc: 'SNS alerts with topics, filters, KMS encryption and dead-letter queues, plus SES email: verified domains, DKIM/SPF/DMARC, sandbox, bounces and SMTP.'
    },
    {
      id: 'aws-opensearch',
      section: 'AWS',
      title: 'Firehose and OpenSearch',
      badge: 'LOGS',
      color: '#9a3412',
      level: 'Intermediate',
      hours: 3,
      desc: 'Ship logs from EKS and EC2 with Fluent Bit and Amazon Data Firehose into OpenSearch: secure domain, role mapping, Dashboards search, ISM retention and alarms.'
    },
    {
      id: 'atlantis-aws',
      section: 'AWS',
      title: 'Atlantis on AWS: Manual Setup',
      badge: 'ATL',
      color: '#4338ca',
      level: 'Advanced',
      hours: 5,
      desc: 'Terraform from pull requests, built by hand: ECS Fargate, ALB + ACM, Route 53, Secrets Manager, Parameter Store, cross-account IAM roles, S3 state, and a Bitbucket Cloud webhook.'
    },
    {
      id: 'terraform',
      section: 'Infrastructure as Code',
      title: 'Terraform',
      badge: 'TF',
      color: '#7b42bc',
      level: 'Intermediate',
      hours: 10,
      desc: 'Infrastructure as Code: providers, state, variables, modules and environments.'
    },
    {
      id: 'kubernetes',
      section: 'Kubernetes',
      title: 'Kubernetes',
      badge: 'K8s',
      color: '#326ce5',
      level: 'Intermediate',
      hours: 15,
      desc: 'Pods, Deployments, Services, config, storage, Ingress, Helm and debugging.'
    },
    {
      id: 'helm-environments',
      section: 'Kubernetes',
      title: 'Helm: App per Environment',
      badge: 'HELM',
      color: '#1c7ed6',
      level: 'Intermediate',
      hours: 3,
      desc: 'Build a Helm chart for the sample app and deploy it to dev, staging and prod with per-environment values.'
    },
    {
      id: 'eks-cluster',
      section: 'Kubernetes',
      title: 'EKS Cluster Setup: Runbook',
      badge: 'EKS',
      color: '#ff9900',
      level: 'Runbook',
      hours: 3,
      desc: 'Copy-paste runbook: eksctl cluster in an existing VPC, Load Balancer Controller, EBS, EFS and Istio.'
    },
    {
      id: 'k8s-troubleshooting',
      section: 'Kubernetes',
      title: 'Kubernetes Troubleshooting',
      badge: 'FIX',
      color: '#e03131',
      level: 'Intermediate',
      hours: 3,
      desc: 'CrashLoopBackOff, Pending, ImagePullBackOff, timeouts, OOMKilled, probes, stuck rollouts, plus a break-and-fix lab.'
    },
    {
      id: 'cicd-basics',
      section: 'CI/CD',
      title: 'CI/CD Basics',
      badge: 'CI',
      color: '#0d9488',
      level: 'Beginner',
      hours: 2,
      desc: 'What CI/CD is, how pipelines work, the tools compared, and the sample app every CI/CD guide uses.'
    },
    {
      id: 'jenkins',
      section: 'CI/CD',
      title: 'Jenkins',
      badge: 'JK',
      color: '#d33833',
      level: 'Intermediate',
      hours: 8,
      desc: 'Install Jenkins from scratch, then Freestyle jobs, Jenkinsfiles, credentials, multibranch, agents.'
    },
    {
      id: 'jenkins-devsecops',
      section: 'CI/CD',
      title: 'Jenkins DevSecOps Pipeline',
      badge: 'SEC',
      color: '#be123c',
      level: 'Intermediate',
      hours: 4,
      desc: 'Build, scan and push to ECR: Gitleaks, SonarQube (SAST), Trivy (SCA, IaC, image), OWASP ZAP (DAST).'
    },
    {
      id: 'github-actions',
      section: 'CI/CD',
      title: 'GitHub Actions',
      badge: 'GHA',
      color: '#4f46e5',
      level: 'Intermediate',
      hours: 6,
      desc: 'Workflows, matrix CI, secrets and environments, GHCR images, AWS OIDC and GitOps hand-off.'
    },
    {
      id: 'gitlab-ci',
      section: 'CI/CD',
      title: 'GitLab CI/CD',
      badge: 'GL',
      color: '#fc6d26',
      level: 'Intermediate',
      hours: 6,
      desc: '.gitlab-ci.yml, stages and rules, container registry, environments, and your own runners.'
    },
    {
      id: 'argocd',
      section: 'CI/CD',
      title: 'Argo CD',
      badge: 'CD',
      color: '#ef7b4d',
      level: 'Advanced',
      hours: 8,
      desc: 'GitOps: installation methods, deploying from Git, sync policies, and a full commit-to-pod sample flow.'
    },
    {
      id: 'argocd-eks',
      section: 'CI/CD',
      title: 'Argo CD on EKS: Runbook',
      badge: 'ARGO',
      color: '#dd6b20',
      level: 'Runbook',
      hours: 2,
      desc: 'Copy-paste runbook: install Argo CD on EKS, internal load balancer, Bitbucket over SSH, Helm app.'
    },
    {
      id: 'cicd-troubleshooting',
      section: 'CI/CD',
      title: 'CI/CD Troubleshooting',
      badge: 'FIX',
      color: '#e8590c',
      level: 'Intermediate',
      hours: 3,
      desc: 'Jenkins down, stuck queues, GitHub Actions and GitLab issues, local-vs-CI and dev-vs-prod builds, ECR push errors.'
    },
    {
      id: 'capstone',
      section: 'Final project',
      title: 'Capstone Project',
      badge: '★',
      color: '#16a34a',
      level: 'Final project',
      hours: 8,
      desc: 'Put it all together: Terraform → EKS → Docker image in ECR → Argo CD deploy.'
    }
  ],

  // "How to start DevOps" roadmap page (#/roadmap). Each stage lists guide rows:
  //   { label, then: [ids] }  guides to do in order (shown with →)
  //   { label, pick: [ids or {title, badge, color, url, note}] }  choose one (shown with "or")
  //   { label, links: [...] }  related references, no order (url starting with # stays on this site)
  roadmap: [
    {
      id: 'basics', short: 'DevOps & cloud', icon: '💡', title: 'Understand DevOps & the cloud', color: '#6366f1', time: '1 week',
      why: 'Before touching tools, know what problem DevOps solves, how a real change travels from code to users, and why companies use the cloud instead of their own servers.',
      learn: ['What DevOps is: culture, practices, tools', 'The DevOps loop: plan, code, build, test, release, deploy, operate, monitor', 'The real flow: Git → CI → registry → Argo CD → Kubernetes → monitoring', 'What the cloud is: regions, AZs, pay-as-you-go', 'Cloud vs on-premises, IaaS / PaaS / SaaS, shared responsibility'],
      rows: [{ label: 'Read first', then: ['devops-intro'] }],
      ready: 'You can explain DevOps and the cloud to a friend, and draw the code-to-production flow from memory.'
    },
    {
      id: 'linux', short: 'Linux & Git', icon: '🐧', title: 'Linux, networking & Git', color: '#f59e0b', time: '3–4 weeks',
      why: 'Servers, containers and pipelines almost all run on Linux, networking decides who can talk to whom, and Git is how every team shares code and config. Everything after this stage builds on it.',
      learn: ['Files, folders and permissions', 'Users, processes and services (systemd)', 'Reading logs to find problems', 'Networking: IP addresses, subnets (CIDR), DNS, ports, HTTP/HTTPS, SSH', 'Git: clone, commit, branch, merge, pull request'],
      rows: [{ label: 'Do in order', then: ['setup', 'linux'] }],
      ready: 'You can SSH into a server, find out from the logs why a service failed, and push a change to Git.'
    },
    {
      id: 'scripting', short: 'Scripting', icon: '📜', title: 'Scripting: Bash & Python', color: '#22c55e', time: '3–4 weeks',
      why: 'DevOps means automating repeated work. Bash glues Linux commands together; Python handles bigger jobs like calling AWS, parsing JSON and writing reports.',
      learn: ['Bash: variables, if, loops, functions', 'Text tools: grep, awk, sed, find', 'Python: lists, dicts, files, functions, errors', 'Python modules: os, subprocess, json, requests, boto3', 'Common interview programs'],
      rows: [
        { label: 'Bash first', then: ['bash-scripting'] },
        { label: 'Then Python', then: ['python-basics', 'python-devops', 'python-programs'] }
      ],
      ready: 'You can turn a manual daily task (a health check, log report or backup) into a script that runs on its own.'
    },
    {
      id: 'cloud', short: 'Cloud', icon: '☁️', title: 'Cloud: AWS or Azure', color: '#f97316', time: '4–6 weeks',
      why: 'Most companies run their apps on a cloud provider. Learn one deeply first: the ideas (accounts, networks, servers, storage, permissions) are the same on every cloud.',
      learn: ['Accounts, regions and Availability Zones', 'IAM: users, roles and policies', 'Networking: VPC, subnets, route tables, NAT', 'Servers (EC2) and storage (S3)', 'DNS, load balancers and encryption keys', 'Cost control and clean-up'],
      rows: [
        { label: 'First: open your account', then: ['aws-account'] },
        { label: 'Big picture: every service in one real app', then: ['aws-real-deployment'] },
        { label: 'Pick one cloud', pick: ['aws', { title: 'Azure', badge: 'AZ', color: '#0078d4', url: 'https://learn.microsoft.com/en-us/azure/architecture/aws-professional/', note: 'Microsoft Learn: Azure for AWS professionals' }] },
        { label: 'AWS deep dives', then: ['aws-iam', 'aws-vpc', 'aws-privatelink', 'ec2-website', 'aws-ssm', 'aws-s3', 'aws-efs-fsx', 'aws-backup', 'aws-route53', 'aws-elb', 'aws-rds', 'aws-lambda', 'aws-kms', 'aws-secrets'] }
      ],
      ready: 'You can build a VPC, run a website on a server behind a load balancer, and give it only the IAM permissions it needs.'
    },
    {
      id: 'containers', short: 'Containers', icon: '🐳', title: 'Containers: Docker & Kubernetes', color: '#3b82f6', time: '5–6 weeks',
      why: 'Containers package an app with everything it needs, so it runs the same on a laptop and in production. Kubernetes runs many containers, restarts them when they fail and scales them.',
      learn: ['Images, containers, Dockerfile, volumes', 'Pushing images to a registry (ECR)', 'Pods, Deployments, Services, Ingress', 'ConfigMaps, Secrets, probes, scaling', 'Helm charts per environment', 'Debugging CrashLoopBackOff, Pending, ImagePullBackOff'],
      rows: [
        { label: 'Core path', then: ['docker', 'kubernetes'] },
        { label: 'Go further', then: ['aws-ecr', 'aws-ecs', 'helm-environments', 'eks-cluster', 'k8s-troubleshooting'] }
      ],
      ready: 'You can containerize an app, deploy it to Kubernetes with Helm, and fix a pod that will not start.'
    },
    {
      id: 'iac', short: 'Terraform', icon: '🏗️', title: 'Infrastructure as Code: Terraform', color: '#8b5cf6', time: '2–3 weeks',
      why: 'Clicking in the console is slow and easy to get wrong. With Terraform you describe infrastructure in code, review it like code, and rebuild a whole environment with one command.',
      learn: ['Providers, resources and variables', 'plan, apply and destroy', 'State and remote state (S3)', 'Modules and reusing code', 'Separate dev, staging and prod'],
      rows: [
        { label: 'Do in order', then: ['terraform'] },
        { label: 'Then: Terraform from pull requests', then: ['atlantis-aws'] }
      ],
      ready: 'You can create a VPC and a server with terraform apply, change it safely, and remove it with terraform destroy.'
    },
    {
      id: 'cicd', short: 'CI/CD', icon: '🔁', title: 'CI/CD: Jenkins, GitHub Actions, GitLab & Argo CD', color: '#10b981', time: '4–5 weeks',
      why: 'CI/CD builds, tests and deploys every change automatically, so releases are small, frequent and boring. CI builds the image; Argo CD (GitOps) deploys what is in Git to Kubernetes.',
      learn: ['Pipeline stages: build, test, scan, push, deploy', 'Credentials and secrets in pipelines', 'Build and push Docker images to ECR', 'GitOps: Git as the source of truth', 'Rollbacks and troubleshooting failed pipelines'],
      rows: [
        { label: 'Start with the basics', then: ['cicd-basics'] },
        { label: 'Pick one CI tool', pick: ['jenkins', 'github-actions', 'gitlab-ci'] },
        { label: 'Then deploy with GitOps', then: ['argocd', 'argocd-eks'] },
        { label: 'When it breaks', then: ['cicd-troubleshooting'] }
      ],
      ready: 'A push to Git builds and tests your app, pushes the image, and Argo CD deploys it to Kubernetes without you touching the cluster.'
    },
    {
      id: 'security', short: 'Security', icon: '🛡️', title: 'Security tools (DevSecOps)', color: '#e11d48', time: '2–3 weeks',
      why: 'Security is part of every stage, not a last-minute check. Scanners in the pipeline catch leaked secrets, vulnerable libraries and risky images before they reach production ("shift left").',
      learn: ['Secret scanning in code', 'SAST: static code analysis', 'SCA and image scanning for known vulnerabilities', 'IaC scanning for Terraform and Kubernetes files', 'DAST: testing the running app', 'Least-privilege IAM and encryption with KMS'],
      tools: [['Gitleaks', 'secrets'], ['SonarQube', 'SAST'], ['Trivy', 'images & libraries'], ['Checkov', 'IaC'], ['OWASP ZAP', 'DAST'], ['AWS IAM & KMS', 'access & encryption']],
      rows: [
        { label: 'Secure pipeline', then: ['jenkins-devsecops'] },
        { label: 'Secure the cloud', then: ['aws-iam', 'aws-kms', 'aws-secrets'] }
      ],
      ready: 'Your pipeline fails the build on a leaked secret or a critical vulnerability, and every service runs with only the permissions it needs.'
    },
    {
      id: 'monitoring', short: 'Monitoring', icon: '📈', title: 'Monitoring & logging', color: '#06b6d4', time: '2–3 weeks',
      why: 'Deploying is only half the job: you must know when users are having problems before they tell you. Metrics, logs and alerts close the DevOps loop and feed the next plan.',
      learn: ['Metrics, logs and traces: what each one tells you', 'CloudWatch: metrics, alarms, logs and dashboards', 'Prometheus and Grafana for Kubernetes', 'Good alerts: only when users are affected', 'Reading pod logs and events to find a problem', 'On-call basics and blameless incident reviews'],
      tools: [['CloudWatch', 'AWS metrics, logs & alarms'], ['Prometheus', 'metrics & alerts'], ['Grafana', 'dashboards'], ['kubectl logs / events', 'pod problems']],
      rows: [
        { label: 'On this site', links: ['aws-cloudwatch', 'aws-sns-ses', 'aws-opensearch', 'k8s-troubleshooting'] },
        { label: 'Official docs', links: [
          { title: 'Prometheus', badge: 'PR', color: '#e6522c', url: 'https://prometheus.io/docs/introduction/overview/', note: 'Overview' },
          { title: 'Grafana', badge: 'GF', color: '#f46800', url: 'https://grafana.com/docs/grafana/latest/', note: 'Documentation' },
          { title: 'Amazon CloudWatch', badge: 'CW', color: '#e7157b', url: 'https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/WhatIsCloudWatch.html', note: 'User guide' }
        ] }
      ],
      ready: 'An alarm tells you when your app is slow or failing, and you can find the cause from dashboards and logs.'
    },
    {
      id: 'project', short: 'Final project', icon: '🏆', title: 'Final project', color: '#a855f7', time: '1–2 weeks',
      why: 'Put every stage together in one real project. This is what you show in interviews.',
      learn: ['Terraform builds the network and the EKS cluster', 'CI builds, scans and pushes the image to ECR', 'Argo CD deploys it with Helm', 'Write a README that explains your design'],
      rows: [{ label: 'Build it', then: ['capstone'] }],
      ready: 'You can explain, and demo, how a code change travels from Git to production on Kubernetes.'
    }
  ]
};
