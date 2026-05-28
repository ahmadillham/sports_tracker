/// BLE Service and Characteristic UUIDs matching the ESP32 firmware.
/// Sport mode enum mirroring the firmware's SportMode.

import 'package:flutter/material.dart';

class BleConstants {
  BleConstants._();

  // ── Custom Sport Service ──
  static const String sportServiceUuid =
      '6e57fc85-a1b3-4f8e-9bd2-0a5e8e6e5c10';
  static const String sensorDataCharUuid =
      '6e57fc85-a1b3-4f8e-9bd2-0a5e8e6e5c11';
  static const String gpsDataCharUuid =
      '6e57fc85-a1b3-4f8e-9bd2-0a5e8e6e5c12';
  static const String commandCharUuid =
      '6e57fc85-a1b3-4f8e-9bd2-0a5e8e6e5c13';

  // ── BLE Device Name ──
  static const String deviceName = 'SportTracker';

  // ── Scan timeout ──
  static const Duration scanTimeout = Duration(seconds: 10);

  // ── Reconnect delay ──
  static const Duration reconnectDelay = Duration(seconds: 3);
}

/// Sport modes matching ESP32 firmware enum.
enum SportMode {
  idle(0x00, 'Idle', Icons.pause_circle_outline),
  running(0x01, 'Running', Icons.directions_run),
  cycling(0x02, 'Cycling', Icons.directions_bike),
  jumpRope(0x03, 'Jump Rope', Icons.fitness_center),
  pushup(0x04, 'Push-up', Icons.accessibility_new),
  squat(0x05, 'Squat', Icons.airline_seat_legroom_extra),
  plank(0x06, 'Plank', Icons.straighten);

  const SportMode(this.code, this.label, this.icon);
  final int code;
  final String label;
  final IconData icon;

  /// Whether this mode is a GPS/outdoor activity
  bool get isOutdoor => this == running || this == cycling;

  /// Whether this mode is an indoor calisthenics mode
  bool get isIndoor => !isOutdoor && this != idle;
}
