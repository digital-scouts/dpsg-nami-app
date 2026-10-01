import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/appearance/appearance_catalog.dart';
import 'package:nami/domain/statistiks/statistik_kachel_einstellungen.dart';
import 'package:nami/domain/statistiks/statistik_kachel_typen.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/statistics/kacheln/kachel_daten.dart';
import 'package:nami/presentation/statistics/kacheln/kachel_katalog.dart';
import 'package:nami/presentation/statistics/kacheln/kachel_rahmen.dart';
import 'package:nami/presentation/statistics/kacheln/kachel_raster.dart';
import 'package:nami/presentation/theme/theme.dart';
import 'package:nami/presentation/widgets/app_page_header.dart';
import 'package:nami/stories/statistik/statistik_kachel_beispiele.dart';

/// Jede Kachel in jeder erlaubten Größe, bei mehreren Breiten und
/// Textskalen, mit allen Beispielstämmen: Nichts darf eine Exception werfen
/// (auch kein RenderFlex-Overflow), und jeder Text bleibt in seiner Kachel.
void main() {
  const breiten = [320.0, 390.0, 820.0];
  const textSkalen = [1.0, 1.3, 1.4, 2.0];

  for (final datensatz in StatistikBeispielDatensatz.values) {
    for (final breite in breiten) {
      testWidgets('${datensatz.name} bei $breite pt', (tester) async {
        final daten = StatistikKachelBeispiele.daten(datensatz);
        final eintraege = _alleEintraege(daten);
        for (final skala in textSkalen) {
          for (final helligkeit in Brightness.values) {
            await _pruefen(
              tester,
              daten: daten,
              eintraege: eintraege,
              breite: breite,
              skala: skala,
              helligkeit: helligkeit,
            );
          }
        }
      });
    }
  }
}

List<KachelEintrag> _alleEintraege(StatistikKachelDaten daten) {
  var n = 0;
  return [
    for (final d in KachelKatalog.definitionen)
      for (final g in d.groessen)
        KachelEintrag(id: 'k${n++}', typId: d.typId, groesse: g),
    for (final eigene in daten.einstellungen.eigeneKacheln)
      for (final g in StatistikKachelTypen.groessenFuer(
        StatistikKachelTypen.eigene,
      ))
        KachelEintrag(
          id: 'k${n++}',
          typId: StatistikKachelTypen.eigene,
          groesse: g,
          eigeneKachelId: eigene.id,
        ),
  ];
}

Future<void> _pruefen(
  WidgetTester tester, {
  required StatistikKachelDaten daten,
  required List<KachelEintrag> eintraege,
  required double breite,
  required double skala,
  required Brightness helligkeit,
}) async {
  final fall = 'Skala $skala, ${helligkeit.name}';
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(breite, 9000);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      // Neuer Baum je Fall, damit keine Übergänge vom letzten Fall laufen.
      key: ValueKey(fall),
      theme: buildTheme(AppPaletteId.standard, helligkeit),
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de'), Locale('en')],
      locale: const Locale('de'),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(skala)),
          // Wie in der Stamm-Ansicht: Text höchstens auf 1,4 skaliert.
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: AppPageHeader.maxTextScaleFactor,
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: KachelRaster(eintraege: eintraege, daten: daten),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  // Standorte lösen asynchron auf.
  await tester.pump();
  await tester.pump();
  expect(tester.takeException(), isNull, reason: fall);

  final kacheln = find.byType(KachelRahmen);
  expect(kacheln, findsNWidgets(eintraege.length), reason: fall);
  for (final element in kacheln.evaluate()) {
    final box = element.renderObject! as RenderBox;
    final rahmen = box.localToGlobal(Offset.zero) & box.size;
    final titel = (element.widget as KachelRahmen).titel;
    void besuchen(RenderObject kind) {
      if (kind is RenderParagraph && kind.hasSize) {
        final text = kind.localToGlobal(Offset.zero) & kind.size;
        // FittedBox schrumpft per Transformation; die Ecken zählen.
        final unten = kind.localToGlobal(kind.size.bottomRight(Offset.zero));
        final echt = Rect.fromPoints(text.topLeft, unten);
        expect(
          rahmen.inflate(0.5).contains(echt.topLeft) &&
              rahmen.inflate(0.5).contains(echt.bottomRight),
          isTrue,
          reason:
              '$fall: „${kind.text.toPlainText()}“ ragt aus „$titel“ '
              '($echt außerhalb von $rahmen)',
        );
      }
      kind.visitChildren(besuchen);
    }

    box.visitChildren(besuchen);
  }
}
