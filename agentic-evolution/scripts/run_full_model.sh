#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)
ARTIFACT_ROOT=${AE_ARTIFACT_ROOT:-"$ROOT_DIR/artifacts"}
RUN_LABEL=${AE_RUN_LABEL:-full_model}
TASK_FILE=${1:-"$ROOT_DIR/templates/task.yaml"}

if [[ ! -f "$TASK_FILE" ]]; then
  echo "task file not found: $TASK_FILE" >&2
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

extract_metric() {
  local log_file=$1
  local value
  value=$(grep -Eoi 'latency[^0-9]*[0-9]+([.][0-9]+)?' "$log_file" | grep -Eo '[0-9]+([.][0-9]+)?' | tail -1 || true)
  if [[ -z "$value" ]]; then
    value=$(grep -Eoi 'time[^0-9]*[0-9]+([.][0-9]+)?' "$log_file" | grep -Eo '[0-9]+([.][0-9]+)?' | tail -1 || true)
  fi
  if [[ -z "$value" ]]; then
    value=$(grep -Eoi 'throughput[^0-9]*[0-9]+([.][0-9]+)?' "$log_file" | grep -Eo '[0-9]+([.][0-9]+)?' | tail -1 || true)
  fi
  printf "%s" "${value:-unknown}"
}

MODEL_NAME=$(read_task_value model_name)
TARGET_LATENCY_MS=$(read_task_value target_latency_ms)
BENCHMARK_ENTRY=$(read_task_value benchmark_entry)
CORRECTNESS_ENTRY=$(read_task_value correctness_entry)
BASELINE_LATENCY_MS=$(read_task_value baseline_latency_ms)

if [[ -z "$BENCHMARK_ENTRY" ]]; then
  echo "benchmark_entry is required in $TASK_FILE" >&2
  exit 1
fi

RUN_ID=$(date +%Y%m%d_%H%M%S)
RUN_DIR="$ARTIFACT_ROOT/run_$RUN_ID"
mkdir -p "$RUN_DIR"

printf "model=%s\n" "$MODEL_NAME" >"$RUN_DIR/context.txt"
printf "target_latency_ms=%s\n" "$TARGET_LATENCY_MS" >>"$RUN_DIR/context.txt"
printf "baseline_latency_ms=%s\n" "$BASELINE_LATENCY_MS" >>"$RUN_DIR/context.txt"
printf "task_file=%s\n" "$TASK_FILE" >>"$RUN_DIR/context.txt"

if [[ -n "$CORRECTNESS_ENTRY" ]]; then
  "$ROOT_DIR/scripts/local_xla_exec.sh" "$CORRECTNESS_ENTRY" | tee "$RUN_DIR/correctness.log"
else
  printf "correctness_entry not configured\n" >"$RUN_DIR/correctness.log"
fi

# Safety: enforce local execution only
if [[ -n "${AE_EXEC_MODE:-}" && "${AE_EXEC_MODE:-}" != "local" ]]; then
  echo "AE_EXEC_MODE must be 'local' or unset for safe local runs" >&2
  exit 1
fi

# Optionally use the project's common_runner.sh for whole-model validation.
# Set AE_USE_COMMON_RUNNER=1 to enable. AE_COMMON_RUNNER_PATH can override path.
if [[ "${AE_USE_COMMON_RUNNER:-0}" == "1" || "${AE_USE_COMMON_RUNNER:-}" == "true" ]]; then
  COMMON_RUNNER_PATH=${AE_COMMON_RUNNER_PATH:-"/workspace/tf215_openxla_mtgpu/scripts/common_runner.sh"}
  if [[ ! -x "$COMMON_RUNNER_PATH" && ! -f "$COMMON_RUNNER_PATH" ]]; then
    echo "common runner not found at $COMMON_RUNNER_PATH" >&2
    exit 1
  fi
  echo "Using common runner: $COMMON_RUNNER_PATH"
  # Run the common runner and tee its output into the artifacts directory.
  # The common_runner creates its own outputs/*/common_runner.log files as required.
  bash -lc "$COMMON_RUNNER_PATH" | tee "$RUN_DIR/${RUN_LABEL}.log"
else
  "$ROOT_DIR/scripts/local_xla_exec.sh" "$BENCHMARK_ENTRY" | tee "$RUN_DIR/${RUN_LABEL}.log"
fi

MEASURED=$(extract_metric "$RUN_DIR/${RUN_LABEL}.log")

cat >"$RUN_DIR/summary.json" <<EOF
{
  "model_name": "$(printf "%s" "$MODEL_NAME")",
  "target_latency_ms": "$(printf "%s" "$TARGET_LATENCY_MS")",
  "baseline_latency_ms": "$(printf "%s" "$BASELINE_LATENCY_MS")",
  "measured_metric": "$(printf "%s" "$MEASURED")",
  "run_label": "$(printf "%s" "$RUN_LABEL")",
  "run_dir": "$(printf "%s" "$RUN_DIR")"
}
EOF

printf "Run artifacts written to %s\n" "$RUN_DIR"
