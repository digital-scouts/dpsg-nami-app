import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/statistiks/berechne_stamm_statistik_usecase.dart';
import 'package:nami/domain/statistiks/stamm_statistik.dart';
import 'package:nami/domain/statistiks/statistik_kachel_typen.dart';
import 'package:nami/domain/stufe/altersgrenzen.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/statistics/kacheln/diagramme.dart';
import 'package:nami/presentation/statistics/kacheln/inhalte_mitglieder.dart';
import 'package:nami/presentation/statistics/kacheln/kachel_daten.dart';
import 'package:nami/presentation/statistics/kacheln/kachel_katalog.dart';
import 'package:nami/domain/statistiks/statistik_kachel_einstellungen.dart';

AltersZeile _zeile(List<double> alter) => AltersZeile(
  beschriftung: 'Wö',
  alter: alter,
  min: 6,
  max: 10,
  farbe: Colors.orange,
  flaeche: Colors.orange.shade50,
);

/// Statistik aus einem kleinen Stamm mit den angegebenen Stufengruppen;
/// jede Gruppe bekommt so viele Kinder wie ihre ID.
StammStatistik _statistik(List<(int, String, String)> gruppen) {
  final readModel = ArbeitskontextReadModel(
    arbeitskontext: Arbeitskontext(
      aktiverLayer: const ArbeitskontextLayer(id: 11, name: 'Stamm'),
    ),
    rolesSindGeladen: true,
    mitglieder: [
      for (final (id, _, _) in gruppen)
        for (var i = 0; i < id; i++)
          Mitglied.peopleListItem(
            mitgliedsnummer: '$id-$i',
            vorname: 'K',
            nachname: '$i',
          ),
    ],
    gruppen: [
      for (final (id, name, typ) in gruppen)
        ArbeitskontextGruppe(id: id, name: name, layerId: 11, gruppenTyp: typ),
    ],
    mitgliedsZuordnungen: [
      for (final (id, _, _) in gruppen)
        for (var i = 0; i < id; i++)
          ArbeitskontextMitgliedsZuordnung(
            mitgliedsnummer: '$id-$i',
            gruppenId: id,
            rollenLabel: 'Mitglied',
          ),
    ],
  );
  final heute = DateTime(2026, 10, 1);
  return const BerechneStammStatistikUseCase()(
    readModel,
    heute: heute,
    altersgrenzen: StufenDefaults.build(),
    stichtag: heute,
  );
}

Widget _app(Widget kachel, {double hoehe = 110}) => MaterialApp(
  localizationsDelegates: [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [Locale('de'), Locale('en')],
  locale: const Locale('de'),
  home: Scaffold(
    body: Center(
      child: SizedBox(width: 340, height: hoehe, child: kachel),
    ),
  ),
);

void main() {
  group('Altersstruktur 2×1', () {
    test('Achse reicht vom jüngsten bis ein Jahr über das älteste Kind', () {
      // Ältestes Kind 12 Jahre: Achse bis einschließlich 13.
      expect(
        AltersSaeulenGestapelt.achse([
          _zeile(const [9.4, 10.2, 12.8]),
        ]),
        (8, 14),
      );
      expect(
        AltersSaeulenGestapelt.achse([
          _zeile(const [4.1]),
          _zeile(const [16.9]),
        ]),
        (3, 18),
      );
      expect(AltersSaeulenGestapelt.achse(const []), (3, 23));
    });

    testWidgets('zeichnet ohne Fehler', (tester) async {
      await tester.pumpWidget(
        _app(
          AltersSaeulenGestapelt(
            zeilen: [
              _zeile(const [7, 8, 8, 9.5]),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Gruppen 2×1', () {
    StatistikKachelDaten daten(
      List<(int, String, String)> gruppen, {
      ValueChanged<int>? oeffnen,
    }) => StatistikKachelDaten(
      statistik: _statistik(gruppen),
      grenzen: StufenDefaults.build(),
      heute: DateTime(2026, 10, 1),
      onGruppeOeffnen: oeffnen,
    );
    const meute1 = (4, 'Meute Wirbelwind', 'Group::StammGruppeWoelflinge');
    const meute2 = (2, 'Meute Sternschnuppe', 'Group::StammGruppeWoelflinge');
    const trupp = (3, 'Trupp Kompass', 'Group::StammGruppeJungpfadfinder');

    testWidgets('zeigt bis zu zwei Gruppen je eine antippbare Spalte', (
      tester,
    ) async {
      final geoeffnet = <int>[];
      await tester.pumpWidget(
        _app(
          GruppenKachel(
            daten: daten(const [meute1, meute2], oeffnen: geoeffnet.add),
            groesse: KachelGroesse.breit,
          ),
        ),
      );

      expect(find.text('Meute Wirbelwind'), findsOneWidget);
      expect(find.text('Meute Sternschnuppe'), findsOneWidget);
      await tester.tap(find.byKey(const Key('gruppen-spalte-2')));
      expect(geoeffnet, [2]);
    });

    testWidgets('fasst ab drei Gruppen wieder je Stufe zusammen', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          GruppenKachel(
            daten: daten(const [meute1, meute2, trupp]),
            groesse: KachelGroesse.breit,
          ),
        ),
      );

      expect(find.byKey(const Key('gruppen-spalte-4')), findsNothing);
      expect(find.text('Wö'), findsOneWidget);
      expect(find.text('Jufi'), findsOneWidget);
    });
  });

  group('Gruppen 2×2 und Auswahl', () {
    const typen = [
      'Group::StammGruppeBiber',
      'Group::StammGruppeWoelflinge',
      'Group::StammGruppeJungpfadfinder',
      'Group::StammGruppePfadfinder',
      'Group::StammGruppeRover',
    ];
    // n Gruppen, reihum auf die Stufen verteilt; IDs ab 1.
    List<(int, String, String)> gruppen(int n) => [
      for (var i = 1; i <= n; i++) (i, 'Gruppe $i', typen[(i - 1) % 5]),
    ];
    StatistikKachelDaten daten(int n, List<int> geoeffnet) =>
        StatistikKachelDaten(
          statistik: _statistik(gruppen(n)),
          grenzen: StufenDefaults.build(),
          heute: DateTime(2026, 10, 1),
          onGruppeOeffnen: geoeffnet.add,
        );
    // Innenhöhe einer 2×2-Kachel ohne Titel.
    Widget gross(Widget kachel) => _app(kachel, hoehe: 264);

    testWidgets('wechselt nach Anzahl zwischen Liste, Zellen und Chips', (
      tester,
    ) async {
      final geoeffnet = <int>[];
      await tester.pumpWidget(
        gross(
          GruppenKachel(
            daten: daten(6, geoeffnet),
            groesse: KachelGroesse.gross,
          ),
        ),
      );
      expect(find.byKey(const Key('gruppen-zelle-1')), findsNothing);
      expect(find.byKey(const Key('gruppen-weitere')), findsNothing);
      expect(
        find.textContaining('Gruppe 6', findRichText: true),
        findsOneWidget,
      );

      await tester.pumpWidget(
        gross(
          GruppenKachel(
            daten: daten(9, geoeffnet),
            groesse: KachelGroesse.gross,
          ),
        ),
      );
      expect(find.byKey(const Key('gruppen-zelle-9')), findsOneWidget);
      await tester.tap(find.byKey(const Key('gruppen-zelle-9')));
      expect(geoeffnet, [9]);

      await tester.pumpWidget(
        gross(
          GruppenKachel(
            daten: daten(13, geoeffnet),
            groesse: KachelGroesse.gross,
          ),
        ),
      );
      expect(find.byKey(const Key('gruppen-chip-13')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final skala in const [1.0, 1.3, 1.4]) {
      testWidgets('läuft mit 9 und 15 Gruppen bei Schrift $skala nicht über', (
        tester,
      ) async {
        for (final n in const [6, 9, 12, 15]) {
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(skala)),
              child: gross(
                GruppenKachel(
                  daten: daten(n, <int>[]),
                  groesse: KachelGroesse.gross,
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull, reason: '$n Gruppen');
        }
      });
    }

    testWidgets('Stufe mit mehreren Gruppen öffnet die Auswahl dieser Stufe', (
      tester,
    ) async {
      final geoeffnet = <int>[];
      // 7 Gruppen: Biber hat Gruppe 1 und 6, Pfadi nur Gruppe 4.
      final d = daten(7, geoeffnet);
      await tester.pumpWidget(
        _app(GruppenKachel(daten: d, groesse: KachelGroesse.breit)),
      );
      expect(find.text('2 Gruppen'), findsWidgets);

      await tester.tap(find.byKey(const Key('stufen-spalte-pfadfinder')));
      await tester.pumpAndSettle();
      expect(geoeffnet, [4]);

      await tester.tap(find.byKey(const Key('stufen-spalte-biber')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('gruppen-auswahl-1')), findsOneWidget);
      expect(find.byKey(const Key('gruppen-auswahl-6')), findsOneWidget);
      expect(find.byKey(const Key('gruppen-auswahl-2')), findsNothing);
      await tester.tap(find.byKey(const Key('gruppen-auswahl-6')));
      await tester.pumpAndSettle();
      expect(geoeffnet, [4, 6]);
    });

    testWidgets('Titel heißt ab drei Gruppen Stufen und öffnet alle Gruppen', (
      tester,
    ) async {
      final geoeffnet = <int>[];
      final d = daten(7, geoeffnet);
      const eintrag = KachelEintrag(
        id: 'g',
        typId: StatistikKachelTypen.gruppen,
        groesse: KachelGroesse.breit,
      );
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => KachelKatalog.kachel(context, d, eintrag),
          ),
          hoehe: 150,
        ),
      );
      expect(find.text('Stufen · 7 Gruppen'), findsOneWidget);

      await tester.tap(find.byKey(const Key('kachel-titel-link')));
      await tester.pumpAndSettle();
      // Alle Stufen, beginnend mit beiden Bibergruppen.
      expect(find.text('Gruppen'), findsOneWidget);
      expect(find.byKey(const Key('gruppen-auswahl-1')), findsOneWidget);
      expect(find.byKey(const Key('gruppen-auswahl-6')), findsOneWidget);
      expect(find.byKey(const Key('gruppen-auswahl-2')), findsOneWidget);
    });
  });
}
