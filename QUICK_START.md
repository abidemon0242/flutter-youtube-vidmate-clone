# Tube Arena — Quick Start

Tube Arena is an Android-first Flutter prototype. GitHub Actions currently generates the missing Android native scaffold during CI, then builds the APKs.

## Get an Android build

1. Open the repository's **Actions** tab.
2. Open the latest **Tube Arena Android CI** run for the branch you want to test.
3. Check the **Flutter analyze, tests and Android build** job.
4. Download the `tube-arena-debug-apk` artifact for device testing, or `tube-arena-release-apks` for per-ABI release builds.
5. Install the APK on an Android device and test the actual workflows.

The separate emulator smoke-test job must also pass before treating installation and launch as CI-verified. A successful build alone does not prove every device-specific or network feature works.

## Current feature boundaries

- Live YouTube search is available; search results open in the official YouTube app/browser.
- The Home recommendations are demo data; sample demo playback is in-app.
- The batch download queue uses single-file muxed streams so downloaded videos include audio; quality is typically limited to 360p30.
- Local audio playback, MP3 conversion, local video/audio merge, and audio media-session controls are implemented.
- Ad/tracker URL classification is not a network interceptor and does not remove YouTube ads.
- A dedicated button-phone/3GP compatibility export option is not implemented yet.

See README.md for the full limitations and safety notes.
