# Tube Arena — Android Setup Guide

Tube Arena is an Android Flutter app. There is no web or iOS build; the app relies on Android media plugins.

## Option 1: Download an APK from CI

1. Open the repository on GitHub.
2. Select **Actions** and open a recent **Tube Arena Android CI** run.
3. Inspect the **Flutter analyze, tests and Android build** job.
4. Download `tube-arena-release-apks` (use `app-arm64-v8a-release.apk` for most phones) or `tube-arena-debug-apk`.
5. Move the APK to your Android device and install it.

The separate emulator smoke test checks whether the generated APK installs and launches. Review that job independently from the APK build.

## Option 2: Build on a computer

Install Flutter 3.50 (3.47 or newer), JDK 17 and the Android SDK, then run:

```bash
flutter doctor
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

The debug APK is written to:

```
build/app/outputs/flutter-apk/app-debug.apk
```

## What works

- Live YouTube feed, search and paste-a-link
- Streaming playback with seek, skip, fullscreen and lock-screen controls
- Video (with video and audio combined) and audio-only downloads with progress, pause, resume, retry and cancel
- Downloads saved across app restarts; interrupted ones resume from where they stopped
- Offline playback and folder management in the Library

## Limits

- Downloads run while the app is alive. If Android stops the app, reopen it and tap Resume.
- YouTube sometimes blocks or rate-limits requests; the app then shows sample videos and a Retry button.
- Downloading from YouTube may break YouTube's Terms of Service, and this app can't be published on Google Play. Install it directly from the APK.
