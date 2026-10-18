"""Patch project Android hasil `flutter create`: izin, nama app, minSdk."""
import pathlib
import re

root = pathlib.Path("android")

manifest = root / "app/src/main/AndroidManifest.xml"
text = manifest.read_text()
perms = (
    '    <uses-permission android:name="android.permission.RECORD_AUDIO"/>\n'
    '    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" '
    'android:maxSdkVersion="28"/>\n'
)
if "RECORD_AUDIO" not in text:
    text = text.replace("<application", perms + "    <application", 1)
text = re.sub(r'android:label="[^"]*"', 'android:label="ChatKit"', text, count=1)
manifest.write_text(text)

for name in ("build.gradle.kts", "build.gradle"):
    gradle = root / "app" / name
    if not gradle.exists():
        continue
    content = gradle.read_text()
    content = content.replace("minSdk = flutter.minSdkVersion", "minSdk = 24")
    content = content.replace("minSdkVersion flutter.minSdkVersion", "minSdkVersion 24")
    content = content.replace("minSdkVersion = flutter.minSdkVersion", "minSdkVersion = 24")
    gradle.write_text(content)

print("Android project dipatch.")
