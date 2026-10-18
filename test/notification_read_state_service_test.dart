import 'package:flutter_test/flutter_test.dart';
import 'package:smart_tourist_safety/services/notification_read_state_service.dart';

void main() {
  final readState = NotificationReadStateService.shared;

  setUp(() {
    readState.resetForTest();
  });

  test('marking a notification read hides the unread indicator', () {
    expect(
      readState.isRead('sos:alert_1', persistedIsRead: false),
      isFalse,
      reason:
          'the unread indicator is visible before the notification is opened',
    );

    readState.markRead('sos:alert_1');

    expect(
      readState.isRead('sos:alert_1', persistedIsRead: false),
      isTrue,
      reason: 'the unread indicator disappears once the notification is opened',
    );
  });

  test('persisted read state stays read', () {
    expect(readState.isRead('geo:alert_read', persistedIsRead: true), isTrue);

    readState.revertRead('geo:alert_read');

    expect(
      readState.isRead('geo:alert_read', persistedIsRead: true),
      isTrue,
      reason: 'reverting only clears state that was not persisted',
    );
  });

  test('read state survives returning to the list and reopening the screen', () {
    readState.markRead('sos:alert_screen');

    // Rebuilding the notifications screen reads the same shared service, which
    // is what keeps the indicator hidden after navigating back and reopening.
    expect(
      readState.isRead('sos:alert_screen', persistedIsRead: false),
      isTrue,
    );
    expect(
      readState.isRead('geo:alert_screen', persistedIsRead: false),
      isFalse,
    );
  });

  test('reverting a notification restores the unread indicator', () {
    readState.markRead('geo:alert_retry');

    readState.revertRead('geo:alert_retry');

    expect(
      readState.isRead('geo:alert_retry', persistedIsRead: false),
      isFalse,
      reason: 'a failed persistence write must show the unread indicator again',
    );
  });

  test('other notifications keep their own read state', () {
    readState.markRead('sos:alert_1');

    expect(readState.isRead('sos:alert_2', persistedIsRead: false), isFalse);
  });
}
