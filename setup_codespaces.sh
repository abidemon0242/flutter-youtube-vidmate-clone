#!/usr/bin/env bash
# Sets up Flutter for Tube Arena in GitHub Codespaces or another Linux shell.
# The app is Android-only, so no Linux desktop toolchain is installed.
set -euo pipefail

FLUTTER_VERSION="3.50.1"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f "$PROJECT_DIR/pubspec.yaml" ]; then
  echo "Error: run this script from the Tube Arena repository (pubspec.yaml not found in $PROJECT_DIR)." >&2
  exit 1
fi

echo "Installing system packages..."
sudo apt-get update -qq
sudo apt-get install -y -qq git curl unzip xz-utils zip openjdk-17-jdk-headless

if [ ! -x "$HOME/flutter/bin/flutter" ]; then
  echo "Downloading Flutter $FLUTTER_VERSION..."
  git clone https://github.com/flutter/flutter.git -b "$FLUTTER_VERSION" --depth 1 "$HOME/flutter"
fi

export PATH="$HOME/flutter/bin:$PATH"
if ! grep -q 'flutter/bin' "$HOME/.bashrc" 2>/dev/null; then
  echo 'export PATH="$HOME/flutter/bin:$PATH"' >> "$HOME/.bashrc"
fi

flutter --version
cd "$PROJECT_DIR"
flutter pub get
flutter analyze
flutter test

cat <<'MSG'

Setup complete. Dart analysis and tests ran successfully.

Building an APK also needs the Android SDK. Without it, download an APK from the
repository's Actions tab (artifact "tube-arena-release-apks" or "tube-arena-debug-apk").
With the Android SDK installed:
  flutter build apk --release --split-per-abi
MSG
