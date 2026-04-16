#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  remote_xla_exec.sh [--mode tmux|ssh|print] <command...>

Environment:
  AE_REMOTE_ENV_FILE    optional env file to source before resolving values
  AE_REMOTE_EXEC_MODE   default: tmux
  AE_TMUX_SESSION       required in tmux mode
  AE_REMOTE_HOST        required in ssh mode
  AE_REMOTE_CONTAINER   required
  AE_REMOTE_WORKDIR     required
  AE_CAPTURE_LINES      default: 200
  AE_CAPTURE_WAIT_SECS  default: 2

Notes:
  - tmux mode assumes the tmux session already exists and is connected to the
    remote host shell.
  - ssh mode assumes key or interactive auth is already available.
  - print mode emits the remote docker command without executing it.
EOF
}

MODE=${AE_REMOTE_EXEC_MODE:-tmux}
ENV_FILE=${AE_REMOTE_ENV_FILE:-}

if [[ -n "$ENV_FILE" ]]; then
  if [[ ! -f "$ENV_FILE" ]]; then
    echo "env file not found: $ENV_FILE" >&2
    exit 1
  fi
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

SESSION=${AE_TMUX_SESSION:-}
HOST=${AE_REMOTE_HOST:-}
CONTAINER=${AE_REMOTE_CONTAINER:-}
REMOTE_WORKDIR=${AE_REMOTE_WORKDIR:-}
CAPTURE_LINES=${AE_CAPTURE_LINES:-200}
CAPTURE_WAIT_SECS=${AE_CAPTURE_WAIT_SECS:-2}

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

escape_sq() {
  printf "%s" "$1" | sed "s/'/'\\\\''/g"
}

USER_CMD="$*"
INNER_CMD="cd '$REMOTE_WORKDIR' && $USER_CMD"
ESCAPED_INNER=$(escape_sq "$INNER_CMD")
DOCKER_CMD="docker exec -i $CONTAINER bash -lc '$ESCAPED_INNER'"

case "$MODE" in
  print)
    [[ -n "$CONTAINER" ]] || { echo "AE_REMOTE_CONTAINER is required" >&2; exit 1; }
    [[ -n "$REMOTE_WORKDIR" ]] || { echo "AE_REMOTE_WORKDIR is required" >&2; exit 1; }
    printf "%s\n" "$DOCKER_CMD"
    ;;
  ssh)
    [[ -n "$HOST" ]] || { echo "AE_REMOTE_HOST is required in ssh mode" >&2; exit 1; }
    [[ -n "$CONTAINER" ]] || { echo "AE_REMOTE_CONTAINER is required" >&2; exit 1; }
    [[ -n "$REMOTE_WORKDIR" ]] || { echo "AE_REMOTE_WORKDIR is required" >&2; exit 1; }
    ssh -tt "$HOST" "$DOCKER_CMD"
    ;;
  tmux)
    [[ -n "$SESSION" ]] || { echo "AE_TMUX_SESSION is required in tmux mode" >&2; exit 1; }
    [[ -n "$CONTAINER" ]] || { echo "AE_REMOTE_CONTAINER is required" >&2; exit 1; }
    [[ -n "$REMOTE_WORKDIR" ]] || { echo "AE_REMOTE_WORKDIR is required" >&2; exit 1; }
    tmux has-session -t "$SESSION" >/dev/null 2>&1 || {
      echo "tmux session '$SESSION' does not exist" >&2
      exit 1
    }
    MARKER="AE_$(date +%s)_$$"
    REMOTE_WRAPPED="printf '%s\n' '$MARKER BEGIN'; $DOCKER_CMD; rc=\$?; printf '%s %s\n' '$MARKER END' \"\$rc\""
    tmux send-keys -t "$SESSION" "$REMOTE_WRAPPED" C-m
    sleep "$CAPTURE_WAIT_SECS"
    tmux capture-pane -pt "$SESSION" | tail -n "$CAPTURE_LINES"
    ;;
  *)
    echo "unsupported mode: $MODE" >&2
    exit 1
    ;;
esac
