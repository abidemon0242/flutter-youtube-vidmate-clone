# Tube Arena

Tube Arena is an Android-first Flutter media browser and private offline media library prototype.

## Implemented app features

- Live YouTube video search; selected YouTube results open through the official YouTube app or browser
- Demo feed and sample in-app network playback
- Category filtering and local feed search
- Batch URL input for media the user owns or is authorized to save
- Download queue with persistent history, background task callbacks, progress, pause, resume, cancel, retry, and file deletion
- Wi-Fi-only preference with network-aware pausing while the app is active
- Private local media library with folder creation, browsing, file rename, move, and safe deletion
- Local video and audio playback
- Local audio-to-MP3 conversion
- Local video/audio merge workflow using FFmpeg
- Android media notification / lock-screen controls for local audio playback
- Safe ad/tracker URL classification

## Known limitations

- The home recommendations/feed are still demo data; live YouTube search is available separately.
- YouTube search results open in the official YouTube app/browser rather than playing inside Tube Arena.
- YouTube stream extraction can fail when the source changes or does not expose a compatible stream. Only download content you own or have permission to save.
- Adaptive video-only and audio-only streams are not yet automatically combined by the download queue. The queue currently saves the selected video stream; use the local merge workflow when you have both source files.
- Audio-only downloads preserve the available source format. MP3 conversion is a separate local action after the file is downloaded.
- Wi-Fi-only pausing depends on Android delivering connectivity changes; it cannot guarantee a mobile-data block while the app is suspended.
- Ad/tracker classification is implemented, but it is not wired into YouTube's own player network traffic and does not remove YouTube ads.
- Media-session controls are connected to local audio playback; video-player lock-screen controls are not implemented.
- Emulator launch and real-device behavior still need verification.

## Android build and verification

The Android CI workflow formats Dart files, runs static analysis and tests, builds a debug APK, creates per-ABI release APKs, and attempts an emulator install/launch smoke test.

A successful build does not prove every network or device-specific feature works. Check each CI job and test the APK on a real Android device before treating the app as release-ready.