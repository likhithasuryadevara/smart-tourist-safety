import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:smart_tourist_safety/services/safe_zone_service.dart';
import 'package:smart_tourist_safety/utils/geographic_validation.dart';

void main() {
  group('Zone model parsing', () {
    test('parses numeric coordinates and available metadata', () {
      final safeZone = SafeZone.fromData({
        'latitude': 16,
        'longitude': 80.5,
        'radius': 250,
        'name': '  Central zone ',
        'description': '  Monitored area ',
      }, id: 'safe-1');

      expect(safeZone.id, 'safe-1');
      expect(safeZone.latitude, 16);
      expect(safeZone.longitude, 80.5);
      expect(safeZone.radius, 250);
      expect(safeZone.name, 'Central zone');
      expect(safeZone.description, 'Monitored area');

      final dangerZone = DangerZone.fromData('danger-1', {
        'latitude': 16,
        'longitude': 80.5,
        'radius': 100,
        'name': 'Danger area',
        'dangerLevel': 'High',
        'warningMessage': 'Stay away',
      });
      expect(dangerZone.name, 'Danger area');
      expect(dangerZone.dangerLevel, 'High');
      expect(dangerZone.warningMessage, 'Stay away');
    });

    test('omits malformed optional metadata without inventing values', () {
      final zone = DangerZone.fromData('danger-1', {
        'latitude': 0,
        'longitude': 0,
        'radius': 0,
        'name': 42,
        'description': '  ',
      });

      expect(zone.name, isNull);
      expect(zone.description, isNull);
      expect(zone.radius, 0);
    });

    test(
      'parses integer and double Firestore numeric values and observed fields',
      () {
        final safeZoneInt = SafeZone.fromData({
          'latitude': 16,
          'longitude': 80,
          'radius': 15,
          'name': 'Home',
          'type': 'Home',
          'status': 'enabled',
        }, id: 'safe-home');
        expect(safeZoneInt.id, 'safe-home');
        expect(safeZoneInt.latitude, 16.0);
        expect(safeZoneInt.longitude, 80.0);
        expect(safeZoneInt.radius, 15.0);
        expect(safeZoneInt.type, 'Home');
        expect(safeZoneInt.status, 'enabled');

        final dangerZoneObserved = DangerZone.fromData('suzuki-1', {
          'latitude': 16.517857398331373,
          'longitude': 80.64739441811022,
          'radius': 7,
          'name': 'Suzuki Showroom',
          'dangerLevel': 'Low',
          'warningMessage': 'you are near suzuki showroom',
          'status': 'disabled',
        });
        expect(dangerZoneObserved.latitude, 16.517857398331373);
        expect(dangerZoneObserved.longitude, 80.64739441811022);
        expect(dangerZoneObserved.radius, 7.0);
        expect(dangerZoneObserved.name, 'Suzuki Showroom');
        expect(dangerZoneObserved.dangerLevel, 'Low');
        expect(
          dangerZoneObserved.warningMessage,
          'you are near suzuki showroom',
        );
        expect(dangerZoneObserved.status, 'disabled');
      },
    );

    test('rejects missing, malformed, non-finite, or out-of-range data', () {
      final invalidDocuments = <Map<String, Object?>>[
        {'longitude': 0, 'radius': 1},
        {'latitude': '0', 'longitude': 0, 'radius': 1},
        {'latitude': 91, 'longitude': 0, 'radius': 1},
        {'latitude': 0, 'longitude': -181, 'radius': 1},
        {'latitude': double.nan, 'longitude': 0, 'radius': 1},
        {'latitude': 0, 'longitude': double.infinity, 'radius': 1},
        {'latitude': 0, 'longitude': 0, 'radius': -1},
        {'latitude': 0, 'longitude': 0, 'radius': double.infinity},
        {'latitude': 0, 'longitude': 0, 'radius': '50'},
      ];

      for (final document in invalidDocuments) {
        expect(
          () => SafeZone.fromData(document),
          throwsFormatException,
          reason: 'Expected invalid zone data to be rejected: $document',
        );
      }
    });
  });

  group('Zone list parsing and malformed document isolation', () {
    test('empty list returns empty without error', () {
      expect(SafeZoneService.parseSafeZoneList([]), isEmpty);
      expect(SafeZoneService.parseDangerZoneList([]), isEmpty);
    });

    test('one malformed safe zone does not crash valid zones in the list', () {
      final documents = [
        MapEntry('valid-1', <String, dynamic>{
          'latitude': 16.5,
          'longitude': 80.5,
          'radius': 100,
          'name': 'Valid Safe Zone',
        }),
        MapEntry('invalid-1', <String, dynamic>{
          'latitude': 999.0, // invalid out-of-range
          'longitude': 80.5,
          'radius': 100,
        }),
      ];

      final parsed = SafeZoneService.parseSafeZoneList(documents);
      expect(parsed, hasLength(1));
      expect(parsed.single.id, 'valid-1');
      expect(parsed.single.name, 'Valid Safe Zone');
    });

    test('all malformed safe zones throw FormatException to distinguish error from empty', () {
      final documents = [
        MapEntry('invalid-1', <String, dynamic>{
          'latitude': 999.0,
          'longitude': 80.5,
          'radius': 100,
        }),
        MapEntry('invalid-2', <String, dynamic>{
          'latitude': 16.5,
          'longitude': 80.5,
          'radius': -50,
        }),
      ];

      expect(
        () => SafeZoneService.parseSafeZoneList(documents),
        throwsFormatException,
      );
    });

    test(
      'one malformed danger zone does not crash valid zones in the list',
      () {
        final documents = [
          MapEntry('danger-valid', <String, dynamic>{
            'latitude': 16.5,
            'longitude': 80.5,
            'radius': 50,
            'name': 'Valid Danger Zone',
          }),
          MapEntry('danger-invalid', <String, dynamic>{
            'latitude': double.nan,
            'longitude': 80.5,
            'radius': 50,
          }),
        ];

        final parsed = SafeZoneService.parseDangerZoneList(documents);
        expect(parsed, hasLength(1));
        expect(parsed.single.id, 'danger-valid');
        expect(parsed.single.name, 'Valid Danger Zone');
      },
    );

    test('all malformed danger zones throw FormatException', () {
      final documents = [
        MapEntry('invalid-1', <String, dynamic>{
          'latitude': 16.5,
          'longitude': double.infinity,
          'radius': 10,
        }),
      ];

      expect(
        () => SafeZoneService.parseDangerZoneList(documents),
        throwsFormatException,
      );
    });
  });

  group('Geographic validation and distance', () {
    final service = SafeZoneService();

    test('accepts valid geographic bounds and rejects invalid coordinates', () {
      expect(isValidCoordinate(-90, -180), isTrue);
      expect(isValidCoordinate(90, 180), isTrue);
      expect(isValidCoordinate(0, 0), isTrue);
      expect(isValidCoordinate(null, 0), isFalse);
      expect(isValidCoordinate(0, null), isFalse);
      expect(isValidCoordinate(90.01, 0), isFalse);
      expect(isValidCoordinate(0, -180.01), isFalse);
      expect(isValidCoordinate(double.nan, 0), isFalse);
      expect(isValidCoordinate(0, double.infinity), isFalse);
    });

    test('radius is finite and non-negative; zero remains a point radius', () {
      expect(isValidRadius(0), isTrue);
      expect(isValidRadius(100), isTrue);
      expect(isValidRadius(-0.1), isFalse);
      expect(isValidRadius(double.nan), isFalse);
      expect(isValidRadius(double.infinity), isFalse);
    });

    test('inside, outside, and exact boundary use meters consistently', () {
      const latitude = 0.001;
      final boundaryMeters = Geolocator.distanceBetween(0, 0, latitude, 0);
      final zone = SafeZone(latitude: 0, longitude: 0, radius: boundaryMeters);

      expect(
        service.calculateDistance(
          touristLatitude: 0,
          touristLongitude: 0,
          safeZone: zone,
        ),
        0,
      );
      // Exactly on boundary is inside
      expect(
        service.isInsideSafeZone(
          touristLatitude: latitude,
          touristLongitude: 0,
          safeZone: zone,
        ),
        isTrue,
      );
      // Past boundary is outside
      expect(
        service.isInsideSafeZone(
          touristLatitude: latitude + 0.0001,
          touristLongitude: 0,
          safeZone: zone,
        ),
        isFalse,
      );
    });

    test('zero radius point behavior: exact center is inside, any offset is outside', () {
      final pointZone = SafeZone(latitude: 16.0, longitude: 80.0, radius: 0);
      expect(
        service.isInsideSafeZone(
          touristLatitude: 16.0,
          touristLongitude: 80.0,
          safeZone: pointZone,
        ),
        isTrue,
      );
      expect(
        service.isInsideSafeZone(
          touristLatitude: 16.0001,
          touristLongitude: 80.0,
          safeZone: pointZone,
        ),
        isFalse,
      );
    });

    test('overlapping safe and danger zones evaluate independently and consistently', () {
      final safe = SafeZone(latitude: 16.0, longitude: 80.0, radius: 500);
      final danger = DangerZone(
        id: 'overlap-danger',
        latitude: 16.0,
        longitude: 80.0,
        radius: 100,
      );

      // Tourist at (16.0, 80.0) is inside both
      expect(
        service.isInsideSafeZone(
          touristLatitude: 16.0,
          touristLongitude: 80.0,
          safeZone: safe,
        ),
        isTrue,
      );
      expect(
        service.isInsideDangerZone(
          touristLatitude: 16.0,
          touristLongitude: 80.0,
          dangerZone: danger,
        ),
        isTrue,
      );

      // Tourist at 200m away is inside safe but outside danger
      const offsetLat = 16.0018; // approx 200m
      expect(
        service.isInsideSafeZone(
          touristLatitude: offsetLat,
          touristLongitude: 80.0,
          safeZone: safe,
        ),
        isTrue,
      );
      expect(
        service.isInsideDangerZone(
          touristLatitude: offsetLat,
          touristLongitude: 80.0,
          dangerZone: danger,
        ),
        isFalse,
      );
    });

    test('rejects invalid location, zone coordinate, or radius', () {
      expect(
        () => service.calculateDistance(
          touristLatitude: 91,
          touristLongitude: 0,
          safeZone: SafeZone(latitude: 0, longitude: 0, radius: 10),
        ),
        throwsArgumentError,
      );
      expect(
        () => service.isInsideDangerZone(
          touristLatitude: 0,
          touristLongitude: 0,
          dangerZone: DangerZone(
            id: 'invalid',
            latitude: 0,
            longitude: 0,
            radius: -1,
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  group('Geofence transition tracking', () {
    test(
      'first fix is a baseline; repeated inside updates do not duplicate',
      () {
        final tracker = ZoneTransitionTracker();

        expect(tracker.update({'safe': true, 'danger': true}), isEmpty);
        expect(tracker.update({'safe': true, 'danger': true}), isEmpty);
        expect(tracker.update({'safe': true, 'danger': false}), hasLength(1));
        expect(tracker.update({'safe': true, 'danger': false}), isEmpty);
      },
    );

    test(
      'entry, exit, and re-entry are emitted once per actual transition',
      () {
        final tracker = ZoneTransitionTracker();

        expect(tracker.update({'zone': false}), isEmpty);
        final entry = tracker.update({'zone': true});
        expect(entry, hasLength(1));
        expect(entry.single.zoneId, 'zone');
        expect(entry.single.entered, isTrue);

        expect(tracker.update({'zone': true}), isEmpty);
        final exit = tracker.update({'zone': false});
        expect(exit, hasLength(1));
        expect(exit.single.entered, isFalse);

        final reentry = tracker.update({'zone': true});
        expect(reentry, hasLength(1));
        expect(reentry.single.entered, isTrue);
      },
    );

    test('multiple overlapping zones transition independently', () {
      final tracker = ZoneTransitionTracker();

      // Establish baseline in 3 zones
      expect(
        tracker.update({'safe-1': true, 'safe-2': true, 'danger-1': true}),
        isEmpty,
      );

      // Exits safe-2 only
      final exitSafe2 = tracker.update({
        'safe-1': true,
        'safe-2': false,
        'danger-1': true,
      });
      expect(exitSafe2, hasLength(1));
      expect(exitSafe2.single.zoneId, 'safe-2');
      expect(exitSafe2.single.entered, isFalse);

      // Exits both remaining zones
      final exitAll = tracker.update({
        'safe-1': false,
        'safe-2': false,
        'danger-1': false,
      });
      expect(exitAll, hasLength(2));
      final exitedIds = exitAll.map((t) => t.zoneId).toSet();
      expect(exitedIds, {'safe-1', 'danger-1'});

      // Re-enters safe-1 and safe-2
      final reenter = tracker.update({
        'safe-1': true,
        'safe-2': true,
        'danger-1': false,
      });
      expect(reenter, hasLength(2));
      expect(reenter.every((t) => t.entered), isTrue);
    });

    test('reset after unavailable location makes the next fix a baseline', () {
      final tracker = ZoneTransitionTracker();
      tracker.update({'zone': false});
      tracker.reset();

      expect(tracker.update({'zone': true}), isEmpty);
      expect(tracker.update({'zone': true}), isEmpty);
    });
  });

  group('geo_fence_alerts contract and payload building', () {
    test(
      'builds valid ENTER and EXIT alert payloads with all required fields',
      () {
        const timestamp = '2026-10-10T12:00:00Z';
        final enterPayload = SafeZoneService.buildGeoFenceAlertPayload(
          userId: 'tourist-101',
          userName: 'John Doe',
          userEmail: 'john@example.com',
          safeZoneId: 'home-safe-1',
          safeZoneName: 'Home',
          eventType: 'ENTER',
          latitude: 16.51747554280894,
          longitude: 80.64728468653634,
          timestamp: timestamp,
          status: 'Unread',
          zoneType: 'Safe',
        );

        expect(enterPayload['userId'], 'tourist-101');
        expect(enterPayload['userName'], 'John Doe');
        expect(enterPayload['userEmail'], 'john@example.com');
        expect(enterPayload['safeZoneId'], 'home-safe-1');
        expect(enterPayload['safeZoneName'], 'Home');
        expect(enterPayload['eventType'], 'ENTER');
        expect(enterPayload['latitude'], 16.51747554280894);
        expect(enterPayload['longitude'], 80.64728468653634);
        expect(enterPayload['timestamp'], timestamp);
        expect(enterPayload['status'], 'Unread');
        expect(enterPayload['zoneType'], 'Safe');

        final exitPayload = SafeZoneService.buildGeoFenceAlertPayload(
          userId: 'tourist-101',
          userName: 'John Doe',
          userEmail: 'john@example.com',
          safeZoneId: 'danger-suzuki',
          safeZoneName: 'Suzuki Showroom',
          eventType: 'EXIT',
          latitude: 16.517857398331373,
          longitude: 80.64739441811022,
          timestamp: timestamp,
          status: 'Read',
          zoneType: 'Danger',
        );

        expect(exitPayload['eventType'], 'EXIT');
        expect(exitPayload['status'], 'Read');
        expect(exitPayload['zoneType'], 'Danger');
      },
    );

    test('rejects invalid eventType, status, coordinates, and zoneType', () {
      const timestamp = '2026-10-10T12:00:00Z';

      // Rejects invalid eventType
      expect(
        () => SafeZoneService.buildGeoFenceAlertPayload(
          userId: 'u1',
          userName: 'Name',
          userEmail: 'email',
          safeZoneId: 'z1',
          safeZoneName: 'Zone',
          eventType: 'enter', // must be exactly 'ENTER'
          latitude: 0,
          longitude: 0,
          timestamp: timestamp,
        ),
        throwsArgumentError,
      );

      expect(
        () => SafeZoneService.buildGeoFenceAlertPayload(
          userId: 'u1',
          userName: 'Name',
          userEmail: 'email',
          safeZoneId: 'z1',
          safeZoneName: 'Zone',
          eventType: 'EXIT_ZONE',
          latitude: 0,
          longitude: 0,
          timestamp: timestamp,
        ),
        throwsArgumentError,
      );

      // Rejects invalid status
      expect(
        () => SafeZoneService.buildGeoFenceAlertPayload(
          userId: 'u1',
          userName: 'Name',
          userEmail: 'email',
          safeZoneId: 'z1',
          safeZoneName: 'Zone',
          eventType: 'ENTER',
          latitude: 0,
          longitude: 0,
          timestamp: timestamp,
          status: 'Pending',
        ),
        throwsArgumentError,
      );

      // Rejects invalid coordinates
      expect(
        () => SafeZoneService.buildGeoFenceAlertPayload(
          userId: 'u1',
          userName: 'Name',
          userEmail: 'email',
          safeZoneId: 'z1',
          safeZoneName: 'Zone',
          eventType: 'ENTER',
          latitude: 91,
          longitude: 0,
          timestamp: timestamp,
        ),
        throwsArgumentError,
      );

      // Rejects invalid zoneType
      expect(
        () => SafeZoneService.buildGeoFenceAlertPayload(
          userId: 'u1',
          userName: 'Name',
          userEmail: 'email',
          safeZoneId: 'z1',
          safeZoneName: 'Zone',
          eventType: 'ENTER',
          latitude: 0,
          longitude: 0,
          timestamp: timestamp,
          zoneType: 'InvalidType',
        ),
        throwsArgumentError,
      );
    });

    test(
      'zone radius in meters compared without conversion (distance <= radius)',
      () {
        final safeZone = SafeZone(
          id: 'home',
          latitude: 16.51747554280894,
          longitude: 80.64728468653634,
          radius: 15, // exactly 15 meters
        );

        final service = SafeZoneService();

        // Exactly at center: distance = 0 <= 15
        expect(
          service.isInsideSafeZone(
            touristLatitude: 16.51747554280894,
            touristLongitude: 80.64728468653634,
            safeZone: safeZone,
          ),
          isTrue,
        );

        // Point within 15 meters:
        // ~0.0001 deg lat is approx 11.1 meters
        expect(
          service.isInsideSafeZone(
            touristLatitude: 16.51747554280894 + 0.0001,
            touristLongitude: 80.64728468653634,
            safeZone: safeZone,
          ),
          isTrue,
        );

        // Point beyond 15 meters:
        // ~0.0002 deg lat is approx 22.2 meters
        expect(
          service.isInsideSafeZone(
            touristLatitude: 16.51747554280894 + 0.0002,
            touristLongitude: 80.64728468653634,
            safeZone: safeZone,
          ),
          isFalse,
        );
      },
    );

    test(
      'recordGeoFenceAlert returns null safely when unauthenticated',
      () async {
        final service = SafeZoneService();
        final result = await service.recordGeoFenceAlert(
          zoneId: 'safe-1',
          zoneName: 'Home',
          eventType: 'ENTER',
          latitude: 16.5174,
          longitude: 80.6472,
          zoneType: 'Safe',
        );
        expect(result, isNull);
      },
    );
  });
}
