#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for layer in cluster platform services monitoring workloads; do
  kubectl kustomize "$layer" >/dev/null
done

helm lint charts/microservice

if command -v yamllint >/dev/null 2>&1; then
  yamllint -c .yamllint.yaml \
    bootstrap cluster platform services monitoring workloads policies
fi
