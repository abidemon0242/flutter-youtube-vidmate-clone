# Tube Arena — Quick Start

Tube Arena is currently an **Android-first Flutter prototype**. A browser/web preview is not a supported run target because the project includes native Android media plugins.

## Get an Android debug build

1. Open the repository's **Actions** tab.
2. Open a completed **Tube Arena Android CI** run.
3. In the **Flutter analyze, tests and Android build** job, check that analysis, tests and APK build passed.
4. Download the `tube-arena-debug-apk` artifact if it is available.
5. Transfer the APK to your Android device and install it.

The emulator smoke-test job is a separate check. An APK artifact may exist even if that later smoke test fails; check the individual job results.

## Build locally

With Flutter and the Android SDK installed:

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```

## Current prototype scope

- Mock video feed, local search and category filtering
- Sample network video playback
- Local folder creation and browsing
- Downloads list UI and safe file-record deletion

Real YouTube downloads, download progress callbacks, network ad interception, and player-connected lock-screen controls are **not yet integrated end-to-end**. See [README.md](README.md) for details.
