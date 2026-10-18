import 'package:flutter/foundation.dart';

/// Session-scoped record of the Tourist notifications that were opened.
///
/// The Notifications screen keeps using the existing persistence mechanism of
/// `geo_fence_alerts`, whose `status` field already moves from `Unread` to
/// `Read`. The `sos_alerts` documents of the existing schema have no read
/// field, so their read state is remembered here for the current app session
/// only (this keeps the unread indicator hidden while the Tourist keeps
/// navigating back to the list, without inventing new Firebase fields).
class NotificationReadStateService {
  NotificationReadStateService._();

  static final NotificationReadStateService shared =
      NotificationReadStateService._();

  final Set<String> _readIds = <String>{};

  /// Whether a notification is read, combining the persisted state with what
  /// the Tourist already opened in this session.
  bool isRead(String notificationId, {required bool persistedIsRead}) =>
      persistedIsRead || _readIds.contains(notificationId);

  /// Marks a notification as read so the unread indicator disappears at once.
  void markRead(String notificationId) {
    _readIds.add(notificationId);
  }

  /// Restores the unread state when the read state could not be persisted.
  void revertRead(String notificationId) {
    _readIds.remove(notificationId);
  }

  /// Test seam: clears every session-scoped read state.
  @visibleForTesting
  void resetForTest() => _readIds.clear();
}
