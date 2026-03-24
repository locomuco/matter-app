import 'package:flutter/material.dart';

/// Matter device types (Matter Application Cluster Specification §7).
enum DeviceType {
  // ── Lighting ──────────────────────────────────────────────────────────────
  onOffLight,
  dimmableLight,
  colorTemperatureLight,
  extendedColorLight,
  // ── Switches ─────────────────────────────────────────────────────────────
  onOffSwitch,
  dimmerSwitch,
  // ── Smart energy ──────────────────────────────────────────────────────────
  onOffPlugInUnit,
  // ── HVAC ──────────────────────────────────────────────────────────────────
  thermostat,
  fan,
  airPurifier,
  // ── Sensors ───────────────────────────────────────────────────────────────
  temperatureSensor,
  humiditySensor,
  pressureSensor,
  flowSensor,
  contactSensor,
  lightSensor,
  occupancySensor,
  smokeCOAlarm,
  // ── Access control ────────────────────────────────────────────────────────
  doorLock,
  windowCovering,
  // ── Robotic / AV ──────────────────────────────────────────────────────────
  roboticVacuumCleaner,
  // ── Fallback ─────────────────────────────────────────────────────────────
  unknown;

  // ── Display name ──────────────────────────────────────────────────────────
  String get displayName => switch (this) {
        onOffLight            => 'On/Off Light',
        dimmableLight         => 'Dimmable Light',
        colorTemperatureLight => 'Color Temp. Light',
        extendedColorLight    => 'Color Light',
        onOffSwitch           => 'On/Off Switch',
        dimmerSwitch          => 'Dimmer Switch',
        onOffPlugInUnit       => 'Smart Plug',
        thermostat            => 'Thermostat',
        fan                   => 'Fan',
        airPurifier           => 'Air Purifier',
        temperatureSensor     => 'Temperature Sensor',
        humiditySensor        => 'Humidity Sensor',
        pressureSensor        => 'Pressure Sensor',
        flowSensor            => 'Flow Sensor',
        contactSensor         => 'Contact Sensor',
        lightSensor           => 'Light Sensor',
        occupancySensor       => 'Occupancy Sensor',
        smokeCOAlarm          => 'Smoke/CO Alarm',
        doorLock              => 'Door Lock',
        windowCovering        => 'Window Covering',
        roboticVacuumCleaner  => 'Robotic Vacuum',
        unknown               => 'Unknown Device',
      };

  // ── Capability flags ───────────────────────────────────────────────────────
  bool get hasOnOff => switch (this) {
        onOffLight ||
        dimmableLight ||
        colorTemperatureLight ||
        extendedColorLight ||
        onOffSwitch ||
        dimmerSwitch ||
        onOffPlugInUnit      => true,
        _                    => false,
      };

  bool get hasBrightness => switch (this) {
        dimmableLight ||
        colorTemperatureLight ||
        extendedColorLight ||
        dimmerSwitch         => true,
        _                    => false,
      };

  bool get isLight => switch (this) {
        onOffLight ||
        dimmableLight ||
        colorTemperatureLight ||
        extendedColorLight   => true,
        _                    => false,
      };

  bool get isSensor => switch (this) {
        temperatureSensor ||
        humiditySensor    ||
        pressureSensor    ||
        flowSensor        ||
        contactSensor     ||
        lightSensor       ||
        occupancySensor   ||
        smokeCOAlarm      => true,
        _                 => false,
      };

  // ── Device type ID ↔ enum mapping (Matter spec §7) ────────────────────────
  static DeviceType fromMatterDeviceTypeId(int id) => switch (id) {
        // Lighting
        0x0100 => onOffLight,
        0x0101 => dimmableLight,
        0x010C => colorTemperatureLight,
        0x010D => extendedColorLight,
        // Switches
        0x0103 => onOffSwitch,
        0x0104 => dimmerSwitch,
        // Smart energy
        0x010A => onOffPlugInUnit,
        // HVAC
        0x0301 => thermostat,
        0x002B => fan,
        0x002D => airPurifier,
        // Sensors
        0x0302 => temperatureSensor,
        0x0307 => humiditySensor,
        0x0305 => pressureSensor,
        0x0306 => flowSensor,
        0x0015 => contactSensor,
        0x0106 => lightSensor,
        0x0107 => occupancySensor,
        0x0076 => smokeCOAlarm,
        // Access control
        0x000A => doorLock,
        0x0202 => windowCovering,
        // Robotic
        0x0074 => roboticVacuumCleaner,
        _      => unknown,
      };

  // ── Icon ──────────────────────────────────────────────────────────────────
  IconData get icon => switch (this) {
        onOffLight ||
        dimmableLight ||
        colorTemperatureLight ||
        extendedColorLight    => Icons.lightbulb_outline,
        onOffSwitch ||
        dimmerSwitch          => Icons.toggle_on_outlined,
        onOffPlugInUnit       => Icons.power_outlined,
        thermostat            => Icons.thermostat,
        fan                   => Icons.wind_power_outlined,
        airPurifier           => Icons.air_outlined,
        temperatureSensor     => Icons.device_thermostat_outlined,
        humiditySensor        => Icons.water_drop_outlined,
        pressureSensor        => Icons.compress_outlined,
        flowSensor            => Icons.water_outlined,
        contactSensor         => Icons.sensor_door_outlined,
        lightSensor           => Icons.light_mode_outlined,
        occupancySensor       => Icons.person_search_outlined,
        smokeCOAlarm          => Icons.emergency_outlined,
        doorLock              => Icons.lock_outline,
        windowCovering        => Icons.blinds_outlined,
        roboticVacuumCleaner  => Icons.smart_toy_outlined,
        unknown               => Icons.device_unknown_outlined,
      };
}
