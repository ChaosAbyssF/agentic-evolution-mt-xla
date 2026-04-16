#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)
TASK_FILE=${1:-"$ROOT_DIR/templates/operator_task.yaml"}
MODE=${2:-targeted}
OUT_DIR=${3:-"$ROOT_DIR/artifacts/operator_runs/$(date +%Y%m%d_%H%M%S)"}

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

TARGETED_ENTRY=$(read_task_value operator_targeted_profile_entry)
FULL_ENTRY=$(read_task_value operator_full_profile_entry)

case "$MODE" in
  targeted)
    [[ -n "$TARGETED_ENTRY" ]] || { echo "operator_targeted_profile_entry is required" >&2; exit 1; }
    "$ROOT_DIR/scripts/remote_xla_exec.sh" "$TARGETED_ENTRY" | tee "$OUT_DIR/msys_targeted.log"
    ;;
  full)
    [[ -n "$FULL_ENTRY" ]] || { echo "operator_full_profile_entry is required" >&2; exit 1; }
    "$ROOT_DIR/scripts/remote_xla_exec.sh" "$FULL_ENTRY" | tee "$OUT_DIR/msys_full.log"
    ;;
  *)
    echo "unknown mode: $MODE" >&2
    exit 1
    ;;
esac

printf "MSYS %s profiling artifacts written to %s\n" "$MODE" "$OUT_DIR"
