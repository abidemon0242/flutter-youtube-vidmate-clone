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

## 3. Persistent CI debug signing (one-time setup)

CI builds use a persistent debug keystore stored as a GitHub Actions secret to ensure
a stable SHA-1/SHA-256 fingerprint across all runs. This prevents the
`[16] Account reauth failed` error caused by changing debug keystores.

### One-time setup steps:

1. **Generate a debug keystore** (or use the one provided in the repo's `debug_keystore/` directory):
   ```bash
   keytool -genkeypair -v -keystore debug.keystore -alias androiddebugkey \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -storepass android -keypass android \
     -dname "CN=Android Debug,O=Android,C=US"
   ```

2. **Extract the SHA-1 and SHA-256 fingerprints**:
   ```bash
   keytool -list -v -keystore debug.keystore -alias androiddebugkey -storepass android
   ```

3. **Register both fingerprints in Firebase Console**:
   - Go to Firebase Project Settings → Your apps → Android → Add fingerprint
   - Add the SHA-1 and SHA-256 from step 2

4. **Download a fresh `google-services.json`** and place it at `android/app/google-services.json`

5. **Encode the keystore as base64**:
   ```bash
   base64 -w 0 debug.keystore > debug.keystore.b64
   ```

6. **Add GitHub Actions secrets**:
   - Go to GitHub → Repository → Settings → Secrets and variables → Actions
   - Create secret `DEBUG_KEYSTORE_BASE64` with the contents of `debug.keystore.b64`
   - (Optional) Create secret `DEBUG_KEYSTORE_PASSWORD` with value `android`

### Important notes:
- The keystore file (`debug.keystore`) and its base64 encoding (`debug.keystore.b64`) must **never** be committed to Git.
- The `debug_keystore/` directory in the repo contains only instructions, not the actual keystore.
- The password `android` is the standard Android debug keystore password and is not a secret.
- Once configured, the CI SHA-1/SHA-256 will remain stable across all future builds.

## 4. Build and verify

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


## 5. Enable passwordless email sign-in

The onboarding screen also offers **Send login link**. This uses Firebase's built-in email-link authentication; it does not use a numeric OTP or a custom email backend.

In Firebase Console for the same project:

1. Open **Authentication → Sign-in method**.
2. Enable **Email/Password**.
3. Enable the **Email link (passwordless sign-in)** option under that provider.
4. Confirm that `tube-arena-261114-106732.firebaseapp.com` is listed under Authentication → Settings → Authorized domains.
5. Use the same Firebase project configuration in the Android app.

The user enters an email address, receives a one-time sign-in link, and opens that link on the same Android device. The app stores the pending email locally until the link is completed. Email delivery and link completion still need a real-device check; CI can verify compilation and automated UI behavior but cannot verify inbox delivery.
