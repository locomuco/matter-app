import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/matter_device.dart';

/// Persists the device list to SharedPreferences.
class DeviceStore {
  static const _kDevices = 'matter_devices';
  static const _kFabricId = 'matter_fabric_id';
  static const _kSimMode = 'matter_simulation_mode';

  final SharedPreferences _prefs;

  DeviceStore._(this._prefs);

  static Future<DeviceStore> open() async {
    final prefs = await SharedPreferences.getInstance();
    return DeviceStore._(prefs);
  }

  // -------------------------------------------------------------------------
  // Devices
  // -------------------------------------------------------------------------

  List<MatterDevice> loadDevices() {
    final raw = _prefs.getStringList(_kDevices) ?? [];
    return raw
        .map((s) {
          try {
            return MatterDevice.fromJson(
              jsonDecode(s) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<MatterDevice>()
        .toList();
  }

  Future<void> saveDevices(List<MatterDevice> devices) async {
    final raw = devices.map((d) => jsonEncode(d.toJson())).toList();
    await _prefs.setStringList(_kDevices, raw);
  }

  // -------------------------------------------------------------------------
  // Settings
  // -------------------------------------------------------------------------

  String? get fabricId => _prefs.getString(_kFabricId);

  Future<void> setFabricId(String id) => _prefs.setString(_kFabricId, id);

  bool get simulationMode => _prefs.getBool(_kSimMode) ?? true;

  Future<void> setSimulationMode(bool v) => _prefs.setBool(_kSimMode, v);
}
