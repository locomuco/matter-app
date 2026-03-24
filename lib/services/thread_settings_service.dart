import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'matter_channel.dart';

/// Persists the Thread operational dataset hex string and the last discovered
/// border router list across app restarts.
class ThreadSettingsService {
  static const _keyDataset = 'thread_dataset_hex';
  static const _keyRouters = 'thread_discovered_routers';

  static const defaultDataset =
      '35060004001fffc0020812f209ab410ad778'
      '0708fd0e736aab8a000005101821a78a600f'
      '096682821720a51fd913030d4e4553542d50'
      '414e2d32364241010226ba0410f377af82aa'
      '453bb24d2e2b6fd2324e650c0402a0fff800'
      '0300000f0e080000690ddc3ed1a8';

  /// Returns the saved dataset, or [defaultDataset] if none saved yet.
  static Future<String> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDataset) ?? defaultDataset;
  }

  /// Saves [hex] (whitespace is stripped before saving).
  static Future<void> save(String hex) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDataset, hex.replaceAll(RegExp(r'\s'), ''));
  }

  /// Persists the last-scanned border router list as JSON.
  static Future<void> saveRouters(List<ThreadBorderRouter> routers) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(
        routers.map((r) => {
          'serviceName': r.serviceName,
          'networkName': r.networkName,
          'extPanId':    r.extPanId,
          'vendorName':  r.vendorName,
          'modelName':   r.modelName,
          'host':        r.host,
          'port':        r.port,
          'txt':         r.txt,
        }).toList());
    await prefs.setString(_keyRouters, encoded);
  }

  /// Returns the last-persisted border router list, or empty list.
  static Future<List<ThreadBorderRouter>> loadRouters() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyRouters);
    if (raw == null) return [];
    try {
      final list = json.decode(raw) as List<dynamic>;
      return list
          .map((e) => ThreadBorderRouter.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
