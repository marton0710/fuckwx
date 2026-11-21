#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/generate_project.py
mkdir -p build dist
xcodebuild -project ios/LocalDemo.xcodeproj -scheme LocalDemo \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath build/device CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY='' build | tee build/device-build.log
APP="$PWD/build/device/Build/Products/Release-iphoneos/LocalDemo.app"
test -f "$APP/LocalDemo"
APP_PATH="$APP" python3 scripts/package_ipa.py
