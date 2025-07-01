plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.geoforestcoletor"
    
    // VERSÃO CORRIGIDA: Definindo um valor fixo e mais recente.
    compileSdk = 35 
    
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.geoforestcoletor"
        minSdk = 23
        
        // VERSÃO CORRIGIDA: Definindo um valor fixo e mais recente.
        targetSdk = 34
        
        versionCode = 1 // Use flutter.versionCode se preferir
        versionName = "1.0.0" // Use flutter.versionName se preferir
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