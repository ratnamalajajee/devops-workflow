#!/usr/bin/env bash
# Installs the CLIs not covered by dev container features, plus the shell setup
# from the Workstation Setup guide.
set -euo pipefail

ARCH=$(dpkg --print-architecture)   # amd64 or arm64
TMP=$(mktemp -d)
cd "$TMP"

curl -fsSLo kind "https://github.com/kubernetes-sigs/kind/releases/latest/download/kind-linux-${ARCH}"
sudo install -m 0755 kind /usr/local/bin/kind

curl -fsSLo argocd "https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-${ARCH}"
sudo install -m 0555 argocd /usr/local/bin/argocd

curl -fsSL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_${ARCH}.tar.gz" | tar -xz
sudo install -m 0755 eksctl /usr/local/bin/eksctl

sudo apt-get update -qq && sudo apt-get install -y -qq jq tree vim >/dev/null

cat >> ~/.bashrc <<'RC'

# ---- DevOps Launchpad lab ----
alias k=kubectl
alias tf=terraform
alias ll='ls -alh'
source <(kubectl completion bash)
complete -o default -F __start_kubectl k
complete -C /usr/local/bin/aws_completer aws
complete -C "$(command -v terraform)" terraform
mkdir -p ~/labs
RC

rm -rf "$TMP"
echo
echo "Lab ready. Try: docker run hello-world && kind create cluster"
