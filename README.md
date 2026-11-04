# Tube Arena

Tube Arena is an Android-first Flutter prototype for a YouTube-inspired media browser and local media library.

## Working prototype features

- Mock video feed with category filtering and local search
- Sample network video playback
- Local folder creation and browsing inside the app's private storage
- Download-list state management and safe file deletion when a saved path is supplied
- Basic navigation between Home, Watch, Downloads, and Library

## Service foundations (not yet connected end-to-end)

The repository also contains service-level foundations for YouTube metadata/stream extraction, background downloads, FFmpeg processing, media-session controls, and ad/tracker URL classification. These are not currently wired into the visible Watch/Download flow as a complete downloader.

In particular:
- The home feed uses mock data, not live YouTube search or recommendations.
- The Watch screen uses a sample video URL.
- The Download action is explicitly disabled in the prototype; it does not yet start a real download from the UI.
- The ad-blocking class classifies URLs but does not intercept player or WebView network traffic.
- Media-session controls are not yet connected to the video player.

## Android build notes

The Android CI workflow generates the missing Gradle scaffolding, applies the required Android SDK levels, runs Dart analysis and tests, builds a debug APK, and attempts an emulator launch smoke test.

The checked-in Android directory is intentionally minimal; use the CI-generated Android project as the current build verification path.
