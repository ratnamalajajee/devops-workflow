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
  ]
};
