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


# Paksa semua library Android (plugin) compile pakai SDK 36.
# Beberapa plugin masih compileSdk 34 padahal dependency lifecycle butuh 36.
KTS_BLOCK = """// --- ChatKit: paksa compileSdk 36 untuk semua plugin ---
subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            try {
                androidExt.javaClass
                    .getMethod("setCompileSdk", Int::class.javaObjectType)
                    .invoke(androidExt, 36)
            } catch (e: Exception) {
                println("compileSdk override gagal di ${project.name}: $e")
            }
        }
    }
}
// --- akhir blok ChatKit ---

"""
GROOVY_BLOCK = """// --- ChatKit: paksa compileSdk 36 untuk semua plugin ---
subprojects {
    afterEvaluate { p ->
        if (p.hasProperty('android')) {
            p.android.compileSdk = 36
        }
    }
}
// --- akhir blok ChatKit ---

"""
for name, block in (("build.gradle.kts", KTS_BLOCK), ("build.gradle", GROOVY_BLOCK)):
    root_gradle = root / name
    if root_gradle.exists():
        body = root_gradle.read_text()
        if "ChatKit: paksa compileSdk" not in body:
            root_gradle.write_text(block + body)

print("Android project dipatch.")
