import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/tourist_settings_model.dart';

abstract interface class TouristSettingsRepository {
  TouristSettingsModel get settings;

  Future<TouristSettingsModel> load({bool force = false});

  Future<void> save(TouristSetting setting, bool value);
}

class TouristSettingsService implements TouristSettingsRepository {
  TouristSettingsService._();

  static final TouristSettingsService shared = TouristSettingsService._();

  final StreamController<TouristSettingsModel> _controller =
      StreamController<TouristSettingsModel>.broadcast();
  TouristSettingsModel _settings = const TouristSettingsModel();
  Future<TouristSettingsModel>? _pendingLoad;
  bool _isLoaded = false;
  String? _loadedUserId;

  @override
  TouristSettingsModel get settings => _settings;
  bool get isLoaded => _isLoaded;
  Stream<TouristSettingsModel> get changes => _controller.stream;

  @override
  Future<TouristSettingsModel> load({bool force = false}) {
    final user = FirebaseAuth.instance.currentUser;
    if (_isLoaded && !force && user?.uid == _loadedUserId) {
      return Future.value(_settings);
    }
    if (_pendingLoad != null) return _pendingLoad!;

    if (user == null) {
      return Future.error(StateError('Sign in to load your settings.'));
    }

    final pending = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get()
        .then((document) {
          if (!document.exists) {
            throw StateError('Your tourist profile could not be found.');
          }
          final data = document.data();
          _settings = TouristSettingsModel.fromMap(data?['settings']);
          _isLoaded = true;
          _loadedUserId = user.uid;
          _publish();
          return _settings;
        });
    _pendingLoad = pending;
    return pending.whenComplete(() => _pendingLoad = null);
  }

  @override
  Future<void> save(TouristSetting setting, bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Sign in to update your settings.');
    }
    if (!_isLoaded || _loadedUserId != user.uid) await load();

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'settings.${setting.fieldPath}': value,
    });
    _settings = _withSetting(_settings, setting, value);
    _publish();
  }

  Future<bool> isNotificationEnabled(
    TouristNotificationCategory category,
  ) async {
    await load();
    return switch (category) {
      TouristNotificationCategory.safety => _settings.safetyNotifications,
      TouristNotificationCategory.sos => _settings.sosNotifications,
      TouristNotificationCategory.admin => _settings.adminNotifications,
    };
  }

  Future<void> reload() async {
    await load(force: true);
  }

  void _publish() {
    if (!_controller.isClosed) _controller.add(_settings);
  }

  TouristSettingsModel _withSetting(
    TouristSettingsModel settings,
    TouristSetting setting,
    bool value,
  ) {
    return switch (setting) {
      TouristSetting.safetyNotifications => settings.copyWith(
        safetyNotifications: value,
      ),
      TouristSetting.sosNotifications => settings.copyWith(
        sosNotifications: value,
      ),
      TouristSetting.adminNotifications => settings.copyWith(
        adminNotifications: value,
      ),
      TouristSetting.profileVisibility => settings.copyWith(
        profileVisibility: value,
      ),
      TouristSetting.locationSharing => settings.copyWith(
        locationSharing: value,
      ),
      TouristSetting.locationTracking => settings.copyWith(
        locationTracking: value,
      ),
      TouristSetting.backgroundLocation => settings.copyWith(
        backgroundLocation: value,
      ),
      TouristSetting.sosConfirmation => settings.copyWith(
        sosConfirmation: value,
      ),
      TouristSetting.emergencyContactNotification => settings.copyWith(
        emergencyContactNotification: value,
      ),
    };
  }
}
