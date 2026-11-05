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
        '        <meta-data android:name="io.flutter.embedding.android.NormalTheme" android:resource="@style/NormalTheme" />\\n        <intent-filter>',
        1,
    )
if 'android:name="flutterEmbedding"' not in content:
    content = content.replace(
        '    </application>',
        '        <meta-data android:name="flutterEmbedding" android:value="2" />\\n    </application>',
        1,
    )
manifest.write_text(content)
PY

echo "Android project scaffolding generated. Review the Android files before committing them."
