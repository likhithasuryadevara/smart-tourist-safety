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
        .collection('sos')
        .where('touristId', isEqualTo: touristId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchNotificationHistory(
    String touristId,
  ) {
    return _firestore
        .collection('notifications')
        .where('touristId', isEqualTo: touristId)
        .snapshots();
  }

  List<TouristHistoryEvent> combineHistory({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> sosDocuments,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>>
    notificationDocuments,
  }) {
    final events = <TouristHistoryEvent>[
      for (final document in sosDocuments) _sosEvent(document),
      ...notificationDocuments
          .map(_notificationEvent)
          .whereType<TouristHistoryEvent>(),
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
      occurredAt: _dateTime(data['createdAt']),
      latitude: _number(data['latitude']),
      longitude: _number(data['longitude']),
      source: 'sos',
      sosData: data,
    );
  }

  TouristHistoryEvent? _notificationEvent(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final notificationType = data['type']?.toString().toLowerCase();

    final TouristHistoryType? type;
    final String? status;
    switch (notificationType) {
      case 'safe_zone':
        type = TouristHistoryType.safeZone;
        status = 'Entered';
      case 'zone_exit':
        type = TouristHistoryType.safeZone;
        status = 'Exited';
      case 'danger_zone':
        type = TouristHistoryType.dangerZone;
        status = 'Entered';
      case 'sos_acknowledged':
        type = TouristHistoryType.sos;
        status = 'Acknowledged';
      case 'sos_resolved':
        type = TouristHistoryType.sos;
        status = 'Resolved';
      default:
        // SOS confirmation duplicates the corresponding SOS record. Admin and
        // unrelated messages are not safety events in this history.
        return null;
    }

    return TouristHistoryEvent(
      id: 'notification:${document.id}',
      type: type,
      title: _nonEmptyString(data['title']) ?? typeLabelFor(type),
      status: status,
      occurredAt: _dateTime(data['createdAt']),
      latitude: _number(data['latitude']),
      longitude: _number(data['longitude']),
      source: 'notifications',
      description: _nonEmptyString(data['message']),
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

  static double? _number(Object? value) {
    return value is num ? value.toDouble() : null;
  }

  static String? _nonEmptyString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
