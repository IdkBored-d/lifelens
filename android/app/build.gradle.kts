plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Flutter's native assets pipeline doesn't reliably bundle llamadart's .so files
// into the Android APK. This task copies them from the pub cache at build time.
fun llamadartBundleDir(version: String): File? {
    val bundlesRoot = File(
        "${System.getProperty("user.home")}/AppData/Local/Pub/Cache/hosted/pub.dev/" +
        "llamadart-$version/.dart_tool/llamadart/native_bundles"
    )
    return bundlesRoot.listFiles()?.firstOrNull { it.isDirectory }
}

val llamaJniOut = layout.buildDirectory.dir("llama_jni")

val copyLlamaLibs = tasks.register<Copy>("copyLlamaLibs") {
    val bundleDir = llamadartBundleDir("0.6.11")
    if (bundleDir != null) {
        from("${bundleDir}/android-arm64/extracted/") { into("arm64-v8a") }
        from("${bundleDir}/android-x64/extracted/")  { into("x86_64") }
    }
    into(llamaJniOut)
    duplicatesStrategy = DuplicatesStrategy.INCLUDE
}

tasks.configureEach {
    if (name.startsWith("merge") && name.endsWith("JniLibFolders")) {
        dependsOn(copyLlamaLibs)
    }
}

android {
    namespace = "com.example.lifelens"
    compileSdk = flutter.compileSdkVersion

    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.example.lifelens"
        // Changed: health plugin requires Android API level 26 or higher.
        minSdk = 26
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

            // Play Store devices are ARM-based. Exclude x86/x86_64 native libs
            // from release artifacts to avoid 16 KB page-size compatibility flags.
            ndk {
                abiFilters += listOf("arm64-v8a", "armeabi-v7a")
            }
        }
        debug {
            // Disable resource shrinking for debug builds as well
            isShrinkResources = false
        }
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        isCoreLibraryDesugaringEnabled = true
    }

    sourceSets {
        getByName("main") {
            jniLibs.srcDir(llamaJniOut)
        }
    }

    packagingOptions {
        jniLibs {
            pickFirsts += setOf(
                // onnxruntime
                "lib/arm64-v8a/libonnxruntime.so",
                "lib/x86_64/libonnxruntime.so",
                "lib/x86/libonnxruntime.so",
                "lib/armeabi-v7a/libonnxruntime.so",
                // llamadart — guards against duplicates if native assets also bundles them
                "lib/arm64-v8a/libllamadart.so",  "lib/x86_64/libllamadart.so",
                "lib/arm64-v8a/libllama.so",       "lib/x86_64/libllama.so",
                "lib/arm64-v8a/libggml.so",        "lib/x86_64/libggml.so",
                "lib/arm64-v8a/libggml-base.so",   "lib/x86_64/libggml-base.so",
                "lib/arm64-v8a/libggml-cpu.so",    "lib/x86_64/libggml-cpu.so",
                "lib/arm64-v8a/libggml-vulkan.so", "lib/x86_64/libggml-vulkan.so",
                "lib/arm64-v8a/libggml-opencl.so", "lib/x86_64/libggml-opencl.so",
                "lib/arm64-v8a/libmtmd.so",        "lib/x86_64/libmtmd.so",
            )
        }
    }

}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.17.3")
}
