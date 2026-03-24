import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Detect whether the real CHIP SDK AARs are present ─────────────────────
val chipAar     = file("libs/CHIPController.aar")
val chipPayload = file("libs/SetupPayloadParser.jar")
val useRealChipSdk = chipAar.exists()

// ── Release signing (optional — only if key.properties exists) ────────────
val keyPropsFile = rootProject.file("key.properties")
val keyProps = Properties().also { props ->
    if (keyPropsFile.exists()) props.load(keyPropsFile.inputStream())
}

android {
    namespace  = "com.example.matter_home"
    compileSdk = 36

    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.matter_home"
        minSdk     = 27
        targetSdk  = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keyPropsFile.exists()) {
            create("release") {
                keyAlias        = keyProps["keyAlias"]    as String
                keyPassword     = keyProps["keyPassword"] as String
                storeFile       = file(keyProps["storeFile"] as String)
                storePassword   = keyProps["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keyPropsFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
            isMinifyEnabled  = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

dependencies {
    if (useRealChipSdk) {
        // ── Real CHIP SDK (place AARs in android/app/libs/) ─────────────────
        implementation(files("libs/CHIPController.aar"))
        if (chipPayload.exists()) {
            implementation(files("libs/SetupPayloadParser.jar"))
        }
        // Transitive deps required by CHIPController
        implementation("com.google.protobuf:protobuf-java:3.22.0")
        implementation("com.google.code.gson:gson:2.10.1")
    } else {
        // ── Compile-time stubs (simulation mode at runtime) ──────────────────
        implementation(project(":chip-stub"))
    }

    // Thread Network credential store (Play Services, all build variants)
    implementation("com.google.android.gms:play-services-threadnetwork:16.0.0")

    // Coroutines (used by MatterCommissioner, ClusterClient, BleConnectionManager)
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
}

flutter {
    source = "../.."
}
