# Flux

A Flutter app for commissioning and controlling real Matter devices on Android.
Uses the connectedhomeip (CHIP) SDK directly — no Google Home SDK required.

## What it does

- Commission Thread and Wi-Fi Matter devices via BLE or IP
- Control On/Off and dimming for lights and plugs
- Full thermostat control: arc dial setpoint, mode selection, live temperature
- Cluster Inspector: reads all attributes from all endpoints via wildcard read
- Thread network browser: discovers border routers via mDNS (`_meshcop._udp`),
  reads and imports credentials from the Android Thread credential store
- Persists commissioned devices across app restarts (no cloud dependency)

## Architecture

```
Flutter (Dart)
  └── MethodChannel / EventChannel
        └── MatterBridge.kt          ← routes all calls
              ├── ChipClient.kt       ← SDK singleton, CASE sessions
              ├── ClusterClient.kt    ← On/Off, LevelControl, Thermostat,
              │                          BasicInfo, Descriptor, wildcard read
              ├── MatterCommissioner.kt ← BLE+Thread/Wi-Fi & IP commission flows
              ├── BleConnectionManager.kt ← BLE scan, GATT, MTU negotiation
              ├── ThreadBorderRouterScanner.kt ← mDNS _meshcop._udp discovery
              └── AndroidThreadCredentialReader.kt ← Play Services credential store
```

## Prerequisites

| Tool | Version |
|------|---------|
| Flutter | 3.x (stable) |
| Java | 17 |
| Android SDK | API 36 (compile), API 27 (min) |
| NDK | 28.2.13676358 |

The real CHIP SDK AAR (`CHIPController.aar`, ~31 MB) must be placed at:

```
android/app/libs/CHIPController.aar
```

Build it from [connectedhomeip](https://github.com/project-chip/connectedhomeip)
or copy from an existing CHIPTool build:

```
out/android-arm64-chip-tool/lib/src/controller/java/CHIPController.aar
```

Without the AAR the app compiles against `chip-stub` and all Matter calls return
`CHIP_SDK_UNAVAILABLE` at runtime.

## Build

```bash
# 1. Set Java 17
export JAVA_HOME=/path/to/jdk-17
export PATH=$JAVA_HOME/bin:$PATH

cd flux/app/matter_home

# 2. Install Flutter dependencies
flutter pub get

# 3. Debug build (run on connected device)
flutter run --device-id <DEVICE_ID>

# 4. Release APK  (first time: follow signing setup below)
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

### Release signing (one-time)

```bash
# Generate a keystore
$JAVA_HOME/bin/keytool -genkey -v \
  -keystore ~/flux-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias flux \
  -dname "CN=Flux, O=YourOrg, C=NL"

# Create android/key.properties
cat > android/key.properties <<EOF
storePassword=YOUR_PASS
keyPassword=YOUR_PASS
keyAlias=flux
storeFile=/home/youruser/flux-release.jks
EOF
```

`android/key.properties` is gitignored. Without it the release build falls back
to the debug signing key.

## Device setup

- Android 8.1+ (API 27), Bluetooth + Location permission granted
- Target device must be in commissioning mode (factory default or after reset)
- For Thread devices: a Thread border router must be reachable on the same Wi-Fi

**Default Thread dataset** (NEST-PAN-26BA) is pre-filled in Settings → Thread.
Import your own dataset from the Android credential store via
Settings → Thread → Thread credentials → Read from Android.

## Key design decisions

| Decision | Reason |
|----------|--------|
| `setSkipAttestationCertificateValidation(true)` | Commercial devices have PAA certs not in the SDK test store. See `todo.md` for the production fix. |
| `continueCommissioning` posted to main thread | Direct call from attestation callback causes JNI reentrant deadlock. |
| `chip-stub` module | Allows the project to compile without the real AAR; operations fail gracefully at runtime. |
| `CHANGE_WIFI_MULTICAST_STATE` permission | Required by the CHIP mDNS resolver at `FindOperationalForStayActive`; without it the app crashes at that stage. |

## Known limitations / production TODOs

See [`todo.md`](todo.md) for the full list. Key items:

- Attestation validation is disabled (test/dev use only)
- Vendor ID is the CSA test VID `0xFFF4`
- No DAC revocation checking
- `openCommissioningWindow` (multi-admin sharing) is a stub
