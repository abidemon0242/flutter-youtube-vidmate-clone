# YouTube Data API setup

Tube Arena uses the official YouTube Data API v3 for the Bangladesh most-popular chart, video search and public playlist metadata.

## Create and restrict an API key

1. Create or select a Google Cloud project.
2. Enable **YouTube Data API v3**.
3. Create an API key.
4. Restrict the key to **YouTube Data API v3**.
5. Add an Android application restriction for package name `com.tubearena.app` and the SHA-1 certificate fingerprints used to sign your debug and release builds.

An API key embedded in an Android application is visible to anyone who inspects the APK. It is not a secret. Application and API restrictions are essential. Never put a service-account key, OAuth client secret, or private signing key in the app.

## Build with the key

From the project root:

```bash
flutter pub get
flutter build apk --release --dart-define=YOUTUBE_DATA_API_KEY=YOUR_RESTRICTED_KEY
```

For the debug signing certificate SHA-1, run:

```bash
cd android
./gradlew signingReport
```

For GitHub Actions builds, add a repository Actions secret named `YOUTUBE_DATA_API_KEY`. The CI workflow passes it as a Dart compile-time define. If it is absent, the app still builds but the official feed, search and public playlist import show a configuration message.

## Supported API features

- **All / Music / Tech / Movies / Tutorials / News / Gaming:** official regional `videos.list(chart=mostPopular)` endpoint.
- **Search:** official YouTube `search.list` endpoint.
- **Live / Design:** official YouTube search with a relevant query; these are not the most-popular chart.
- **Public playlists:** `playlists.list` and paginated `playlistItems.list`.

Private or unlisted playlist access is not included. Private playlists require a Google OAuth consent flow, an OAuth client configuration, and explicit user authorization. An API key alone cannot access a user's private playlists.

## Playback quality and ads

YouTube videos are rendered using the official YouTube IFrame Player API. The YouTube player manages adaptive quality and may expose its own quality menu. The IFrame API does not provide a supported way for Tube Arena to force a specific YouTube stream quality.

Tube Arena does not remove YouTube ads or interfere with the official player. YouTube controls the ads and playback experience inside its embedded player.
