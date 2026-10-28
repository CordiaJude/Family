#!/bin/bash
# Runs xcodebuild with the given arguments, writing the full log to $LOG.
# On failure, prints every error and the end of the log.
# Usage: LOG=build.log scripts/ci/xcb.sh build -project ... 
set -uo pipefail
LOG="${LOG:?set LOG to a log file path}"
xcodebuild "$@" > "$LOG" 2>&1
STATUS=$?
grep -E "^(Test Suite|Test Case|✔|✘|◇ Test run|✔ Test run|✘ Test run)|Executed [0-9]+ test" "$LOG" | tail -60 || true
if [[ $STATUS -ne 0 ]]; then
  echo "::group::Errors"
  grep -E "(error|failed):" "$LOG" | sort -u | head -150
  echo "::endgroup::"
  echo "::group::Last 150 lines"
  tail -150 "$LOG"
  echo "::endgroup::"
  grep -E ": error: " "$LOG" | sort -u | head -30 | while IFS= read -r line; do echo "::error::$line"; done
fi
exit $STATUS
