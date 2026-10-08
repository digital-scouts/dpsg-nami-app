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
import 'package:nami/domain/bundesstatistik/statistik_abdeckung.dart';
import 'package:nami/domain/supporter/supporter_kauf_repository.dart';
import 'package:nami/presentation/model/supporter_kauf_model.dart';
import 'package:nami/presentation/navigation/app_router.dart';
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

import 'support/fake_supporter_store_client.dart';

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
    SupporterKaufModel? kauf,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: einstellungen),
          if (kauf != null) ChangeNotifierProvider.value(value: kauf),
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
          routes: {
            AppRoutes.supporter: (_) => const Scaffold(body: Text('Kaufseite')),
          },
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

  testWidgets('gesperrt zeigt, was die Uebersicht mit den Rechten bringt', (
    tester,
  ) async {
    final readModel = _readModel().copyWith(
      gruppen: const [
        ArbeitskontextGruppe(id: 22, name: 'Trupp Kompass', layerId: 11),
      ],
    );
    Future<void> zeige(StatistikAbdeckung abdeckung) => pumpSeite(
      tester,
      SettingsQualifikationenPage(
        key: UniqueKey(),
        readModel: readModel,
        heuteProvider: _heute,
        abdeckung: abdeckung,
      ),
      supporter: false,
    );

    await zeige(const StatistikAbdeckung.stamm());
    expect(find.byKey(const Key('quali-nutzen-hilft')), findsOneWidget);
    expect(find.text('Hilft dir'), findsOneWidget);

    await zeige(StatistikAbdeckung.gruppen({22}, vollLesbareGruppenIds: {22}));
    expect(find.byKey(const Key('quali-nutzen-teilweise')), findsOneWidget);
    expect(find.textContaining('Du darfst Trupp Kompass'), findsOneWidget);

    await zeige(
      StatistikAbdeckung.gruppen(const <int>{}, gruppenOhneRollen: {22}),
    );
    expect(find.byKey(const Key('quali-nutzen-hilftNicht')), findsOneWidget);
    expect(
      find.textContaining('Du hast nur Leserecht auf Trupp Kompass'),
      findsOneWidget,
    );
  });

  testWidgets('mit Store wirbt die Sperrseite nur, wenn die Übersicht hilft', (
    tester,
  ) async {
    final kauf = SupporterKaufModel(
      client: FakeSupporterStoreClient(),
      repository: InMemorySupporterKaufRepository(),
    );
    await kauf.start();
    final readModel = _readModel().copyWith(
      gruppen: const [
        ArbeitskontextGruppe(id: 22, name: 'Trupp Kompass', layerId: 11),
      ],
    );
    Future<void> zeige(StatistikAbdeckung abdeckung) => pumpSeite(
      tester,
      SettingsQualifikationenPage(
        key: UniqueKey(),
        readModel: readModel,
        heuteProvider: _heute,
        abdeckung: abdeckung,
      ),
      supporter: false,
      kauf: kauf,
    );

    await zeige(const StatistikAbdeckung.stamm());
    expect(find.byKey(const Key('supporter-foerderer-karte')), findsOneWidget);
    expect(find.byKey(const Key('quali-foerderer-link')), findsNothing);

    await zeige(StatistikAbdeckung.gruppen({22}, vollLesbareGruppenIds: {22}));
    expect(find.byKey(const Key('supporter-foerderer-karte')), findsOneWidget);

    await zeige(
      StatistikAbdeckung.gruppen(const <int>{}, gruppenOhneRollen: {22}),
    );
    expect(find.byKey(const Key('supporter-foerderer-karte')), findsNothing);
    await tester.tap(find.byKey(const Key('quali-foerderer-link')));
    await tester.pumpAndSettle();
    expect(find.text('Kaufseite'), findsOneWidget);
  });

  testWidgets('ohne Store bleibt die Sperrseite ohne Kaufweg', (tester) async {
    await pumpSeite(
      tester,
      SettingsQualifikationenPage(
        readModel: _readModel(),
        heuteProvider: _heute,
        abdeckung: const StatistikAbdeckung.stamm(),
      ),
      supporter: false,
    );

    expect(find.byKey(const Key('supporter-foerderer-karte')), findsNothing);
    expect(find.byKey(const Key('quali-foerderer-link')), findsNothing);
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
