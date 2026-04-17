#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)
TASK_FILE=${1:-"$ROOT_DIR/templates/task.yaml"}
KNOWLEDGE_DIR="$ROOT_DIR/knowledge"

mkdir -p "$KNOWLEDGE_DIR"

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

HOTSPOT_ENTRY=$(read_task_value hotspot_entry)

if [[ ! -f "$KNOWLEDGE_DIR/op_inventory.csv" ]]; then
  cat >"$KNOWLEDGE_DIR/op_inventory.csv" <<'EOF'
op_name,call_count,shape,dtype,layout,total_time_ms,avg_time_ms,source
EOF
fi

if [[ ! -f "$KNOWLEDGE_DIR/backend_map.csv" ]]; then
  cat >"$KNOWLEDGE_DIR/backend_map.csv" <<'EOF'
op_name,current_backend,source_path,notes
EOF
fi

if [[ ! -f "$KNOWLEDGE_DIR/pattern_db.yaml" ]]; then
  cat >"$KNOWLEDGE_DIR/pattern_db.yaml" <<'EOF'
patterns:
  - name: runtime_overhead
    priority: 1
    guidance: "Check layout conversions, copies, sync points, and fallback paths."
  - name: xla_custom_call
    priority: 2
    guidance: "Mirror the LayerNorm-style custom call integration before claiming success."
EOF
fi

if [[ ! -f "$KNOWLEDGE_DIR/error_db.yaml" ]]; then
  cat >"$KNOWLEDGE_DIR/error_db.yaml" <<'EOF'
errors:
  - match: "Cannot find the Xla custom call handler"
    action: "Verify the call target registration and BUILD deps."
  - match: "correctness"
    action: "Treat candidate score as zero and debug before benchmarking."
EOF
fi

if [[ ! -f "$KNOWLEDGE_DIR/perf_db.yaml" ]]; then
  cat >"$KNOWLEDGE_DIR/perf_db.yaml" <<'EOF'
signals:
  - name: no_whole_model_gain
    action: "Check whether the custom call path was actually hit in the full graph."
  - name: local_gain_only
    action: "Reject unless whole-model latency also drops."
EOF
fi

if [[ -n "$HOTSPOT_ENTRY" ]]; then
  "$ROOT_DIR/scripts/local_xla_exec.sh" "$HOTSPOT_ENTRY"
else
  echo "No hotspot_entry configured in $TASK_FILE. Initialized knowledge skeleton only."
fi

printf "Knowledge scaffolding is ready under %s\n" "$KNOWLEDGE_DIR"
