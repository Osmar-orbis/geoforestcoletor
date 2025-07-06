// Arquivo: android/app/build.gradle.kts (SINTAXE KOTLIN FINAL CORRIGIDA)

// ==========================================================
//  >>>>> A CORREÇÃO ESTÁ AQUI: ADICIONANDO O IMPORT <<<<<
// ==========================================================
import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties() // Agora ele sabe o que é 'Properties'
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { stream ->
        localProperties.load(stream)
    }
}

val flutterVersionCode: String = localProperties.getProperty("flutter.versionCode") ?: "1"
val flutterVersionName: String = localProperties.getProperty("flutter.versionName") ?: "1.0"

android {
    namespace = "com.example.geoforestcoletor"
    compileSdk = 34
    ndkVersion = "25.2.9519653"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }

    defaultConfig {
        applicationId = "com.example.geoforestcoletor"
        minSdk = 21
        targetSdk = 34
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
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
    implementation(kotlin("stdlib-jdk7"))

    // Importa o Firebase BoM (Bill of Materials) para gerenciar as versões
    implementation(platform("com.google.firebase:firebase-bom:33.1.0"))

    // Adicione as dependências dos produtos Firebase que você usa
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-analytics")
    
    // Dependência do App Check com a sintaxe Kotlin correta
    implementation("com.google.firebase:firebase-appcheck-debug:17.1.2")
}