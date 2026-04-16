#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)
TASK_FILE=${1:-"$ROOT_DIR/templates/operator_task.yaml"}
OUT_DIR=${2:-"$ROOT_DIR/artifacts/operator_runs/$(date +%Y%m%d_%H%M%S)"}

mkdir -p "$OUT_DIR"

read_task_value() {
  local key=$1
  awk -F': *' -v k="$key" '
    $1 == k {
      sub(/^[^:]*:[[:space:]]*/, "", $0)
      gsub(/^"/, "", $0)
      gsub(/"$/, "", $0)
      print $0
      exit
    }
  ' "$TASK_FILE"
}

CORRECTNESS_ENTRY=$(read_task_value operator_correctness_entry)
BENCH_ENTRY=$(read_task_value operator_benchmark_entry)

[[ -n "$CORRECTNESS_ENTRY" ]] || { echo "operator_correctness_entry is required" >&2; exit 1; }
[[ -n "$BENCH_ENTRY" ]] || { echo "operator_benchmark_entry is required" >&2; exit 1; }

"$ROOT_DIR/scripts/remote_xla_exec.sh" "$CORRECTNESS_ENTRY" | tee "$OUT_DIR/correctness.log"
"$ROOT_DIR/scripts/remote_xla_exec.sh" "$BENCH_ENTRY" | tee "$OUT_DIR/benchmark.log"

printf "Artifacts written to %s\n" "$OUT_DIR"
