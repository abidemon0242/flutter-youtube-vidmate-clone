#!/usr/bin/env bash
# Installs the debug APK on the running emulator, launches it and fails on a crash.
set -euo pipefail
APK="${1:-app-debug.apk}"
PKG=com.tubearena.app

adb wait-for-device
adb install -r "$APK"
adb logcat -c
adb shell am start -W -n "$PKG/.MainActivity"
sleep 20

app_pid="$(adb shell pidof "$PKG" | tr -d '\r' || true)"
if [ -z "$app_pid" ]; then
  echo "App process is not running after launch."
  adb logcat -d -t 2000 || true
  exit 1
fi

if adb logcat -d -t 2000 | grep -E "FATAL EXCEPTION|Process: $PKG"; then
  echo "Android runtime crash detected."
  exit 1
fi

adb exec-out screencap -p > emulator-screenshot.png || true
# Verify that the onboarding screen exposes both authentication choices.
adb shell uiautomator dump /sdcard/tube-arena-window.xml >/dev/null
adb shell cat /sdcard/tube-arena-window.xml > emulator-window.xml
if ! grep -q 'Continue with Google' emulator-window.xml; then
  echo "Google sign-in action is not visible on the launched screen."
  cat emulator-window.xml
  exit 1
fi
if ! grep -q 'Send login link' emulator-window.xml; then
  echo "Email-link sign-in action is not visible on the launched screen."
  cat emulator-window.xml
  exit 1
fi
echo "Both authentication choices are visible on the emulator."
echo "App launched successfully (pid $app_pid)."
