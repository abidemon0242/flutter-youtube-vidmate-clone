# Tube Arena — Android Setup Guide

Tube Arena is an Android-first Flutter prototype. The repository does not currently provide a supported web build; native media plugins are part of the app.

## Option 1: Download the CI debug APK

1. Open the repository on GitHub.
2. Select **Actions** and open a recent **Tube Arena Android CI** run.
3. Inspect the **Flutter analyze, tests and Android build** job.
4. If the APK build step succeeded, download the `tube-arena-debug-apk` artifact.
5. Move the APK to your Android device and install it.

The separate emulator smoke test checks whether the generated APK installs and launches. Review that job independently from the APK build.

## Option 2: Build on a computer

Install Flutter, Android Studio and the Android SDK, then run:

```bash
flutter doctor
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```

The debug APK is written to:

```
build/app/outputs/flutter-apk/app-debug.apk
```

## What currently works

- Mock video feed, category filtering and local search
- Sample network video playback
- Local folder creation and browsing
- Basic Home, Watch, Downloads and Library navigation

## Not yet connected end-to-end

- Real YouTube downloading from the app UI
- Automatic background-download progress/status callbacks
- Ad/tracker network interception
- Lock-screen media controls connected to the video player

The extraction, FFmpeg, download and media-session classes are service foundations only. Do not treat them as complete user-facing features yet.
