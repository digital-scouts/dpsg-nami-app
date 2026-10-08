import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nami/data/appearance/in_memory_appearance_settings_repository.dart';
import 'package:nami/demo/demo_services.dart';
import 'package:nami/domain/appearance/support_access.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/arbeitskontext/teildaten_stand.dart';
import 'package:nami/domain/qualifikation/personenkreis.dart';
import 'package:nami/domain/qualifikation/qualifikations_einstellungen.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/appearance_model.dart';
import 'package:nami/presentation/model/qualifikations_einstellungen_model.dart';
import 'package:nami/presentation/screens/qualifikationen/qualifikation_einstellungen_page.dart';
import 'package:nami/presentation/screens/qualifikationen/qualifikationen_auswahl_page.dart';
import 'package:nami/presentation/screens/settings_qualifikationen_page.dart';
import 'package:nami/services/app_icon_service.dart';
import 'package:nami/stories/support/mitglied_edge_cases.dart';
import 'package:provider/provider.dart';

ArbeitskontextReadModel _readModel({
  TeildatenStand efzStand = TeildatenStand.geladen,
}) => ArbeitskontextReadModel(
  arbeitskontext: Arbeitskontext(
    aktiverLayer: const ArbeitskontextLayer(
      id: 11,
      name: MitgliedEdgeCases.stamm,
    ),
    verfuegbareLayer: const <ArbeitskontextLayer>[],
  ),
  mitglieder: MitgliedEdgeCases.alle.values.toList(),
  efzStand: efzStand,
  efzEinsichtnahmen: MitgliedEdgeCases.efzEinsichtnahmen,
  qualifikationenStand: TeildatenStand.geladen,
  qualifikationen: MitgliedEdgeCases.qualifikationen,
);

DateTime _heute() => MitgliedEdgeCases.heute;

void main() {
  setUpAll(() => initializeDateFormatting('de'));

  late QualifikationsEinstellungenModel einstellungen;

  setUp(() async {
    einstellungen = QualifikationsEinstellungenModel(
      InMemoryQualifikationsEinstellungenRepository(),
    );
    await einstellungen.load();
  });

  Future<void> pumpSeite(
    WidgetTester tester,
    Widget seite, {
    bool supporter = true,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: einstellungen),
          ChangeNotifierProvider.value(
            value: AppearanceModel(
              repository: InMemoryAppearanceSettingsRepository(),
              appIconService: FakeAppIconService(),
              access: SchalterSupportAccess(
                supporter
                    ? SupporterTestZugang.foerderer
                    : SupporterTestZugang.keiner,
              ),
            ),
          ),
        ],
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

  testWidgets('Uebersicht zeigt die Vorgaben mit Zaehlung', (tester) async {
    await pumpSeite(
      tester,
      SettingsQualifikationenPage(
        readModel: _readModel(),
        heuteProvider: _heute,
      ),
    );

    expect(find.byKey(const Key('quali-zeile-efz')), findsOneWidget);
    expect(find.byKey(const Key('quali-zeile-hitobito:14')), findsOneWidget);
    expect(find.byKey(const Key('quali-zeile-hitobito:9')), findsOneWidget);
    // Woodbadge ist keine Vorgabe und bleibt ausgeblendet.
    expect(find.byKey(const Key('quali-zeile-hitobito:3')), findsNothing);
    expect(find.text('Erweitertes Führungszeugnis'), findsOneWidget);
    // EFZ: Funke (bald) und Sami gueltig, Petra und Tim fehlen.
    expect(find.text('2/4', findRichText: true), findsWidgets);
  });

  testWidgets('ohne Foerderer-Abo erscheint nur der Hinweis', (tester) async {
    await pumpSeite(
      tester,
      SettingsQualifikationenPage(
        readModel: _readModel(),
        heuteProvider: _heute,
      ),
      supporter: false,
    );

    expect(find.text('Teil des Förderer-Abos'), findsOneWidget);
    expect(find.byKey(const Key('quali-zeile-efz')), findsNothing);
    expect(find.byKey(const Key('quali-auswahl-oeffnen')), findsNothing);
  });

  testWidgets('ohne EFZ-Recht ist nur die EFZ-Zeile gesperrt', (tester) async {
    await pumpSeite(
      tester,
      SettingsQualifikationenPage(
        readModel: _readModel(efzStand: TeildatenStand.keineBerechtigung),
        heuteProvider: _heute,
      ),
    );

    expect(find.text('Keine Berechtigung für EFZ-Einsicht'), findsOneWidget);
    expect(find.byKey(const Key('quali-zeile-hitobito:14')), findsOneWidget);
  });

  testWidgets('Auswahl blendet eine Art ein und speichert die Reihenfolge', (
    tester,
  ) async {
    await pumpSeite(
      tester,
      QualifikationenAuswahlPage(
        readModel: _readModel(),
        heuteProvider: _heute,
      ),
    );

    await tester.tap(find.byKey(const Key('quali-anzeigen-hitobito:3')));
    await tester.pumpAndSettle();

    final gespeichert = einstellungen.einstellungen;
    expect(gespeichert.art('hitobito:3').angezeigt, isTrue);
    expect(gespeichert.reihenfolge.last, 'hitobito:3');
    expect(gespeichert.reihenfolge.first, QualifikationsSchluessel.efz);
  });

  testWidgets('Einstellungen: Regel hinzufuegen, Erinnerung aendern', (
    tester,
  ) async {
    await pumpSeite(
      tester,
      QualifikationEinstellungenPage(
        schluessel: QualifikationsSchluessel.efz,
        readModel: _readModel(),
        heuteProvider: _heute,
      ),
    );

    await tester.tap(find.byKey(const Key('quali-regel-hinzufuegen')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quali-regeltyp-alterAb')));
    await tester.pumpAndSettle();

    final kreis = einstellungen.einstellungen
        .art(QualifikationsSchluessel.efz)
        .personenkreis!;
    expect(kreis.regeln, hasLength(3));
    expect(kreis.regeln.last.typ, PersonenkreisRegelTyp.alterAb);

    await tester.tap(find.byKey(const Key('quali-regel-verknuepfung-2')));
    await tester.pumpAndSettle();
    expect(
      einstellungen.einstellungen
          .art(QualifikationsSchluessel.efz)
          .personenkreis!
          .regeln
          .last
          .verknuepfung,
      RegelVerknuepfung.und,
    );

    await tester.tap(find.byKey(const Key('quali-nur-von-mir')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quali-tage-mehr')));
    await tester.pumpAndSettle();

    final erinnerung = einstellungen.einstellungen
        .art(QualifikationsSchluessel.efz)
        .erinnerung!;
    expect(erinnerung.vonWem, ErinnerungVonWem.ich);
    expect(erinnerung.tageVorher, 91);
  });

  test('Qualifikationen gibt es nur mit dem Foerderer-Abo', () {
    expect(
      const SchalterSupportAccess(
        SupporterTestZugang.keiner,
      ).qualifikationenFrei,
      isFalse,
    );
    expect(
      const SchalterSupportAccess(SupporterTestZugang.wald).qualifikationenFrei,
      isFalse,
    );
    expect(
      const SchalterSupportAccess(
        SupporterTestZugang.foerderer,
      ).qualifikationenFrei,
      isTrue,
    );
  });
}
