# Tube Arena — Quick Start

## Get an APK from CI

1. Open the repository's **Actions** tab and pick the latest successful **Tube Arena Android CI** run.
2. Download `tube-arena-release-apks` (pick `app-arm64-v8a-release.apk` for most phones) or `tube-arena-debug-apk`.
3. Copy the APK to your phone and install it (allow "Install unknown apps" when asked).

## Build locally

```bash
flutter pub get
flutter test
flutter build apk --release --split-per-abi
```

For a properly signed release build, see "Release signing" in `README.md`.

## Using the app

- **Theme:** tap the sun/moon icon on Home or Library and pick Light, Dark or Use device setting.
- **Home:** browse categories, search, or tap the link icon to paste a YouTube URL. Long-press videos to select several and download them together.
- **Watch:** tap Download to choose a quality or audio only. Allow notifications to get lock-screen playback controls.
- **Downloads:** pause, resume, retry or cancel. Tap a finished download to play it. Long-press to select, then delete. The ⋮ menu on a finished download has **Save to phone** (copies it to Movies/Tube Arena or Music/Tube Arena so Gallery and Files see it) and **Share**. The ⋮ menu in the top bar has **Download on Wi-Fi only**.
- **Library:** the Downloads folder holds everything you save. Create your own folders with the folder icon; long-press a folder to rename or delete it. Each file's ⋮ menu has Move to folder, Save to phone, Share and Delete.

Downloads keep running in the background with a progress notification, and you get a notification when each one finishes or fails. A download that won't fit in free storage is refused up front. If Android still stops the app, reopen it and tap Resume; it continues from where it stopped.
