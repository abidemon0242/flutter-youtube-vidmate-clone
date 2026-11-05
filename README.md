# Tube Arena

Tube Arena is an Android-first Flutter media browser and private offline media library prototype.

## Implemented app features

- Live YouTube search-based Explore feed by category; this is public search discovery, not YouTube's official Trending API
- Selected YouTube results open through the official YouTube app or browser; direct media URLs can play inside Tube Arena
- Category filtering, live search, and local recommendation ranking
- Watch-screen handoff to the batch downloader, with supported YouTube URLs prefilled
- Batch URL input for media the user owns or is authorized to save
- Batch download queue with persistent task metadata and history, native background callbacks, live progress, pause, resume, cancel, retry, and file deletion
- Wi-Fi-only preference with network-aware pausing while the app is active
- Private local media library with folder creation, browsing, file rename, move, and safe deletion
- Local video and audio playback
- Local audio-to-MP3 conversion
- Local video/audio merge workflow using FFmpeg
- Android media notification / lock-screen controls for local audio and the in-app direct-video player
- Safe ad/tracker URL classification

## Known limitations

- The Explore feed is built from live public search results; it is not a personalized or official YouTube Trending feed.
- YouTube watch pages open in the official YouTube app/browser rather than playing inside Tube Arena. Fullscreen and lock-screen controls apply to direct media sources played inside Tube Arena.
- YouTube stream extraction can fail when the source changes or does not expose a compatible stream. Only download content you own or have permission to save.
- The download queue can pair compatible adaptive video-only and audio-only streams and merge them with FFmpeg; it falls back to muxed streams when available. The selected quality depends on the source's available formats.
- The 3GP export path converts an MP4 source to H.263 video and AMR-NB audio. Codec availability and compatibility vary by device, so test on the target feature phone; no export can guarantee playback on every model.
- Audio-only downloads preserve the available source format. MP3 conversion is a separate local action after the file is downloaded.
- Wi-Fi-only pausing depends on Android delivering connectivity changes; it cannot guarantee a mobile-data block while the app is suspended.
- Ad/tracker URL classification is implemented, but it is not a network interceptor and does not remove YouTube ads.
- The in-app player uses the quality of its supplied direct media URL; multi-quality switching is not available unless a source provides selectable variants.
- Emulator launch and real-device behavior still need verification.

## Android build and verification

The Android project scaffold is generated from Flutter's current template by `bash tool/bootstrap_android.sh`; CI runs the same script before formatting Dart files, static analysis, tests, APK builds, and the emulator smoke test. Run the script locally after installing Flutter if you want a complete Android Studio project in your checkout.

A successful build does not prove every network or device-specific feature works. Check each CI job and test the APK on a real Android device before treating the app as release-ready.