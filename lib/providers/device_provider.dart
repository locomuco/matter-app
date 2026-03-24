import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/device_type.dart';
import '../models/matter_device.dart';
import '../services/device_store.dart';
import '../services/matter_channel.dart';

enum DeviceProviderState { idle, loading, error }

class DeviceProvider extends ChangeNotifier {
  final DeviceStore _store;
  final MatterChannel _channel;
  final _uuid = const Uuid();

  DeviceProviderState state = DeviceProviderState.idle;
  String? errorMessage;
  List<MatterDevice> _devices = [];

  List<MatterDevice> get devices => List.unmodifiable(_devices);

  DeviceProvider(this._store, this._channel) {
    _load();
  }

  void _load() {
    _devices = _store.loadDevices().map((d) {
      // One-time migration: onOffLight devices that have a cached temperature
      // reading are thermostats mis-typed before the Descriptor-cluster fix.
      if (d.deviceType == DeviceType.onOffLight && d.localTempCenti != null) {
        return d.copyWith(deviceType: DeviceType.thermostat);
      }
      return d;
    }).toList();
    notifyListeners();
  }

  Future<void> _persist() => _store.saveDevices(_devices);

  // ── Commission ─────────────────────────────────────────────────────────────

  Future<MatterDevice?> commissionDevice(
    String payload,
    String deviceName,
    String room, {
    String? wifiSsid,
    String? wifiPassword,
    String? threadDatasetHex,
  }) async {
    state = DeviceProviderState.loading;
    notifyListeners();

    final result = await _channel.commissionDevice(
      payload,
      wifiSsid:         wifiSsid,
      wifiPassword:     wifiPassword,
      threadDatasetHex: threadDatasetHex,
    );
    return _handleCommissionResult(result, deviceName, room);
  }

  Future<MatterDevice?> commissionViaIp({
    required String ipAddress,
    required int discriminator,
    required int setupPinCode,
    required String deviceName,
    required String room,
    int port = 5540,
  }) async {
    state = DeviceProviderState.loading;
    notifyListeners();

    final result = await _channel.commissionViaIp(
      ipAddress:     ipAddress,
      port:          port,
      discriminator: discriminator,
      setupPinCode:  setupPinCode,
    );
    return _handleCommissionResult(result, deviceName, room);
  }

  Future<MatterDevice?> _handleCommissionResult(
    CommissionResult result,
    String name,
    String room,
  ) async {
    if (!result.success) {
      state        = DeviceProviderState.error;
      errorMessage = result.error ?? 'Commissioning failed';
      notifyListeners();
      return null;
    }

    final deviceType = result.deviceTypeId != null
        ? DeviceType.fromMatterDeviceTypeId(result.deviceTypeId!)
        : DeviceType.onOffLight;

    final device = MatterDevice(
      id:             _uuid.v4(),
      name:           name,
      deviceType:     deviceType,
      nodeId:         result.nodeId!,
      room:           room,
      isOnline:       true,
      isOn:           false,
      commissionedAt: DateTime.now(),
    );

    _devices.add(device);
    await _persist();
    state = DeviceProviderState.idle;
    notifyListeners();
    return device;
  }

  // ── Control ────────────────────────────────────────────────────────────────

  Future<void> toggle(String deviceId) async {
    final idx = _devices.indexWhere((d) => d.id == deviceId);
    if (idx == -1) return;
    final device = _devices[idx];
    if (!device.deviceType.hasOnOff) return;

    final newOn = !device.isOn;
    _devices[idx] = device.copyWith(isOn: newOn); // optimistic
    notifyListeners();

    final ok = await _channel.toggleDevice(device.nodeId, on: newOn);
    if (!ok) {
      _devices[idx] = device; // roll back
      notifyListeners();
    } else {
      await _persist();
    }
  }

  Future<void> setBrightness(String deviceId, double value) async {
    final idx = _devices.indexWhere((d) => d.id == deviceId);
    if (idx == -1) return;
    _devices[idx] = _devices[idx].copyWith(brightness: value);
    notifyListeners();
    final level = (value * 254).round().clamp(0, 254);
    await _channel.setLevel(_devices[idx].nodeId, level);
    await _persist();
  }

  // ── Refresh ────────────────────────────────────────────────────────────────

  Future<void> refreshDevice(String deviceId) async {
    final idx = _devices.indexWhere((d) => d.id == deviceId);
    if (idx == -1) return;
    final device = _devices[idx];

    // Read online state first — skip expensive Descriptor/thermostat reads
    // if the device turns out to be offline.
    final state = await _channel.readDeviceState(device.nodeId);

    if (!state.isOnline) {
      _devices[idx] = device.copyWith(isOnline: false);
      await _persist();
      notifyListeners();
      return;
    }

    // Device is online — refresh type and thermostat state in parallel.
    final typeIdRaw = await _channel.readDeviceTypeId(device.nodeId);
    final newType   = typeIdRaw != null
        ? DeviceType.fromMatterDeviceTypeId(typeIdRaw)
        : device.deviceType;

    int? localTempCenti = device.localTempCenti;
    if (newType == DeviceType.thermostat) {
      final thermo = await _channel.readThermostat(device.nodeId);
      localTempCenti = thermo?.localTempCenti ?? localTempCenti;
    }

    _devices[idx] = device.copyWith(
      isOnline:       true,
      isOn:           state.isOn ?? device.isOn,
      brightness:     state.brightnessLevel != null
          ? state.brightnessLevel! / 254.0
          : device.brightness,
      deviceType:     newType,
      localTempCenti: localTempCenti,
    );
    await _persist();
    notifyListeners();
  }

  Future<void> refreshAll() async {
    for (final d in _devices) {
      await refreshDevice(d.id);
    }
  }

  // ── Share (multi-admin) ────────────────────────────────────────────────────

  Future<bool> shareWithGoogleHome(String deviceId) async {
    final device =
        _devices.firstWhere((d) => d.id == deviceId, orElse: () => throw StateError('not found'));
    final ok = await _channel.shareDevice(device.nodeId);
    if (ok) {
      final idx = _devices.indexWhere((d) => d.id == deviceId);
      _devices[idx] = device.copyWith(sharedWithGoogleHome: true);
      await _persist();
      notifyListeners();
    }
    return ok;
  }

  // ── Edit / Remove ──────────────────────────────────────────────────────────

  Future<void> renameDevice(String deviceId, String newName) async {
    final idx = _devices.indexWhere((d) => d.id == deviceId);
    if (idx == -1) return;
    _devices[idx] = _devices[idx].copyWith(name: newName);
    await _persist();
    notifyListeners();
  }

  Future<void> setRoom(String deviceId, String room) async {
    final idx = _devices.indexWhere((d) => d.id == deviceId);
    if (idx == -1) return;
    _devices[idx] = _devices[idx].copyWith(room: room);
    await _persist();
    notifyListeners();
  }

  Future<bool> removeDevice(String deviceId) async {
    final idx = _devices.indexWhere((d) => d.id == deviceId);
    if (idx == -1) return false;
    final device = _devices[idx];
    await _channel.removeDevice(device.nodeId);
    _devices.removeAt(idx);
    await _persist();
    notifyListeners();
    return true;
  }

  Future<void> clearAllDevices() async {
    _devices.clear();
    await _persist();
    notifyListeners();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  MatterDevice? findById(String id) {
    try {
      return _devices.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  List<String> get rooms {
    final set = <String>{};
    for (final d in _devices) {
      set.add(d.room);
    }
    return set.toList()..sort();
  }
}
