#!/bin/bash
# Prints the UDID of an available iPhone simulator on the newest iOS runtime.
# Usage: scripts/ci/simulator.sh ["iPhone 17 Pro"]
set -euo pipefail
NAME="${1:-iPhone 17 Pro}"
xcrun simctl list devices available -j | python3 -c '
import json, sys
name = sys.argv[1]
devices = json.load(sys.stdin)["devices"]
def version(runtime):
    tail = runtime.rsplit("iOS-", 1)[-1]
    return tuple(int(p) for p in tail.split("-") if p.isdigit())
ios = sorted((r for r in devices if "iOS" in r), key=version, reverse=True)
for runtime in ios:
    for device in devices[runtime]:
        if device["name"] == name:
            print(device["udid"]); sys.exit(0)
for runtime in ios:
    for device in devices[runtime]:
        if device["name"].startswith("iPhone"):
            print(device["udid"]); sys.exit(0)
sys.exit("No iPhone simulator found")
' "$NAME"
