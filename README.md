# Tube Arena

Tube Arena is an Android Flutter app for browsing YouTube, streaming videos and saving them for offline viewing in a local library.

## Features

- Live YouTube feed by category, search, and "paste a link" to open any video. The feed and search results scroll endlessly (the next page loads near the bottom, without duplicates, and "No more results" marks the end). If YouTube can't be reached, sample videos are shown with a Retry banner.
- Watch screen with real YouTube streaming, local-file playback, play/pause/replay, a seek bar, ±10 s skip, fullscreen, and lock-screen / notification media controls. Below the player: the description (tap to expand) with views and upload date, and related videos that open in the player.
- Quality picker (gear button on the player). Progressive MP4 streams are usually 360p only, so the app also asks YouTube for HLS streams, which usually go up to 1080p and include audio. If HLS isn't offered for a video, it plays at 360p. Your choice is remembered as the preferred quality, and switching keeps the position, fullscreen and the notification.
- Background playback: the video keeps playing (as audio) with the screen locked or in another app, controlled from the notification and lock screen. Stop in the notification pauses playback and removes the notification; leaving the watch screen ends playback. You can turn background playback off in the player's settings sheet.
- Download sheet with real options: video (up to the highest quality available, with video and audio combined by FFmpeg) or audio only. File sizes and the actual container (MP4, WebM, MKV, M4A) are shown.
- Download manager: live progress, pause, resume, retry, cancel, multi-select, remove from list, and delete file (with confirmation). The list is saved, and downloads interrupted by closing the app come back as paused and resume from where they stopped.
- Light and dark themes, or follow the phone's setting. Switch from the sun/moon button on Home or Library; the choice is remembered.
- Library: a built-in Downloads folder plus your own folders (create, rename, delete). Tap a file to play it offline, or use its menu to move it to another folder (the Downloads list stays in sync), save it to the phone or share it.
- Save to phone: copies a file into public storage through MediaStore (videos to Movies/Tube Arena, audio to Music/Tube Arena), so it appears in Gallery / Files and survives uninstalling the app. Android 9 and older ask for the storage permission.
- Background downloads: a `dataSync` foreground service shows an ongoing progress notification while downloads run, plus a notification when each download finishes or fails.
- Free-space check: before a download starts (and again once real stream sizes are known) Tube Arena checks free storage, counting merged downloads twice, and refuses with a clear message if it won't fit.
- Download on Wi-Fi only (Downloads ⋮ menu): queued downloads wait with "Waiting for Wi-Fi" and continue automatically when Wi-Fi returns; a running download that loses Wi-Fi goes back to the queue and resumes from the bytes already saved.
- Batch download from Home fetches up to 3 videos' formats at a time, shows "Preparing 3 of 10", and ends with a summary of any failures.

Downloads run in Dart inside the app process; the foreground service keeps that process alive in the background. If Android still stops the app, open it again and tap Resume.

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
