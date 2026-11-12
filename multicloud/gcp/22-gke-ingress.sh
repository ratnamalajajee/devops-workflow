#!/usr/bin/env bash
# Multi-cloud runbook - step 22 - GCP: GKE Ingress + Google-managed certificate
# Replaces AWS: ALB Ingress Controller   |   Page: /multicloud/#alb-ingress
# Run from the multicloud folder:  bash run-step.sh gcp 22
# Set your values once in gcp/settings.env before the first run.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/settings.env"
WORK_DIR="${WORK_DIR:-$HOME/multicloud-work/gcp}"   # scratch files stay out of the repo
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"
set -euo pipefail
# --- runbook commands (shown on the page) ----------------------------------
gcloud compute addresses create "ip-$PREFIX-gke" --global

# Unquoted EOF so $PREFIX and $DOMAIN expand
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata: { name: web, namespace: app }
spec:
  replicas: 2
  selector: { matchLabels: { app: web } }
  template:
    metadata: { labels: { app: web } }
    spec:
      containers:
      - name: web
        image: nginx:1.27
        ports: [{ containerPort: 80 }]
        readinessProbe: { httpGet: { path: /, port: 80 } }
---
apiVersion: v1
kind: Service
metadata: { name: web, namespace: app }
spec:
  selector: { app: web }
  ports: [{ port: 80, targetPort: 80 }]
---
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata: { name: web-cert, namespace: app }
spec:
  domains: ["k8s.$DOMAIN"]
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
  namespace: app
  annotations:
    kubernetes.io/ingress.class: "gce"
    kubernetes.io/ingress.global-static-ip-name: "ip-$PREFIX-gke"
    networking.gke.io/managed-certificates: "web-cert"
spec:
  defaultBackend: { service: { name: web, port: { number: 80 } } }
EOF
kubectl get ingress -n app        # add -w to watch until ADDRESS appears
