import 'package:flutter/foundation.dart';

@immutable
class TouristSettingsModel {
  const TouristSettingsModel({
    this.safetyNotifications = true,
    this.sosNotifications = true,
    this.adminNotifications = true,
    this.profileVisibility = true,
    this.locationSharing = true,
    this.locationTracking = true,
    this.backgroundLocation = false,
    this.sosConfirmation = true,
    this.emergencyContactNotification = true,
  });

  final bool safetyNotifications;
  final bool sosNotifications;
  final bool adminNotifications;
  final bool profileVisibility;
  final bool locationSharing;
  final bool locationTracking;
  final bool backgroundLocation;
  final bool sosConfirmation;
  final bool emergencyContactNotification;

  bool get effectiveLocationTracking => locationSharing && locationTracking;

  factory TouristSettingsModel.fromMap(Object? value) {
    final settings = value is Map ? value : const {};
    final notifications = _group(settings, 'notifications');
    final privacy = _group(settings, 'privacy');
    final location = _group(settings, 'location');
    final emergency = _group(settings, 'emergency');
    return TouristSettingsModel(
      safetyNotifications: _readBool(
        notifications['safetyNotifications'],
        true,
      ),
      sosNotifications: _readBool(notifications['sosNotifications'], true),
      adminNotifications: _readBool(notifications['adminNotifications'], true),
      profileVisibility: _readBool(privacy['profileVisibility'], true),
      locationSharing: _readBool(privacy['locationSharing'], true),
      locationTracking: _readBool(location['locationTracking'], true),
      backgroundLocation: _readBool(location['backgroundLocation'], false),
      sosConfirmation: _readBool(emergency['sosConfirmation'], true),
      emergencyContactNotification: _readBool(
        emergency['emergencyContactNotification'],
        true,
      ),
    );
  }

  Map<String, Object> toMap() => {
    'notifications': {
      'safetyNotifications': safetyNotifications,
      'sosNotifications': sosNotifications,
      'adminNotifications': adminNotifications,
    },
    'privacy': {
      'profileVisibility': profileVisibility,
      'locationSharing': locationSharing,
    },
    'location': {
      'locationTracking': locationTracking,
      'backgroundLocation': backgroundLocation,
    },
    'emergency': {
      'sosConfirmation': sosConfirmation,
      'emergencyContactNotification': emergencyContactNotification,
    },
  };

  TouristSettingsModel copyWith({
    bool? safetyNotifications,
    bool? sosNotifications,
    bool? adminNotifications,
    bool? profileVisibility,
    bool? locationSharing,
    bool? locationTracking,
    bool? backgroundLocation,
    bool? sosConfirmation,
    bool? emergencyContactNotification,
  }) {
    return TouristSettingsModel(
      safetyNotifications: safetyNotifications ?? this.safetyNotifications,
      sosNotifications: sosNotifications ?? this.sosNotifications,
      adminNotifications: adminNotifications ?? this.adminNotifications,
      profileVisibility: profileVisibility ?? this.profileVisibility,
      locationSharing: locationSharing ?? this.locationSharing,
      locationTracking: locationTracking ?? this.locationTracking,
      backgroundLocation: backgroundLocation ?? this.backgroundLocation,
      sosConfirmation: sosConfirmation ?? this.sosConfirmation,
      emergencyContactNotification:
          emergencyContactNotification ?? this.emergencyContactNotification,
    );
  }

  static Map _group(Map settings, String key) {
    final value = settings[key];
    return value is Map ? value : const {};
  }

  static bool _readBool(Object? value, bool fallback) =>
      value is bool ? value : fallback;
}

enum TouristSetting {
  safetyNotifications('notifications.safetyNotifications'),
  sosNotifications('notifications.sosNotifications'),
  adminNotifications('notifications.adminNotifications'),
  profileVisibility('privacy.profileVisibility'),
  locationSharing('privacy.locationSharing'),
  locationTracking('location.locationTracking'),
  backgroundLocation('location.backgroundLocation'),
  sosConfirmation('emergency.sosConfirmation'),
  emergencyContactNotification('emergency.emergencyContactNotification');

  const TouristSetting(this.fieldPath);

  final String fieldPath;
}

enum TouristNotificationCategory { safety, sos, admin }

bool shouldSurfaceNotification(
  String type,
  TouristSettingsModel settings,
) {
  switch (type.toLowerCase()) {
    case 'safe_zone':
    case 'danger_zone':
    case 'zone_exit':
      return settings.safetyNotifications;
    case 'sos':
    case 'sos_acknowledged':
    case 'sos_resolved':
      return settings.sosNotifications;
    case 'admin':
      return settings.adminNotifications;
    default:
      return true;
  }
}
