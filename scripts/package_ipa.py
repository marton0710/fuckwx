"""Package and validate the unsigned device app, without requiring signing assets."""
import hashlib
import os
from pathlib import Path
import plistlib
import zipfile

root = Path(__file__).resolve().parents[1]
app = Path(os.environ.get("APP_PATH", root / "build/device/Build/Products/Release-iphoneos/LocalDemo.app"))
info = plistlib.loads((app / "Info.plist").read_bytes())
assert info["CFBundleSupportedPlatforms"] == ["iPhoneOS"], "Cannot package a simulator build"
assert info["MinimumOSVersion"] == "18.0", info["MinimumOSVersion"]
assert (app / info["CFBundleExecutable"]).is_file(), "Missing executable"
assert (app / "Resources/catalog.json").is_file(), "Missing app resources"
assert not (app / "embedded.mobileprovision").exists(), "Expected an unsigned build"
destination = root / "dist/LocalDemo-unsigned.ipa"
destination.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(app.rglob("*")):
        if path.is_file():
            archive.write(path, "Payload/LocalDemo.app/" + path.relative_to(app).as_posix())
with zipfile.ZipFile(destination) as archive:
    assert archive.testzip() is None
checksum = hashlib.sha256(destination.read_bytes()).hexdigest()
(destination.parent / "SHA256SUMS.txt").write_text(checksum + "  " + destination.name + "\n", encoding="utf-8")
print(f"Validated unsigned iOS 18+ IPA: {destination} ({destination.stat().st_size} bytes)")
