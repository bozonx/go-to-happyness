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
godot --headless --path . --script res://tests/run_all.gd

echo ""
echo "[2/2] Running Feature & Integration Scene Smoke Tests..."

run_test() {
  local script=$1
  local frames=${2:-300}
  echo "-> Running $script ($frames frames)..."
  timeout 45 godot --headless --path . --script "$script" --quit-after "$frames" > /dev/null
}

PASSED=0
FAILED=0

for test_file in $(find tests/features tests/repro -name "test_*.gd" | sort); do
  if run_test "res://$test_file" 300; then
    PASSED=$((PASSED + 1))
  else
    echo "  [FAIL] res://$test_file"
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
