enum TouristHistoryType {
  sos,
  safeZone,
  dangerZone,
}

enum TouristHistoryFilter {
  all,
  sos,
  safeZone,
  dangerZone,
  geofence,
  emergency,
}

class TouristHistoryEvent {
  final String id;
  final TouristHistoryType type;
  final String title;
  final String status;
  final DateTime? occurredAt;
  final double? latitude;
  final double? longitude;
  final String source;
  final String? description;
  final Map<String, dynamic>? sosData;

  const TouristHistoryEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.status,
    required this.occurredAt,
    required this.latitude,
    required this.longitude,
    required this.source,
    this.description,
    this.sosData,
  });

  String get typeLabel {
    switch (type) {
      case TouristHistoryType.sos:
        return 'SOS';
      case TouristHistoryType.safeZone:
        return 'Safe Zone';
      case TouristHistoryType.dangerZone:
        return 'Danger Zone';
    }
  }

  bool matches(TouristHistoryFilter filter) {
    switch (filter) {
      case TouristHistoryFilter.all:
        return true;
      case TouristHistoryFilter.sos:
      case TouristHistoryFilter.emergency:
        return type == TouristHistoryType.sos;
      case TouristHistoryFilter.safeZone:
        return type == TouristHistoryType.safeZone;
      case TouristHistoryFilter.dangerZone:
        return type == TouristHistoryType.dangerZone;
      case TouristHistoryFilter.geofence:
        return type == TouristHistoryType.safeZone ||
            type == TouristHistoryType.dangerZone;
    }
  }
}
