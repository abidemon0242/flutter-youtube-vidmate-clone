# Android release signing

The repository intentionally contains no publisher keystore or passwords. CI builds use the debug key unless a publisher-owned signing configuration is supplied.

## Create a private upload key

Run this from the repository root on a trusted computer with the JDK installed:

```bash
keytool -genkeypair -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Keep `upload-keystore.jks` in the repository root (not inside `android/`), back it up securely, and never commit or share it.

## Configure Gradle

```bash
cp key.properties.example android/key.properties
```

Edit `android/key.properties`:

- `storeFile=../upload-keystore.jks`
- `storePassword`: the keystore password
- `keyAlias=upload`
- `keyPassword`: the key password

The `android/key.properties` file and keystore extensions are ignored by Git. The bootstrap script preserves `android/key.properties` when regenerating the Android scaffold.

Then run:

```bash
bash tool/bootstrap_android.sh
flutter pub get
flutter build appbundle --release
```

If `android/key.properties` exists, the generated Gradle project uses that release signing configuration. Otherwise, release builds use debug signing and are **not suitable for publishing**.

Keep the same signing key for future updates to the same Play Store application. Loss of the key can prevent publishing updates, depending on the Play App Signing setup.
