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

EXPORT_ENTRY=$(read_task_value operator_msys_export_entry)
[[ -n "$EXPORT_ENTRY" ]] || { echo "operator_msys_export_entry is required" >&2; exit 1; }

"$ROOT_DIR/scripts/remote_xla_exec.sh" "$EXPORT_ENTRY" | tee "$OUT_DIR/msys_export.log"
printf "MSYS export log written to %s\n" "$OUT_DIR/msys_export.log"
