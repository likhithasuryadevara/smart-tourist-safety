import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_tourist_safety/models/notification_item.dart';
import 'package:smart_tourist_safety/widgets/notification_card.dart';

NotificationItem _notification({
  String id = 'geo:alert_1',
  String type = 'safe_zone',
  bool isRead = false,
}) {
  return NotificationItem(
    id: id,
    type: type,
    title: 'Safe Zone Entered',
    message: 'You have entered Temple Zone.',
    createdAt: null,
    isRead: isRead,
  );
}

Finder _unreadDot() => find.byWidgetPredicate((widget) {
  if (widget is! Container) return false;
  final decoration = widget.decoration;
  return decoration is BoxDecoration &&
      decoration.shape == BoxShape.circle &&
      decoration.color == Colors.teal;
});

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('unread notification shows the teal unread indicator', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(NotificationCard(notification: _notification(), onOpen: () {})),
    );

    expect(_unreadDot(), findsOneWidget);
    expect(find.text('Safe Zone Entered'), findsOneWidget);
    expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('read notification hides the unread indicator', (tester) async {
    await tester.pumpWidget(
      _host(
        NotificationCard(
          notification: _notification(isRead: true),
          onOpen: () {},
        ),
      ),
    );

    expect(_unreadDot(), findsNothing);
    expect(find.text('Safe Zone Entered'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping an unread notification reports it as opened', (
    tester,
  ) async {
    var openedCalls = 0;
    await tester.pumpWidget(
      _host(
        NotificationCard(
          notification: _notification(),
          onOpen: () => openedCalls++,
        ),
      ),
    );

    await tester.tap(find.text('Safe Zone Entered'));
    await tester.pump();

    expect(openedCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a read notification cannot be opened again', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(
      _host(
        NotificationCard(
          notification: _notification(isRead: true),
          onOpen: () => opened.add('opened'),
        ),
      ),
    );

    await tester.tap(find.text('Safe Zone Entered'), warnIfMissed: false);
    await tester.pump();

    expect(opened, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('read and unread cards keep their existing styling', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            NotificationCard(notification: _notification(), onOpen: () {}),
            NotificationCard(
              notification: _notification(id: 'geo:alert_2', isRead: true),
              onOpen: () {},
            ),
          ],
        ),
      ),
    );

    final cards = tester.widgetList<Card>(find.byType(Card)).toList();
    expect(cards, hasLength(2));
    expect(cards[0].color, const Color(0xFFE6FFFA));
    expect(cards[1].color, Colors.white);

    final titles = tester
        .widgetList<Text>(find.text('Safe Zone Entered'))
        .toList();
    expect(titles[0].style?.fontWeight, FontWeight.bold);
    expect(titles[1].style?.fontWeight, FontWeight.w600);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notification date text falls back when no timestamp exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(NotificationCard(notification: _notification(), onOpen: () {})),
    );

    expect(find.text('Date unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
