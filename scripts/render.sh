#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="${1:-$repo_root/rendered}"
mkdir -p "$output_dir"

for layer in cluster platform services monitoring workloads; do
  kubectl kustomize "$repo_root/$layer" >"$output_dir/$layer.yaml"
done
