# Google sign-in setup for Tube Arena

Tube Arena uses Firebase Authentication with Google's native sign-in provider. The app remains usable without authentication, but the sign-in button stays disabled until the owner configures Firebase.

## 1. Register the Android app

In the Firebase project you want Tube Arena to use:

1. Add an Android app with package name `com.tubearena.app`.
2. Add the SHA-1 certificate fingerprints for every build type you intend to use (debug and release).
3. In Firebase Console, open Authentication → Sign-in method and enable Google.
4. Download the updated `google-services.json`.

## 2. Add the local configuration

Place the downloaded file at:

```text
android/app/google-services.json
```

This file is intentionally ignored by Git and must not be committed. The Android Gradle build applies the Google Services plugin only when this file exists.

## 3. Build and verify

Run:

```bash
flutter pub get
bash tool/bootstrap_android.sh
flutter analyze
flutter test
flutter build apk --debug
```

Install the APK on an Android device with Google Play services, open Settings in Tube Arena, and use **Sign in**. Confirm that the signed-in account email appears, close and reopen the app to verify Firebase restores the session, then use **Sign out**.

## Notes

- No YouTube Data API key is required or used.
- Firebase configuration contains project identifiers and OAuth client information; it is not a substitute for protecting private server credentials.
- Never commit signing keys, passwords, OAuth client secrets, or a user's authentication tokens.
- Google sign-in does not grant access to private YouTube subscriptions or watch history. Tube Arena's public catalog and channel RSS features remain separate.
