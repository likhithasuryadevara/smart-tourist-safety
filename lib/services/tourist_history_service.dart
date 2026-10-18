import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/tourist_history_model.dart';

class TouristHistoryService {
  final FirebaseFirestore _firestore;

  TouristHistoryService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> watchSosHistory(
    String touristId,
  ) {
    return _firestore
        .collection('sos_alerts')
        .where('userId', isEqualTo: touristId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchGeoFenceHistory(
    String touristId,
  ) {
    return _firestore
        .collection('geo_fence_alerts')
        .where('userId', isEqualTo: touristId)
        .snapshots();
  }

  List<TouristHistoryEvent> combineHistory({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> sosDocuments,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>>
    geoFenceDocuments,
  }) {
    final events = <TouristHistoryEvent>[
      for (final document in sosDocuments) _sosEvent(document),
      ...geoFenceDocuments.map(_geoFenceEvent).whereType<TouristHistoryEvent>(),
    ];

    events.sort((a, b) {
      final aTime = a.occurredAt;
      final bTime = b.occurredAt;
      if (aTime == null) return bTime == null ? 0 : 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });

    return events;
  }

  TouristHistoryEvent _sosEvent(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return TouristHistoryEvent(
      id: 'sos:${document.id}',
      type: TouristHistoryType.sos,
      title: 'SOS Emergency',
      status: _nonEmptyString(data['status']) ?? 'Unknown',
      occurredAt: _dateTime(data['timestamp'] ?? data['createdAt']),
      latitude: _number(data['latitude']),
      longitude: _number(data['longitude']),
      source: 'sos_alerts',
      sosData: data,
    );
  }

  TouristHistoryEvent? _geoFenceEvent(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final eventType = data['eventType']?.toString() ?? '';
    final zoneType = data['zoneType']?.toString() ?? '';
    final zoneName = data['safeZoneName']?.toString() ?? 'Unknown zone';
    final timestamp = data['timestamp'];

    final TouristHistoryType? type;
    final String? status;
    final String? title;
    final String? description;

    if (eventType == 'ENTER') {
      if (zoneType == 'Safe') {
        type = TouristHistoryType.safeZone;
        status = 'Entered';
        title = 'Safe Zone Entered';
        description = 'You have entered $zoneName.';
      } else if (zoneType == 'Danger') {
        type = TouristHistoryType.dangerZone;
        status = 'Entered';
        title = 'Danger Zone Alert';
        description = 'You have entered $zoneName. Please exercise caution.';
      } else {
        type = TouristHistoryType.safeZone;
        status = 'Entered';
        title = 'Zone Entered';
        description = 'You have entered $zoneName.';
      }
    } else if (eventType == 'EXIT') {
      if (zoneType == 'Safe') {
        type = TouristHistoryType.safeZone;
        status = 'Exited';
        title = 'Safe Zone Exited';
        description = 'You have left $zoneName.';
      } else if (zoneType == 'Danger') {
        type = TouristHistoryType.dangerZone;
        status = 'Exited';
        title = 'Danger Zone Exited';
        description = 'You have left $zoneName.';
      } else {
        type = TouristHistoryType.safeZone;
        status = 'Exited';
        title = 'Zone Exited';
        description = 'You have left $zoneName.';
      }
    } else {
      return null;
    }

    return TouristHistoryEvent(
      id: 'geo:${document.id}',
      type: type,
      title: title,
      status: status,
      occurredAt: _dateTime(timestamp),
      latitude: _number(data['latitude']),
      longitude: _number(data['longitude']),
      source: 'geo_fence_alerts',
      description: description,
    );
  }

  static String typeLabelFor(TouristHistoryType type) {
    switch (type) {
      case TouristHistoryType.sos:
        return 'SOS';
      case TouristHistoryType.safeZone:
        return 'Safe Zone';
      case TouristHistoryType.dangerZone:
        return 'Danger Zone';
    }
  }

  static DateTime? _dateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static String normalizeStatus(Object? value) =>
      value?.toString().trim().toLowerCase() ?? '';

  static bool isSosStatusActive(Object? value) {
    final normalized = normalizeStatus(value);
    return normalized == 'active' || normalized == 'acknowledged';
  }

  static bool isSosStatusResolved(Object? value) {
    return normalizeStatus(value) == 'resolved';
  }

  static double? _number(Object? value) {
    return value is num ? value.toDouble() : null;
  }

  static String? _nonEmptyString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
