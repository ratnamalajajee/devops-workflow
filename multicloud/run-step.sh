#!/usr/bin/env bash
# Run one runbook step for one cloud, e.g.:
#   bash run-step.sh azure 05      # Virtual network
#   bash run-step.sh aws 13        # runs 13a-eks.sh, then 13b-eks-pod-identity.sh
set -euo pipefail

cloud="${1:?usage: run-step.sh <aws|azure|gcp> <step number>}"
step="$(printf '%02d' "$((10#${2:?usage: run-step.sh <aws|azure|gcp> <step number>}))")"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$cloud" in aws|azure|gcp) ;; *) echo "Unknown cloud '$cloud' (use aws, azure or gcp)" >&2; exit 1 ;; esac

shopt -s nullglob
scripts=("$here/$cloud/$step"[-a-z]*.sh)
if [ "${#scripts[@]}" -eq 0 ]; then
  echo "No script for $cloud step $step. Available:" >&2
  ls "$here/$cloud" | grep -E '^[0-9]+[a-z]?-.*\.sh$' >&2
  exit 1
fi

for s in "${scripts[@]}"; do
  echo "==> ${s#"$here/"}"
  bash "$s"
done
