#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)
RUN_DIR=${1:-"$ROOT_DIR/artifacts/operator_runs"}
OUT_DIR=${2:-"$ROOT_DIR/artifacts/final_selection"}

mkdir -p "$OUT_DIR"

find "$RUN_DIR" -name '*manifest.json' | sort >"$OUT_DIR/run_manifest_index.txt"

cat >"$OUT_DIR/final_summary.md" <<'EOF'
# Final Summary

Use this file to summarize:

- best accepted candidate
- associated targeted/full profiling runs
- proposal history
- whole-model integration outcome
EOF

printf "Generated:\n  %s\n  %s\n" \
  "$OUT_DIR/run_manifest_index.txt" \
  "$OUT_DIR/final_summary.md"
