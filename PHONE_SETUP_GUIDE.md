# Tube Arena — Android Setup Guide

## Build and install

1. Install Flutter stable and Android SDK tools.
2. Run `bash tool/bootstrap_android.sh` from the repository root to generate the Android Gradle project.
3. Run `flutter pub get`.
4. Build with `flutter build apk --debug`, or download a debug APK artifact from GitHub Actions.
5. Install on the target Android phone and test downloads, background behavior, playback, conversion and file export.

The CI emulator test verifies installation and launch only. It does not verify live YouTube extraction, FFmpeg codec availability, or feature-phone compatibility.

## Implemented workflows

- Live public YouTube search; results open in the official YouTube app/browser.
- Batch downloads for content you own or are authorized to save, with available quality selection, progress, pause/resume/cancel/retry and persistent history.
- YouTube stream URLs are refreshed on retry for tasks that retain their original source URL. Older task records and direct media URLs cannot be refreshed automatically.
- 3GP conversion uses H.263 video and AMR-NB audio.
- Completed downloads can be shared/exported using **Share / export file** in Downloads.
- Local folders, file browsing, rename, move and safe deletion.
- Local audio/video playback, MP3 extraction, video/audio merge and media-session controls.
- Android notification permission is requested when starting a batch. If denied, downloads may run without visible notifications.

## Known limitations

- Downloaded files are stored in app-private storage; the share sheet is the supported transfer route.
- Actual 3GP compatibility depends on the FFmpeg encoders in the build and the receiving phone.
- Adaptive merge is a processing state; pause/cancel are disabled during FFmpeg execution.
- Wi-Fi-only behavior is best-effort; Android may suspend the app and delay connectivity events.
- Ad/tracker URL classification does not intercept YouTube traffic or remove YouTube ads.
- Production release signing must be configured with a private key owned by the app publisher. No signing key is included in this repository.

See README.md for the full technical boundaries and release requirements.
