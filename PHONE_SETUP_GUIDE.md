# Tube Arena — Android Setup Guide

## Build

1. Install Flutter stable and Android SDK tools.
2. Run `bash tool/bootstrap_android.sh` from the repository root.
3. Run `flutter pub get`.
4. Build with `flutter build apk --debug`, or download a debug APK artifact from GitHub Actions.

The CI emulator test verifies installation and launch only. It does not verify live catalog availability, FFmpeg codec support, or compatibility with a specific phone.

## Implemented workflows

- Public search and regional metadata through community Invidious instances; public channel subscriptions use YouTube RSS.
- YouTube playback through the official embedded player.
- Batch downloads for direct media URLs and completed HLS VOD manifests, with available quality selection, progress, pause/resume/cancel/retry, and persistent history.
- Local folders, file browsing, rename, move, and safe deletion.
- Local audio/video playback, MP3 extraction, video/audio conversion, and supported media-session controls.
- Completed downloads can be shared/exported using **Share / export file** in Downloads.

## Known limitations

- YouTube watch-page URLs are not extracted or downloaded. No YouTube Data API key is required.
- Private YouTube playlists and private account history are not supported.
- Live HLS playlists are not supported.
- Wi-Fi-only behavior is best-effort. Regular downloads pause on connectivity changes; HLS downloads only check Wi-Fi before starting.
- FFmpeg merge/conversion may fail when a required codec is unavailable. Pause/cancel are unavailable during processing.
- Downloaded files are stored in app-private storage; the share sheet is the supported transfer route.
- Android may delay background notifications and connectivity events.
- Production release signing must use a private key owned by the app publisher.

See README.md for full technical boundaries and release requirements.
