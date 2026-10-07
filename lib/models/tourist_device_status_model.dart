import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class TouristDeviceStatusModel {
  final String? deviceId;
  final String? deviceStatus;
  final double? batteryPercent;
  final String? loraSignal;
  final DateTime? lastCommunication;

  const TouristDeviceStatusModel({
    this.deviceId,
    this.deviceStatus,
    this.batteryPercent,
    this.loraSignal,
    this.lastCommunication,
  });

  factory TouristDeviceStatusModel.fromUserData(
    Map<String, dynamic>? data,
  ) {
    if (data == null) return const TouristDeviceStatusModel();

    return TouristDeviceStatusModel(
      deviceId: _nonEmptyString(data['deviceId'] ?? data['device_id']),
      deviceStatus: _parseDeviceStatus(
        data['deviceStatus'] ?? data['device_status'],
      ),
      batteryPercent: _parseBattery(
        data['battery'] ??
            data['batteryLevel'] ??
            data['batteryPercentage'] ??
            data['battery_percentage'],
      ),
      loraSignal: _nonEmptyString(
        data['loraSignal'] ??
            data['lora_signal'] ??
            data['signalStrength'] ??
            data['signal_strength'],
      ),
      lastCommunication: _parseTimestamp(
        data['lastCommunication'] ?? data['last_communication'],
      ),
    );
  }

  static String? _nonEmptyString(Object? value) {
    if (value is! String && value is! num) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static String? _parseDeviceStatus(Object? value) {
    final text = _nonEmptyString(value)?.toUpperCase();
    if (text == null) return null;
    return const {
      'CONNECTED',
      'ONLINE',
      'OFFLINE',
      'DISCONNECTED',
      'UNKNOWN',
    }.contains(text)
        ? text
        : null;
  }

  static double? _parseBattery(Object? value) {
    final text = value is String ? value.trim().replaceFirst('%', '') : value;
    final number = switch (text) {
      final num value => value.toDouble(),
      final String value => double.tryParse(value),
      _ => null,
    };
    if (number == null || !number.isFinite || number < 0 || number > 100) {
      return null;
    }
    return number;
  }

  static DateTime? _parseTimestamp(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value.trim());
    return null;
  }
}
