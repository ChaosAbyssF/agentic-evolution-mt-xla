#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)
TASK_FILE=${1:-"$ROOT_DIR/templates/task.yaml"}

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

BUILD_ENTRY=$(read_task_value build_entry)
REWRITER_TEST_ENTRY=$(read_task_value rewriter_test_entry)
CUSTOM_CALL_TEST_ENTRY=$(read_task_value custom_call_test_entry)

if [[ -z "$BUILD_ENTRY" && -z "$REWRITER_TEST_ENTRY" && -z "$CUSTOM_CALL_TEST_ENTRY" ]]; then
  echo "No XLA custom-call check commands configured in $TASK_FILE" >&2
  exit 1
fi

if [[ -n "$BUILD_ENTRY" ]]; then
  echo "=== BUILD CHECK ==="
  "$ROOT_DIR/scripts/local_xla_exec.sh" "$BUILD_ENTRY"
fi

if [[ -n "$REWRITER_TEST_ENTRY" ]]; then
  echo "=== REWRITER TEST ==="
  "$ROOT_DIR/scripts/local_xla_exec.sh" "$REWRITER_TEST_ENTRY"
fi

if [[ -n "$CUSTOM_CALL_TEST_ENTRY" ]]; then
  echo "=== CUSTOM CALL TEST ==="
  "$ROOT_DIR/scripts/local_xla_exec.sh" "$CUSTOM_CALL_TEST_ENTRY"
fi
