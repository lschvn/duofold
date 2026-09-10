#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build-app.sh
mkdir -p build/dmg
cp -R build/DuoFold.app build/dmg/
if [ ! -L build/dmg/Applications ]; then ln -s /Applications build/dmg/Applications; fi
hdiutil create -volname DuoFold -srcfolder build/dmg -ov -format UDZO build/DuoFold-0.1.1-arm64.dmg
shasum -a 256 build/DuoFold-0.1.1-arm64.dmg
