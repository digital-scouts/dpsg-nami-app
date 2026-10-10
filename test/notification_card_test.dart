import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/core/notifications/pull_notification.dart';
import 'package:nami/domain/supporter/supporter_kauf_repository.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/supporter_kauf_model.dart';
import 'package:nami/presentation/navigation/app_router.dart';
import 'package:nami/presentation/notifications/notification_card.dart';
import 'package:nami/presentation/notifications/notification_links.dart';
import 'package:provider/provider.dart';

import 'support/fake_supporter_store_client.dart';

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

  Future<BuildContext> pumpeKontext(
    WidgetTester tester, {
    SupporterKaufModel? kauf,
  }) async {
    late BuildContext kontext;
    final inhalt = Builder(
      builder: (context) {
        kontext = context;
        return const SizedBox();
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: kauf == null
            ? inhalt
            : ChangeNotifierProvider<SupporterKaufModel>.value(
                value: kauf,
                child: inhalt,
              ),
        onGenerateRoute: (settings) => MaterialPageRoute(
          settings: settings,
          builder: (_) => Text('Ziel ${settings.name}'),
        ),
      ),
    );
    return kontext;
  }

  testWidgets('Links: nur https extern, deep_link nur erlaubte Ziele', (
    tester,
  ) async {
    final context = await pumpeKontext(tester);
    expect(
      hatMeldungsLink(context, externalLink: 'https://example.org'),
      isTrue,
    );
    expect(
      hatMeldungsLink(context, externalLink: 'http://example.org'),
      isFalse,
    );
    expect(
      hatMeldungsLink(context, externalLink: 'javascript:alert(1)'),
      isFalse,
    );
    expect(
      hatMeldungsLink(context, deepLink: '/settings/notifications'),
      isTrue,
    );
    expect(hatMeldungsLink(context, deepLink: '/settings/debug'), isFalse);
  });

  testWidgets('Unterstuetzen nur mit Store-Anbindung, sonst externer Link', (
    tester,
  ) async {
    var context = await pumpeKontext(tester);
    expect(hatMeldungsLink(context, deepLink: AppRoutes.supporter), isFalse);
    expect(
      hatMeldungsLink(
        context,
        deepLink: AppRoutes.supporter,
        externalLink: 'https://example.org',
      ),
      isTrue,
    );

    final kauf = SupporterKaufModel(
      client: FakeSupporterStoreClient(),
      repository: InMemorySupporterKaufRepository(),
    );
    context = await pumpeKontext(tester, kauf: kauf);
    expect(hatMeldungsLink(context, deepLink: AppRoutes.supporter), isTrue);
    unawaited(oeffneMeldungsLink(context, deepLink: AppRoutes.supporter));
    await tester.pumpAndSettle();
    expect(find.text('Ziel /supporter'), findsOneWidget);
  });
}
