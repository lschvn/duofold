#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP="build/DuoFold.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/DuoFold "$APP/Contents/MacOS/DuoFold"
# App bundle resources take priority over the SwiftPM development fallback.
cp Sources/DuoFold/Resources/Fold.metal "$APP/Contents/Resources/"
cp scripts/Info.plist "$APP/Contents/Info.plist"
if [ -f docs/media/AppIcon.icns ]; then cp docs/media/AppIcon.icns "$APP/Contents/Resources/"; fi
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
printf 'Built %s\n' "$APP"
