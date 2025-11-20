plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.barber_shop"
    compileSdk = 35  // ✅ PERFETTO: aggiornato e compatibile
    ndkVersion = "27.0.12077973"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.barber_shop"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23  // ✅ PERFETTO: 23 > 21 richiesto da Stripe
        multiDexEnabled = true
        targetSdk = 35  // ✅ PERFETTO: aggiornato
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // ✅ PERFETTO: Entrambi disabilitati per evitare problemi
            isMinifyEnabled = false
            isShrinkResources = false  // ✅ OTTIMO: era trueisDebuggable = false
        }
        debug {
            // ✅ PERFETTO: Configurazione debug esplicita
            isMinifyEnabled = false
            isDebuggable = true
        }
    }

    // ✅ PERFETTO: Gestione conflitti packaging
    packaging {
        resources {
            pickFirsts += setOf("**/libc++_shared.so", "**/libjsc.so")
        }
    }

    // ✅ PERFETTO: Configurazione lint
    lint {
        disable += setOf("InvalidPackage")
        checkReleaseBuilds = false
        abortOnError = false
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ✅ PERFETTO: Versione aggiornata
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // ✅ PERFETTO: Dipendenze AndroidX essenziali per Stripe
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")

    // 🆕 AGGIUNTO: Dipendenze specifiche per Stripe (opzionali ma consigliate)
    implementation("androidx.fragment:fragment-ktx:1.6.2")
    implementation("androidx.activity:activity-ktx:1.8.2")
}
