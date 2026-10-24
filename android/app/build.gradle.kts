import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: put the keystore details in android/key.properties (never
// committed) or in the CI secrets described in docs/RELEASE.md. Without them
// the release build falls back to the debug key so it still installs.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val envStore: String? = System.getenv("MISHKAH_KEYSTORE_PATH")
val hasReleaseKey = keystoreProperties.getProperty("storeFile") != null || envStore != null

android {
    namespace = "app.mishkah.mishkah"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications needs java.time on older Android.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "app.mishkah.quran"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        // Shared project key (password "android", not a secret). Every build
        // without a private release key is signed with it, so each new APK
        // installs as an update over the previous one instead of clashing.
        create("shared") {
            storeFile = file("mishkah-shared.keystore")
            storePassword = "android"
            keyAlias = "mishkah"
            keyPassword = "android"
        }
        getByName("debug") {
            storeFile = file("mishkah-shared.keystore")
            storePassword = "android"
            keyAlias = "mishkah"
            keyPassword = "android"
        }
        create("release") {
            if (envStore != null) {
                storeFile = file(envStore)
                storePassword = System.getenv("MISHKAH_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("MISHKAH_KEY_ALIAS")
                keyPassword = System.getenv("MISHKAH_KEY_PASSWORD")
            } else if (keystoreProperties.getProperty("storeFile") != null) {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) signingConfigs.getByName("release") else signingConfigs.getByName("shared")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
