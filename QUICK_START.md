# Tube Arena — Quick Start

Tube Arena is an Android-first Flutter app. The Android scaffold is generated locally or in CI with `bash tool/bootstrap_android.sh`.

## Build and install

1. Install Flutter stable and Android SDK tools.
2. Run `bash tool/bootstrap_android.sh` from the repository root.
3. Run `flutter pub get`.
4. Build with `flutter build apk --debug`, or download a debug APK artifact from GitHub Actions.
5. Install on Android and test downloads, background behavior, playback, 3GP conversion and file sharing.

Check both the Flutter build/test job and the separate emulator smoke-test job. The emulator job verifies install and launch, not all app workflows.

## Current feature boundaries

- Explore uses live public YouTube search results, not official Trending.
- YouTube watch pages open in the official YouTube app/browser.
- Batch downloads use available stream qualities and FFmpeg for adaptive stream merging.
- Retry refreshes YouTube stream URLs for tasks that saved the original source URL. Older records and generic direct URLs cannot be refreshed.
- The Downloads screen provides **Share / export file** for completed files. Files are stored privately and shared through Android's share sheet.
- 3GP conversion uses H.263/AMR-NB; codec and feature-phone compatibility vary.
- The app requests notification permission when starting a batch. Downloads may continue if permission is denied, but notifications can be hidden.
- FFmpeg merge is shown as a separate processing state. Pause/cancel are unavailable during processing.
- Wi-Fi-only is best-effort pausing, not a system-level data block.
- Ad/tracker URL classification does not intercept traffic or remove YouTube ads.

See README.md for full limitations and release requirements.
