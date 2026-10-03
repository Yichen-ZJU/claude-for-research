#!/usr/bin/env bash
# One-command regression suite (T01): queue state machine + installer scenarios.
set -e
cd "$(dirname "$0")/.."
python3 tests/queue_state_test.py
bash tests/installer_test.sh
echo "== ALL TEST SUITES PASSED =="
