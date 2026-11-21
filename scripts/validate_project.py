"""Fast cross-platform checks before using a macOS build runner."""
import json
from pathlib import Path
import plistlib
import re
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
app = root / "ios/LocalDemo"
catalog = json.loads((app / "DemoResources/catalog.json").read_text(encoding="utf-8"))
assert len(catalog["workSections"]) == 16
assert sum(len(s["items"]) for s in catalog["workSections"]) == 75
for relative in catalog["assets"].values():
    path = app / "DemoResources" / relative
    assert path.is_file() and path.stat().st_size > 0, relative
info = plistlib.loads((app / "Info.plist").read_bytes())
assert info["CFBundlePackageType"] == "APPL"
project = (root / "ios/LocalDemo.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
assert 'IPHONEOS_DEPLOYMENT_TARGET = 18.0;' in project
assert 'path = DemoResources;' in project
assert 'path = Resources;' not in project, 'Resources is reserved in Apple bundle layout detection'
for path in app.glob("*.swift"):
    assert f"path = {path.name};" in project, path.name
assert re.search(r'TARGETED_DEVICE_FAMILY = 1;', project)
ET.parse(root / "ios/LocalDemo.xcodeproj/xcshareddata/xcschemes/LocalDemo.xcscheme")
print(f"Validated iOS 18 project, 75 work entries and {len(catalog['assets'])} asset references")
