#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/screenshots
python3 scripts/generate_project.py
xcrun simctl list devices available -j > build/simulators.json
python3 - <<'PY' > build/test-devices.txt
import json
from pathlib import Path
devices = json.loads(Path('build/simulators.json').read_text())['devices']
runtimes = sorted((key for key in devices if '.iOS-18-' in key), reverse=True)
if not runtimes:
    raise SystemExit('An iOS 18 simulator runtime is required')
for name in ['iPhone 16', 'iPhone 16 Pro Max']:
    match = next((d for r in runtimes for d in devices[r] if d['name'] == name and d.get('isAvailable')), None)
    if not match:
        raise SystemExit('Missing simulator: ' + name)
    print(match['udid'])
PY
index=0
while IFS= read -r device; do
  index=$((index + 1))
  xcodebuild build-for-testing -project ios/LocalDemo.xcodeproj -scheme LocalDemo \
    -configuration Debug -destination "platform=iOS Simulator,id=$device" \
    -derivedDataPath build/simulator ONLY_ACTIVE_ARCH=YES \
    CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=YES CODE_SIGN_IDENTITY=- \
    | tee "build/simulator-build-$index.log"
  plutil -p build/simulator/Build/Products/Debug-iphonesimulator/LocalDemo.app/Info.plist
  xcodebuild test-without-building -project ios/LocalDemo.xcodeproj -scheme LocalDemo \
    -configuration Debug -destination "platform=iOS Simulator,id=$device" \
    -derivedDataPath build/simulator -resultBundlePath "build/iPhone16-$index.xcresult" \
    -parallel-testing-enabled NO ONLY_ACTIVE_ARCH=YES \
    CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=YES CODE_SIGN_IDENTITY=- \
    | tee "build/simulator-$index.log"
  xcrun xcresulttool export attachments --path "build/iPhone16-$index.xcresult" \
    --output-path "build/screenshots/iPhone16-$index"
done < build/test-devices.txt
