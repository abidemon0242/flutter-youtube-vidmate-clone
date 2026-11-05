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
if [[ -f android/key.properties ]]; then
  cp android/key.properties "$TEMP_DIR/TubeArenaKeyProperties.properties"
fi

flutter create --platforms=android --org com.tubearena --project-name app "$TEMP_DIR/native"
rm -rf android
cp -R "$TEMP_DIR/native/android" android
cp "$TEMP_DIR/TubeArenaManifest.xml" android/app/src/main/AndroidManifest.xml
if [[ -f "$TEMP_DIR/TubeArenaKeyProperties.properties" ]]; then
  cp "$TEMP_DIR/TubeArenaKeyProperties.properties" android/key.properties
fi

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
        r"(?m)^(\s*compileSdk(?:Version)?\s*(?:=\s*)?)(?:flutter\.compileSdkVersion|\d+)(\s*(?://.*)?$)",
        r"\g<1>36\g<2>",
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

# Configure a publisher-owned release key when android/key.properties exists.
signing_updated = False
for path in gradle_paths:
    if not path.exists():
        continue
    content = path.read_text()
    if path.name.endswith(".kts"):
        if "keystorePropertiesFile" not in content:
            prefix = """import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

"""
            content = prefix + content
        if 'create("release")' not in content:
            signing_block = """  signingConfigs {
    create("release") {
      if (keystorePropertiesFile.exists()) {
        storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
        storePassword = keystoreProperties.getProperty("storePassword")
        keyAlias = keystoreProperties.getProperty("keyAlias")
        keyPassword = keystoreProperties.getProperty("keyPassword")
      }
    }
  }

"""
            content, count = re.subn(r"(?m)^(\s*)buildTypes\s*\{", signing_block + r"\1buildTypes {", content, count=1)
            if not count:
                raise SystemExit("Could not add release signing configuration to Kotlin Gradle file.")
        content, count = re.subn(
            r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)',
            'signingConfig = if (keystorePropertiesFile.exists()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")',
            content,
            count=1,
        )
        if not count:
            raise SystemExit("Could not connect release signing in Kotlin Gradle file.")
        signing_updated = True
    else:
        if "keystorePropertiesFile" not in content:
            prefix = """def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

"""
            content = prefix + content
        if "signingConfigs {" not in content:
            signing_block = """  signingConfigs {
    release {
      if (keystorePropertiesFile.exists()) {
        storeFile rootProject.file(keystoreProperties['storeFile'])
        storePassword keystoreProperties['storePassword']
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
      }
    }
  }

"""
            content, count = re.subn(r"(?m)^(\s*)buildTypes\s*\{", signing_block + r"\1buildTypes {", content, count=1)
            if not count:
                raise SystemExit("Could not add release signing configuration to Groovy Gradle file.")
        content, count = re.subn(
            r"signingConfig\s+signingConfigs\.debug",
            "signingConfig keystorePropertiesFile.exists() ? signingConfigs.release : signingConfigs.debug",
            content,
            count=1,
        )
        if not count:
            raise SystemExit("Could not connect release signing in Groovy Gradle file.")
        signing_updated = True
    path.write_text(content)

if not signing_updated:
    raise SystemExit("Could not configure release signing for the generated Android project.")
PY

echo "Android project scaffolding generated with plugin-compatible SDK levels."
