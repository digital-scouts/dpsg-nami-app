import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nami/demo/demo_data.dart';
import 'package:nami/demo/demo_services.dart';
import 'package:nami/domain/auth/auth_session.dart';
import 'package:nami/domain/veranstaltung/veranstaltung.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/veranstaltungen_model.dart';
import 'package:nami/presentation/screens/veranstaltungen/veranstaltung_detail_page.dart';
import 'package:nami/presentation/screens/veranstaltungen/veranstaltungen_page.dart';
import 'package:nami/services/app_mode_controller.dart';
import 'package:nami/services/hitobito_events_service.dart';
import 'package:provider/provider.dart';

final _jetzt = DateTime(2026, 10, 10, 9);

class _KaputterService extends DemoHitobitoEventsService {
  _KaputterService(super.demoData);

  @override
  Future<List<Veranstaltung>> fetchVeranstaltungen(
    String accessToken, {
    required DateTime abTag,
    Set<int>? gruppenIds,
  }) async => throw const HitobitoEventsException('kaputt', statusCode: 500);
}

void main() {
  setUpAll(() => initializeDateFormatting('de'));

  final demoData = DemoData(DemoZugang.stammesvorstand, now: () => _jetzt);

  VeranstaltungenModel modelMit(HitobitoEventsService service) =>
      VeranstaltungenModel(
        service: service,
        remoteAccessExecutor: <T>({required trigger, required action}) =>
            action(AuthSession(accessToken: 't', receivedAt: _jetzt)),
        readModel: () => null,
        jetzt: () => _jetzt,
      );

  Future<void> pumpe(
    WidgetTester tester,
    Widget seite, {
    VeranstaltungenModel? model,
    Size groesse = const Size(390, 1400),
  }) async {
    tester.view.physicalSize = groesse * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<VeranstaltungenModel>.value(
        value: model ?? modelMit(DemoHitobitoEventsService(demoData)),
        child: MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('de')],
          locale: const Locale('de'),
          home: seite,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Liste nach Monat, ohne Vergangenes, mit Status', (tester) async {
    await pumpe(tester, const VeranstaltungenPage());

    expect(find.text('7 kommende'), findsOneWidget);
    expect(find.text('OKTOBER 2026'), findsOneWidget);
    expect(find.text('NOVEMBER 2026'), findsOneWidget);
    expect(find.textContaining('Waldputzaktion'), findsNothing);
    expect(find.textContaining('Anmeldung offen bis 20. Okt.'), findsOneWidget);
    expect(find.textContaining('Anmeldeschluss vorbei'), findsOneWidget);
    expect(find.textContaining('ausgebucht'), findsOneWidget);
  });

  testWidgets('Chip Kurse und Suche filtern lokal', (tester) async {
    await pumpe(tester, const VeranstaltungenPage());

    await tester.tap(find.byKey(const Key('veranstaltungen-chip-kurse')));
    await tester.pumpAndSettle();
    expect(find.text('3 kommende'), findsOneWidget);
    expect(find.textContaining('Kinoabend'), findsNothing);

    await tester.tap(find.byKey(const Key('veranstaltungen-chip-alle')));
    await tester.enterText(find.byType(TextField), 'kino');
    await tester.pumpAndSettle();
    expect(find.text('1 kommende'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'gibtsnicht');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('veranstaltungen-leer')), findsOneWidget);
    await tester.tap(find.text('Filter zurücksetzen'));
    await tester.pumpAndSettle();
    expect(find.text('7 kommende'), findsOneWidget);
  });

  testWidgets('Tippen oeffnet das Detail mit Banner und Abschnitten', (
    tester,
  ) async {
    await pumpe(tester, const VeranstaltungenPage());

    await tester.tap(find.byKey(const Key('veranstaltung-9104')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('veranstaltung-detail')), findsOneWidget);
    expect(find.text('KURS · GLK'), findsOneWidget);
    expect(find.textContaining('Anmeldung offen bis 4. Nov.'), findsOneWidget);
    expect(find.textContaining('8 von 12 frei'), findsOneWidget);
    expect(find.text('Wochenende 1'), findsOneWidget);
    expect(find.text('Martin Krause'), findsOneWidget);
    expect(find.text('Svenja Albers'), findsOneWidget);
    // Im Demo gibt es keine Webseite.
    expect(find.byKey(const Key('veranstaltung-web')), findsNothing);
  });

  testWidgets('Kalender fragt bei mehreren Terminen nach', (tester) async {
    final eingetragen = <VeranstaltungsTermin>[];
    final kurs = demoData.veranstaltungen().firstWhere((v) => v.id == 9104);
    await pumpe(
      tester,
      VeranstaltungDetailPage(
        veranstaltung: kurs,
        heute: _jetzt,
        webLink: Uri.parse('https://nami.example/groups/1/events/9104'),
        kalenderEintragen: (veranstaltung, termin) async {
          eingetragen.add(termin);
          return true;
        },
      ),
    );

    expect(find.text('Im Web öffnen'), findsOneWidget);
    await tester.tap(find.byKey(const Key('veranstaltung-kalender')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('veranstaltung-kalender-termin-1')));
    await tester.tap(find.byKey(const Key('veranstaltung-kalender-weiter')));
    await tester.pumpAndSettle();

    expect(eingetragen.single.label, 'Wochenende 2');
  });

  testWidgets('leere Veranstaltung zeigt fehlende Angaben', (tester) async {
    final leer = demoData.veranstaltungen().firstWhere((v) => v.id == 9107);
    await pumpe(
      tester,
      VeranstaltungDetailPage(veranstaltung: leer, heute: _jetzt),
    );

    expect(find.text('Keine Angaben zur Anmeldung'), findsOneWidget);
    expect(find.text('kein Ort angegeben'), findsOneWidget);
    expect(find.text('keine Kosten angegeben'), findsOneWidget);
    expect(find.text('BESCHREIBUNG'), findsNothing);
  });

  testWidgets('Fehlerzustand mit erneutem Versuch', (tester) async {
    await pumpe(
      tester,
      const VeranstaltungenPage(),
      model: modelMit(_KaputterService(demoData)),
    );

    expect(find.byKey(const Key('veranstaltungen-fehler')), findsOneWidget);
    expect(find.text('Erneut versuchen'), findsOneWidget);
  });

  testWidgets('breit stehen Liste und Detail nebeneinander', (tester) async {
    await pumpe(
      tester,
      const VeranstaltungenPage(),
      groesse: const Size(1180, 820),
    );

    expect(find.byKey(const Key('veranstaltungen-liste')), findsOneWidget);
    expect(find.byKey(const Key('veranstaltung-detail')), findsOneWidget);
    // Das erste Event ist gewaehlt, das Detail hat keinen Zurueck-Pfeil.
    expect(
      find.descendant(
        of: find.byKey(const Key('veranstaltung-detail')),
        matching: find.text('Herbstaktion Silberfels'),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Zurück'), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('veranstaltung-9104')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('veranstaltung-9104')));
    await tester.pumpAndSettle();
    expect(find.text('KURS · GLK'), findsOneWidget);
    expect(find.byKey(const Key('veranstaltung-detail')), findsOneWidget);
  });
}
