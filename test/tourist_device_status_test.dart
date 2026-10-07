import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_tourist_safety/models/tourist_device_status_model.dart';
import 'package:smart_tourist_safety/services/safe_zone_status_service.dart';
import 'package:smart_tourist_safety/widgets/tourist_device_status_section.dart';

void main() {
  group('TouristDeviceStatusModel', () {
    test('parses available device telemetry fields', () {
      final timestamp = DateTime.utc(2026, 10, 7, 17, 12);
      final model = TouristDeviceStatusModel.fromUserData({
        'device_id': 'DEVICE-123',
        'device_status': 'online',
        'battery_percentage': '72%',
        'lora_signal': '-72 dBm',
        'last_communication': timestamp.toIso8601String(),
      });

      expect(model.deviceId, 'DEVICE-123');
      expect(model.deviceStatus, 'ONLINE');
      expect(model.batteryPercent, 72);
      expect(model.loraSignal, '-72 dBm');
      expect(model.lastCommunication!.isAtSameMomentAs(timestamp), isTrue);
    });

    test('parses Firestore timestamps for last communication', () {
      final timestamp = DateTime.utc(2026, 10, 7, 17, 12);
      final model = TouristDeviceStatusModel.fromUserData({
        'lastCommunication': Timestamp.fromDate(timestamp),
      });

      expect(model.lastCommunication!.isAtSameMomentAs(timestamp), isTrue);
    });

    test('leaves absent device ID unavailable and does not use digitalId', () {
      final model = TouristDeviceStatusModel.fromUserData({
        'digitalId': 'STS-123',
      });

      expect(model.deviceId, isNull);
    });

    test('handles missing, null, and malformed device data safely', () {
      expect(TouristDeviceStatusModel.fromUserData(null).deviceId, isNull);
      final model = TouristDeviceStatusModel.fromUserData({
        'deviceId': '  ',
        'deviceStatus': 'CONNECTED TO SOMEWHERE',
        'battery': 'not-a-number',
        'batteryLevel': 101,
        'loraSignal': <String>['invalid'],
        'lastCommunication': 'not-a-timestamp',
      });

      expect(model.deviceId, isNull);
      expect(model.deviceStatus, isNull);
      expect(model.batteryPercent, isNull);
      expect(model.loraSignal, isNull);
      expect(model.lastCommunication, isNull);
    });

    test('rejects out-of-range and non-finite battery values', () {
      for (final invalidBattery in [-1, 101, double.infinity, double.nan]) {
        final model = TouristDeviceStatusModel.fromUserData({
          'battery': invalidBattery,
        });
        expect(model.batteryPercent, isNull);
      }
    });
  });

  group('TouristDeviceStatusSection', () {
    testWidgets('shows unavailable telemetry and shared GPS status read-only', (
      tester,
    ) async {
      final gpsStatus = TouristSafetySnapshot(
        gpsStatus: TouristGpsStatus.permissionDenied,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TouristDeviceStatusSection(
              deviceStatusStream: Stream.value(
                TouristDeviceStatusModel.fromUserData(null),
              ),
              gpsStatusStream: Stream.value(gpsStatus),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Tourist Device Status'), findsOneWidget);
      expect(find.text('Device ID'), findsOneWidget);
      expect(find.text('Device Status'), findsOneWidget);
      expect(find.text('Battery'), findsOneWidget);
      expect(find.text('LoRa Signal'), findsOneWidget);
      expect(find.text('GPS Status'), findsOneWidget);
      expect(find.text('Last Communication'), findsOneWidget);
      expect(find.text('PERMISSION DENIED'), findsOneWidget);
      expect(find.text('Unavailable'), findsNWidgets(5));
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('shows GPS unavailable from the shared safety state', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TouristDeviceStatusSection(
              deviceStatusStream: Stream.value(
                const TouristDeviceStatusModel(),
              ),
              gpsStatusStream: Stream.value(
                const TouristSafetySnapshot(
                  gpsStatus: TouristGpsStatus.unavailable,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('GPS Status'), findsOneWidget);
      expect(find.text('UNAVAILABLE'), findsOneWidget);
    });

    testWidgets('displays available values and fits narrow and wide widths', (
      tester,
    ) async {
      final device = TouristDeviceStatusModel.fromUserData({
        'deviceId': 'DEVICE-123',
        'deviceStatus': 'CONNECTED',
        'battery': 85,
        'loraSignal': 'Strong',
        'lastCommunication': DateTime(2026, 10, 7, 22, 42),
      });

      for (final width in [360.0, 1024.0]) {
        await tester.binding.setSurfaceSize(Size(width, 900));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: TouristDeviceStatusSection(
                  deviceStatusStream: Stream.value(device),
                  gpsStatusStream: Stream.value(
                    const TouristSafetySnapshot(
                      gpsStatus: TouristGpsStatus.active,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('DEVICE-123'), findsOneWidget);
        expect(find.text('CONNECTED'), findsOneWidget);
        expect(find.text('85%'), findsOneWidget);
        expect(find.text('Strong'), findsOneWidget);
        expect(find.text('ACTIVE'), findsOneWidget);
        expect(find.textContaining('Oct 7, 10:42 PM'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.binding.setSurfaceSize(null);
    });
  });
}
