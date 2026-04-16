#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)
TARGET_DIR=${1:-"$HOME/.codex/skills/agentic-evolution"}

mkdir -p "$(dirname "$TARGET_DIR")"
ln -sfn "$ROOT_DIR" "$TARGET_DIR"

printf "Installed skill link:\n  %s -> %s\n" "$TARGET_DIR" "$ROOT_DIR"
printf "If Codex is already running, restart it so the skill list refreshes.\n"
