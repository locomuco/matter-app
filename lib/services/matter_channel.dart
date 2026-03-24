import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// ── Parsed setup payload ───────────────────────────────────────────────────

enum DiscoveryCapability { ble, onNetwork, softAp, wifiPaf, nfc, unknown }

class ParsedPayload {
  final int vendorId;
  final int productId;
  final int discriminator;
  final bool hasShortDiscriminator;
  final List<DiscoveryCapability> discoveryCapabilities;

  const ParsedPayload({
    required this.vendorId,
    required this.productId,
    required this.discriminator,
    required this.hasShortDiscriminator,
    required this.discoveryCapabilities,
  });

  /// True when the device can be commissioned over BLE.
  bool get hasBle => discoveryCapabilities.contains(DiscoveryCapability.ble);

  /// True when the device is already on the network (IP commissioning).
  bool get hasOnNetwork =>
      discoveryCapabilities.contains(DiscoveryCapability.onNetwork);

  /// Whether BLE is the preferred commissioning transport.
  bool get prefersBle => hasBle;

  /// Suggested device name derived from VID/PID.
  String get suggestedName {
    const vendorNames = <int, String>{
      0xFFF1: 'Test Device',
      0xFFF4: 'Test Device',
      0x134E: 'tado°',
      0x1037: 'Silicon Labs Device',
      0x1135: 'NXP Device',
      0x10C4: 'Silicon Labs Device',
      0x1321: 'Espressif Device',
      0x131B: 'Nordic Semiconductor',
      0x1049: 'Google Device',
      0x1387: 'Eve Device',
      0x117C: 'Legrand Device',
      0x100B: 'Infineon Device',
      0x100F: 'Signify (Philips Hue)',
      0x1101: 'Samsung ARTIK',
      0x1275: 'Third Reality',
      0x1398: 'Amazon Device',
    };
    final vendor = vendorNames[vendorId];
    if (vendor != null) return vendor;
    return 'Device ${vendorId.toRadixString(16).padLeft(4,'0').toUpperCase()}'
           ':${productId.toRadixString(16).padLeft(4,'0').toUpperCase()}';
  }
}

/// Result returned after a commissioning attempt.
class CommissionResult {
  final bool success;
  final int? nodeId;
  final int? deviceTypeId;
  final String? error;

  const CommissionResult._({
    required this.success,
    this.nodeId,
    this.deviceTypeId,
    this.error,
  });

  factory CommissionResult.ok({required int nodeId, int? deviceTypeId}) =>
      CommissionResult._(success: true, nodeId: nodeId, deviceTypeId: deviceTypeId);

  factory CommissionResult.err(String error) =>
      CommissionResult._(success: false, error: error);
}

/// Result of a device-state read.
class DeviceStateResult {
  final bool isOnline;
  final bool? isOn;
  final int? brightnessLevel;

  const DeviceStateResult({
    required this.isOnline,
    this.isOn,
    this.brightnessLevel,
  });
}

class ThermostatState {
  /// All temperatures in centidegrees (0.01 °C). Null = not available.
  final int? localTempCenti;
  final int? heatingSetptCenti;
  final int? coolingSetptCenti;
  /// 0=Off 1=Auto 3=Cool 4=Heat 5=EmergencyHeat 6=Precooling 7=FanOnly
  final int? systemMode;
  /// ControlSequenceOfOperation (0x001B):
  ///   0/1 = CoolingOnly, 2/3 = HeatingOnly, 4/5 = CoolingAndHeating
  final int? controlSequence;

  const ThermostatState({
    this.localTempCenti,
    this.heatingSetptCenti,
    this.coolingSetptCenti,
    this.systemMode,
    this.controlSequence,
  });

  double? get localTempC =>
      localTempCenti != null ? localTempCenti! / 100.0 : null;
  double? get heatingSetptC =>
      heatingSetptCenti != null ? heatingSetptCenti! / 100.0 : null;
  double? get coolingSetptC =>
      coolingSetptCenti != null ? coolingSetptCenti! / 100.0 : null;

  /// True when the device supports heating (CSO 2, 3, 4, 5; or unknown).
  bool get supportsHeating {
    if (controlSequence == null) return true; // assume heating if unknown
    return const {2, 3, 4, 5}.contains(controlSequence);
  }

  /// True only when the device explicitly advertises cooling (CSO 0, 1, 4, 5).
  bool get supportsCooling {
    if (controlSequence == null) return false; // don't show if unknown
    return const {0, 1, 4, 5}.contains(controlSequence);
  }

  static const _modeNames = <int, String>{
    0: 'Off', 1: 'Auto', 3: 'Cool', 4: 'Heat',
    5: 'Emergency Heat', 6: 'Precooling', 7: 'Fan Only', 8: 'Dry', 9: 'Sleep',
  };
  String get systemModeName =>
      systemMode != null ? (_modeNames[systemMode!] ?? 'Mode $systemMode') : '—';

  /// The mode buttons to show, derived from ControlSequenceOfOperation.
  List<({int mode, String label})> get availableModes {
    const off  = (mode: 0, label: 'Off');
    const auto = (mode: 1, label: 'Auto');
    const cool = (mode: 3, label: 'Cool');
    const heat = (mode: 4, label: 'Heat');
    return switch (controlSequence) {
      0 || 1 => [off, cool],          // cooling only
      2 || 3 => [off, heat],          // heating only
      4 || 5 => [off, heat, cool, auto], // both
      _      => [off, heat, cool, auto], // unknown — show all
    };
  }
}

/// A Thread Border Router discovered via mDNS (_meshcop._udp).
class ThreadBorderRouter {
  final String serviceName;
  final String networkName;
  final String extPanId;
  final String vendorName;
  final String modelName;
  final String host;
  final int    port;
  /// Raw TXT record key→value pairs (values decoded as UTF-8 or hex).
  final Map<String, String> txt;

  const ThreadBorderRouter({
    required this.serviceName,
    required this.networkName,
    required this.extPanId,
    required this.vendorName,
    required this.modelName,
    required this.host,
    required this.port,
    this.txt = const {},
  });

  factory ThreadBorderRouter.fromJson(Map<String, dynamic> j) =>
      ThreadBorderRouter(
        serviceName: j['serviceName'] as String? ?? '',
        networkName: j['networkName'] as String? ?? '',
        extPanId:    j['extPanId']    as String? ?? '',
        vendorName:  j['vendorName']  as String? ?? '',
        modelName:   j['modelName']   as String? ?? '',
        host:        j['host']        as String? ?? '',
        port:        j['port']        as int?    ?? 0,
        txt: (j['txt'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, v.toString())),
      );
}

/// Flutter ↔ Android bridge.
class MatterChannel {
  static const _method = MethodChannel('com.example.matter_home/matter');
  static const _events = EventChannel('com.example.matter_home/commission_events');

  // ── Commission progress stream ─────────────────────────────────────────────
  /// Emits plain-text progress lines from the Android commissioning flow.
  Stream<String> get commissionEvents =>
      _events.receiveBroadcastStream().map((e) => e as String);

  // ── Parse setup payload ────────────────────────────────────────────────────

  /// Parses a QR code or manual pairing code string and returns device metadata.
  /// Returns null if the payload is invalid or the SDK is unavailable.
  Future<ParsedPayload?> parsePayload(String payload) async {
    try {
      final result = await _method.invokeMapMethod<String, dynamic>(
        'parsePayload', {'payload': payload},
      );
      if (result == null) return null;

      DiscoveryCapability cap(String s) => switch (s) {
            'BLE'        => DiscoveryCapability.ble,
            'ON_NETWORK' => DiscoveryCapability.onNetwork,
            'SOFT_AP'    => DiscoveryCapability.softAp,
            'WIFI_PAF'   => DiscoveryCapability.wifiPaf,
            'NFC'        => DiscoveryCapability.nfc,
            _            => DiscoveryCapability.unknown,
          };

      return ParsedPayload(
        vendorId:              result['vendorId']              as int,
        productId:             result['productId']             as int,
        discriminator:         result['discriminator']         as int,
        hasShortDiscriminator: result['hasShortDiscriminator'] as bool? ?? false,
        discoveryCapabilities: (result['discoveryCapabilities'] as List<dynamic>?)
                ?.map((e) => cap(e as String))
                .toList() ??
            [],
      );
    } on PlatformException {
      return null;
    }
  }

  // ── Commission via BLE ─────────────────────────────────────────────────────

  Future<CommissionResult> commissionDevice(
    String payload, {
    String? wifiSsid,
    String? wifiPassword,
    String? threadDatasetHex,
  }) async {
    try {
      final result = await _method.invokeMapMethod<String, dynamic>(
        'commissionDevice',
        {
          'payload':          payload,
          'wifiSsid':         wifiSsid,
          'wifiPassword':     wifiPassword,
          'threadDatasetHex': threadDatasetHex,
        },
      );
      if (result == null) return CommissionResult.err('No result from channel');
      return CommissionResult.ok(
        nodeId:       result['nodeId']       as int,
        deviceTypeId: result['deviceTypeId'] as int?,
      );
    } on PlatformException catch (e) {
      return CommissionResult.err(e.message ?? 'Commission failed');
    }
  }

  Future<CommissionResult> commissionViaIp({
    required String ipAddress,
    int port = 5540,
    required int discriminator,
    required int setupPinCode,
  }) async {
    try {
      final result = await _method.invokeMapMethod<String, dynamic>(
        'commissionViaIp',
        {
          'ipAddress':     ipAddress,
          'port':          port,
          'discriminator': discriminator,
          'setupPinCode':  setupPinCode,
        },
      );
      if (result == null) return CommissionResult.err('No result from channel');
      return CommissionResult.ok(
        nodeId:       result['nodeId']       as int,
        deviceTypeId: result['deviceTypeId'] as int?,
      );
    } on PlatformException catch (e) {
      return CommissionResult.err(e.message ?? 'IP commission failed');
    }
  }

  // ── Device control ─────────────────────────────────────────────────────────

  Future<bool> toggleDevice(int nodeId, {required bool on}) async {
    try {
      return await _method.invokeMethod<bool>(
            'toggleDevice', {'nodeId': nodeId, 'on': on}) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> setLevel(int nodeId, int level) async {
    try {
      return await _method.invokeMethod<bool>(
            'setLevel', {'nodeId': nodeId, 'level': level}) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  // ── Thermostat ─────────────────────────────────────────────────────────────

  /// Reads LocalTemperature, OccupiedHeatingSetpoint, OccupiedCoolingSetpoint
  /// and SystemMode from the Thermostat cluster.
  /// All temperatures are in centidegrees (divide by 100 for °C).
  /// Returns null if the call fails.
  Future<({String serialNumber, String softwareVersion})?> readBasicInfo(
      int nodeId) async {
    try {
      final map = await _method
          .invokeMapMethod<String, String>('readBasicInfo', {'nodeId': nodeId});
      if (map == null) return null;
      return (
        serialNumber:    map['serialNumber']    ?? '',
        softwareVersion: map['softwareVersion'] ?? '',
      );
    } on PlatformException catch (e) {
      debugPrint('readBasicInfo error: ${e.message}');
      return null;
    }
  }

  Future<ThermostatState?> readThermostat(int nodeId) async {
    try {
      final map = await _method.invokeMapMethod<String, int>(
          'readThermostat', {'nodeId': nodeId});
      if (map == null) return null;
      int? orNull(int v) => v == -32768 || v == 0x80000000 ? null : v;
      return ThermostatState(
        localTempCenti:    orNull(map['localTemp'] ?? -32768),
        heatingSetptCenti: orNull(map['heatingSetpoint'] ?? -32768),
        coolingSetptCenti: orNull(map['coolingSetpoint'] ?? -32768),
        systemMode:        map['systemMode'] == -1 ? null : map['systemMode'],
        controlSequence:   map['controlSequence'] == -1 ? null : map['controlSequence'],
      );
    } on PlatformException catch (e) {
      debugPrint('readThermostat error: ${e.message}');
      return null;
    }
  }

  /// Writes [centidegrees] to OccupiedHeatingSetpoint (int16, 0.01 °C units).
  Future<bool> writeHeatingSetpoint(int nodeId, int centidegrees) async {
    try {
      await _method.invokeMethod<bool>(
          'writeHeatingSetpoint', {'nodeId': nodeId, 'centidegrees': centidegrees});
      return true;
    } on PlatformException catch (e) {
      debugPrint('writeHeatingSetpoint error: ${e.message}');
      return false;
    }
  }

  /// Writes [mode] to SystemMode (0=Off 1=Auto 3=Cool 4=Heat 7=FanOnly).
  Future<bool> writeSystemMode(int nodeId, int mode) async {
    try {
      await _method.invokeMethod<bool>(
          'writeSystemMode', {'nodeId': nodeId, 'mode': mode});
      return true;
    } on PlatformException catch (e) {
      debugPrint('writeSystemMode error: ${e.message}');
      return false;
    }
  }

  /// Opens the Android Thread credential picker (system consent UI).
  /// Returns the selected hex dataset string, or empty string if cancelled.
  Future<String?> readAndroidThreadCredentials() async {
    try {
      return await _method.invokeMethod<String>('readAndroidThreadCredentials');
    } on PlatformException catch (e) {
      debugPrint('readAndroidThreadCredentials error: ${e.message}');
      return null;
    }
  }

  /// Scans the local network for Thread Border Routers via mDNS (_meshcop._udp).
  /// Returns a list of [ThreadBorderRouter] records (may take up to 6 s).
  Future<List<ThreadBorderRouter>> discoverThreadNetworks() async {
    try {
      final jsonStr = await _method.invokeMethod<String>('discoverThreadNetworks');
      if (jsonStr == null || jsonStr == '[]') return [];
      final list = json.decode(jsonStr) as List<dynamic>;
      return list
          .map((e) => ThreadBorderRouter.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PlatformException catch (e) {
      debugPrint('discoverThreadNetworks error: ${e.message}');
      return [];
    }
  }

  Future<String?> readClusters(int nodeId) async {
    try {
      return await _method.invokeMethod<String>('readClusters', {'nodeId': nodeId});
    } on PlatformException catch (e) {
      debugPrint('readClusters error: ${e.message}');
      return null;
    }
  }

  Future<int?> readDeviceTypeId(int nodeId) async {
    try {
      return await _method.invokeMethod<int>(
          'readDeviceType', {'nodeId': nodeId});
    } on PlatformException {
      return null;
    }
  }

  Future<DeviceStateResult> readDeviceState(int nodeId) async {
    try {
      final result = await _method.invokeMapMethod<String, dynamic>(
        'readDeviceState', {'nodeId': nodeId},
      );
      if (result == null) return const DeviceStateResult(isOnline: false);
      return DeviceStateResult(
        isOnline:        result['isOnline']   as bool? ?? false,
        isOn:            result['isOn']       as bool?,
        brightnessLevel: result['brightness'] as int?,
      );
    } on PlatformException {
      return const DeviceStateResult(isOnline: false);
    }
  }

  // ── Share / remove / fabric ────────────────────────────────────────────────

  Future<bool> shareDevice(int nodeId) async {
    try {
      return await _method.invokeMethod<bool>(
            'shareDevice', {'nodeId': nodeId}) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> removeDevice(int nodeId) async {
    try {
      return await _method.invokeMethod<bool>(
            'removeDevice', {'nodeId': nodeId}) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<String?> getFabricId() async {
    try {
      return await _method.invokeMethod<String>('getFabricId');
    } on PlatformException {
      return null;
    }
  }
}
