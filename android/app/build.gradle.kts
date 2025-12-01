plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

fun arbLocales(): List<String> {
    val arbDir = File(projectDir, "../../lib/l10n")
    if (!arbDir.exists()) {
        println("No l10n directory found at ${arbDir.absolutePath}")
        return emptyList()
    }

    val list = arbDir
        .listFiles { file -> file.name.matches(Regex("app_(.*)\\.arb")) }
        ?.mapNotNull { file ->
            val match = Regex("app_(.*)\\.arb").find(file.name)
            match?.groupValues?.get(1)?.replace("_", "-")
        }
        ?: emptyList()
    return list
}

android {
    namespace = "it.casaricci.airborne"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "it.casaricci.airborne"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // TODO import from Flutter code or config?
        resValue("string", "app_name", "Airborne")
    }

    androidResources {
        // TODO generate locales_config.xml automatically
        localeFilters += arbLocales()
    }

    signingConfigs {
        create("release") {
            storeFile = rootProject.file("fastlane/androidkey.jks")
            storePassword = System.getenv("RELEASE_STORE_PASSWORD")
            keyAlias = System.getenv("RELEASE_KEY_ALIAS")
            keyPassword = System.getenv("RELEASE_KEY_PASSWORD")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isDebuggable = false
            isShrinkResources = true
        }
        debug {
            applicationIdSuffix = ".debug"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // TODO is this still needed?
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
