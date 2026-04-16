import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/core/notifications/pull_notification.dart';
import 'package:nami/l10n/app_localizations.dart';
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
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de'), Locale('en')],
        locale: const Locale('de'),
        home: NotificationsList(
          notifications: notifications,
          acknowledged: const {},
          onTap: (_) {},
          onAcknowledge: (_) {},
        ),
      ),
    );
    expect(find.text('Test'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });
}
