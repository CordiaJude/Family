#!/bin/bash
# Fails if an xcodebuild log contains any compiler or build warnings.
# Usage: scripts/ci/check-warnings.sh build.log
set -uo pipefail
LOG="$1"
WARNINGS=$(grep -E "(^|: )warning: " "$LOG" | grep -v "^ld: warning: ignoring duplicate libraries" | sort -u)
if [[ -n "$WARNINGS" ]]; then
  echo "::group::Warnings ($(echo "$WARNINGS" | wc -l | tr -d ' '))"
  echo "$WARNINGS"
  echo "::endgroup::"
  echo "$WARNINGS" | head -50 | while IFS= read -r line; do echo "::warning::$line"; done
  echo "Build produced warnings. The project must build with zero warnings."
  exit 1
fi
echo "No warnings."
