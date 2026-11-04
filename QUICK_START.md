# Tube Arena — Quick Start

Tube Arena is an Android-first Flutter app. The repository does not currently support a browser/web preview because it uses native Android media and download plugins.

## Get an Android build

1. Open the repository's Actions tab.
2. Open the latest Tube Arena Android CI run for the branch you want.
3. Check the analysis, tests, debug APK build, split release APK build, and emulator smoke-test jobs separately.
4. Download tube-arena-debug-apk for device testing, or tube-arena-release-apks for per-ABI release builds.
5. Transfer the APK to your Android device and install it.

A successful APK build does not guarantee that every media source, background task, or device-specific feature works. Test the app on a real device.

## Build locally

With Flutter and the Android SDK installed:

    flutter pub get
    dart format lib test
    flutter analyze
    flutter test
    flutter build apk --debug

## Feature overview

- Live YouTube search opens videos in the official YouTube app/browser.
- Demo feed and sample in-app playback.
- Authorized-media URL batch download queue and download management.
- Wi-Fi-only preference, private library, and local media playback.
- Local MP3 conversion and video/audio merge tools.
- Lock-screen controls for local audio playback.

See README.md for current limitations and verification requirements.