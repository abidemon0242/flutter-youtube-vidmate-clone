# Tube Arena

Tube Arena is an Android-first Flutter media browser and private offline media library.

## Implemented app features

- Live public YouTube search-based Explore feed by category (not the official YouTube Trending API)
- YouTube watch-page handoff to the official YouTube app/browser; supported direct media URLs can play inside Tube Arena
- Category filtering, live search, and on-device recommendation ranking with local consent controls
- Batch download queue for media the user owns or is authorized to save
- Available video/audio quality selection, adaptive stream pairing, FFmpeg merge, progress, pause/resume/cancel/retry
- YouTube stream URL refresh when retrying downloads created by the current version
- Persistent download task metadata and history
- Wi-Fi-only preference with best-effort network-aware pausing
- Private local media library with folder creation, browsing, rename, move and safe deletion
- Local audio/video playback, MP3 extraction and local video/audio merge
- 3GP conversion preset using H.263 video and AMR-NB audio
- Share/export of completed downloads through Android's system share sheet
- Android notification permission request when a batch is started
- Media notification / lock-screen controls for local audio and the in-app direct-video player
- Ad/tracker URL classification

## Known limitations and external dependencies

- Explore uses live public search queries. It is not the official YouTube Trending feed or a personalized YouTube account feed.
- YouTube watch pages open in the official YouTube app/browser. In-app playback is for supported direct media URLs and local files.
- YouTube stream extraction depends on a third-party library and can stop working when YouTube changes its delivery system.
- Retry can refresh YouTube streams only when the original YouTube URL was saved. Older task records and generic direct media URLs cannot be re-extracted automatically.
- The selected quality depends on source availability. Adaptive streams require successful FFmpeg merging; muxed sources may be used when compatible.
- During adaptive merging the task displays **Merging**. Pause/cancel are unavailable while FFmpeg is processing; delete is disabled to protect files in use.
- 3GP conversion uses H.263 video and AMR-NB audio. The FFmpeg build must include the required encoders. Older-phone compatibility varies, so test on the exact receiving phone.
- Downloaded files remain in app-private storage. **Share / export file** opens Android's share sheet; the destination app or transfer method determines whether a feature phone can receive it.
- Audio-only downloads preserve the available source format. MP3 conversion is a separate local operation.
- Notification permission is requested when a batch starts on Android. If denied, downloads may still run but notifications can be hidden.
- Wi-Fi-only behavior is best-effort network-aware pausing, not a system-level mobile-data firewall. Android may delay connectivity events while the app is suspended.
- Ad/tracker URL classification is not a network interceptor and does not remove YouTube ads.
- The in-app player cannot switch quality unless the supplied source exposes selectable variants.
- Public playlist import requires a YouTube Data API key. A key embedded in a client app can be extracted; restrict it to the Android application/package and relevant API, or use a trusted backend. Private playlist access is not implemented.
- No production signing key is included. Release builds must be signed with a key controlled by the app owner before distribution.
- A successful build does not prove every network, codec, notification or device-specific workflow. Real-device testing remains necessary.

## Android build and verification

The Android project scaffold is generated from Flutter's stable template by `bash tool/bootstrap_android.sh`. Run it locally after installing Flutter and Android SDK tools, then run `flutter pub get`. CI uses the same bootstrap script before formatting verification, static analysis, tests, APK builds and an emulator install/launch smoke test.

The bootstrap-generated Android project is not currently committed as a complete native scaffold. The generated files are local build output. The repository does not yet pin the complete dependency graph with a committed `pubspec.lock`; dependency resolution may therefore change between builds.

The emulator smoke test checks installation and launch only. It does not exercise real YouTube extraction, background recovery, FFmpeg encoders, share-sheet transfer or feature-phone compatibility.
