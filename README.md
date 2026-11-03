# Tube Arena

Tube Arena is an Android-focused Flutter media app prototype with a YouTube-inspired interface, background download management, and a local media library.

> **Project status:** Development prototype. It is not yet a production-ready YouTube client or a live video catalogue.

## Current features

- Demo home feed with local search and basic category filtering.
- Sample video playback screen with clear demo-content labeling.
- Batch link entry for videos the user owns or is authorized to save.
- YouTube URL validation and metadata/stream inspection.
- Selection of compatible video streams that already contain both audio and video.
- Audio-only downloads that preserve the source audio container (no conversion).
- Background download queue using FlutterDownloader.
- Download progress, persisted task metadata, and startup restoration.
- Pause, resume, cancel, retry, and remove controls.
- Local Library folders with real file counts.
- Local playback for supported video and audio files.
- Local share, like/dislike, and bookmark UI interactions on the demo watch screen.

## Important limitations

- The home feed is mock data, not a live YouTube feed.
- The Watch screen uses a sample MP4; it does not play the original media represented by a demo card.
- Separate adaptive video/audio stream merging is not implemented.
- Actual MP3 conversion is not implemented. Audio-only downloads retain their original container.
- Like/dislike/bookmark actions are local UI state only; there is no account sync or cloud persistence.
- Full folder/file management UI, advanced queue controls, and comprehensive retry/backoff behavior are still in progress.
- The app has not yet passed a verified Android build and physical-device test cycle.

Only use the link-download feature for media you own or have permission to save, and follow the source platform's terms.

## Development setup

Requirements:
- Flutter stable (Dart SDK constraint: >=3.3.0 and <4.0.0).
- Android development toolchain and Java 17 for Android builds.

Run these commands from the project root:

    flutter pub get
    flutter analyze
    flutter test
    flutter build apk --debug

A GitHub Actions workflow in .github/workflows/flutter-ci.yml runs analysis, tests, and a debug APK build for pull requests and pushes to the configured branches.

## App identity

- Name: Tube Arena
- Android application ID: com.tubearena.app
- Current version: 1.0.0+1
