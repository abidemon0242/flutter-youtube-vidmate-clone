# Tube Arena

Tube Arena is an Android-first Flutter media browser and private offline media library.

## Implemented app features

- Official YouTube Data API v3 regional `mostPopular` chart for Bangladesh, plus official YouTube Data API search for query and special categories (requires a restricted API key)
- YouTube videos play inside Tube Arena through the official YouTube IFrame Player API; direct media URLs and local files use the native Flutter player
- Category filtering, live search, and on-device recommendation ranking with local consent controls
- Batch download queue for media the user owns or is authorized to save
- Available video/audio quality selection, adaptive stream pairing, FFmpeg merge, progress, pause/resume/cancel/retry
- YouTube stream URL refresh when retrying downloads created by the current version
- Persistent download task metadata and history
- Wi-Fi-only preference with best-effort network-aware pausing
- Private local media library with folder creation, browsing, rename, move and safe deletion
- Local audio/video playback, MP3 extraction and local video/audio merge with H.264/AAC normalization for MP4 compatibility (local merges normalize to H.264/AAC MP4)
- 3GP conversion preset using QCIF 176×144 H.263 video and AMR-NB audio
- Share/export of completed downloads through Android's system share sheet
- Android notification permission request when a batch is started
- Media notification / lock-screen controls for local audio, local video and the in-app direct-video player
- Ad/tracker URL classification

## Known limitations and external dependencies

- The Bangladesh Explore feed uses the official regional YouTube `mostPopular` chart for All, Music, Tech, Movies, Tutorials, News and Gaming. Live and Design use official YouTube search queries, not the most-popular chart. This is not a personalized YouTube account feed.
- YouTube videos play inside Tube Arena through the official YouTube IFrame Player API. The embedded player is subject to YouTube's availability, playback rules and ad experience.
- Legacy YouTube stream extraction still depends on a third-party library and can stop working when YouTube changes its delivery system; use only content you are authorized to save and do not treat this as an official YouTube download API.
- Retry can refresh YouTube streams only when the original YouTube URL was saved. Older task records and generic direct media URLs cannot be re-extracted automatically.
- The selected quality depends on source availability. Adaptive streams require successful FFmpeg merging; muxed sources may be used when compatible.
- During adaptive merging the task displays **Merging**. Pause/cancel are unavailable while FFmpeg is processing; delete is disabled to protect files in use.
- 3GP conversion uses QCIF 176×144 H.263 video at 15 fps and AMR-NB mono audio. The FFmpeg build must include the required encoders. Older-phone compatibility varies, so test on the exact receiving phone.
- Downloaded files remain in app-private storage. **Share / export file** opens Android's share sheet; the destination app or transfer method determines whether a feature phone can receive it.
- Audio-only downloads preserve the available source format. MP3 conversion is a separate local operation.
- Notification permission is requested when a batch starts on Android. If denied, downloads may still run but notifications can be hidden.
- Wi-Fi-only behavior is best-effort network-aware pausing, not a system-level mobile-data firewall. Android may delay connectivity events while the app is suspended.
- The app does not block YouTube ads or interfere with the official YouTube player. Ad/tracker URL classification is not a network interceptor; it must not be presented as network-level ad blocking.
- The official YouTube embedded player manages quality itself and may expose YouTube's own quality menu when available; the IFrame API does not let Tube Arena force a fixed YouTube stream quality. Direct media playback cannot switch quality unless the source exposes selectable variants.
- Official trending, search and public playlist import require a YouTube Data API key. A key embedded in an APK can be extracted; restrict it to Android package `com.tubearena.app`, its signing certificate SHA-1, and the YouTube Data API. Private playlists require a separate Google OAuth consent flow and are not enabled.
- No production signing key is included. Release builds must be signed with a key controlled by the app owner before distribution.
- A successful build does not prove every network, codec, notification or device-specific workflow. Real-device testing remains necessary.

## Android build and verification

The Android project scaffold is generated from Flutter's stable template by `bash tool/bootstrap_android.sh`. Run it locally after installing Flutter and Android SDK tools, then run `flutter pub get`. CI uses the same bootstrap script before formatting verification, static analysis, tests, APK builds and an emulator install/launch smoke test. The bootstrap script preserves `android/key.properties` and configures an owner-managed release keystore when present; see [Release signing](docs/RELEASE_SIGNING.md). CI artifacts use debug signing when no publisher key is supplied.

The Android CI job generates and commits the complete Flutter Android scaffold and resolved `pubspec.lock` back to `feature/complete-tube-arena` after successful build checks. The API key setup is documented in [YouTube API setup](docs/YOUTUBE_API_SETUP.md).

The emulator smoke test checks installation and launch only. It does not exercise real YouTube extraction, background recovery, FFmpeg encoders, share-sheet transfer or feature-phone compatibility.
