plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.lifelens"
    compileSdk = flutter.compileSdkVersion

    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.example.lifelens"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: enable shrinking/obfuscation when ready for release
            isMinifyEnabled = false
            // Keep resource shrinking off while code shrinking is disabled
            isShrinkResources = false
        }
        debug {
            // Disable resource shrinking for debug builds as well
            isShrinkResources = false
        }
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }
}

flutter {
    source = "../.."
}
