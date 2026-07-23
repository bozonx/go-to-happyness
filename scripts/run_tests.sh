#!/usr/bin/env bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

echo "=================================================="
echo "          GO TO HAPPYNESS TEST SUITE              "
echo "=================================================="

echo ""
echo "[1/2] Running Domain & AI Unit Tests..."
unit_log="$(mktemp)"
if ! godot --headless --path . --script res://tests/run_all.gd > "$unit_log" 2>&1; then
  cat "$unit_log"
  rm -f "$unit_log"
  exit 1
fi
if rg -q 'Assertion failed|Parse Error|Compile Error|SCRIPT ERROR:' "$unit_log"; then
  echo "[FAIL] Unit test runner emitted an error."
  cat "$unit_log"
  rm -f "$unit_log"
  exit 1
fi
cat "$unit_log"
rm -f "$unit_log"

echo ""
echo "[2/2] Running Feature & Integration Scene Smoke Tests..."

run_test() {
  local script=$1
  local frames=${2:-300}
  local tmpfile
  tmpfile="$(mktemp)"
  echo "-> Running $script ($frames frames)..."
  if timeout 45 godot --headless --path . --script "$script" --quit-after "$frames" > "$tmpfile" 2>&1 && ! rg -q 'Assertion failed|Parse Error|Compile Error|SCRIPT ERROR:' "$tmpfile"; then
    rm -f "$tmpfile"
  else
    echo "  [FAIL] $script"
    echo "  --- output ---"
    cat "$tmpfile"
    echo "  --- end output ---"
    rm -f "$tmpfile"
    return 1
  fi
}

PASSED=0
FAILED=0

for test_file in $(find tests/features tests/repro -name "test_*.gd" | sort); do
  if run_test "res://$test_file" 300; then
    PASSED=$((PASSED + 1))
  else
    FAILED=$((FAILED + 1))
  fi
done

echo ""
echo "=================================================="
echo " RESULTS: $PASSED feature test(s) passed, $FAILED failed."
echo "=================================================="

if [ "$FAILED" -ne 0 ]; then
  exit 1
fi
