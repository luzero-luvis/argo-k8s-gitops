#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for layer in cluster platform services monitoring workloads; do
  kubectl diff -k "$repo_root/$layer" || status=$?
  if [[ "${status:-0}" -gt 1 ]]; then
    exit "$status"
  fi
  unset status
done
