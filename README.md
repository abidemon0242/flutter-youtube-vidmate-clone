# Tube Arena

Tube Arena is an Android Flutter app for browsing YouTube, streaming videos and saving them for offline viewing in a local library.

## Features

- Live YouTube feed by category, search, and "paste a link" to open any video. If YouTube can't be reached, sample videos are shown with a Retry banner.
- Watch screen with real YouTube streaming, local-file playback, play/pause/replay, a seek bar, ±10 s skip, fullscreen, and lock-screen / notification media controls.
- Download sheet with real options: video (up to the highest quality available, with video and audio combined by FFmpeg) or audio only. File sizes and the actual container (MP4, WebM, MKV, M4A) are shown.
- Download manager: live progress, pause, resume, retry, cancel, multi-select, remove from list, and delete file (with confirmation). The list is saved, and downloads interrupted by closing the app come back as paused and resume from where they stopped.
- Library: a built-in Downloads folder plus your own folders (create, rename, delete). Tap a file to play it offline.

Downloads run while the app is open (including when it's in the background but still alive). They aren't scheduled by the operating system, so if Android stops the app, open it again and tap Resume.

## Build

Requires Flutter 3.50 (3.47 or newer) and JDK 17.

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release --split-per-abi
```

### Release signing

Release builds are signed with your keystore when one of these is provided:

- `android/key.properties` with `storeFile`, `storePassword`, `keyAlias` and `keyPassword`, or
- the environment variables `TUBE_ARENA_KEYSTORE_PATH`, `TUBE_ARENA_KEYSTORE_PASSWORD`, `TUBE_ARENA_KEY_ALIAS` and `TUBE_ARENA_KEY_PASSWORD`.

Without them, the release build falls back to the debug key and prints a warning; that APK installs fine but can't be published or updated over a properly signed build. `key.properties` and `*.jks` are ignored by git.

## CI

`.github/workflows/android-ci.yml` checks formatting, runs analysis and tests, builds the debug APK and the split release APKs, then installs the same debug APK on an Android emulator and makes sure it launches without crashing. APKs are uploaded as workflow artifacts.

## Legal note

Downloading from YouTube may be against YouTube's Terms of Service, and apps that do it aren't allowed on Google Play. Only download content you have the rights to, and distribute this app outside Play.
