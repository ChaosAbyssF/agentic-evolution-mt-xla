#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)
TASK_FILE=${1:-"$ROOT_DIR/templates/operator_task.yaml"}
ITER_NAME=${2:-iter_v1}
RUN_DIR=${3:-"$ROOT_DIR/artifacts/operator_runs/$(date +%Y%m%d_%H%M%S)"}

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

SEED_PATH=$(read_task_value operator_seed_path)
SEMANTIC_OP_ID=$(read_task_value semantic_op_id)

cat >"$RUN_DIR/${ITER_NAME}_manifest.json" <<EOF
{
  "semantic_op_id": "$(printf "%s" "$SEMANTIC_OP_ID")",
  "seed_path": "$(printf "%s" "$SEED_PATH")",
  "next_seed": "$(printf "%s" "$ITER_NAME")",
  "status": "prepared"
}
EOF

printf "Prepared %s\n" "$RUN_DIR/${ITER_NAME}_manifest.json"
