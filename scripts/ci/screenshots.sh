#!/bin/bash
# Installs the built app on a booted simulator and screenshots each tab in
# light and dark mode. Usage: scripts/ci/screenshots.sh <udid> <Family.app> <out-dir>
set -euo pipefail
UDID="$1"; APP="$2"; OUT="$3"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP/Info.plist")
mkdir -p "$OUT"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
xcrun simctl install "$UDID" "$APP"
for appearance in light dark; do
  xcrun simctl ui "$UDID" appearance "$appearance"
  for tab in today calendar map home search; do
    xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE_ID" -FamilyInitialTab "$tab" >/dev/null
    sleep $([[ "$tab" == "map" ]] && echo 10 || echo 5)
    xcrun simctl io "$UDID" screenshot "$OUT/$appearance-$tab.png" >/dev/null
    echo "Captured $appearance-$tab"
  done
done
