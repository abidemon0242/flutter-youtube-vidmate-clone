# Google sign-in setup for Tube Arena

Tube Arena presents Google sign-in during first-run onboarding. If Firebase has not been configured yet, the Google button stays disabled and the user can continue as a guest; Google sign-in can also be used later from Settings. Firebase Authentication restores a successful account session on subsequent launches.

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

Install the APK on an Android device with Google Play services. On first launch, use **Continue with Google** in the onboarding screen. Confirm that the signed-in account appears in Settings, close and reopen the app to verify Firebase restores the session, then use **Sign out**. If you choose **Continue as guest**, the app opens without an account; you can sign in later from Settings.

## Notes

- No YouTube Data API key is required or used.
- Firebase configuration contains project identifiers and OAuth client information; it is not a substitute for protecting private server credentials.
- Never commit signing keys, passwords, OAuth client secrets, or a user's authentication tokens.
- Google sign-in does not grant access to private YouTube subscriptions or watch history. Tube Arena's public catalog and channel RSS features remain separate.
