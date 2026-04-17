#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  musa_bazel.sh <build|test> <bazel_target> [more_targets...]

Environment:
  AE_LOCAL_WORKDIR      local workspace root, e.g. /workspace/tf215_openxla_mtgpu
  AE_XLA_REPO_DIR       optional override, default: $AE_LOCAL_WORKDIR/tf_openxla_mtgpu
EOF
}

[[ $# -ge 2 ]] || { usage; exit 1; }

MODE=$1
shift

case "$MODE" in
  build|test) ;;
  *)
    echo "unsupported mode: $MODE" >&2
    usage
    exit 1
    ;;
esac

WORKDIR=${AE_LOCAL_WORKDIR:-/workspace/tf215_openxla_mtgpu}
XLA_REPO_DIR=${AE_XLA_REPO_DIR:-"$WORKDIR/tf_openxla_mtgpu"}

[[ -d "$XLA_REPO_DIR" ]] || { echo "xla repo not found: $XLA_REPO_DIR" >&2; exit 1; }

(
  cd "$XLA_REPO_DIR"
  bazel --noworkspace_rc --bazelrc=.bazelrc.cstage --batch "$MODE" \
    --enable_bzlmod=false --enable_workspace \
    --config=musa \
    --define framework_shared_object=false \
    --copt=-Wno-error=stringop-truncation \
    --host_copt=-Wno-error=stringop-truncation \
    --verbose_failures \
    "$@"
)

