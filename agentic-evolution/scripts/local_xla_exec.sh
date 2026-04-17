#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  local_xla_exec.sh [--mode local|print] <command...>

Environment:
  AE_ENV_FILE           optional env file to source before resolving values
  AE_EXEC_MODE          default: local
  AE_LOCAL_WORKDIR      required

Notes:
  - local mode executes commands directly in the current environment.
  - print mode emits the resolved local shell command without executing it.
EOF
}

MODE=${AE_EXEC_MODE:-local}
ENV_FILE=${AE_ENV_FILE:-}

if [[ -n "$ENV_FILE" ]]; then
  if [[ ! -f "$ENV_FILE" ]]; then
    echo "env file not found: $ENV_FILE" >&2
    exit 1
  fi
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

LOCAL_WORKDIR=${AE_LOCAL_WORKDIR:-}

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

if [[ ${1:-} == "--mode" ]]; then
  MODE=${2:-}
  shift 2
fi

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

USER_CMD="$*"
INNER_CMD="cd '$LOCAL_WORKDIR' && $USER_CMD"

case "$MODE" in
  print)
    [[ -n "$LOCAL_WORKDIR" ]] || { echo "AE_LOCAL_WORKDIR is required" >&2; exit 1; }
    printf "%s\n" "$INNER_CMD"
    ;;
  local)
    [[ -n "$LOCAL_WORKDIR" ]] || { echo "AE_LOCAL_WORKDIR is required" >&2; exit 1; }
    bash -lc "$INNER_CMD"
    ;;
  *)
    echo "unsupported mode: $MODE" >&2
    exit 1
    ;;
esac
