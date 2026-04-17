#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)
TASK_FILE=${AE_OPERATOR_TASK_FILE:-"$ROOT_DIR/templates/operator_task.yaml"}

usage() {
  cat <<'EOF'
Usage:
  operator_model2_eval.sh --mode correctness|benchmark [--semantic-op-id id_or_csv]

Environment:
  AE_LOCAL_WORKDIR       workspace root (default: /workspace/tf215_openxla_mtgpu)
  AE_SEMANTIC_OP_ID      fallback semantic op id list (comma-separated)
  AE_BATCH_SIZE          default: 1024
  AE_WARMUP_RUNS         default: 5
  AE_BENCHMARK_RUNS      default: 20
  AE_DEFAULT_UNKNOWN_DIM default: 1024
  AE_MUSA_VISIBLE_DEVICE default: 0
EOF
}

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

MODE=""
SEMANTIC_OP_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE=${2:-}
      shift 2
      ;;
    --semantic-op-id)
      SEMANTIC_OP_ID=${2:-}
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

[[ "$MODE" == "correctness" || "$MODE" == "benchmark" ]] || { echo "--mode correctness|benchmark is required" >&2; exit 1; }

if [[ -z "$SEMANTIC_OP_ID" && -f "$TASK_FILE" ]]; then
  SEMANTIC_OP_ID=$(read_task_value semantic_op_id)
fi
SEMANTIC_OP_ID=${SEMANTIC_OP_ID:-${AE_SEMANTIC_OP_ID:-}}

if [[ -z "$SEMANTIC_OP_ID" || "$SEMANTIC_OP_ID" == "fill-me" ]]; then
  echo "semantic_op_id is required (set --semantic-op-id or AE_SEMANTIC_OP_ID or templates/operator_task.yaml)" >&2
  exit 1
fi

WORKDIR=${AE_LOCAL_WORKDIR:-/workspace/tf215_openxla_mtgpu}
BATCH_SIZE=${AE_BATCH_SIZE:-1024}
WARMUP_RUNS=${AE_WARMUP_RUNS:-5}
BENCHMARK_RUNS=${AE_BENCHMARK_RUNS:-20}
DEFAULT_UNKNOWN_DIM=${AE_DEFAULT_UNKNOWN_DIM:-1024}
DEVICE=${AE_MUSA_VISIBLE_DEVICE:-0}
ADPOS_VALUE=${AE_ADPOS_VALUE:-8}
RUNNER_BIN=${AE_GRAPH_DEF_RUNNER_BIN:-"$WORKDIR/tf_openxla_mtgpu/bazel-bin/tensorflow/compiler/jit/xla_gpu_graph_def_runner"}
OUT_DIR=${AE_OPERATOR_EVAL_OUT_DIR:-"$WORKDIR/outputs/ae_operator_${MODE}_$(date +%Y%m%d_%H%M%S)"}

if [[ "$MODE" == "correctness" ]]; then
  BENCHMARK_RUNS=1
fi

mkdir -p "$OUT_DIR/meta_graph_2"

python3 "$WORKDIR/model/run_pb_with_xla.py" \
  --graph_path "$WORKDIR/model/meta_graph_2/meta_graph_2.pb" \
  --spec_path "$WORKDIR/model/meta_graph_2/meta_graph_2.spec" \
  --dump_dir "$OUT_DIR/model_dump" \
  --fetches "$SEMANTIC_OP_ID" \
  --batch_size "$BATCH_SIZE" \
  --default_unknown_dim "$DEFAULT_UNKNOWN_DIM" \
  --warmup_runs "$WARMUP_RUNS" \
  --benchmark_runs "$BENCHMARK_RUNS" \
  --adpos_value "$ADPOS_VALUE" \
  --use_auto_jit \
  --musa_visible_devices "$DEVICE" \
  --runner_bin "$RUNNER_BIN" \
  --summary_json "$OUT_DIR/meta_graph_2/graph_def_runner_summary.json" \
  >"$OUT_DIR/operator_${MODE}.log" 2>&1

echo "operator_${MODE}_log=$OUT_DIR/operator_${MODE}.log"
