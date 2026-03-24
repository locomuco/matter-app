/// Represents a single attribute inside a Matter cluster.
class ClusterAttribute {
  final int attributeId;
  final String name;
  final String value;
  final String type;

  const ClusterAttribute({
    required this.attributeId,
    required this.name,
    required this.value,
    this.type = 'uint8',
  });

  factory ClusterAttribute.fromJson(Map<String, dynamic> json) =>
      ClusterAttribute(
        attributeId: json['attributeId'] as int,
        name: json['name'] as String,
        value: json['value'] as String,
        type: json['type'] as String? ?? 'uint8',
      );
}

/// A single Matter cluster (e.g. On/Off, Level Control, Basic Information).
class MatterCluster {
  final int clusterId;
  final String name;
  final List<ClusterAttribute> attributes;

  const MatterCluster({
    required this.clusterId,
    required this.name,
    required this.attributes,
  });

  factory MatterCluster.fromJson(Map<String, dynamic> json) => MatterCluster(
        clusterId: json['clusterId'] as int,
        name: json['name'] as String,
        attributes: (json['attributes'] as List<dynamic>)
            .map((e) =>
                ClusterAttribute.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  String get hexId => '0x${clusterId.toRadixString(16).toUpperCase().padLeft(4, '0')}';
}

// ---------------------------------------------------------------------------
// Static helpers – build mock cluster data for a device (used in simulation)
// ---------------------------------------------------------------------------

List<MatterCluster> mockClustersForNode(int nodeId) {
  return [
    MatterCluster(
      clusterId: 0x0003,
      name: 'Identify',
      attributes: [
        ClusterAttribute(attributeId: 0x0000, name: 'IdentifyTime', value: '0', type: 'uint16'),
        ClusterAttribute(attributeId: 0x0001, name: 'IdentifyType', value: '2', type: 'enum8'),
      ],
    ),
    MatterCluster(
      clusterId: 0x0004,
      name: 'Groups',
      attributes: [
        ClusterAttribute(attributeId: 0x0000, name: 'NameSupport', value: '0x80', type: 'bitmap8'),
      ],
    ),
    MatterCluster(
      clusterId: 0x0006,
      name: 'On/Off',
      attributes: [
        ClusterAttribute(attributeId: 0x0000, name: 'OnOff', value: 'false', type: 'boolean'),
        ClusterAttribute(attributeId: 0x4000, name: 'GlobalSceneControl', value: 'true', type: 'boolean'),
        ClusterAttribute(attributeId: 0x4001, name: 'OnTime', value: '0', type: 'uint16'),
        ClusterAttribute(attributeId: 0x4002, name: 'OffWaitTime', value: '0', type: 'uint16'),
      ],
    ),
    MatterCluster(
      clusterId: 0x0008,
      name: 'Level Control',
      attributes: [
        ClusterAttribute(attributeId: 0x0000, name: 'CurrentLevel', value: '254', type: 'uint8'),
        ClusterAttribute(attributeId: 0x0001, name: 'RemainingTime', value: '0', type: 'uint16'),
        ClusterAttribute(attributeId: 0x000F, name: 'Options', value: '0x00', type: 'bitmap8'),
        ClusterAttribute(attributeId: 0x0011, name: 'OnLevel', value: '254', type: 'uint8'),
      ],
    ),
    MatterCluster(
      clusterId: 0x001D,
      name: 'Descriptor',
      attributes: [
        ClusterAttribute(attributeId: 0x0000, name: 'DeviceTypeList', value: '[0x0100]', type: 'list'),
        ClusterAttribute(attributeId: 0x0001, name: 'ServerList', value: '[3, 4, 6, 8, 29, 40]', type: 'list'),
        ClusterAttribute(attributeId: 0x0003, name: 'PartsList', value: '[]', type: 'list'),
      ],
    ),
    MatterCluster(
      clusterId: 0x0028,
      name: 'Basic Information',
      attributes: [
        ClusterAttribute(attributeId: 0x0000, name: 'DataModelRevision', value: '1', type: 'uint16'),
        ClusterAttribute(attributeId: 0x0001, name: 'VendorName', value: 'ACME Corp', type: 'string'),
        ClusterAttribute(attributeId: 0x0002, name: 'VendorID', value: '0xFFF1', type: 'vendor_id'),
        ClusterAttribute(attributeId: 0x0003, name: 'ProductName', value: 'Matter Light', type: 'string'),
        ClusterAttribute(attributeId: 0x0004, name: 'ProductID', value: '0x8001', type: 'uint16'),
        ClusterAttribute(attributeId: 0x0005, name: 'NodeLabel', value: 'Living Room Light', type: 'string'),
        ClusterAttribute(attributeId: 0x0007, name: 'HardwareVersion', value: '1', type: 'uint16'),
        ClusterAttribute(attributeId: 0x0009, name: 'SoftwareVersion', value: '1', type: 'uint32'),
        ClusterAttribute(attributeId: 0x000B, name: 'ManufacturingDate', value: '20231201', type: 'string'),
        ClusterAttribute(attributeId: 0x000C, name: 'PartNumber', value: 'MTR-LIGHT-001', type: 'string'),
        ClusterAttribute(attributeId: 0x000F, name: 'UniqueID', value: 'node-${nodeId.toRadixString(16)}', type: 'string'),
      ],
    ),
  ];
}
