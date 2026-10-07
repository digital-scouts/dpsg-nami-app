import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/widgets/app_log_view.dart';

const String _inhalt = '''
===== app-2026-10-06.log =====
[2026-10-06 21:14:06] [info] [hitobito_sync] Hitobito-Sync erfolgreich trigger=resume
===== app-2026-10-07.log =====
[2026-10-07 08:02:11] [info] [nav] route_open route=/
[2026-10-07 08:02:13] [info] [http] source=hitobito_groups method=GET url=https://dpsg.example/api/groups status=200
[2026-10-07 08:02:15] [warn] [arbeitskontext] Mitglieder-Refresh fehlgeschlagen status=503 versuch=1
[2026-10-07 08:02:21] [error] [arbeitskontext] Arbeitskontext konnte nicht aktualisiert werden error=HitobitoPeopleException: People-Anfrage fehlgeschlagen (503).
#0 HitobitoPeopleService._fetchPeoplePage (package:nami/services/hitobito_people_service.dart:745)
#1 HitobitoPeopleService.fetchPeople (package:nami/services/hitobito_people_service.dart:96)
[2026-10-07 08:04:10] [info] [arbeitskontext] Arbeitskontext geladen: layer=68 name=Santa Lucia mitglieder=27''';

Widget _app(String content) {
  return MaterialApp(
    locale: const Locale('de'),
    supportedLocales: const [Locale('de'), Locale('en')],
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: AppLogView(
        content: content,
        nowProvider: () => DateTime(2026, 10, 7, 9),
      ),
    ),
  );
}

void main() {
  testWidgets('zeigt Eintraege mit Tagen, Level und Feldern', (tester) async {
    // Alle Eintraege auf einmal sichtbar; die Liste baut nur sichtbare Zeilen.
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(_inhalt));

    expect(find.text('Alle 6'), findsOneWidget);
    expect(find.text('Warnungen & Fehler 2'), findsOneWidget);
    expect(find.text('HEUTE'), findsOneWidget);
    expect(find.text('GESTERN'), findsOneWidget);
    expect(find.text('WARN'), findsOneWidget);
    expect(find.text('FEHLER'), findsOneWidget);
    expect(find.text('Arbeitskontext geladen:'), findsOneWidget);
    // Werte mit Leerzeichen bleiben zusammen, Schluessel stehen davor.
    expect(
      find.textContaining('name=Santa Lucia', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text(
        'HitobitoPeopleException: People-Anfrage fehlgeschlagen (503).',
      ),
      findsOneWidget,
    );
    expect(find.text('Details (2 Zeilen)'), findsOneWidget);
    expect(find.byKey(const Key('applog_details')), findsNothing);
  });

  testWidgets('Details klappen den Stacktrace auf', (tester) async {
    await tester.pumpWidget(_app(_inhalt));

    await tester.tap(find.text('Details (2 Zeilen)'));
    await tester.pump();

    expect(find.byKey(const Key('applog_details')), findsOneWidget);
    expect(find.text('Details einklappen'), findsOneWidget);
  });

  testWidgets('filtert Probleme, Routine und Suche', (tester) async {
    await tester.pumpWidget(_app(_inhalt));

    await tester.tap(find.byKey(const Key('applog_filter_hide_routine')));
    await tester.pump();
    expect(find.text('route_open'), findsNothing);
    expect(find.text('Hitobito-Sync erfolgreich'), findsOneWidget);

    await tester.tap(find.byKey(const Key('applog_filter_problems')));
    await tester.pump();
    expect(find.text('Hitobito-Sync erfolgreich'), findsNothing);
    expect(find.text('WARN'), findsOneWidget);

    await tester.tap(find.byKey(const Key('applog_filter_all')));
    await tester.enterText(find.byKey(const Key('applog_search')), 'resume');
    await tester.pump();
    expect(find.text('Hitobito-Sync erfolgreich'), findsOneWidget);
    expect(find.text('WARN'), findsNothing);
  });

  testWidgets('zeigt Hinweis ohne passende Eintraege', (tester) async {
    await tester.pumpWidget(_app(_inhalt));

    await tester.enterText(
      find.byKey(const Key('applog_search')),
      'gibtsnicht',
    );
    await tester.pump();

    expect(find.text('Keine passenden Einträge.'), findsOneWidget);
  });
}
