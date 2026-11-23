import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing. Create android/key.properties (never commit it) with:
//   storeFile=/absolute/path/to/upload-keystore.jks
//   storePassword=...
//   keyAlias=upload
//   keyPassword=...
// In CI, the same values can be supplied through the TUBE_ARENA_* environment variables.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

fun signingValue(key: String, env: String): String? =
    keystoreProperties.getProperty(key)?.takeIf { it.isNotBlank() }
        ?: System.getenv(env)?.takeIf { it.isNotBlank() }

val releaseStoreFile = signingValue("storeFile", "TUBE_ARENA_KEYSTORE_PATH")
val releaseStorePassword = signingValue("storePassword", "TUBE_ARENA_KEYSTORE_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "TUBE_ARENA_KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "TUBE_ARENA_KEY_PASSWORD")
val hasReleaseSigning = releaseStoreFile != null &&
    releaseStorePassword != null &&
    releaseKeyAlias != null &&
    releaseKeyPassword != null &&
    file(releaseStoreFile).isFile

// Fail closed: a release task must never silently fall back to the debug key.
val releaseTaskRequested = gradle.startParameter.taskNames.any { taskName ->
    taskName.substringAfterLast(":").contains("Release", ignoreCase = true)
}
if (releaseTaskRequested && !hasReleaseSigning) {
    throw GradleException(
        "Release signing is not configured. Supply android/key.properties or all TUBE_ARENA_* signing variables. " +
            "Debug builds remain available; no debug-signed release APK will be produced.",
    )
}

android {
    namespace = "com.tubearena.app"
    // permission_handler_android 14.x requires Android API 37 or newer.
    compileSdk = maxOf(37, flutter.compileSdkVersion)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.tubearena.app"
        // ffmpeg_kit and audio_service require Android 7.0 (API 24) or newer.
        minSdk = maxOf(24, flutter.minSdkVersion)
        // Google Play requires API 35 or newer for new apps and updates.
        targetSdk = maxOf(35, flutter.targetSdkVersion)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
