#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)
TASK_FILE=${1:-"$ROOT_DIR/templates/operator_task.yaml"}

if [[ ! -f "$TASK_FILE" ]]; then
  echo "operator task file not found: $TASK_FILE" >&2
  exit 1
fi

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
BASELINE_VALUE=$(read_task_value user_baseline_metric)
BASELINE_SOURCE=$(read_task_value baseline_source)
SEED_PATH=$(read_task_value operator_seed_path)
PTX_SEMANTICS=$(read_task_value ptx_semantics)

[[ -n "$SEMANTIC_OP_ID" ]] || { echo "semantic_op_id is required" >&2; exit 1; }
[[ -n "$BASELINE_VALUE" ]] || { echo "user_baseline_metric is required" >&2; exit 1; }
[[ -n "$BASELINE_SOURCE" ]] || { echo "baseline_source is required" >&2; exit 1; }
[[ -n "$SEED_PATH" ]] || { echo "operator_seed_path is required" >&2; exit 1; }

if [[ ! -e "$ROOT_DIR/$SEED_PATH" && ! -e "$SEED_PATH" ]]; then
  echo "operator seed path not found: $SEED_PATH" >&2
  exit 1
fi

printf "Preflight OK\n"
printf "semantic_op_id=%s\n" "$SEMANTIC_OP_ID"
printf "baseline_source=%s\n" "$BASELINE_SOURCE"
printf "user_baseline_metric=%s\n" "$BASELINE_VALUE"
printf "operator_seed_path=%s\n" "$SEED_PATH"
printf "ptx_semantics=%s\n" "${PTX_SEMANTICS:-}"
