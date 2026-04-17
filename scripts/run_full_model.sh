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
  value=$(grep -Eo 'avg_latency_ms=([0-9]+([.][0-9]+)?)' "$log_file" | grep -Eo '[0-9]+([.][0-9]+)?' | tail -1 || true)
  if [[ -z "$value" ]]; then
    value=$(grep -Eo '"avg_latency_ms"[[:space:]]*:[[:space:]]*[0-9]+([.][0-9]+)?' "$log_file" | grep -Eo '[0-9]+([.][0-9]+)?' | tail -1 || true)
  fi
  if [[ -z "$value" ]]; then
    value=$(grep -Eoi 'latency[^0-9]*[0-9]+([.][0-9]+)?' "$log_file" | grep -Eo '[0-9]+([.][0-9]+)?' | tail -1 || true)
  fi
  if [[ -z "$value" ]]; then
    value=$(grep -Eoi 'time[^0-9]*[0-9]+([.][0-9]+)?' "$log_file" | grep -Eo '[0-9]+([.][0-9]+)?' | tail -1 || true)
  fi
  if [[ -z "$value" ]]; then
    value=$(grep -Eoi 'throughput[^0-9]*[0-9]+([.][0-9]+)?' "$log_file" | grep -Eo '[0-9]+([.][0-9]+)?' | tail -1 || true)
  fi
  printf "%s" "${value:-unknown}"
}

is_number() {
  [[ ${1:-} =~ ^[0-9]+([.][0-9]+)?$ ]]
}

write_experiment_log() {
  local exp_dir=$1
  local metric_source=$2
  local measured_value=$3
  local report_file="$exp_dir/experiment_log.md"
  local workspace_root
  local changed_files="(not available)"
  local diff_stat="(not available)"
  local comparison="comparison unavailable (non-numeric baseline or metric)"
  local core_thought
  workspace_root=${AE_LOCAL_WORKDIR:-}
  core_thought=${AE_EXPERIMENT_NOTE:-"Focused on reducing end-to-end avg_latency_ms on meta_graph_2 while preserving XLA custom-call correctness and hit path."}

  if [[ -z "$exp_dir" ]]; then
    return
  fi

  mkdir -p "$exp_dir"

  if [[ -n "$workspace_root" ]] && git -C "$workspace_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    changed_files=$(git -C "$workspace_root" --no-pager diff --name-only || true)
    diff_stat=$(git -C "$workspace_root" --no-pager diff --stat || true)
    if [[ -z "$changed_files" ]]; then
      changed_files="(no unstaged tracked-file changes found)"
    fi
    if [[ -z "$diff_stat" ]]; then
      diff_stat="(no unstaged tracked-file diff stat found)"
    fi
  fi

  if is_number "$BASELINE_LATENCY_MS" && is_number "$measured_value"; then
    comparison=$(awk -v b="$BASELINE_LATENCY_MS" -v m="$measured_value" '
      BEGIN {
        d = b - m
        p = (d / b) * 100
        if (d > 0) {
          printf("improved by %.3f ms (%.3f%%)", d, p)
        } else if (d < 0) {
          printf("regressed by %.3f ms (%.3f%%)", -d, -p)
        } else {
          printf("no change")
        }
      }')
  fi

  cat >"$report_file" <<EOF
# experiment_log

- timestamp: $(date -Is)
- model: ${MODEL_NAME}
- run_label: ${RUN_LABEL}
- baseline_w_musa_xla_bsz1024_ms: ${BASELINE_LATENCY_MS}
- measured_avg_latency_ms: ${measured_value}
- metric_source: ${metric_source}
- comparison_vs_baseline: ${comparison}

## Core changes (current workspace diff)

${core_thought}

\`\`\`
${changed_files}
\`\`\`

## Diff stat

\`\`\`
${diff_stat}
\`\`\`
EOF
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
COMMON_RUNNER_LOG=""
OUTPUT_DIR_FROM_RUN=""
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
  OUTPUT_DIR_FROM_RUN=$(grep -Eo 'Saving outputs to .*$' "$RUN_DIR/${RUN_LABEL}.log" | tail -1 | sed -E 's/^Saving outputs to //')
  COMMON_RUNNER_LOG=""
  if [[ -n "$OUTPUT_DIR_FROM_RUN" && -f "$OUTPUT_DIR_FROM_RUN/common_runner.log" ]]; then
    COMMON_RUNNER_LOG="$OUTPUT_DIR_FROM_RUN/common_runner.log"
  else
    SEARCH_WORKDIR=${AE_LOCAL_WORKDIR:-"/workspace/tf215_openxla_mtgpu"}
    COMMON_RUNNER_LOG=$(find "$SEARCH_WORKDIR/outputs" -maxdepth 2 -type f -name common_runner.log -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk 'NR==1 {print $2}')
  fi
else
  "$ROOT_DIR/scripts/local_xla_exec.sh" "$BENCHMARK_ENTRY" | tee "$RUN_DIR/${RUN_LABEL}.log"
fi

if [[ -n "${COMMON_RUNNER_LOG:-}" && -f "${COMMON_RUNNER_LOG:-}" ]]; then
  MEASURED=$(extract_metric "$COMMON_RUNNER_LOG")
  METRIC_SOURCE="$COMMON_RUNNER_LOG"
else
  MEASURED=$(extract_metric "$RUN_DIR/${RUN_LABEL}.log")
  METRIC_SOURCE="$RUN_DIR/${RUN_LABEL}.log"
fi

if [[ -n "${COMMON_RUNNER_LOG:-}" ]]; then
  write_experiment_log "$(dirname "$COMMON_RUNNER_LOG")" "$METRIC_SOURCE" "$MEASURED"
fi

cat >"$RUN_DIR/summary.json" <<EOF
{
  "model_name": "$(printf "%s" "$MODEL_NAME")",
  "target_latency_ms": "$(printf "%s" "$TARGET_LATENCY_MS")",
  "baseline_latency_ms": "$(printf "%s" "$BASELINE_LATENCY_MS")",
  "measured_metric": "$(printf "%s" "$MEASURED")",
  "metric_source": "$(printf "%s" "$METRIC_SOURCE")",
  "run_label": "$(printf "%s" "$RUN_LABEL")",
  "common_runner_log": "$(printf "%s" "${COMMON_RUNNER_LOG:-}")",
  "run_dir": "$(printf "%s" "$RUN_DIR")"
}
EOF

printf "Run artifacts written to %s\n" "$RUN_DIR"
