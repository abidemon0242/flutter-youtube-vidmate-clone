# Tube Arena

[![Android CI](https://github.com/abidemon0242/flutter-youtube-vidmate-clone/actions/workflows/android-ci.yml/badge.svg?branch=fix%2Fhigh-priority-bugs)](https://github.com/abidemon0242/flutter-youtube-vidmate-clone/actions/workflows/android-ci.yml)

Tube Arena is an Android-first Flutter media app with video discovery, playback, downloads, and an offline library. It is an independent project and is not affiliated with or endorsed by YouTube or Google.

> **Development status:** active development. A successful CI run is not a substitute for testing on a physical Android device. Do not treat this project as a production-ready release until the release checklist and device tests have passed.

## Current functionality

The current repair branch includes the following implementations. Some depend on live third-party extraction or Android-specific runtime behavior and still require device verification.

- **Discovery:** search-based video discovery, category filters, pagination, paste-a-link, and fallback sample content when the remote source is unavailable. Trending is search-derived discovery, not YouTube's official Trending feed.
- **Home personalization:** local interests and study subtopics, show-more/show-less feedback, hidden-channel controls, local subscriptions, Watch Later, and watch history. These preferences are stored locally; they are not synced to a YouTube or Firebase account.
- **Playback:** streaming and local playback, seek controls, skip controls, fullscreen, playback speed, press-and-hold 2×, quality selection, and Android media notification/lock-screen controls. Exact stream availability varies by video and source.
- **Downloads:** single and batch download flows, progress, pause/resume/retry/cancel, Wi-Fi-only setting, video/audio selection, and local download history. Some higher-quality video downloads require FFmpeg stream merging.
- **Offline library:** local folders, file management, offline playback, and separate regular-video, Shorts-video, and audio storage.
- **Shorts:** a vertical swipe player and an offline Shorts library. The discovery source is search-based and duration-filtered (up to three minutes); it is **not verified to be an official Shorts-only or vertical-video feed**.
- **Shorts protection and rotation:** default retention limit of 1,000, any positive custom limit or Unlimited, protected/Important Shorts, and automatic replacement of the oldest eligible unprotected item after a new download succeeds.
- **Themes:** light and dark themes.

## Important limitations

- No YouTube Data API key is used or required by this project.
- Firebase Authentication with Google sign-in is implemented in the app. Its live provider, OAuth fingerprints, API-key restrictions, and Firebase project settings still require verification in the Firebase/Google Cloud consoles. Local subscriptions are not access to a user's private YouTube subscriptions.
- Trending and Shorts discovery are search-derived, not official YouTube feeds.
- Automatic bitrate adaptation based on measured throughput and configurable advanced prebuffering are not implemented.
- Persistent automatic offline caching is not implemented; explicit downloads are separate from temporary playback buffering.
- Actual player-network ad interception is not implemented. URL classification must not be described as a working in-player ad blocker.
- Audio codec execution, stream merging, background service reliability, and notification behavior need Android runtime testing.
- Physical testing on Redmi 12 / Android 15 / HyperOS has not yet been confirmed.

## Build locally

Requirements: Flutter 3.50.1 (stable), Dart version bundled with that Flutter release, and JDK 17.

```bash
flutter pub get
dart format --line-length 120 --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos --fatal-warnings
flutter test --reporter expanded
flutter build apk --debug
```

For split release APKs:

```bash
flutter build apk --release --split-per-abi
```

### Release signing

Release signing can use `android/key.properties` with `storeFile`, `storePassword`, `keyAlias`, and `keyPassword`, or the `TUBE_ARENA_KEYSTORE_PATH`, `TUBE_ARENA_KEYSTORE_PASSWORD`, `TUBE_ARENA_KEY_ALIAS`, and `TUBE_ARENA_KEY_PASSWORD` environment variables.

Never commit keystores, signing properties, API credentials, or private configuration. A debug-signed APK is for testing only and is not suitable for publishing as a trusted production update.

## CI verification

The Android CI workflow runs formatting, Flutter analysis, unit/widget tests, a debug APK build, and an Android emulator launch smoke test. Release APK generation is intentionally skipped until a private release keystore is configured in CI secrets. A downloadable debug APK is published as a workflow artifact when the job completes successfully.

Check the [Actions page](https://github.com/abidemon0242/flutter-youtube-vidmate-clone/actions) for the exact commit and run result. A queued, cancelled, skipped, or `action_required` run is **not a pass**. Emulator smoke testing does not verify all device-specific behavior.

## Legal and permitted use

Tube Arena is not affiliated with YouTube or Google. YouTube is a third-party service and its terms, content-owner permissions, copyright rules, and regional laws apply. Downloading or redistributing content may be restricted even when a technical download path exists. Use the app only for content you own or are expressly permitted to download, and do not bypass access controls or redistribute copyrighted material without permission.

Review [YouTube's Terms of Service](https://www.youtube.com/t/terms) and the applicable copyright rules before using or distributing the app. The project does not guarantee that any particular source, stream, or download method will remain available.

## Project documentation

- [Quick start](QUICK_START.md)
- [Phone setup guide](PHONE_SETUP_GUIDE.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
- [Release and device test checklist](RELEASE_CHECKLIST.md)

## License

No license has been selected or granted yet. Until the project owner adds a license, do not assume that the source code may be reused, modified, redistributed, or included in another project. See [GitHub's licensing guidance](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository).
