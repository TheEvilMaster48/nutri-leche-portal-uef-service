plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.nutrileche.nutri_leche"

    // Puedes mantener los de Flutter, pero asegúrate que compile >= 34
    compileSdk = maxOf(34, flutter.compileSdkVersion)
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.nutrileche.nutri_leche"
        // Asegura minSdk >= 21 (requerido por firebase_messaging y flutter_local_notifications)
        minSdk = maxOf(21, flutter.minSdkVersion)
        targetSdk = maxOf(34, flutter.targetSdkVersion)
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Opcional: si luego te aparece error de métodos DEX
        multiDexEnabled = true
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    // ⬇️ Java 17 + desugaring
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }
    kotlinOptions {
        jvmTarget = "17"
    }
}

flutter {
    source = "../.."
}

dependencies {


    // ⬇️ Necesario cuando habilitas desugaring
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // ⬇️ Opcional si activaste multiDex
    implementation("androidx.multidex:multidex:2.0.1")
}
