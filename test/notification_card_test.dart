import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/core/notifications/pull_notification.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/notifications/notification_card.dart';
import 'package:nami/presentation/notifications/notification_links.dart';

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [Locale('de'), Locale('en')],
  locale: const Locale('de'),
  home: Scaffold(body: child),
);

final _meldung = PullNotification(
  id: '1',
  title: const LocalizedString(de: 'Wartung', en: 'Maintenance'),
  body: const LocalizedString(de: 'Text', en: 'Text'),
  type: 'urgent',
);

void main() {
  testWidgets('zeigt Prioritaet, Link und Bestaetigen', (tester) async {
    var link = 0;
    var ack = 0;
    await tester.pumpWidget(
      _app(
        NotificationCard(
          notification: _meldung,
          onOpenLink: () => link++,
          onAcknowledge: () => ack++,
        ),
      ),
    );

    expect(find.text('DRINGEND'), findsOneWidget);
    await tester.tap(find.byKey(const Key('notification-link-button')));
    await tester.tap(find.byKey(const Key('notification-ack-button')));
    expect(link, 1);
    expect(ack, 1);
  });

  testWidgets('ohne Callbacks keine Aktionen, Kopfzeile sichtbar', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        NotificationCard(
          notification: _meldung,
          kopfzeile: const Text('1 von 3'),
        ),
      ),
    );

    expect(find.text('1 von 3'), findsOneWidget);
    expect(find.byKey(const Key('notification-link-button')), findsNothing);
    expect(find.byKey(const Key('notification-ack-button')), findsNothing);
  });

  test('Links: nur https extern, deep_link nur erlaubte Ziele', () {
    expect(hatMeldungsLink(externalLink: 'https://example.org'), isTrue);
    expect(hatMeldungsLink(externalLink: 'http://example.org'), isFalse);
    expect(hatMeldungsLink(externalLink: 'javascript:alert(1)'), isFalse);
    expect(hatMeldungsLink(deepLink: '/settings/notifications'), isTrue);
    expect(hatMeldungsLink(deepLink: '/settings/debug'), isFalse);
  });
}
