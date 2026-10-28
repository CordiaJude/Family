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
shoot() {  # shoot <name> <seconds> <launch arguments...>
  local name="$1" wait="$2"; shift 2
  xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE_ID" "$@" >/dev/null
  sleep "$wait"
  xcrun simctl io "$UDID" screenshot "$OUT/$name.png" >/dev/null
  echo "Captured $name"
}
for appearance in light dark; do
  xcrun simctl ui "$UDID" appearance "$appearance"
  # Onboarding, from an empty store.
  for step in welcome you household family home connect done; do
    shoot "$appearance-onboarding-$step" 4 -FamilyResetAllData -FamilyOnboardingStep "$step"
  done
  # The app with the sample household.
  for tab in today calendar map home search; do
    shoot "$appearance-$tab" "$([[ "$tab" == "map" ]] && echo 10 || echo 5)" -FamilySampleData -FamilyInitialTab "$tab"
  done
done
