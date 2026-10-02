import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nami/domain/arbeitskontext/teildaten_stand.dart';
import 'package:nami/domain/member/efz_einsichtnahme.dart';
import 'package:nami/domain/qualifikation/qualifikation.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/widgets/member_detail/member_qualifikationen_tab.dart';
import 'package:nami/stories/support/mitglied_edge_cases.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de');
  });

  final mitglied = MitgliedEdgeCases.funke;

  Future<void> zeige(
    WidgetTester tester, {
    TeildatenStand efzStand = TeildatenStand.geladen,
    List<EfzEinsichtnahme> efz = const <EfzEinsichtnahme>[],
    TeildatenStand qualiStand = TeildatenStand.geladen,
    List<Qualifikation> qualis = const <Qualifikation>[],
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de')],
        locale: const Locale('de'),
        home: Scaffold(
          body: MemberQualifikationenTab(
            key: UniqueKey(),
            mitglied: mitglied,
            heute: MitgliedEdgeCases.heute,
            efzStand: efzStand,
            efzEinsichtnahmen: efz,
            qualifikationenStand: qualiStand,
            qualifikationen: qualis,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  EfzEinsichtnahme ausgestellt(DateTime datum) =>
      EfzEinsichtnahme(id: 1, personId: mitglied.personId!, issuedOn: datum);

  testWidgets('zeigt alle EFZ-Zustaende kompakt', (tester) async {
    await zeige(tester);
    expect(find.text('Keines hinterlegt'), findsOneWidget);
    expect(find.byKey(const Key('efz-antrag-download')), findsOneWidget);

    await zeige(tester, efz: [ausgestellt(DateTime(2025, 8, 30))]);
    expect(find.text('Gültig bis 30.08.2030'), findsOneWidget);
    expect(find.byKey(const ValueKey('status-punkt-gut')), findsOneWidget);

    await zeige(tester, efz: [ausgestellt(DateTime(2021, 11, 20))]);
    expect(find.text('Gültig bis 20.11.2026'), findsOneWidget);
    expect(find.text('noch 7 Wochen'), findsOneWidget);
    expect(find.byKey(const ValueKey('status-punkt-warnung')), findsOneWidget);

    await zeige(tester, efz: [ausgestellt(DateTime(2019, 10, 1))]);
    expect(find.text('Abgelaufen am 01.10.2024'), findsOneWidget);
    expect(find.byKey(const ValueKey('status-punkt-kritisch')), findsOneWidget);

    await zeige(tester, efzStand: TeildatenStand.unbekannt);
    expect(find.text('Noch nicht synchronisiert'), findsOneWidget);
    expect(find.text('Wird beim nächsten Abgleich geladen'), findsOneWidget);

    await zeige(tester, efzStand: TeildatenStand.keineBerechtigung);
    expect(find.text('Keine Berechtigung'), findsOneWidget);
    expect(find.byKey(const Key('efz-antrag-download')), findsNothing);
  });

  testWidgets('sortiert abgelaufene Qualifikationen ans Ende', (tester) async {
    await zeige(
      tester,
      qualis: MitgliedEdgeCases.qualifikationen
          .where((q) => q.personId == mitglied.personId)
          .toList(),
    );

    expect(find.text('5'), findsOneWidget);
    expect(find.text('erworben 10.06.2019 · ohne Ablauf'), findsOneWidget);
    expect(find.text('abgelaufen 01.05.2023 · reaktivierbar'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Juleica')).dy,
      greaterThan(tester.getTopLeft(find.text('Modulausbildung')).dy),
    );
  });

  testWidgets('meldet fehlende Daten statt still zu scheitern', (tester) async {
    await zeige(tester);

    await tester.tap(find.byKey(const Key('efz-antrag-download')));
    await tester.pump();

    expect(
      find.text(
        'Antragsunterlagen konnten nicht geladen werden (fehlende Daten).',
      ),
      findsOneWidget,
    );
  });
}
