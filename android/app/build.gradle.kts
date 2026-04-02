plugins {
    id("com.android.application")
    // FlutterFire Configuration
    id("com.google.gms.google-services")
    id("kotlin-android")
    // Flutter Gradle Plugin
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.restaurant_admin_panel"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.restaurant_admin_panel"
        minSdk = flutter.minSdkVersion   // 🔥 Important for many plugins
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // ✅ Required for flutter_local_notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}
