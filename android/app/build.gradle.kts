plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.cineglobal"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        // Ubah ke VERSION_1_8 agar kompatibel dengan library notifikasi
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8

        // PERBAIKAN SINTAKS KOTLIN: Pakai "is..." dan "="
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.cineglobal"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Opsional: Jika nanti butuh multiDex
        multiDexEnabled = true 
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // PERBAIKAN SINTAKS KOTLIN: Pakai kurung () dan petik dua ""
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")
}