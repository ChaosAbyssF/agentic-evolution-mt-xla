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

PROFILE_WORKDIR=$(read_task_value operator_profile_workdir)
FULL_PREFIX=$(read_task_value operator_profile_full_report_prefix)
EXPORT_PREFIX=$(read_task_value operator_profile_export_prefix)
STATS_REPORTS=$(read_task_value operator_profile_stats_reports)

[[ -n "$PROFILE_WORKDIR" ]] || { echo "operator_profile_workdir is required" >&2; exit 1; }
[[ -n "$FULL_PREFIX" ]] || { echo "operator_profile_full_report_prefix is required" >&2; exit 1; }
[[ -n "$EXPORT_PREFIX" ]] || { echo "operator_profile_export_prefix is required" >&2; exit 1; }
[[ -n "$STATS_REPORTS" ]] || { echo "operator_profile_stats_reports is required" >&2; exit 1; }

build_export_entry() {
  local report_file="${FULL_PREFIX}.msys-rep"
  local export_file="${EXPORT_PREFIX}_\$(date +%Y%m%d_%H%M%S).md"
  local shell_lines=""
  local idx=1
  local report
  IFS=',' read -r -a reports <<< "$STATS_REPORTS"
  for report in "${reports[@]}"; do
    report=$(printf "%s" "$report" | xargs)
    [[ -n "$report" ]] || continue
    shell_lines="$shell_lines echo '## ${idx}) ${report}'; echo; msys stats -r ${report} ${report_file} | sed 's/^/    /'; echo; "
    idx=$((idx + 1))
  done
  printf "cd %s && OUT=%s && { echo '# MSYS Profiling Report'; echo; echo \"- Generated at: \$(date '+%%Y-%%m-%%d %%H:%%M:%%S')\"; echo '- Report file: %s'; echo; %s} > \"\$OUT\" && echo \"Generated: \$(pwd)/\$OUT\"" \
    "$PROFILE_WORKDIR" \
    "$export_file" \
    "$report_file" \
    "$shell_lines"
}

"$ROOT_DIR/scripts/local_xla_exec.sh" "$(build_export_entry)" | tee "$OUT_DIR/msys_export.log"
printf "MSYS export log written to %s\n" "$OUT_DIR/msys_export.log"
