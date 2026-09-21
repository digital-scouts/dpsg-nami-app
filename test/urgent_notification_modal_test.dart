import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/core/notifications/pull_notification.dart';
import 'package:nami/presentation/notifications/urgent_notification_modal.dart';

void main() {
  testWidgets('Zeigt Modal für urgent', (tester) async {
    final notification = PullNotification(
      id: '1',
      title: const LocalizedString(de: 'Wichtig', en: 'Important'),
      body: const LocalizedString(
        de: 'Dringende Nachricht',
        en: 'Urgent message',
      ),
      type: 'urgent',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showUrgentNotificationModal(context, notification),
            child: const Text('Show'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
    expect(find.text('Wichtig'), findsOneWidget);
    expect(find.text('Dringende Nachricht'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
  });
}
