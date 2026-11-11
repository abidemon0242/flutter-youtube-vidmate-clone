# Tube Arena

Tube Arena is an Android-first Flutter media browser and private offline media library with a modern, polished UI.

## Implemented app features

- Public catalog via community Invidious instances for search and regional trending (Bangladesh), plus RSS channel subscriptions
- YouTube videos play inside Tube Arena through the official YouTube IFrame Player API; direct media URLs and local files use the native Flutter player
- Category filtering (Trending / Subscriptions), live search with **recent search history**, and on-device recommendation ranking with local consent controls
- Batch download queue for media the user owns or is authorized to save
- Available video/audio quality selection, adaptive stream pairing, FFmpeg merge, progress, pause/resume/cancel/retry
- YouTube stream URL refresh when retrying downloads created by the current version
- Persistent download task metadata and history
- Clearer failure messages and retry guidance in the Downloads screen
- Wi-Fi-only preference with best-effort network-aware pausing (toggle in Settings)
- Private local media library with folder creation, browsing, rename, move and safe deletion
- Local audio/video playback, MP3 extraction and local video/audio merge with H.264/AAC normalization for MP4 compatibility
- 3GP conversion preset using QCIF 176×144 H.263 video and AMR-NB audio
- Share/export of completed downloads through Android's system share sheet
- Android notification permission request when a batch is started
- Media notification / lock-screen controls for local audio, local video and the in-app direct-video player
- Settings screen with Wi-Fi-only control, **persistent light/dark theme switcher**, and clear notes about official player and download limitations
- Modern polished UI with refined cards, spacing, and typography

## Known limitations and external dependencies

- Search and trending rely on public Invidious instances. These can be slow or temporarily unavailable.
- YouTube videos play inside Tube Arena through the official YouTube IFrame Player API. The embedded player is subject to YouTube's availability, playback rules and ad experience. Tube Arena cannot remove ads from the official player.
- Legacy YouTube stream extraction still depends on a third-party library and can stop working when YouTube changes its delivery system; use only content you are authorized to save.
- Retry can refresh YouTube streams only when the original YouTube URL was saved.
- The selected quality depends on source availability. Adaptive streams require successful FFmpeg merging.
- During adaptive merging the task displays **Merging**. Pause/cancel are unavailable while FFmpeg is processing.
- 3GP conversion uses QCIF 176×144 H.263 video at 15 fps and AMR-NB mono audio. Test on the exact receiving phone.
- Downloaded files remain in app-private storage. Share opens Android's share sheet.
- Wi-Fi-only behavior is best-effort network-aware pausing, not a system-level firewall.
- The official YouTube embedded player manages quality itself. The IFrame API does not let Tube Arena force a fixed stream quality.
- No production signing key is included. Release builds must be signed with a key controlled by the app owner.
- Real-device testing remains necessary for network, codec, and notification workflows.

## Remaining work (next steps)

1. **Production signing** — Add a real release keystore and signing config.
2. **Real-device testing** — Especially FFmpeg merge, 3GP conversion, notifications, and share sheet.
3. **Optional Google Sign-In** — If you want a true personalized subscriptions feed.

## Android build and verification

The Android project scaffold is generated from Flutter's stable template by `bash tool/bootstrap_android.sh`. Run it locally after installing Flutter and Android SDK tools, then run `flutter pub get`. CI uses the same bootstrap script before formatting verification, static analysis, tests, APK builds and an emulator install/launch smoke test. The bootstrap script preserves `android/key.properties` and configures an owner-managed release keystore when present; see [Release signing](docs/RELEASE_SIGNING.md).
