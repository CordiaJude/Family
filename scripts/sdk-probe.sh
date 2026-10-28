#!/bin/bash
# Prints real SDK declarations for the symbols listed in scripts/probe-patterns.txt.
# Used to verify iOS 26 API names and signatures instead of guessing.
set -uo pipefail

echo "== Xcode =="
xcodebuild -version
echo
echo "== SDKs =="
xcodebuild -showsdks | grep -iE 'ios|watch' || true
echo
echo "== Simulators =="
xcrun simctl list devices available | grep -E 'iPhone|iPad|-- iOS' | head -40

SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
FW="$SDK/System/Library/Frameworks"
echo
echo "SDK: $SDK"

while IFS= read -r line; do
  [[ -z "$line" || "$line" == \#* ]] && continue
  echo
  echo "================ $line ================"
  grep -rhE --include='*arm64-apple-ios-simulator.swiftinterface' -- "$line" "$FW" 2>/dev/null \
    | sed -E 's/^[[:space:]]+//' | sort -u | head -40
done < "$(dirname "$0")/probe-patterns.txt"
