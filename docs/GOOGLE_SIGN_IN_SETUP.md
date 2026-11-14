# Firebase setup for Tube Arena

Tube Arena uses Firebase Authentication for optional Google sign-in. The app remains usable as a guest when Firebase is not configured. The repository now also includes a secure starter Firestore ruleset and Firebase CLI deployment configuration; no Firestore application data is currently written by the app.

## What is already prepared in the repository

- Firebase Core and Firebase Auth dependencies.
- Google Sign-In integration and first-run onboarding.
- Android Google Services Gradle plugin registration, conditional on the local config file.
- `firebase.json`, `firestore.rules`, and `firestore.indexes.json`.
- `.firebaserc.example` template (copy it to `.firebaserc` and replace the placeholder with your actual project ID).
- `android/app/google-services.json` is ignored by Git and must remain local.

## 1. Create a separate Firebase project

Use a new project for Tube Arena; do not reuse the Abid's Web Studio project unless you explicitly decide to combine them.

You can create the project in Firebase Console, or after installing the Firebase CLI and signing in:

```bash
firebase login
firebase projects:create YOUR_UNIQUE_PROJECT_ID --display-name "Tube Arena"
```

Project IDs are globally unique and cannot contain spaces. Choose one you are comfortable keeping.

## 2. Register the Android app

In the new Firebase project:

1. Add an Android app with package name `com.tubearena.app`.
2. In the repository, generate Android Gradle files if they are not present:
   `bash tool/bootstrap_android.sh`.
3. From the `android` directory, run `./gradlew signingReport` and copy the **debug SHA-1** for local testing. Add it in Firebase Console → Project settings → Your apps → SHA certificate fingerprints. Add the release SHA-1 later when a release signing key exists.
4. Download the generated `google-services.json` and put it at `android/app/google-services.json`. Do not commit this file.

## 3. Enable Google Authentication

In Firebase Console, open Authentication → Get started → Sign-in method, enable **Google**, select the support email if prompted, and save.

## 4. Create Firestore (optional for current app build)

The current app uses Firebase Authentication; it does not yet sync profile or download data to Firestore. If you want the prepared rules deployed now, create a Firestore database in Firebase Console → Firestore Database → Create database. Choose a location close to your expected users; database location cannot easily be changed later.

Copy `.firebaserc.example` to `.firebaserc` and replace the placeholder with the project ID. Then deploy the restrictive starter rules:

```bash
firebase deploy --only firestore:rules,firestore:indexes --project YOUR_UNIQUE_PROJECT_ID
```

The rules allow a signed-in user to access only their own `users/{uid}` document and deny all other Firestore paths. They are intentionally restrictive; do not loosen them to public read/write.

## 5. Build and verify

```bash
flutter pub get
bash tool/bootstrap_android.sh
flutter analyze
flutter test
flutter build apk --debug
```

Install the APK on an Android device with Google Play services. On first launch, tap **Continue with Google**. Confirm that the signed-in account appears in Settings, close and reopen the app to verify Firebase restores the session, then use **Sign out**. Guest mode should still work when Firebase is not configured.

## What still needs your Google-account action

- Create the new Firebase project (or authorize a signed-in CLI session).
- Register the Android app and add the debug SHA-1.
- Enable Google as an Authentication provider.
- Download `google-services.json` into the ignored local Android path.
- Create the Firestore database only if you want Firestore enabled now.

## Security and scope notes

- No YouTube Data API key is required or used.
- Never paste service-account private keys, passwords, OAuth client secrets, or authentication tokens into chat or commit them to Git.
- Google sign-in does not grant access to private YouTube subscriptions or watch history.
- Firestore rules are deployed only after you run the Firebase CLI command; adding the rules file to Git does not publish them.
