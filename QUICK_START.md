# Tube Arena — Quick Start

Tube Arena is an Android-first Flutter app. The Android scaffold is generated locally or in CI with `bash tool/bootstrap_android.sh`.

## Build

1. Install Flutter stable and Android SDK tools.
2. Run `bash tool/bootstrap_android.sh` from the repository root.
3. Run `flutter pub get`.
4. Build with `flutter build apk --debug`, or download a debug APK artifact from GitHub Actions.

## Feature boundaries

- Explore uses public Invidious search and regional catalog metadata; it is not the official YouTube Trending feed.
- YouTube watch pages play through the official embedded player. Tube Arena does not extract YouTube streams.
- Batch downloads accept direct media-file URLs and completed HLS VOD manifests. Live HLS playlists are not supported.
- HLS master manifests can expose available resolutions and estimated sizes; FFmpeg merges separate audio/video streams when required.
- Retry reuses the saved direct media URL; it does not refresh or extract YouTube streams.
- The Downloads screen provides **Share / export file** for completed files stored in app-private storage.
- 3GP conversion uses H.263/AMR-NB; codec and feature-phone compatibility vary.
- Android notification permission is requested when starting a batch. Notifications may be hidden if permission is denied.
- Pause/cancel are unavailable during FFmpeg processing.
- Wi-Fi-only is best-effort. Regular downloads pause on connectivity changes; HLS downloads only check Wi-Fi before starting.
- The emulator smoke test verifies install and launch, not every app workflow.

See README.md for data sources, limitations, and release requirements.
