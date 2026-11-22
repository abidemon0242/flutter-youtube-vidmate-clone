# Contributing to Tube Arena

Thanks for taking an interest in the project. Contributions should be focused, testable, and honest about what has and has not been verified.

## Before starting

1. Check open issues and pull requests to avoid duplicate work.
2. For a large change, open an issue or discussion first to agree on scope.
3. Never add a YouTube Data API key, Firebase credentials, signing keys, keystores, personal tokens, or other secrets.
4. Do not add code that bypasses authentication, access controls, paywalls, or content-owner restrictions.

## Development setup

Use Flutter 3.50.1 stable and JDK 17. Run:

```bash
flutter pub get
dart format --line-length 120 lib test
flutter analyze --fatal-infos --fatal-warnings
flutter test --reporter expanded
flutter build apk --debug
```

## Pull requests

- Keep changes focused and explain the user-visible behavior.
- Add or update tests for bug fixes and new behavior.
- Include migration notes when persisted settings or stored files change.
- Document platform-specific permissions and runtime requirements.
- Do not claim device verification unless it was performed on the named device and Android version.
- Include the CI run or explain why it could not complete.
- Do not commit generated build output, local signing files, or secrets.

## Reporting results

Separate automated checks, emulator checks, and physical-device checks. A passing unit test does not prove that YouTube extraction, codecs, background downloads, or Android notifications work on every device.
