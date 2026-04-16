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

PROFILE_DRIVER=$(read_task_value operator_profile_driver)
PROFILE_WORKDIR=$(read_task_value operator_profile_workdir)
PROFILE_DURATION=$(read_task_value operator_profile_duration_sec)
PROFILE_TARGET=$(read_task_value operator_profile_target)
PROFILE_RUN_COMMAND=$(read_task_value operator_profile_run_command)
TARGETED_PREFIX=$(read_task_value operator_profile_targeted_report_prefix)
FULL_PREFIX=$(read_task_value operator_profile_full_report_prefix)

[[ -n "$PROFILE_DRIVER" ]] || { echo "operator_profile_driver is required" >&2; exit 1; }
[[ "$PROFILE_DRIVER" == "msys" ]] || { echo "unsupported operator_profile_driver: $PROFILE_DRIVER" >&2; exit 1; }
[[ -n "$PROFILE_WORKDIR" ]] || { echo "operator_profile_workdir is required" >&2; exit 1; }
[[ -n "$PROFILE_DURATION" ]] || { echo "operator_profile_duration_sec is required" >&2; exit 1; }
[[ -n "$PROFILE_TARGET" ]] || { echo "operator_profile_target is required" >&2; exit 1; }
[[ -n "$PROFILE_RUN_COMMAND" ]] || { echo "operator_profile_run_command is required" >&2; exit 1; }

build_profile_entry() {
  local report_prefix=$1
  printf "cd %s && msys profile --duration %s -t %s -o %s %s" \
    "$PROFILE_WORKDIR" \
    "$PROFILE_DURATION" \
    "$PROFILE_TARGET" \
    "$report_prefix" \
    "$PROFILE_RUN_COMMAND"
}

case "$MODE" in
  targeted)
    [[ -n "$TARGETED_PREFIX" ]] || { echo "operator_profile_targeted_report_prefix is required" >&2; exit 1; }
    "$ROOT_DIR/scripts/remote_xla_exec.sh" "$(build_profile_entry "$TARGETED_PREFIX")" | tee "$OUT_DIR/msys_targeted.log"
    ;;
  full)
    [[ -n "$FULL_PREFIX" ]] || { echo "operator_profile_full_report_prefix is required" >&2; exit 1; }
    "$ROOT_DIR/scripts/remote_xla_exec.sh" "$(build_profile_entry "$FULL_PREFIX")" | tee "$OUT_DIR/msys_full.log"
    ;;
  *)
    echo "unknown mode: $MODE" >&2
    exit 1
    ;;
esac

printf "MSYS %s profiling artifacts written to %s\n" "$MODE" "$OUT_DIR"
