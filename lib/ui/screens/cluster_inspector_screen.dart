import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/matter_device.dart';
import '../../services/matter_channel.dart';

// ---------------------------------------------------------------------------
// Well-known cluster / attribute names
// ---------------------------------------------------------------------------

const _kClusterNames = <int, String>{
  0x0003: 'Identify',
  0x0004: 'Groups',
  0x0005: 'Scenes',
  0x0006: 'On/Off',
  0x0008: 'Level Control',
  0x001D: 'Descriptor',
  0x001E: 'Binding',
  0x001F: 'Access Control',
  0x0025: 'Actions',
  0x0028: 'Basic Information',
  0x002A: 'OTA Software Update Requestor',
  0x002B: 'Localization Configuration',
  0x002C: 'Time Format Localization',
  0x002D: 'Unit Localization',
  0x002E: 'Power Source Configuration',
  0x002F: 'Power Source',
  0x0030: 'General Commissioning',
  0x0031: 'Network Commissioning',
  0x0032: 'Diagnostic Logs',
  0x0033: 'General Diagnostics',
  0x0034: 'Software Diagnostics',
  0x0035: 'Thread Network Diagnostics',
  0x0036: 'Wi-Fi Network Diagnostics',
  0x0037: 'Ethernet Network Diagnostics',
  0x0038: 'Time Synchronization',
  0x003B: 'Switch',
  0x003C: 'Administrator Commissioning',
  0x003E: 'Node Operational Credentials',
  0x003F: 'Group Key Management',
  0x0040: 'Fixed Label',
  0x0041: 'User Label',
  0x0045: 'Boolean State',
  0x0046: 'ICD Management',
  0x0050: 'Mode Select',
  0x0059: 'Scenes Management',
  0x0071: 'HEPA Filter Monitoring',
  0x0072: 'Activated Carbon Filter Monitoring',
  0x0080: 'Boolean State Configuration',
  0x0081: 'Valve Configuration and Control',
  0x0090: 'Electrical Energy Measurement',
  0x0091: 'Electrical Power Measurement',
  0x0096: 'Microwave Oven Control',
  0x0101: 'Door Lock',
  0x0102: 'Window Covering',
  0x0200: 'Pump Configuration and Control',
  0x0201: 'Thermostat',
  0x0202: 'Fan Control',
  0x0204: 'Thermostat User Interface Configuration',
  0x0300: 'Color Control',
  0x0301: 'Ballast Configuration',
  0x0400: 'Illuminance Measurement',
  0x0402: 'Temperature Measurement',
  0x0403: 'Pressure Measurement',
  0x0404: 'Flow Measurement',
  0x0405: 'Relative Humidity Measurement',
  0x0406: 'Occupancy Sensing',
  0x040C: 'Carbon Monoxide Concentration',
  0x040D: 'Carbon Dioxide Concentration',
  0x042A: 'PM2.5 Concentration',
  0x0500: 'IAS Zone',
  0x0503: 'Wake on LAN',
  0x0504: 'Channel',
  0x0507: 'Media Input',
  0x050A: 'Content Launcher',
  0x050B: 'Audio Output',
  0x050C: 'Application Launcher',
  0x050D: 'Application Basic',
  0x050E: 'Account Login',
};

const _kAttrNames = <int, Map<int, String>>{
  0x0006: {0x0000: 'OnOff', 0x4000: 'GlobalSceneControl', 0x4001: 'OnTime', 0x4002: 'OffWaitTime', 0x4003: 'StartUpOnOff'},
  0x0008: {0x0000: 'CurrentLevel', 0x0001: 'RemainingTime', 0x000F: 'Options', 0x0010: 'OnOffTransitionTime', 0x0011: 'OnLevel', 0x0012: 'OnTransitionTime', 0x0013: 'OffTransitionTime'},
  0x001D: {0x0000: 'DeviceTypeList', 0x0001: 'ServerList', 0x0002: 'ClientList', 0x0003: 'PartsList'},
  0x0028: {0x0000: 'DataModelRevision', 0x0001: 'VendorName', 0x0002: 'VendorID', 0x0003: 'ProductName', 0x0004: 'ProductID', 0x0005: 'NodeLabel', 0x0006: 'Location', 0x0007: 'HardwareVersion', 0x0008: 'HardwareVersionString', 0x0009: 'SoftwareVersion', 0x000A: 'SoftwareVersionString', 0x000B: 'ManufacturingDate', 0x000C: 'PartNumber', 0x000E: 'SerialNumber', 0x000F: 'LocalConfigDisabled', 0x0010: 'Reachable', 0x0011: 'UniqueID'},
  0x0030: {0x0000: 'Breadcrumb', 0x0001: 'BasicCommissioningInfo', 0x0002: 'RegulatoryConfig', 0x0003: 'LocationCapability', 0x0004: 'SupportsConcurrentConnection'},
  0x0031: {0x0000: 'MaxNetworks', 0x0001: 'Networks', 0x0002: 'ScanMaxTimeSeconds', 0x0003: 'ConnectMaxTimeSeconds', 0x0004: 'InterfaceEnabled', 0x0005: 'LastNetworkingStatus', 0x0006: 'LastNetworkID', 0x0007: 'LastConnectErrorValue'},
  0x0033: {0x0000: 'NetworkInterfaces', 0x0001: 'RebootCount', 0x0002: 'UpTime', 0x0003: 'TotalOperationalHours', 0x0004: 'BootReason', 0x0008: 'TestEventTriggersEnabled'},
  0x003E: {0x0000: 'NOCs', 0x0001: 'Fabrics', 0x0002: 'SupportedFabrics', 0x0003: 'CommissionedFabrics', 0x0004: 'TrustedRootCertificates', 0x0005: 'CurrentFabricIndex'},
  0x0046: {0x0000: 'IdleModeDuration', 0x0001: 'ActiveModeDuration', 0x0002: 'ActiveModeThreshold'},
  0x0201: {0x0000: 'LocalTemperature', 0x0001: 'OutdoorTemperature', 0x0003: 'AbsMinHeatSetpointLimit', 0x0004: 'AbsMaxHeatSetpointLimit', 0x0005: 'AbsMinCoolSetpointLimit', 0x0006: 'AbsMaxCoolSetpointLimit', 0x0010: 'LocalTemperatureCalibration', 0x0011: 'OccupiedCoolingSetpoint', 0x0012: 'OccupiedHeatingSetpoint', 0x0015: 'MinHeatSetpointLimit', 0x0016: 'MaxHeatSetpointLimit', 0x0017: 'MinCoolSetpointLimit', 0x0018: 'MaxCoolSetpointLimit', 0x001B: 'ControlSequenceOfOperation', 0x001C: 'SystemMode', 0x001E: 'ThermostatRunningMode', 0x0025: 'HVACSystemTypeConfiguration', 0x0029: 'SetpointChangeSource', 0x002A: 'SetpointChangeAmount', 0x002B: 'SetpointChangeSourceTimestamp'},
  0x0402: {0x0000: 'MeasuredValue', 0x0001: 'MinMeasuredValue', 0x0002: 'MaxMeasuredValue', 0x0003: 'Tolerance'},
  0x0405: {0x0000: 'MeasuredValue', 0x0001: 'MinMeasuredValue', 0x0002: 'MaxMeasuredValue', 0x0003: 'Tolerance'},
};

// Global attributes common to all clusters
const _kGlobalAttrs = <int, String>{
  0xFFF8: 'GeneratedCommandList',
  0xFFF9: 'AcceptedCommandList',
  0xFFFA: 'EventList',
  0xFFFB: 'AttributeList',
  0xFFFC: 'FeatureMap',
  0xFFFD: 'ClusterRevision',
};

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ClusterInspectorScreen extends StatefulWidget {
  final MatterDevice device;
  const ClusterInspectorScreen({super.key, required this.device});

  @override
  State<ClusterInspectorScreen> createState() => _ClusterInspectorScreenState();
}

class _ClusterInspectorScreenState extends State<ClusterInspectorScreen> {
  late Future<List<_ClusterData>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_ClusterData>> _load() async {
    final channel = context.read<MatterChannel>();
    final jsonStr = await channel.readClusters(widget.device.nodeId);
    if (jsonStr == null || jsonStr == '[]') return [];

    final raw = json.decode(jsonStr) as List<dynamic>;
    // Group by endpoint first, then by cluster ID
    final Map<int, Map<int, List<_AttrData>>> byEpCluster = {};
    for (final entry in raw) {
      final ep  = (entry['endpoint'] as num).toInt();
      final cid = (entry['clusterId'] as num).toInt();
      final attrs = (entry['attributes'] as List<dynamic>)
          .map((a) => _AttrData(
                id: (a['id'] as num).toInt(),
                value: a['value']?.toString() ?? 'null',
              ))
          .toList();
      byEpCluster.putIfAbsent(ep, () => {})[cid] = attrs;
    }

    // Flatten into a sorted list of _ClusterData
    final result = <_ClusterData>[];
    final sortedEps = byEpCluster.keys.toList()..sort();
    for (final ep in sortedEps) {
      final clusters = byEpCluster[ep]!;
      final sortedClusters = clusters.keys.toList()..sort();
      for (final cid in sortedClusters) {
        result.add(_ClusterData(
          endpoint: ep,
          clusterId: cid,
          attributes: clusters[cid]!,
        ));
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.device.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              'Cluster Inspector · '
              '0x${widget.device.nodeId.toRadixString(16).padLeft(16, '0').toUpperCase()}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
            onPressed: () => setState(() { _future = _load(); }),
          ),
        ],
      ),
      body: FutureBuilder<List<_ClusterData>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Reading all clusters…'),
                ],
              ),
            );
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final clusters = snap.data ?? [];
          if (clusters.isEmpty) {
            return const Center(child: Text('No cluster data returned'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: clusters.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) => _ClusterCard(data: clusters[i]),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class _AttrData {
  final int id;
  final String value;
  const _AttrData({required this.id, required this.value});
}

class _ClusterData {
  final int endpoint;
  final int clusterId;
  final List<_AttrData> attributes;
  const _ClusterData(
      {required this.endpoint,
      required this.clusterId,
      required this.attributes});

  String get clusterName =>
      _kClusterNames[clusterId] ??
      '0x${clusterId.toRadixString(16).toUpperCase().padLeft(4, '0')}';

  String get hexId =>
      '0x${clusterId.toRadixString(16).toUpperCase().padLeft(4, '0')}';

  String attrName(int attrId) {
    final clusterMap = _kAttrNames[clusterId];
    if (clusterMap != null && clusterMap.containsKey(attrId)) {
      return clusterMap[attrId]!;
    }
    if (_kGlobalAttrs.containsKey(attrId)) return _kGlobalAttrs[attrId]!;
    return '0x${attrId.toRadixString(16).toUpperCase().padLeft(4, '0')}';
  }
}

// ---------------------------------------------------------------------------
// Cluster card widget
// ---------------------------------------------------------------------------

class _ClusterCard extends StatefulWidget {
  final _ClusterData data;
  const _ClusterCard({required this.data});

  @override
  State<_ClusterCard> createState() => _ClusterCardState();
}

class _ClusterCardState extends State<_ClusterCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final data = widget.data;

    // Non-global attributes first, then global
    final appAttrs = data.attributes
        .where((a) => !_kGlobalAttrs.containsKey(a.id))
        .toList();
    final globalAttrs = data.attributes
        .where((a) => _kGlobalAttrs.containsKey(a.id))
        .toList();

    return Card(
      color: cs.surfaceContainerHighest,
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Endpoint badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'EP${data.endpoint}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: cs.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Cluster ID badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      data.hexId,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(data.clusterName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Text(
                    '${appAttrs.length} attr.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            ...appAttrs.map((a) => _AttrRow(
                attr: a, name: data.attrName(a.id), highlight: true)),
            if (globalAttrs.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                child: Text('Global attributes',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant)),
              ),
              ...globalAttrs.map((a) => _AttrRow(
                  attr: a, name: data.attrName(a.id), highlight: false)),
            ],
          ],
        ],
      ),
    );
  }
}

class _AttrRow extends StatelessWidget {
  final _AttrData attr;
  final String name;
  final bool highlight;
  const _AttrRow(
      {required this.attr, required this.name, required this.highlight});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hexAttr =
        '0x${attr.id.toRadixString(16).toUpperCase().padLeft(4, '0')}';

    return InkWell(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: '$name: ${attr.value}'));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Copied to clipboard'),
              duration: Duration(seconds: 1)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 60,
              child: Text(
                hexAttr,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Text(name,
                  style: TextStyle(
                    fontSize: 13,
                    color: highlight ? cs.onSurface : cs.onSurfaceVariant,
                  )),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                attr.value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: highlight ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
