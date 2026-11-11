# Tube Arena

Tube Arena is an Android-first Flutter media browser and private offline media library.

## Implemented features

- Public video search and Bangladesh regional metadata through community Invidious catalog instances.
- Public channel subscriptions through YouTube RSS.
- Public playlist import and local playlist history; private playlists are not supported.
- YouTube playback through the official embedded player; direct media URLs and local files use the native player.
- Category filtering, recent search history, and on-device recommendations with local consent controls.
- Batch downloads for direct media files that the user owns or is authorized to save.
- Completed HLS VOD resolution selection, estimated sizes, and FFmpeg stream merging where required.
- Download progress, pause/resume/cancel/retry, and persistent task history.
- Wi-Fi-only preference with best-effort pausing for regular downloads.
- Private local media library with folder creation, browsing, rename, move, and safe deletion.
- Local audio/video playback, MP3 extraction, and local video/audio conversion.
- 3GP conversion preset using H.263 video and AMR-NB audio.
- Share/export of completed downloads through Android's system share sheet.
- Media notification and lock-screen controls for supported local and embedded playback.
- Persistent light/dark theme and personalization settings.

## Data sources and download boundaries

- No YouTube Data API key is used or required.
- Public search, regional trending metadata, and public playlist metadata use independently operated Invidious instances. Availability can vary.
- Public channel subscriptions use YouTube RSS. The app does not access private account subscriptions, watch history, or private playlists.
- YouTube watch pages are played with the official YouTube player; Tube Arena does not extract or download YouTube streams.
- Downloads accept direct media-file URLs and completed HLS VOD manifests only. Live HLS playlists are not supported.
- Only download content you own or are authorized to save.

## Known limitations

- Public Invidious instances can be slow or temporarily unavailable.
- The official YouTube player controls ads, quality, and playback availability. Tube Arena cannot remove YouTube ads or force a YouTube stream quality.
- Adaptive HLS streams require successful FFmpeg processing. Pause/cancel are unavailable while FFmpeg is processing.
- Wi-Fi-only is best-effort, not a system-level firewall. Regular downloads pause when the app receives connectivity changes; HLS downloads only check Wi-Fi before starting and are not automatically paused if the connection changes.
- Android may delay background connectivity events and notifications.
- 3GP compatibility depends on the available FFmpeg encoders and the receiving phone.
- Downloaded files are stored in app-private storage and exported through Android's share sheet.
- No production signing key is included. Release builds must be signed with a key controlled by the app owner.
- Real-device testing remains necessary for network, codec, notification, and file-sharing workflows.

## Build and verification

The Android scaffold is generated from Flutter's stable template by `bash tool/bootstrap_android.sh`. Run it locally after installing Flutter and Android SDK tools, then run `flutter pub get`. CI checks formatting, static analysis, Flutter tests, debug/release APK builds, and an Android emulator install/launch smoke test. The emulator smoke test does not verify every feature. See [Release signing](docs/RELEASE_SIGNING.md).
