#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)
OUT_FILE=${1:-"$ROOT_DIR/artifacts/operator_task.local.yaml"}

SEMANTIC_OP_ID=${AE_SEMANTIC_OP_ID:-}
PTX_SEMANTICS=${AE_PTX_SEMANTICS:-}
OP_SEED_PATH=${AE_OPERATOR_SEED_PATH:-}
BASELINE=${AE_OPERATOR_BASELINE_MS:-457.706}

[[ -n "$SEMANTIC_OP_ID" ]] || { echo "AE_SEMANTIC_OP_ID is required" >&2; exit 1; }
[[ -n "$OP_SEED_PATH" ]] || { echo "AE_OPERATOR_SEED_PATH is required" >&2; exit 1; }

mkdir -p "$(dirname "$OUT_FILE")"

cat >"$OUT_FILE" <<EOF
semantic_op_id: "$SEMANTIC_OP_ID"
ptx_semantics: "$PTX_SEMANTICS"
baseline_source: "result_graph2.md:w_musa_xla@bsz=1024"
user_baseline_metric: "$BASELINE"
operator_seed_path: "$OP_SEED_PATH"
iteration_limit: "5"
operator_correctness_entry: "bash .github/skills/agentic-evolution/scripts/operator_model2_eval.sh --mode correctness"
operator_benchmark_entry: "bash .github/skills/agentic-evolution/scripts/operator_model2_eval.sh --mode benchmark"
operator_profile_driver: "msys"
operator_profile_workdir: "model/meta_graph_2"
operator_profile_duration_sec: "120"
operator_profile_target: "musa"
operator_profile_targeted_report_prefix: "msys_targeted"
operator_profile_full_report_prefix: "msys_full"
operator_profile_run_command: "python3 model/run_pb_with_xla.py --graph_path model/meta_graph_2/meta_graph_2.pb --spec_path model/meta_graph_2/meta_graph_2.spec --dump_dir outputs/ae_operator_profile/model_dump --batch_size 1024 --default_unknown_dim 1024 --warmup_runs 5 --benchmark_runs 20 --adpos_value 8 --use_auto_jit --musa_visible_devices 0 --runner_bin tf_openxla_mtgpu/bazel-bin/tensorflow/compiler/jit/xla_gpu_graph_def_runner --summary_json outputs/ae_operator_profile/meta_graph_2/graph_def_runner_summary.json"
operator_profile_stats_reports: "gpu_engine_time_sum,musa_kern_exec_sum,musa_gpu_kern_sum"
operator_profile_export_prefix: "README_MSYS_STATS"
EOF

echo "operator_task_file=$OUT_FILE"
