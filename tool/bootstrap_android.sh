#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -f android/app/src/main/AndroidManifest.xml ]]; then
  echo "Expected the Tube Arena AndroidManifest.xml at android/app/src/main/AndroidManifest.xml" >&2
  exit 1
fi

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
cp android/app/src/main/AndroidManifest.xml "$TEMP_DIR/TubeArenaManifest.xml"

flutter create --platforms=android --org com.tubearena --project-name app "$TEMP_DIR/native"
rm -rf android
cp -R "$TEMP_DIR/native/android" android
cp "$TEMP_DIR/TubeArenaManifest.xml" android/app/src/main/AndroidManifest.xml

python3 - <<'PY'
from pathlib import Path

manifest = Path("android/app/src/main/AndroidManifest.xml")
content = manifest.read_text()
content = content.replace(' package="com.tubearena.app"', '')
if 'android:name="io.flutter.embedding.android.NormalTheme"' not in content:
    content = content.replace(
        '        <intent-filter>',
        '        <meta-data android:name="io.flutter.embedding.android.NormalTheme" android:resource="@style/NormalTheme" />\n        <intent-filter>',
        1,
    )
if 'android:name="flutterEmbedding"' not in content:
    content = content.replace(
        '    </application>',
        '        <meta-data android:name="flutterEmbedding" android:value="2" />\n    </application>',
        1,
    )
manifest.write_text(content)

# Keep this bootstrap usable outside CI too. Several plugins require API 24+
# and the current plugin set is compiled against Android API 36.
import re

gradle_paths = [
    Path("android/app/build.gradle"),
    Path("android/app/build.gradle.kts"),
]
min_replacements = [
    ("minSdkVersion flutter.minSdkVersion", "minSdkVersion 24"),
    ("minSdkVersion = flutter.minSdkVersion", "minSdkVersion = 24"),
    ("minSdk = flutter.minSdkVersion", "minSdk = 24"),
]
min_updated = False
compile_updated = False
for path in gradle_paths:
    if not path.exists():
        continue
    original = path.read_text()
    updated = original
    for old, new in min_replacements:
        updated = updated.replace(old, new)
    if updated != original:
        min_updated = True
    updated, count = re.subn(
        r"(?m)^(\\s*compileSdk(?:Version)?\\s*(?:=\\s*)?)(?:flutter\\.compileSdkVersion|\\d+)(\\s*(?://.*)?$)",
        r"\\g<1>36\\g<2>",
        updated,
    )
    if count:
        compile_updated = True
    if updated != original:
        path.write_text(updated)

if not min_updated:
    raise SystemExit("Could not set Android minSdk to 24 in generated Gradle configuration.")
if not compile_updated:
    raise SystemExit("Could not set Android compileSdk to 36 in generated Gradle configuration.")
PY

echo "Android project scaffolding generated with plugin-compatible SDK levels."
