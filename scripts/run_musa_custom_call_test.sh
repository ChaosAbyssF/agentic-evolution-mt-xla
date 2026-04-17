#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)
CUSTOM_TARGET=${1:-${AE_CUSTOM_CALL_TEST_TARGET:-"//third_party/xla/xla/service/gpu:musa_fusion_custom_calls_test"}}
WITH_RUNTIME_REG=${AE_WITH_RUNTIME_REG_TEST:-1}

"$ROOT_DIR/scripts/musa_bazel.sh" test "$CUSTOM_TARGET"

if [[ "$WITH_RUNTIME_REG" == "1" || "$WITH_RUNTIME_REG" == "true" ]]; then
  "$ROOT_DIR/scripts/musa_bazel.sh" test "//third_party/xla/xla/service/gpu:musa_runtime_registration_test"
fi

