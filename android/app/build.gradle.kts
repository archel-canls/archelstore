plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    // PERBAIKAN PENTING: Plugin Google Services untuk Firebase
    id("com.google.gms.google-services") 
}

android {
    // PERBAIKAN: Namespace disesuaikan dengan Package Name di Firebase Console
    namespace = "com.archel.archelstore"
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
        // PERBAIKAN: Application ID disesuaikan dengan Firebase Console
        applicationId = "com.archel.archelstore"
        
        // Min SDK untuk Firebase & Biometric sebaiknya minimal 21
        // Jika flutter.minSdkVersion di local.properties Anda < 21, ini akan error.
        // Jika error, ganti baris di bawah menjadi: minSdk = 21
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}