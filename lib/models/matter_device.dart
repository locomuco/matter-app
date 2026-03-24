import 'dart:convert';

import 'device_type.dart';

/// Represents a commissioned Matter device held in our local fabric.
class MatterDevice {
  final String id;
  final String name;
  final DeviceType deviceType;
  final int nodeId;
  final String room;
  final bool isOnline;
  final bool isOn;
  final double brightness;
  final bool sharedWithGoogleHome;
  final DateTime commissionedAt;
  /// Cached thermostat local temperature in centidegrees (0.01 °C). Null if
  /// not a thermostat or not yet read.
  final int? localTempCenti;

  const MatterDevice({
    required this.id,
    required this.name,
    required this.deviceType,
    required this.nodeId,
    this.room = 'Unassigned',
    this.isOnline = true,
    this.isOn = false,
    this.brightness = 1.0,
    this.sharedWithGoogleHome = false,
    required this.commissionedAt,
    this.localTempCenti,
  });

  MatterDevice copyWith({
    String? id,
    String? name,
    DeviceType? deviceType,
    int? nodeId,
    String? room,
    bool? isOnline,
    bool? isOn,
    double? brightness,
    bool? sharedWithGoogleHome,
    DateTime? commissionedAt,
    int? localTempCenti,
    bool clearLocalTemp = false,
  }) {
    return MatterDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      deviceType: deviceType ?? this.deviceType,
      nodeId: nodeId ?? this.nodeId,
      room: room ?? this.room,
      isOnline: isOnline ?? this.isOnline,
      isOn: isOn ?? this.isOn,
      brightness: brightness ?? this.brightness,
      sharedWithGoogleHome: sharedWithGoogleHome ?? this.sharedWithGoogleHome,
      commissionedAt: commissionedAt ?? this.commissionedAt,
      localTempCenti: clearLocalTemp ? null : (localTempCenti ?? this.localTempCenti),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'deviceType': deviceType.name,
        'nodeId': nodeId,
        'room': room,
        'isOnline': isOnline,
        'isOn': isOn,
        'brightness': brightness,
        'sharedWithGoogleHome': sharedWithGoogleHome,
        'commissionedAt': commissionedAt.toIso8601String(),
        if (localTempCenti != null) 'localTempCenti': localTempCenti,
      };

  factory MatterDevice.fromJson(Map<String, dynamic> json) {
    return MatterDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      deviceType: DeviceType.values.firstWhere(
        (e) => e.name == json['deviceType'],
        orElse: () => DeviceType.unknown,
      ),
      nodeId: json['nodeId'] as int,
      room: json['room'] as String? ?? 'Unassigned',
      isOnline: json['isOnline'] as bool? ?? true,
      isOn: json['isOn'] as bool? ?? false,
      brightness: (json['brightness'] as num?)?.toDouble() ?? 1.0,
      sharedWithGoogleHome: json['sharedWithGoogleHome'] as bool? ?? false,
      commissionedAt: DateTime.parse(json['commissionedAt'] as String),
      localTempCenti: json['localTempCenti'] as int?,
    );
  }

  static MatterDevice fromJsonString(String raw) =>
      MatterDevice.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  String toJsonString() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is MatterDevice && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
