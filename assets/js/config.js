// Learning path. Order here = order on the roadmap and in the sidebar.
// To add a new tool: create content/<id>.md and add an entry below.
window.DEVOPS_CONFIG = {
  tools: [
    {
      id: 'setup',
      title: 'Workstation Setup',
      badge: '00',
      color: '#64748b',
      level: 'Start here',
      hours: 2,
      desc: 'WSL2 / macOS, VS Code, Git, SSH keys and every CLI you will need.'
    },
    {
      id: 'linux',
      title: 'Linux',
      badge: 'LX',
      color: '#eab308',
      level: 'Beginner',
      hours: 10,
      desc: 'Filesystem, permissions, processes, systemd, networking, SSH and Bash scripting.'
    },
    {
      id: 'docker',
      title: 'Docker',
      badge: 'DK',
      color: '#2496ed',
      level: 'Beginner',
      hours: 8,
      desc: 'Images, containers, Dockerfiles, volumes, networks, Compose and registries.'
    },
    {
      id: 'aws',
      title: 'AWS',
      badge: 'AWS',
      color: '#ff9900',
      level: 'Intermediate',
      hours: 12,
      desc: 'Secure account, IAM, CLI, VPC, EC2, S3, ECR, EKS and cost control.'
    },
    {
      id: 'terraform',
      title: 'Terraform',
      badge: 'TF',
      color: '#7b42bc',
      level: 'Intermediate',
      hours: 10,
      desc: 'Infrastructure as Code: providers, state, variables, modules and environments.'
    },
    {
      id: 'kubernetes',
      title: 'Kubernetes',
      badge: 'K8s',
      color: '#326ce5',
      level: 'Intermediate',
      hours: 15,
      desc: 'Pods, Deployments, Services, config, storage, Ingress, Helm and debugging.'
    },
    {
      id: 'argocd',
      title: 'Argo CD',
      badge: 'CD',
      color: '#ef7b4d',
      level: 'Advanced',
      hours: 6,
      desc: 'GitOps: install Argo CD, deploy apps from Git, sync policies, app-of-apps.'
    },
    {
      id: 'capstone',
      title: 'Capstone Project',
      badge: '★',
      color: '#16a34a',
      level: 'Final project',
      hours: 8,
      desc: 'Put it all together: Terraform → EKS → Docker image in ECR → Argo CD deploy.'
    }
  ]
};
