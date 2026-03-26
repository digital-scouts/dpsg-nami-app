import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/core/notifications/pull_notification.dart';
import 'package:nami/presentation/notifications/notifications_list.dart';

void main() {
  testWidgets('Zeigt Mitteilungen an', (tester) async {
    final notifications = [
      PullNotification(
        id: '1',
        title: const LocalizedString(de: 'Test', en: 'Test'),
        body: const LocalizedString(de: 'Text', en: 'Text'),
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsList(
          notifications: notifications,
          acknowledged: const {},
          onTap: (_) {},
          onAcknowledge: (_) {},
        ),
      ),
    );
    expect(find.text('Test'), findsOneWidget);
    expect(find.byIcon(Icons.done), findsOneWidget);
  });
}
