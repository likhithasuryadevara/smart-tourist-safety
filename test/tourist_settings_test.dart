import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_tourist_safety/models/tourist_settings_model.dart';
import 'package:smart_tourist_safety/screens/tourist_settings_screen.dart';
import 'package:smart_tourist_safety/services/tourist_settings_service.dart';

void main() {
  group('TouristSettingsModel', () {
    test('uses safe defaults for absent and malformed preference values', () {
      final missing = TouristSettingsModel.fromMap(null);
      final malformed = TouristSettingsModel.fromMap({
        'notifications': {
          'safetyNotifications': 'false',
          'sosNotifications': false,
        },
        'privacy': null,
        'location': {'locationTracking': 0},
      });

      expect(missing.safetyNotifications, isTrue);
      expect(missing.sosNotifications, isTrue);
      expect(missing.backgroundLocation, isFalse);
      expect(malformed.safetyNotifications, isTrue);
      expect(malformed.sosNotifications, isFalse);
      expect(malformed.profileVisibility, isTrue);
      expect(malformed.locationTracking, isTrue);
    });

    test('round-trips all settings groups and computes effective tracking', () {
      const settings = TouristSettingsModel(
        safetyNotifications: false,
        profileVisibility: false,
        locationSharing: false,
        locationTracking: true,
        emergencyContactNotification: false,
      );

      final decoded = TouristSettingsModel.fromMap(settings.toMap());

      expect(decoded.safetyNotifications, isFalse);
      expect(decoded.profileVisibility, isFalse);
      expect(decoded.locationSharing, isFalse);
      expect(decoded.effectiveLocationTracking, isFalse);
      expect(decoded.emergencyContactNotification, isFalse);
    });

    test('notification preferences filter matching categories', () {
      const settings = TouristSettingsModel(
        safetyNotifications: false,
        sosNotifications: true,
        adminNotifications: false,
      );

      expect(shouldSurfaceNotification('safe_zone', settings), isFalse);
      expect(shouldSurfaceNotification('danger_zone', settings), isFalse);
      expect(shouldSurfaceNotification('sos', settings), isTrue);
      expect(shouldSurfaceNotification('admin', settings), isFalse);
      expect(shouldSurfaceNotification('general', settings), isTrue);
    });
  });

  testWidgets(
    'settings sections render and changes persist through repository',
    (tester) async {
      final repository = _FakeSettingsRepository();
      await tester.binding.setSurfaceSize(const Size(360, 900));

      await tester.pumpWidget(
        MaterialApp(
          home: TouristSettingsScreen(settingsRepository: repository),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('NOTIFICATION SETTINGS'), findsOneWidget);
      expect(find.text('PRIVACY SETTINGS'), findsOneWidget);
      expect(find.text('LOCATION SETTINGS'), findsOneWidget);
      expect(find.text('EMERGENCY PREFERENCES'), findsOneWidget);
      expect(find.text('Safety Notifications'), findsOneWidget);
      expect(find.text('SOS Notifications'), findsOneWidget);
      expect(find.text('Admin Notifications'), findsOneWidget);
      expect(find.text('Profile Visibility'), findsOneWidget);
      expect(find.text('Location Sharing'), findsOneWidget);
      expect(find.text('Location Tracking'), findsOneWidget);
      expect(find.text('Background Location'), findsOneWidget);
      expect(find.text('SOS Confirmation'), findsOneWidget);
      expect(find.text('Emergency Contact Notification'), findsOneWidget);
      expect(find.textContaining('Not supported'), findsOneWidget);

      await tester.tap(find.byType(SwitchListTile).first);
      await tester.pumpAndSettle();
      expect(repository.settings.safetyNotifications, isFalse);
      expect(
        repository.savedSettings,
        contains(TouristSetting.safetyNotifications),
      );

      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      await tester.pumpWidget(
        MaterialApp(
          home: TouristSettingsScreen(settingsRepository: repository),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('load failure offers a working retry', (tester) async {
    final repository = _FakeSettingsRepository()..failNextLoad = true;
    await tester.pumpWidget(
      MaterialApp(home: TouristSettingsScreen(settingsRepository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unable to load settings.'), findsOneWidget);
    await tester.tap(find.text('RETRY'));
    await tester.pumpAndSettle();
    expect(find.text('NOTIFICATION SETTINGS'), findsOneWidget);
    expect(repository.loadCount, 2);
  });

  testWidgets('save failure restores the prior preference', (tester) async {
    final repository = _FakeSettingsRepository()..failSaves = true;
    await tester.pumpWidget(
      MaterialApp(home: TouristSettingsScreen(settingsRepository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    expect(repository.settings.safetyNotifications, isTrue);
    expect(
      find.text('Unable to save setting. Please try again.'),
      findsOneWidget,
    );
  });
}

class _FakeSettingsRepository implements TouristSettingsRepository {
  TouristSettingsModel _settings = const TouristSettingsModel();
  final savedSettings = <TouristSetting>[];
  int loadCount = 0;
  bool failNextLoad = false;
  bool failSaves = false;

  @override
  TouristSettingsModel get settings => _settings;

  @override
  Future<TouristSettingsModel> load({bool force = false}) async {
    loadCount++;
    if (failNextLoad) {
      failNextLoad = false;
      throw StateError('read failed');
    }
    return _settings;
  }

  @override
  Future<void> save(TouristSetting setting, bool value) async {
    if (failSaves) throw StateError('write failed');
    savedSettings.add(setting);
    _settings = switch (setting) {
      TouristSetting.safetyNotifications => _settings.copyWith(
        safetyNotifications: value,
      ),
      TouristSetting.sosNotifications => _settings.copyWith(
        sosNotifications: value,
      ),
      TouristSetting.adminNotifications => _settings.copyWith(
        adminNotifications: value,
      ),
      TouristSetting.profileVisibility => _settings.copyWith(
        profileVisibility: value,
      ),
      TouristSetting.locationSharing => _settings.copyWith(
        locationSharing: value,
      ),
      TouristSetting.locationTracking => _settings.copyWith(
        locationTracking: value,
      ),
      TouristSetting.backgroundLocation => _settings.copyWith(
        backgroundLocation: value,
      ),
      TouristSetting.sosConfirmation => _settings.copyWith(
        sosConfirmation: value,
      ),
      TouristSetting.emergencyContactNotification => _settings.copyWith(
        emergencyContactNotification: value,
      ),
    };
  }
}
