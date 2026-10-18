import 'package:cloud_firestore/cloud_firestore.dart';

/// A notification shown on the Tourist Notifications screen.
///
/// These items are derived from the documents that already exist for the
/// Tourist: `sos_alerts` (SOS lifecycle) and `geo_fence_alerts` (safe and
/// danger zone enter/exit events). Geofence alerts already carry a read state
/// in their `status` field (`Unread` -> `Read`); see
/// [NotificationReadStateService] for the remaining read state.
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
  });

  final String id;
  final String type;
  final String title;
  final String message;
  final Timestamp? createdAt;
  final bool isRead;

  String get dateText {
    final created = createdAt;
    if (created == null) return 'Date unavailable';
    return formatNotificationDate(created.toDate());
  }

  /// Returns a copy whose read state reflects what the Tourist already opened.
  NotificationItem withReadState({required bool isRead}) => NotificationItem(
    id: id,
    type: type,
    title: title,
    message: message,
    createdAt: createdAt,
    isRead: isRead,
  );
}

String formatNotificationDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');

  final month = date.month.toString().padLeft(2, '0');

  final year = date.year.toString();

  final hour = date.hour.toString().padLeft(2, '0');

  final minute = date.minute.toString().padLeft(2, '0');

  return '$day/$month/$year $hour:$minute';
}
