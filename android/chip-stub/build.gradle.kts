/**
 * chip-stub
 *
 * Compile-time stand-in for the real CHIPController.aar.
 * Every method throws ChipSdkStubException at runtime, which MatterBridge
 * catches and uses to activate simulation mode.
 *
 * To switch to real hardware:
 *   1. Copy CHIPController.aar + SetupPayloadParser.jar into android/app/libs/
 *   2. The app/build.gradle.kts dependency block will automatically prefer the
 *      real AAR over this module.
 */
plugins {
    id("com.android.library")
    id("kotlin-android")
}

android {
    namespace  = "chip.stub"
    compileSdk = 36

    defaultConfig {
        minSdk = 24
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    // Only standard Android SDK – no external deps.
}
