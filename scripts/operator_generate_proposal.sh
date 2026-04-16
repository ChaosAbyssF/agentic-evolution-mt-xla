#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)
TASK_FILE=${1:-"$ROOT_DIR/templates/operator_task.yaml"}
RUN_DIR=${2:-"$ROOT_DIR/artifacts/operator_runs/$(date +%Y%m%d_%H%M%S)"}

mkdir -p "$RUN_DIR"

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

SEMANTIC_OP_ID=$(read_task_value semantic_op_id)
BASELINE=$(read_task_value user_baseline_metric)

cat >"$RUN_DIR/optimization_proposal.md" <<EOF
# Optimization Proposal

- semantic_op_id: $SEMANTIC_OP_ID
- baseline_metric: $BASELINE

## Required Inputs

- Targeted MSYS profiling summary
- Full MSYS profiling summary
- Bottleneck classification

## Bottleneck Classification

- DRAM:
- L1:
- Latency:
- Compute:
- Occupancy:

## Proposed Next Seed

- implementation path:
- expected gain:
- correctness risk:
- integration impact:

## Notes

- Fill this file after reviewing the exported MSYS report.
EOF

printf "Generated %s\n" "$RUN_DIR/optimization_proposal.md"
