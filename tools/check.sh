#!/usr/bin/env bash
# Runs locally exactly what CI runs. Set GODOT to your binary if it is not on PATH.
set -euo pipefail

GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."

echo "== $($GODOT --version)"

# The import pass must come first on a fresh checkout: class_name registration
# lives in .godot/, which is gitignored.
echo "== import"
"$GODOT" --headless --import

echo "== boot"
"$GODOT" --headless --quit

echo "== tests"
"$GODOT" --headless --script res://tests/run_tests.gd
