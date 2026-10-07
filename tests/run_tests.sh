#!/usr/bin/env bash
# One-command regression suite (T01): queue state machine + installer scenarios.
set -e
cd "$(dirname "$0")/.."
python3 tests/queue_state_test.py
python3 tests/queue_integration_test.py  # real screen/process chain (E04 guard), skips if no screen
python3 tests/queue_namespace_test.py     # real screen namespace coexistence (E05), skips if no screen
bash tests/installer_test.sh
echo "== ALL TEST SUITES PASSED =="
