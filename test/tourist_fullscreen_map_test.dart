import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:smart_tourist_safety/screens/tourist_fullscreen_map_screen.dart';
import 'package:smart_tourist_safety/services/location_service.dart';
import 'package:smart_tourist_safety/services/safe_zone_service.dart';
import 'package:smart_tourist_safety/services/safe_zone_status_service.dart';

class _FakeSafeZoneService extends SafeZoneService {
  _FakeSafeZoneService({
    this.safeZones = const [],
    this.dangerZones = const [],
    this.failure,
  });

  final List<SafeZone> safeZones;
  final List<DangerZone> dangerZones;
  final Object? failure;
  int safeZoneRequests = 0;
  int dangerZoneRequests = 0;

  @override
  Future<List<SafeZone>> getActiveSafeZones() async {
    safeZoneRequests++;
    if (failure != null) throw failure!;
    return safeZones;
  }

  @override
  Future<List<DangerZone>> getActiveDangerZones() async {
    dangerZoneRequests++;
    if (failure != null) throw failure!;
    return dangerZones;
  }
}

class _FakeLocationService extends LocationService {
  _FakeLocationService({this.position});

  final Position? position;
  int currentLocationRequests = 0;

  @override
  Future<Position?> getCurrentLocation() async {
    currentLocationRequests++;
    return position;
  }
}

final _touristLocation = Position(
  latitude: 16.4854,
  longitude: 80.6916,
  timestamp: DateTime.now(),
  accuracy: 0,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void _publishTouristLocation() {
  final statusService = SafeZoneStatusService();
  statusService.updateGpsStatus(TouristGpsStatus.active);
  statusService.updateLocation(
    latitude: 16.4854,
    longitude: 80.6916,
    updatedAt: DateTime.now(),
    dangerZones: const [],
    safeZoneService: SafeZoneService(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('full-screen map fills the screen with map controls and status', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    final safeZoneService = _FakeSafeZoneService(
      safeZones: [
        SafeZone(
          id: 'zone_1',
          name: 'Temple Zone',
          latitude: 16.4854,
          longitude: 80.6916,
          radius: 120,
        ),
      ],
      dangerZones: [
        DangerZone(
          id: 'zone_2',
          name: 'River Bend',
          dangerLevel: 'high',
          latitude: 16.4954,
          longitude: 80.705,
          radius: 100,
        ),
      ],
    );
    _publishTouristLocation();

    await tester.pumpWidget(
      MaterialApp(
        home: TouristFullScreenMapScreen(
          safeZoneService: safeZoneService,
          locationService: _FakeLocationService(position: _touristLocation),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('Live Safety Map'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.remove), findsOneWidget);
    expect(find.byIcon(Icons.my_location), findsOneWidget);
    expect(tester.takeException(), isNull);

    final mapRect = tester.getRect(find.byType(FlutterMap));
    expect(mapRect.width, equals(400));
    expect(mapRect.height, equals(800));

    expect(find.text('Live location 16.4854, 80.6916'), findsOneWidget);
    expect(find.text('Map data © OpenStreetMap'), findsOneWidget);
    expect(find.text('Safe zone'), findsWidgets);
    expect(find.text('Inside Safe Zone'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.my_location));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byIcon(Icons.center_focus_strong), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('zone load failure shows a retry banner that reloads the zones', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    final safeZoneService = _FakeSafeZoneService(
      failure: Exception('simulated offline failure'),
    );
    SafeZoneStatusService().updateGpsStatus(TouristGpsStatus.unavailable);

    await tester.pumpWidget(
      MaterialApp(
        home: TouristFullScreenMapScreen(
          safeZoneService: safeZoneService,
          locationService: _FakeLocationService(position: null),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(safeZoneService.safeZoneRequests, 1);
    expect(safeZoneService.dangerZoneRequests, 1);
    expect(find.text('Unable to load safe zone information.'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'RETRY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(safeZoneService.safeZoneRequests, 2);
    expect(safeZoneService.dangerZoneRequests, 2);
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('locate button shows a clear message when location is missing', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    final locationService = _FakeLocationService(position: null);
    SafeZoneStatusService().updateGpsStatus(TouristGpsStatus.permissionDenied);

    await tester.pumpWidget(
      MaterialApp(
        home: TouristFullScreenMapScreen(
          safeZoneService: _FakeSafeZoneService(),
          locationService: locationService,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text('Location permission is needed to show your current location.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, 'LOCATE ME'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(locationService.currentLocationRequests, 1);
    expect(
      find.text(
        'Unable to get your current location. Check that location permission '
        'is granted and try again.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });
}
