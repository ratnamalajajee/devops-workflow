# Workstation Setup

Before learning any tool you need a working environment. This guide turns a fresh laptop into a DevOps workstation: a Linux shell, an editor, Git, and every CLI used in the later guides. Do it once, then verify everything with the check script at the end.

> **Tip:** Can't install things on your laptop yet? The [Practice lab](#/lab) has a **cloud lab machine** (GitHub Codespaces) with every tool in this guide already installed. Come back to this setup when you're ready.

> **Note:** All later guides assume a **bash shell on Linux**. On Windows that means WSL2 (Ubuntu). On macOS the native terminal works, with Homebrew for installs.

## Start here: what we are setting up and why

> **In simple words:** Before a carpenter builds anything, they set up their workbench and tools. This guide does the same for your computer: it installs the tools a DevOps engineer uses every day, so every later guide just works.

### What is a terminal?

Most of the time you use a computer by **clicking** icons. A **terminal** (also called the *command line* or *shell*) is a window where you **type** instructions instead. It looks old-fashioned, but it's how engineers control servers, because:

- You can't "click" on a server in a data center far away, but you *can* type commands to it.
- Typed commands can be saved in a file and repeated exactly, with no mistakes. That's called **automation**.
- Every DevOps tool (Docker, Kubernetes, Terraform, AWS) has a command-line version.

### What you'll install, in plain words

| Tool | Think of it as |
|---|---|
| **WSL2 + Ubuntu** (Windows only) | A real Linux computer living inside your Windows laptop |
| **VS Code** | A smart notepad for code and config files |
| **Git** | A "save history" for files: every change is recorded and can be undone |
| **Docker** | A way to pack an app into a box that runs the same everywhere |
| **AWS CLI** | A remote control for your Amazon cloud account |
| **Terraform** | A tool that builds cloud servers from a written plan |
| **kubectl / kind / Helm** | Tools to run and manage apps on Kubernetes |
| **Argo CD CLI** | A tool that deploys apps automatically from Git |

### Typing commands: the basics

- When this site shows a grey box of commands, **click Copy** and paste it into your terminal (right-click or `Ctrl+Shift+V` in most Linux terminals).
- Lines starting with `#` are **comments**: notes for you. The computer ignores them.
- `sudo` at the start of a command means "run this as administrator". It will ask for **your Linux password**, and nothing appears on screen while you type it. That's normal.
- If a command is running and you want to stop it, press `Ctrl+C`.

### Check yourself

1. What's the difference between clicking and using a terminal?
2. What does a line starting with `#` mean?
3. Why does nothing show when you type your password after `sudo`?

> **Tip:** Answers: 1) A terminal lets you type instructions, which works on remote servers and can be automated. 2) It's a comment, so it isn't run. 3) It's hidden on purpose for security. Just type it and press Enter.

## What you will install

> **In simple words:** A shopping list of the tools you'll need, and which guide uses each one.

| Tool | Why you need it | Used in |
|---|---|---|
| WSL2 + Ubuntu (Windows only) | A real Linux environment on Windows | Everything |
| VS Code | Editor with extensions for YAML, Terraform, Docker, Kubernetes | Everything |
| Git | Version control; GitOps depends on it | Everything |
| Docker | Build and run containers | Docker, Kubernetes, Capstone |
| AWS CLI v2 | Talk to AWS from the terminal | AWS, Terraform |
| Terraform | Infrastructure as Code | Terraform, Capstone |
| kubectl, kind, Helm | Run and manage Kubernetes | Kubernetes, Argo CD |
| eksctl | Create EKS clusters quickly | AWS |
| argocd CLI | Manage Argo CD from the terminal | Argo CD |

Budget about 2 hours, mostly for downloads.

## Windows: install WSL2 and Ubuntu

> **In simple words:** WSL2 puts a real Linux system inside Windows, so you can follow every guide without buying another computer.

WSL2 runs a real Linux kernel inside Windows. Open **PowerShell as Administrator** and run:

```powershell
wsl --install -d Ubuntu-24.04
```

Reboot when asked. After the reboot, Ubuntu opens and asks you to create a **Linux username and password**. These are separate from your Windows login. Remember the password: `sudo` will ask for it.

Check the install from PowerShell:

```powershell
wsl -l -v
# NAME            STATE    VERSION
# Ubuntu-24.04    Running  2
```

Update Ubuntu straight away (inside the Ubuntu terminal):

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget unzip git jq tree ca-certificates gnupg lsb-release build-essential
```

> **Tip:** Keep your project files **inside** the Linux filesystem (for example `~/code`), not under `/mnt/c/...`. File access across the Windows boundary is many times slower.

> **Note:** Install **Windows Terminal** from the Microsoft Store. It gives you tabs, better fonts, and an Ubuntu profile.

## macOS: install Homebrew

> **In simple words:** Homebrew is an "app store" for the Mac terminal: one command installs a tool for you.

Homebrew is the package manager for macOS. Open Terminal and run:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install git jq tree wget
```

From here on, wherever a guide shows an `apt` install, Mac users can usually run `brew install <tool>` instead. This guide gives the Mac command for each tool.

## VS Code and extensions

> **In simple words:** VS Code is the editor where you'll read and write files. Extensions add helpers like colours, error hints and autocomplete for each tool.

Install VS Code from [code.visualstudio.com](https://code.visualstudio.com/). On Windows, also install the **WSL** extension, then open a project from inside Ubuntu with:

```bash
mkdir -p ~/code && cd ~/code
code .
```

Recommended extensions:

| Extension | Purpose |
|---|---|
| WSL (Microsoft) | Edit files inside WSL seamlessly |
| YAML (Red Hat) | Validation and autocomplete for Kubernetes YAML |
| HashiCorp Terraform | Syntax, formatting, docs on hover |
| Docker / Container Tools (Microsoft) | Dockerfile linting, container explorer |
| Kubernetes (Microsoft) | Browse clusters and resources |
| GitLens | See Git history inline |

## Git and SSH keys

> **In simple words:** Git keeps a history of every change to your files. An SSH key is like a digital ID card that proves to GitHub it's really you, without typing a password.

Configure your identity. This name and email are recorded on every commit:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@company.com"
git config --global init.defaultBranch main
git config --global pull.rebase false
```

Create an SSH key so you can push to GitHub or GitLab without typing a password:

```bash
ssh-keygen -t ed25519 -C "you@company.com"
# Press Enter to accept the default path; set a passphrase
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub
```

Copy the output (the **public** key) to GitHub under **Settings → SSH and GPG keys → New SSH key**, then test it:

```bash
ssh -T git@github.com
# Hi <username>! You've successfully authenticated...
```

> **Warning:** Never share or commit `~/.ssh/id_ed25519`, the file without `.pub`. That is your private key.

### Git in 60 seconds

```bash
git clone git@github.com:<you>/<repo>.git    # get a repo
git checkout -b feature/my-change            # new branch
git status                                   # what changed?
git add . && git commit -m "Describe change" # save a snapshot
git push -u origin feature/my-change         # publish branch
git pull                                     # get latest
git log --oneline --graph -10                # history
```

## Install Docker

> **In simple words:** Docker lets you run apps inside "containers", sealed boxes that work the same on any machine.

**Windows:** install **Docker Desktop** and enable **Settings → Resources → WSL integration → Ubuntu**. The `docker` command then works inside Ubuntu.

**Linux / WSL without Docker Desktop:** use Docker Engine:

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
newgrp docker          # or log out and back in
docker run hello-world
```

**macOS:** `brew install --cask docker`, then start Docker Desktop once from Applications.

> **Note:** Docker Desktop requires a paid subscription for larger companies. Ask your team which option is approved.

## Install the cloud and Kubernetes CLIs

> **In simple words:** Each block installs one command-line tool. Run them one at a time and check that the version line prints at the end.

Run these inside Ubuntu (WSL) or any Linux x86_64 machine. Each block installs one tool.

### AWS CLI v2

```bash
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp && sudo /tmp/aws/install
aws --version
```

### Terraform

```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform
terraform -version
```

### kubectl

```bash
curl -fsSLO "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -m 0755 kubectl /usr/local/bin/kubectl && rm kubectl
kubectl version --client
```

### kind (Kubernetes in Docker)

```bash
curl -fsSLo kind https://github.com/kubernetes-sigs/kind/releases/latest/download/kind-linux-amd64
sudo install -m 0755 kind /usr/local/bin/kind && rm kind
kind version
```

### Helm

```bash
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4 | bash
helm version          # v4.x (Helm 3 is still maintained if your team needs it: use get-helm-3)
```

### eksctl

```bash
curl -fsSL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" | tar -xz -C /tmp
sudo install -m 0755 /tmp/eksctl /usr/local/bin/eksctl
eksctl version
```

### Argo CD CLI

```bash
curl -fsSLo argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 0555 argocd /usr/local/bin/argocd && rm argocd
argocd version --client
```

### macOS (all at once)

```bash
brew install awscli kubectl kind helm eksctl argocd
brew tap hashicorp/tap && brew install hashicorp/tap/terraform
```

> **Tip:** On ARM machines (Apple Silicon, Graviton) replace `amd64` / `x86_64` with `arm64` / `aarch64` in the download URLs.

## Shell quality-of-life

> **In simple words:** Shortcuts so you type less, for example `k` instead of `kubectl`, and Tab-completion that fills in commands for you.

Add useful aliases and autocompletion to `~/.bashrc`:

```bash
cat >> ~/.bashrc <<'EOF'

# ---- DevOps workstation ----
alias k=kubectl
alias tf=terraform
alias ll='ls -alh'
source <(kubectl completion bash)
complete -o default -F __start_kubectl k
complete -C /usr/local/bin/aws_completer aws
complete -C /usr/bin/terraform terraform
export EDITOR=vim
EOF
source ~/.bashrc
```

## Verify everything

> **In simple words:** A quick test that every tool is installed. If a line says MISSING, go back to that tool's install step.

Save this as `~/check-tools.sh`, then run `bash ~/check-tools.sh`. Every line should show a version.

```bash
#!/usr/bin/env bash
for cmd in git docker aws terraform kubectl kind helm eksctl argocd jq; do
  if command -v "$cmd" >/dev/null 2>&1; then
    printf "  OK   %-10s %s\n" "$cmd" "$($cmd version --client 2>/dev/null | head -1 || $cmd --version 2>/dev/null | head -1)"
  else
    printf "  MISSING  %s\n" "$cmd"
  fi
done
docker info >/dev/null 2>&1 && echo "  OK   docker daemon is running" || echo "  FAIL docker daemon not reachable"
```

> **Tip:** If `docker` says *permission denied*, you skipped `usermod -aG docker $USER`, or you have not opened a new shell since. Run `newgrp docker`.

Once every tool shows **OK**, you are ready for **Linux**.
