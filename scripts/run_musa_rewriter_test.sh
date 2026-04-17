#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)
TARGET=${1:-${AE_REWRITER_TEST_TARGET:-"//third_party/xla/xla/service/gpu:musa_layer_norm_rewriter_test"}}

"$ROOT_DIR/scripts/musa_bazel.sh" test "$TARGET"

