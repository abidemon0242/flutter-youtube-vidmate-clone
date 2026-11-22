# Android Release and Device Verification Checklist

This checklist distinguishes automated checks from real-device verification. Do not mark an item complete based only on source-code inspection.

## Automated CI

- [ ] Formatting check passes on the exact release commit.
- [ ] Flutter analysis passes with fatal infos and warnings.
- [ ] All Flutter tests pass.
- [ ] Debug APK builds and is uploaded.
- [ ] Split release APKs build and are uploaded.
- [ ] Emulator smoke test installs and launches the same debug APK.
- [ ] Workflow run concludes with `success`; `action_required`, skipped, cancelled, or queued is not success.

## Physical Android device

Record device model, Android version, app commit, and test date.

- [ ] Fresh install and first launch.
- [ ] Search, pagination, empty state, retry, and paste-a-link.
- [ ] Playback, seek, speed, 2× hold, fullscreen, and navigation.
- [ ] Background playback, notification controls, and lock-screen controls.
- [ ] Download video and audio at multiple available qualities.
- [ ] Pause, resume, retry, cancel, and app-restart recovery.
- [ ] Wi-Fi-only queue behavior when connectivity changes.
- [ ] FFmpeg merge and audio conversion on supported formats.
- [ ] Storage-full and insufficient-space handling.
- [ ] Offline playback and file/folder operations.
- [ ] Shorts batch download, separate folders, protection, and rotation.
- [ ] Custom retention limit, Unlimited, and protected-item behavior.
- [ ] Notification permission and foreground-service behavior.
- [ ] Heat, memory use, and long-session stability.

## Release packaging

- [ ] Use a private production keystore.
- [ ] Verify signing certificate and package/application ID.
- [ ] Test upgrade installation over the previous signed build.
- [ ] Verify app version and changelog.
- [ ] Review third-party licenses and applicable service terms.
- [ ] Confirm privacy disclosures match actual data collection and permissions.
- [ ] Confirm distribution channel and legal review.

## Current project caveats

- Live extraction can fail due to upstream changes, regional restrictions, or rate limiting.
- Search-derived Trending and Shorts are not official YouTube feeds.
- Firebase/Google sign-in, private YouTube subscription access, measured-throughput ABR, persistent automatic offline caching, and actual in-player ad interception are not implemented.
- No Redmi 12 / Android 15 / HyperOS physical-device test is currently confirmed.
- Audio codec and FFmpeg runtime behavior must be verified on Android hardware.
