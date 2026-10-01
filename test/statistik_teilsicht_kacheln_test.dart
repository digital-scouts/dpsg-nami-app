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

Widget _app(Widget kachel) => MaterialApp(
  localizationsDelegates: [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [Locale('de'), Locale('en')],
  locale: const Locale('de'),
  home: Scaffold(
    body: Center(child: SizedBox(width: 340, height: 110, child: kachel)),
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
}
