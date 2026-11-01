// Learning path. Order here = order on the roadmap and in the sidebar.
// `section` groups guides under a heading; consecutive guides with the same section share it.
// To add a new tool: create content/<id>.md and add an entry below.
window.DEVOPS_CONFIG = {
  // GitHub repo (owner/name) used for the "Open lab machine" Codespaces button.
  repo: 'ratnamalajajee/devops-workflow',
  tools: [
    {
      id: 'setup',
      section: 'Foundations',
      title: 'Workstation Setup',
      badge: '00',
      color: '#64748b',
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
      id: 'aws',
      section: 'Cloud & infrastructure',
      title: 'AWS',
      badge: 'AWS',
      color: '#ff9900',
      level: 'Intermediate',
      hours: 12,
      desc: 'Secure account, IAM, CLI, VPC, EC2, S3, ECR, EKS and cost control.'
    },
    {
      id: 'ec2-website',
      section: 'Cloud & infrastructure',
      title: 'AWS Lab: Website on EC2',
      badge: 'EC2',
      color: '#d45b07',
      level: 'Beginner lab',
      hours: 3,
      desc: 'Launch an EC2 server, install a web page with user data, open it by URL, and learn every service involved.'
    },
    {
      id: 'terraform',
      section: 'Cloud & infrastructure',
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
      id: 'github-actions',
      section: 'CI/CD',
      title: 'GitHub Actions',
      badge: 'GHA',
      color: '#24292f',
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
