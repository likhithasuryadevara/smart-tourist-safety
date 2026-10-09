import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:smart_tourist_safety/services/location_service.dart';
import 'package:smart_tourist_safety/services/safe_zone_service.dart';
import 'package:smart_tourist_safety/services/safe_zone_status_service.dart';
import 'package:smart_tourist_safety/widgets/tourist_safety_status.dart';

void main() {
  final statusService = SafeZoneStatusService();
  final geofenceService = SafeZoneService();
  final safeZone = SafeZone(latitude: 0, longitude: 0, radius: 500);
  final dangerZone = DangerZone(
    id: 'danger',
    name: 'Test Danger Zone',
    latitude: 0,
    longitude: 0,
    radius: 100,
  );

  void updateLocation({
    required double latitude,
    required double longitude,
    SafeZone? safeZone,
    List<DangerZone> dangerZones = const [],
  }) {
    statusService.updateLocation(
      latitude: latitude,
      longitude: longitude,
      updatedAt: DateTime.utc(2026, 10, 7, 12),
      safeZone: safeZone,
      dangerZones: dangerZones,
      safeZoneService: geofenceService,
    );
  }

  setUp(() {
    statusService.updateGpsStatus(TouristGpsStatus.active);
  });

  group('Tourist safety status', () {
    test(
      'location permission states request once and remain distinguishable',
      () async {
        final permissionGateway = _FakeLocationPermissionGateway();
        final locationService = LocationService(
          permissionGateway: permissionGateway,
        );

        permissionGateway.permission = LocationPermission.denied;
        permissionGateway.requestResult = LocationPermission.denied;
        expect(
          await locationService.getAvailability(requestPermission: true),
          LocationAvailability.permissionDenied,
        );
        expect(permissionGateway.requestCount, 1);

        permissionGateway.permission = LocationPermission.deniedForever;
        expect(
          await locationService.getAvailability(requestPermission: true),
          LocationAvailability.permissionDeniedForever,
        );
        expect(permissionGateway.requestCount, 1);

        permissionGateway.permission = LocationPermission.whileInUse;
        expect(
          await locationService.getAvailability(),
          LocationAvailability.active,
        );
        expect(permissionGateway.requestCount, 1);

        permissionGateway.permission = LocationPermission.denied;
        permissionGateway.requestResult = LocationPermission.whileInUse;
        expect(
          await locationService.getAvailability(requestPermission: true),
          LocationAvailability.active,
        );
        expect(permissionGateway.requestCount, 2);
      },
    );

    test(
      'disabled location services do not request location permission',
      () async {
        final permissionGateway = _FakeLocationPermissionGateway()
          ..serviceEnabled = false;
        final locationService = LocationService(
          permissionGateway: permissionGateway,
        );

        expect(
          await locationService.getAvailability(requestPermission: true),
          LocationAvailability.disabled,
        );
        expect(permissionGateway.checkCount, 0);
        expect(permissionGateway.requestCount, 0);
      },
    );

    test('reports GPS active and permission denied accurately', () {
      statusService.updateGpsStatus(TouristGpsStatus.active);
      expect(statusService.snapshot.gpsStatus, TouristGpsStatus.active);

      statusService.updateGpsStatus(TouristGpsStatus.permissionDenied);
      expect(
        statusService.snapshot.gpsStatus,
        TouristGpsStatus.permissionDenied,
      );
      expect(statusService.snapshot.zoneStatus, TouristZoneStatus.unknown);
      expect(statusService.snapshot.safetyIndicator, 'UNKNOWN');

      statusService.updateGpsStatus(TouristGpsStatus.permissionDeniedForever);
      expect(
        statusService.snapshot.gpsStatus,
        TouristGpsStatus.permissionDeniedForever,
      );
      expect(statusService.snapshot.zoneStatus, TouristZoneStatus.unknown);

      statusService.updateGpsStatus(TouristGpsStatus.disabled);
      expect(statusService.snapshot.gpsStatus, TouristGpsStatus.disabled);
      statusService.updateGpsStatus(TouristGpsStatus.unavailable);
      expect(statusService.snapshot.gpsStatus, TouristGpsStatus.unavailable);
    });

    test('classifies safe, danger, outside, and unknown zones', () {
      updateLocation(latitude: 0, longitude: 0, safeZone: safeZone);
      expect(statusService.snapshot.zoneStatus, TouristZoneStatus.safe);
      expect(statusService.snapshot.safetyIndicator, 'SAFE');

      updateLocation(
        latitude: 0,
        longitude: 0,
        safeZone: safeZone,
        dangerZones: [dangerZone],
      );
      expect(statusService.snapshot.zoneStatus, TouristZoneStatus.danger);
      expect(statusService.snapshot.safetyIndicator, 'DANGER');
      expect(statusService.snapshot.isInsideSafeZone, isTrue);

      updateLocation(latitude: 0.02, longitude: 0, safeZone: safeZone);
      expect(
        statusService.snapshot.zoneStatus,
        TouristZoneStatus.outsideSafeZone,
      );
      expect(statusService.snapshot.safetyIndicator, 'DANGER');

      updateLocation(latitude: 0, longitude: 0);
      expect(statusService.snapshot.zoneStatus, TouristZoneStatus.unknown);
      expect(statusService.snapshot.safetyIndicator, 'UNKNOWN');

      statusService.updateGpsStatus(TouristGpsStatus.unavailable);
      updateLocation(latitude: 0, longitude: 0, safeZone: safeZone);
      expect(statusService.snapshot.zoneStatus, TouristZoneStatus.unknown);
    });

    test(
      'retains the real latest coordinates, timestamp, and calculated distance',
      () {
        final updatedAt = DateTime.utc(2026, 10, 7, 12);
        statusService.updateLocation(
          latitude: 0.01,
          longitude: 0,
          updatedAt: updatedAt,
          safeZone: safeZone,
          dangerZones: const [],
          safeZoneService: geofenceService,
        );

        expect(statusService.snapshot.latitude, 0.01);
        expect(statusService.snapshot.longitude, 0);
        expect(statusService.snapshot.locationUpdatedAt, updatedAt);
        expect(statusService.snapshot.distanceToSafeZone, greaterThan(1000));
        expect(statusService.snapshot.hasLocation, isTrue);
      },
    );

    test(
      'bounded automatic retries stop at the limit and manual retry resets',
      () {
        final policy = GpsRetryPolicy(
          maxRetries: 3,
          initialDelay: const Duration(seconds: 2),
          maximumDelay: const Duration(seconds: 5),
        );

        expect(policy.nextDelay(), const Duration(seconds: 2));
        expect(policy.nextDelay(), const Duration(seconds: 4));
        expect(policy.nextDelay(), const Duration(seconds: 5));
        expect(policy.nextDelay(), isNull);
        expect(policy.exhausted, isTrue);

        policy.reset();
        expect(policy.exhausted, isFalse);
        expect(policy.nextDelay(), const Duration(seconds: 2));
      },
    );

    test('RETRY GPS invokes the active monitor retry handler', () async {
      var attempts = 0;
      final completion = Completer<void>();
      statusService.registerRetryHandler(() async {
        attempts++;
        await completion.future;
      });

      final firstRetry = statusService.retryGps();
      final secondRetry = statusService.retryGps();
      expect(identical(firstRetry, secondRetry), isTrue);
      expect(attempts, 1);
      completion.complete();
      await Future.wait([firstRetry, secondRetry]);

      expect(attempts, 1);
      statusService.registerRetryHandler(null);
    });

    testWidgets('renders live GPS, zone, location, distance, and retry UI', (
      tester,
    ) async {
      var retryCount = 0;
      statusService.registerRetryHandler(() async {
        retryCount++;
      });
      updateLocation(latitude: 0.01, longitude: 0, safeZone: safeZone);
      statusService.updateGpsStatus(TouristGpsStatus.unavailable);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TouristSafetyStatus())),
      );

      expect(find.text('Tourist Safety Status'), findsOneWidget);
      expect(find.text('GPS Status'), findsOneWidget);
      expect(find.text('UNAVAILABLE'), findsOneWidget);
      expect(find.text('Current Zone'), findsOneWidget);
      expect(find.text('UNKNOWN'), findsNWidgets(2));
      expect(find.text('LAST LOCATION'), findsOneWidget);
      expect(find.text('0.010000, 0.000000'), findsOneWidget);
      expect(find.textContaining('Updated 2026-10-07'), findsOneWidget);
      expect(find.text('Distance to Safe Zone'), findsOneWidget);
      expect(
        find.text('Unable to obtain your current location. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Retry GPS'), findsOneWidget);
      await tester.tap(find.text('Retry GPS'));
      await tester.pump();
      expect(retryCount, 1);
      statusService.registerRetryHandler(null);

      statusService.updateGpsStatus(TouristGpsStatus.active);
      updateLocation(latitude: 0.01, longitude: 0, safeZone: safeZone);
      await tester.pump();

      expect(find.text('OUTSIDE SAFE ZONE'), findsOneWidget);
      expect(find.text('1.1 km'), findsOneWidget);
      expect(find.text('DANGER'), findsOneWidget);
    });
  });
}

class _FakeLocationPermissionGateway implements LocationPermissionGateway {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.denied;
  LocationPermission requestResult = LocationPermission.denied;
  int checkCount = 0;
  int requestCount = 0;

  @override
  Future<LocationPermission> checkPermission() async {
    checkCount++;
    return permission;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> requestPermission() async {
    requestCount++;
    permission = requestResult;
    return requestResult;
  }
}
