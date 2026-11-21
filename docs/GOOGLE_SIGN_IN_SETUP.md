# Firebase setup for Tube Arena

This guide reflects the Firebase project already created for this app.

## Existing Firebase project

- Project name: **Tube Arena**
- Project ID: `tube-arena-261114-106732`
- Android package: `com.tubearena.app`
- Firebase Android app: `1:1097230695627:android:c7e2f10cefef528afcaf4e`
- Firestore database: `(default)`, region `asia-south1`
- Google provider: enabled in Firebase Authentication
- The Firebase Android config file has been downloaded by the project owner but still needs to be placed in the local project at `android/app/google-services.json`.

Do not create another Firebase project or reuse the Abid's Web Studio Firebase project.

## Repository preparation

The repository includes Firebase Core/Auth dependencies, Google sign-in integration, conditional Google Services Gradle plugin application, `firebase.json`, `firestore.rules`, and `firestore.indexes.json`.

The config file `android/app/google-services.json` is intentionally ignored by Git. Keep it local; do not upload it to the public repository. Never commit service-account private keys, signing keys, passwords, or authentication tokens.

## Remaining setup

1. Copy the downloaded `google-services.json` into the existing project at `android/app/google-services.json`. The filename must remain exactly `google-services.json`.
2. Generate the Android debug signing report using the project's Gradle wrapper and register the **debug SHA-1** in Firebase Console → Project settings → Your apps → Tube Arena Android → SHA certificate fingerprints. Add the release signing fingerprint later when a dedicated release keystore exists. Do not guess or manually invent fingerprints.
3. Confirm Google is enabled in Firebase Console → Authentication → Sign-in method. The project owner previously enabled this provider.
4. The Firestore database already exists in `asia-south1`. The repository's rules are only a local source file until deployed.

## Firebase CLI project selection and Firestore rules

The `.firebaserc.example` file now contains the correct project ID. In a local checkout, copy it to `.firebaserc` if that file does not already exist. Then deploy the rules and indexes from the repository root using an authenticated Firebase CLI session:

```bash
firebase deploy --only firestore:rules,firestore:indexes --project tube-arena-261114-106732
```

The starter rules allow a signed-in user to read/write only their own `users/{uid}` document and deny all other Firestore paths. Keep this restrictive until the app's actual Firestore data model is implemented and reviewed.

## Important implementation status

- Google sign-in is prepared in the app but cannot be verified until the local Android config file and correct signing fingerprint are in place and an Android build is tested.
- Firestore is created, but the current app does **not yet sync user profiles, download history, or other app data to Firestore**. Creating the database and deploying rules does not add that application functionality.
- No YouTube Data API key is required or used by Tube Arena.
- Google sign-in does not grant access to private YouTube subscriptions or watch history.
- Emulator CI is not a substitute for testing Google sign-in and app behavior on the Redmi 12.
