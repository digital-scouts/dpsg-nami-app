import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/screens/log_viewer_page.dart';
import 'package:nami/presentation/widgets/app_log_view.dart';
import 'package:nami/services/logger_service.dart';

const String _inhalt = '''
[2026-10-06 21:00:00] [info] [hitobito_sync] Gestern-Eintrag
[2026-10-07 08:00:00] [warn] [arbeitskontext] Warnung heute status=503
[2026-10-07 08:55:00] [info] [nav] route_open route=/
[2026-10-07 08:58:00] [error] [arbeitskontext] Fehler heute error=Boom
#0 stack''';

class _Fixture {
  String content = _inhalt;
  int loeschAufrufe = 0;
  File? geteilt;
  File? gemeldet;
  bool meldenScheitert = false;

  LogQuelle get quelle => LogQuelle(
    titelKey: 'debug_logs_app_title',
    heuteKey: 'debug_logs_app_today',
    dateiKennung: 'app',
    lesen: () async => content,
    loeschen: () async {
      loeschAufrufe++;
      content = '';
    },
    eintraege: (content) => [
      for (final entry in AppLogEntry.parseAll(content))
        LogEintragInfo(entry.timestamp, fehler: entry.level == 'error'),
    ],
    ansicht: (content, zeitfenster, zeitraumAuswahl, onAusschnitt) =>
        AppLogView(
          content: content,
          nowProvider: () => DateTime(2026, 10, 7, 9),
          zeitfenster: zeitfenster,
          zeitraumAuswahl: zeitraumAuswahl,
          onAusschnitt: onAusschnitt,
        ),
  );

  Widget app(Directory temp) => MaterialApp(
    locale: const Locale('de'),
    supportedLocales: const [Locale('de'), Locale('en')],
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: LogViewerPage(
      quelle: quelle,
      nowProvider: () => DateTime(2026, 10, 7, 9),
      temporaeresVerzeichnis: () async => temp,
      teilen: (datei, anker) async => geteilt = datei,
      melden: (datei) async {
        if (meldenScheitert) {
          throw StateError('kein Mailprogramm');
        }
        gemeldet = datei;
      },
    ),
  );
}

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('log_viewer_page_test');
  });

  tearDown(() async {
    await temp.delete(recursive: true);
  });

  Future<void> starte(WidgetTester tester, _Fixture fixture) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(fixture.app(temp));
    await tester.pumpAndSettle();
  }

  // Datei-IO laeuft nur ausserhalb der Fake-Zeit.
  Future<void> warteAufDateien(WidgetTester tester) async {
    for (var runde = 0; runde < 10; runde++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  testWidgets('startet mit Heute', (tester) async {
    await starte(tester, _Fixture());

    expect(find.text('Heute'), findsOneWidget);
    expect(find.text('3 Einträge · Heute'), findsOneWidget);
    expect(find.text('Gestern-Eintrag'), findsNothing);
    expect(find.text('Warnung heute'), findsOneWidget);
  });

  testWidgets('Zeitraum wechselt ueber das Blatt', (tester) async {
    await starte(tester, _Fixture());

    await tester.tap(find.byKey(const Key('log_range_chip')));
    await tester.pumpAndSettle();
    // Anzahl je Vorlage: 10 Minuten 2, Stunde 3, Heute 3, Alles 4.
    expect(
      find.descendant(
        of: find.byKey(const Key('log_range_alles')),
        matching: find.text('4'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('log_range_alles')));
    await tester.pumpAndSettle();
    expect(find.text('Gestern-Eintrag'), findsOneWidget);
    expect(find.text('4 Einträge · Alles'), findsOneWidget);

    await tester.tap(find.byKey(const Key('log_range_chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('log_range_zehnMinuten')));
    await tester.pumpAndSettle();
    expect(find.text('Warnung heute'), findsNothing);
    expect(find.text('2 Einträge · Letzte 10 Minuten'), findsOneWidget);
  });

  testWidgets('Teilen nimmt nur den sichtbaren Ausschnitt', (tester) async {
    final fixture = _Fixture();
    await starte(tester, fixture);

    await tester.tap(find.byKey(const Key('applog_filter_problems')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Aktionen'));
    await tester.pumpAndSettle();
    expect(
      find.text('2 Einträge · Heute · Warnungen & Fehler'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('log_menu_teilen')));
    await warteAufDateien(tester);

    final datei = fixture.geteilt!;
    expect(datei.path, endsWith('nami-app-log_2026-10-07_0900.log'));
    final inhalt = await tester.runAsync(datei.readAsString);
    expect(
      inhalt,
      '[2026-10-07 08:00:00] [warn] [arbeitskontext] Warnung heute status=503\n'
      '[2026-10-07 08:58:00] [error] [arbeitskontext] Fehler heute error=Boom\n'
      '#0 stack\n',
    );
  });

  testWidgets('Report Issue haengt denselben Ausschnitt an', (tester) async {
    final fixture = _Fixture();
    await starte(tester, fixture);

    await tester.tap(find.byTooltip('Aktionen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('log_menu_melden')));
    await warteAufDateien(tester);

    final inhalt = await tester.runAsync(fixture.gemeldet!.readAsString);
    expect(inhalt, isNot(contains('Gestern-Eintrag')));
    expect(inhalt, contains('Warnung heute'));
  });

  testWidgets('Report Issue weist auf Teilen hin, wenn die Mail scheitert', (
    tester,
  ) async {
    final fixture = _Fixture()..meldenScheitert = true;
    await starte(tester, fixture);

    await tester.tap(find.byTooltip('Aktionen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('log_menu_melden')));
    await warteAufDateien(tester);

    expect(
      find.text(
        'Die Mail konnte nicht geöffnet werden. Teile die Logs stattdessen.',
      ),
      findsOneWidget,
    );
    // Einblendung der Leiste abwarten.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(TextButton, 'Teilen'));
    await warteAufDateien(tester);
    expect(fixture.geteilt, isNotNull);
  });

  testWidgets('Loeschen fragt nach und loescht alle Tage', (tester) async {
    final fixture = _Fixture();
    await starte(tester, fixture);

    await tester.tap(find.byTooltip('Aktionen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('log_menu_loeschen')));
    await tester.pumpAndSettle();
    expect(find.text('App-Log löschen?'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(fixture.loeschAufrufe, 0);

    await tester.tap(find.byTooltip('Aktionen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('log_menu_loeschen')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('log_delete_confirm')));
    await tester.pumpAndSettle();

    expect(fixture.loeschAufrufe, 1);
    expect(find.text('Keine Einträge.'), findsOneWidget);
    expect(find.text('Alle Logdateien gelöscht'), findsOneWidget);
  });
}
