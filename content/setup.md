# Workstation Setup

Before learning any tool you need a working environment. This guide turns a fresh laptop into a DevOps workstation: a Linux shell, an editor, Git, and every CLI used in the later guides. Do it once, then verify everything with the check script at the end.

> **Tip:** Can't install things on your laptop yet? The [Practice lab](#/lab) has a **cloud lab machine** (GitHub Codespaces) with every tool in this guide already installed. Come back to this setup when you're ready.

> **Note:** All later guides assume a **bash shell on Linux**. On Windows that means WSL2 (Ubuntu). On macOS the native terminal works, with Homebrew for installs.

## Start here: what we are setting up and why

> **In simple words:** Before a carpenter builds anything, they set up their workbench and tools. This guide does the same for your computer: it installs the tools a DevOps engineer uses every day, so every later guide just works.

### Watch how it works

```svg Watch it work: a Linux shell and VS Code on your laptop, an SSH key that lets Git reach GitHub with no password, an AWS sign-in, and kubectl talking to a kind cluster. The animation loops.
<svg viewBox="0 0 600 416" role="img" data-anim="setup" aria-label="Animated workstation setup. Your workbench: on Windows, wsl --install -d Ubuntu-24.04 gives you a real Linux bash shell; on a Mac you use Terminal and Homebrew. Every tool runs from this shell. VS Code opens your project folder inside Ubuntu through the WSL extension. SSH key for GitHub: ssh-keygen makes a key pair in the .ssh folder; the private key id_ed25519 never leaves your laptop, and you paste only the public key, id_ed25519.pub, into GitHub under Settings, SSH and GPG keys. After that, git clone over SSH works with no password: your private key signs a challenge and GitHub checks it with the public key. AWS and Kubernetes: aws sso login --profile dev opens the browser, you sign in once, and a short-lived token is saved in the .aws folder. aws sts get-caller-identity then answers with your account and role. kind create cluster starts Kubernetes inside Docker and adds it to the kubeconfig file, and kubectl get nodes reads that file, asks the cluster, and shows the node as Ready.">
<style>@media (prefers-reduced-motion: reduce) { .dfa-move { display: none } }</style>
<rect x="8" y="8" width="366" height="314" rx="12" fill="none" stroke="#64748b" stroke-width="2" stroke-dasharray="7 4"/>
<polyline points="87,65 272,65" fill="none" stroke-linejoin="round" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".75"/>
<polyline points="87,137 272,137 504,137" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="87,209 272,209 504,209" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="87,281 272,281" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<rect x="14" y="15" width="91.6" height="18" rx="5" class="dg-box"/><text x="18" y="27" font-size="13" font-weight="800" class="dg-muted">Your laptop</text>
<g><rect x="18" y="36" width="138" height="274" rx="12" fill="#6366f1" fill-opacity=".18" stroke="#6366f1" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0;1;0;1" keyTimes="0;0.3095;0.4206;0.5397;0.6508" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/></rect><rect x="22" y="40" width="130" height="266" rx="9" class="dg-box" stroke="#6366f1" stroke-width="2.2"/><text x="87" y="162" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">bash</text><text x="87" y="177.5" text-anchor="middle" font-size="11" class="dg-muted">Ubuntu on WSL2</text><text x="87" y="192.5" text-anchor="middle" font-size="11" class="dg-muted">or macOS Terminal</text></g>
<g><rect x="180" y="36" width="184" height="58" rx="12" fill="#0ea5e9" fill-opacity=".18" stroke="#0ea5e9" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1032;0.2063" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/></rect><rect x="184" y="40" width="176" height="50" rx="9" class="dg-box" stroke="#0ea5e9" stroke-width="2.2"/><text x="272" y="61.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">VS Code</text><text x="272" y="77" text-anchor="middle" font-size="11" class="dg-muted">WSL extension</text></g>
<g><rect x="180" y="108" width="184" height="58" rx="12" fill="#ca8a04" fill-opacity=".18" stroke="#ca8a04" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2063;0.4206" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/></rect><rect x="184" y="112" width="176" height="50" rx="9" class="dg-box" stroke="#ca8a04" stroke-width="2.2"/><text x="272" y="133.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">~/.ssh</text><text x="272" y="149" text-anchor="middle" font-size="11" class="dg-muted">id_ed25519 + id_ed25519.pub</text></g>
<g><rect x="180" y="180" width="184" height="58" rx="12" fill="#f97316" fill-opacity=".18" stroke="#f97316" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5397;0.6508" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/></rect><rect x="184" y="184" width="176" height="50" rx="9" class="dg-box" stroke="#f97316" stroke-width="2.2"/><text x="272" y="205.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">~/.aws</text><text x="272" y="221" text-anchor="middle" font-size="11" class="dg-muted">profile dev (SSO)</text></g>
<g><rect x="180" y="252" width="184" height="58" rx="12" fill="#3b82f6" fill-opacity=".18" stroke="#3b82f6" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.7698" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/></rect><rect x="184" y="256" width="176" height="50" rx="9" class="dg-box" stroke="#3b82f6" stroke-width="2.2"/><text x="272" y="277.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">kind cluster</text><text x="272" y="293" text-anchor="middle" font-size="11" class="dg-muted">Kubernetes in Docker</text></g>
<g><rect x="416" y="108" width="176" height="58" rx="12" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3095;0.5397" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/></rect><rect x="420" y="112" width="168" height="50" rx="9" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="504" y="133.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">GitHub</text><text x="504" y="149" text-anchor="middle" font-size="11" class="dg-muted">git@github.com</text></g>
<g><rect x="416" y="180" width="176" height="58" rx="12" fill="#ff9900" fill-opacity=".18" stroke="#ff9900" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5397;0.7698" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/></rect><rect x="420" y="184" width="168" height="50" rx="9" class="dg-box" stroke="#ff9900" stroke-width="2.2"/><text x="504" y="205.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">AWS account</text><text x="504" y="221" text-anchor="middle" font-size="11" class="dg-muted">sign in with SSO</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4206;0.5397" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="588" cy="112" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M583.5,112 L587,115.5 L592.5,108.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6508;0.7698" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="588" cy="184" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M583.5,184 L587,187.5 L592.5,180.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.881" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="360" cy="256" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M355.5,256 L359,259.5 L364.5,252.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1094;0.1919" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><animateMotion path="M87,65 L272,65" keyPoints="0;0;1;1" keyTimes="0;0.1094;0.1919;1" calcMode="linear" dur="25.2s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2125;0.2951" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><animateMotion path="M87,137 L272,137" keyPoints="0;0;1;1" keyTimes="0;0.2125;0.2951;1" calcMode="linear" dur="25.2s" repeatCount="indefinite"/><g><circle cx="-4" r="5" fill="#eab308" stroke="#fff" stroke-width="1.6"/><rect x="0" y="-2" width="10" height="4" rx="1" fill="#eab308" stroke="#fff" stroke-width="1.2"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3162;0.4051" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><animateMotion path="M272,137 L504,137" keyPoints="0;0;1;1" keyTimes="0;0.3162;0.4051;1" calcMode="linear" dur="25.2s" repeatCount="indefinite"/><g><circle cx="-4" r="5" fill="#eab308" stroke="#fff" stroke-width="1.6"/><rect x="0" y="-2" width="10" height="4" rx="1" fill="#eab308" stroke="#fff" stroke-width="1.2"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4266;0.4742" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><animateMotion path="M87,137 L272,137 L504,137" keyPoints="0;0;1;1" keyTimes="0;0.4266;0.4742;1" calcMode="linear" dur="25.2s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4825;0.5325" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><animateMotion path="M504,137 L272,137 L87,137" keyPoints="0;0;1;1" keyTimes="0;0.4825;0.5325;1" calcMode="linear" dur="25.2s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5463;0.6352" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><animateMotion path="M504,209 L272,209" keyPoints="0;0;1;1" keyTimes="0;0.5463;0.6352;1" calcMode="linear" dur="25.2s" repeatCount="indefinite"/><g><circle cx="-4" r="5" fill="#eab308" stroke="#fff" stroke-width="1.6"/><rect x="0" y="-2" width="10" height="4" rx="1" fill="#eab308" stroke="#fff" stroke-width="1.2"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6567;0.7044" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><animateMotion path="M87,209 L272,209 L504,209" keyPoints="0;0;1;1" keyTimes="0;0.6567;0.7044;1" calcMode="linear" dur="25.2s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7127;0.7627" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><animateMotion path="M504,209 L272,209 L87,209" keyPoints="0;0;1;1" keyTimes="0;0.7127;0.7627;1" calcMode="linear" dur="25.2s" repeatCount="indefinite"/><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7765;0.8654" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><animateMotion path="M87,281 L272,281" keyPoints="0;0;1;1" keyTimes="0;0.7765;0.8654;1" calcMode="linear" dur="25.2s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8869;0.9345" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><animateMotion path="M87,281 L272,281" keyPoints="0;0;1;1" keyTimes="0;0.8869;0.9345;1" calcMode="linear" dur="25.2s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.9429;0.9929" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><animateMotion path="M272,281 L87,281" keyPoints="0;0;1;1" keyTimes="0;0.9429;0.9929;1" calcMode="linear" dur="25.2s" repeatCount="indefinite"/><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g>
<g font-size="10.5" class="dg-muted"><g transform="translate(20.4,340.5) scale(.8)"><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g><text x="31.8" y="344">command</text><g transform="translate(94.2,340.5) scale(.8)"><g><circle cx="-4" r="5" fill="#eab308" stroke="#fff" stroke-width="1.6"/><rect x="0" y="-2" width="10" height="4" rx="1" fill="#eab308" stroke="#fff" stroke-width="1.2"/></g></g><text x="107.2" y="344">key / sign-in</text><g transform="translate(202.4,340.5) scale(.8)"><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g><text x="213.8" y="344">request</text><g transform="translate(275.4,340.5) scale(.8)"><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g><text x="286.8" y="344">answer</text><g transform="translate(343.6,340.5) scale(.8)"><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g><text x="355.8" y="344">code</text></g>
<rect x="12" y="356" width="576" height="56" rx="10" class="dg-box" stroke="#94a3b8" stroke-opacity=".45"/><rect x="12" y="356" width="0" height="3" rx="1.5" fill="#94a3b8"><animate attributeName="width" values="0;576" dur="25.2s" repeatCount="indefinite"/></rect><g opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1032" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="36" cy="384" r="14" fill="#6366f1"/><text x="36" y="389" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">1</text><text x="60" y="379" font-size="14" font-weight="800" fill="#6366f1">A Linux shell on your laptop</text><text x="578" y="379" text-anchor="end" font-size="10.5" class="dg-muted">Your workbench · 1/9</text><text x="60" y="400" font-size="12.5" class="dg-text">Windows: wsl --install -d Ubuntu-24.04. Mac: Terminal and Homebrew.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1032;0.2063" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="36" cy="384" r="14" fill="#6366f1"/><text x="36" y="389" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">2</text><text x="60" y="379" font-size="14" font-weight="800" fill="#6366f1">VS Code edits files in Ubuntu</text><text x="578" y="379" text-anchor="end" font-size="10.5" class="dg-muted">Your workbench · 2/9</text><text x="60" y="400" font-size="12.5" class="dg-text">code . opens ~/code through the WSL extension. Same files, nicer editor.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2063;0.3095" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="36" cy="384" r="14" fill="#ca8a04"/><text x="36" y="389" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">3</text><text x="60" y="379" font-size="14" font-weight="800" fill="#ca8a04">ssh-keygen makes a key pair</text><text x="578" y="379" text-anchor="end" font-size="10.5" class="dg-muted">SSH key for GitHub · 3/9</text><text x="60" y="400" font-size="12.5" class="dg-text">The private key id_ed25519 never leaves ~/.ssh. You share only the .pub.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3095;0.4206" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="36" cy="384" r="14" fill="#ca8a04"/><text x="36" y="389" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">4</text><text x="60" y="379" font-size="14" font-weight="800" fill="#ca8a04">The public key goes to GitHub</text><text x="578" y="379" text-anchor="end" font-size="10.5" class="dg-muted">SSH key for GitHub · 4/9</text><text x="60" y="400" font-size="12.5" class="dg-text">Paste id_ed25519.pub in Settings → SSH and GPG keys → New SSH key.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4206;0.5397" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="36" cy="384" r="14" fill="#ca8a04"/><text x="36" y="389" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">5</text><text x="60" y="379" font-size="14" font-weight="800" fill="#ca8a04">git clone, no password asked</text><text x="578" y="379" text-anchor="end" font-size="10.5" class="dg-muted">SSH key for GitHub · 5/9</text><text x="60" y="400" font-size="12.5" class="dg-text">Your private key signs a challenge; GitHub checks it with the .pub.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5397;0.6508" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="36" cy="384" r="14" fill="#0891b2"/><text x="36" y="389" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">6</text><text x="60" y="379" font-size="14" font-weight="800" fill="#0891b2">aws sso login --profile dev</text><text x="578" y="379" text-anchor="end" font-size="10.5" class="dg-muted">AWS and Kubernetes · 6/9</text><text x="60" y="400" font-size="12.5" class="dg-text">You sign in once in the browser. A short-lived token is saved in ~/.aws.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6508;0.7698" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="36" cy="384" r="14" fill="#0891b2"/><text x="36" y="389" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">7</text><text x="60" y="379" font-size="14" font-weight="800" fill="#0891b2">aws sts get-caller-identity</text><text x="578" y="379" text-anchor="end" font-size="10.5" class="dg-muted">AWS and Kubernetes · 7/9</text><text x="60" y="400" font-size="12.5" class="dg-text">The CLI signs the call with that sign-in. AWS answers: your account and role.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7698;0.881" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="36" cy="384" r="14" fill="#0891b2"/><text x="36" y="389" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">8</text><text x="60" y="379" font-size="14" font-weight="800" fill="#0891b2">kind create cluster</text><text x="578" y="379" text-anchor="end" font-size="10.5" class="dg-muted">AWS and Kubernetes · 8/9</text><text x="60" y="400" font-size="12.5" class="dg-text">Kubernetes starts inside Docker, and kind adds it to ~/.kube/config.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.881" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="36" cy="384" r="14" fill="#0891b2"/><text x="36" y="389" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">9</text><text x="60" y="379" font-size="14" font-weight="800" fill="#0891b2">kubectl get nodes</text><text x="578" y="379" text-anchor="end" font-size="10.5" class="dg-muted">AWS and Kubernetes · 9/9</text><text x="60" y="400" font-size="12.5" class="dg-text">kubectl reads ~/.kube/config, asks the cluster, and the node is Ready.</text></g>
</svg>
```

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
