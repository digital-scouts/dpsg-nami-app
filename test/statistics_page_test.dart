import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/data/statistiks/shared_prefs_statistik_kachel_repository.dart';
import 'package:nami/data/statistiks/shared_prefs_statistik_verlauf_repository.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/bundesstatistik/statistik_abdeckung.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/statistiks/statistik_kachel_einstellungen.dart';
import 'package:nami/domain/statistiks/statistik_kachel_typen.dart';
import 'package:nami/domain/statistiks/statistik_verlauf.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/navigation/app_router.dart';
import 'package:nami/presentation/screens/statistics_group_detail_page.dart';
import 'package:nami/presentation/screens/statistics_page.dart';
import 'package:nami/presentation/statistics/statistik_kopf_zeile.dart';
import 'package:nami/presentation/statistics/statistik_stamm_ansicht.dart';
import 'package:nami/presentation/widgets/app_page_header.dart';
import 'package:nami/stories/statistik/statistik_beispiel_staemme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/page_header_height.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('zeigt Personen und Stufenband im Kopf und beide Tabs', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(_buildReadModel()));
    await tester.pump();

    final header = find.byType(AppPageHeader);
    expect(header, findsOneWidget);
    expect(
      find.descendant(of: header, matching: find.byType(StatistikKopfZeile)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: header, matching: find.text('Personen')),
      findsOneWidget,
    );
    // Der Stammesname ersetzt "Stamm" im Tab-Switch.
    expect(
      tester
          .widget<Text>(find.byKey(const Key('statistics-header-title')))
          .data,
      'Stamm Testdorf',
    );

    await tester.tap(find.text('Bundesweit'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Der bundesweite Vergleich ist in dieser App-Version nicht verfügbar.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Statistik-Header folgt dem Header-Raster', (tester) async {
    await expectPageHeaderMatchesRaster(
      tester,
      () => _buildTestApp(_buildReadModel()),
    );
  });

  testWidgets('zeigt keine Global-Ansicht mehr', (tester) async {
    await tester.pumpWidget(_buildTestApp(_buildReadModel()));
    await tester.pump();

    expect(find.text('Global'), findsNothing);
  });

  testWidgets('wechselt zwischen Überblick, Stufen und Entwicklung', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(_buildReadModel()));
    await tester.pump();

    expect(_themenLeiste, findsOneWidget);
    expect(find.text('Gruppen'), findsOneWidget);
    expect(find.text('Geschlecht'), findsOneWidget);
    expect(find.text('Altersstruktur'), findsNothing);

    await tester.tap(find.text('Stufen'));
    await tester.pumpAndSettle();
    expect(find.text('Altersstruktur'), findsOneWidget);
    expect(find.text('Alter in Zahlen'), findsOneWidget);
    expect(find.text('Geschlecht'), findsNothing);

    await tester.tap(find.text('Entwicklung'));
    await tester.pumpAndSettle();
    expect(find.text('Stufenwechsel'), findsOneWidget);
    expect(find.text('Verlauf'), findsOneWidget);
    expect(find.text('Altersstruktur'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blendet ausgeblendete Themen und ohne sie die Leiste aus', (
    tester,
  ) async {
    final repository = InMemoryStatistikKachelRepository();
    await repository.saveForLayer(
      11,
      const StatistikKachelEinstellungen(stufenSichtbar: false),
    );
    await tester.pumpWidget(
      _buildTestApp(_buildReadModel(), kacheln: repository),
    );
    await tester.pumpAndSettle();

    expect(find.text('Stufen'), findsNothing);
    expect(find.text('Entwicklung'), findsOneWidget);

    await repository.saveForLayer(
      11,
      const StatistikKachelEinstellungen(
        stufenSichtbar: false,
        entwicklungSichtbar: false,
      ),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      _buildTestApp(_buildReadModel(), kacheln: repository),
    );
    await tester.pumpAndSettle();

    expect(_themenLeiste, findsNothing);
    expect(find.text('Gruppen'), findsOneWidget);
  });

  testWidgets('oeffnet Gruppendetailseite aus der Gruppenzeile', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(_buildReadModel()));
    await tester.pump();

    await tester.tap(find.text('Stufen'));
    await tester.pumpAndSettle();
    // Die Zeile zeigt Name und Untertitel als einen Rich-Text.
    await tester.tap(find.textContaining('Meute Nord', findRichText: true));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.text('Meute Nord'), findsAtLeastNWidgets(1));
    // Dieselben Kacheln wie im Stamm, in fester Belegung.
    expect(find.text('Personen'), findsOneWidget);
    expect(find.text('Altersstruktur'), findsOneWidget);
  });

  testWidgets('zeigt bei Teilsicht nur den Überblick der lesbaren Gruppe', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        _buildReadModelMitZweiGruppen(),
        kacheln: InMemoryStatistikKachelRepository(),
        abdeckung: StatistikAbdeckung.gruppen({21}),
      ),
    );
    await tester.pumpAndSettle();

    expect(_themenLeiste, findsNothing);
    // Standardbelegung bei Teilsicht: mit Altersstruktur in 2×1.
    expect(find.text('Altersstruktur'), findsOneWidget);
    // Nur die lesbare Meute, eine Spalte je Gruppe.
    expect(find.byKey(const Key('gruppen-spalte-21')), findsOneWidget);
    expect(find.byKey(const Key('gruppen-spalte-22')), findsNothing);
    expect(find.text('Meute Süd'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.byKey(const Key('statistik-bearbeiten')),
      200,
      scrollable: _statistikListe,
    );
    await tester.tap(find.byKey(const Key('statistik-bearbeiten')));
    await _warten(tester);
    // Stufen und Entwicklung lassen sich bei Teilsicht nicht einblenden.
    expect(find.text('Entwicklung'), findsNothing);
  });

  testWidgets('setzt den Überblick nach Bestätigung zurück', (tester) async {
    final repository = InMemoryStatistikKachelRepository();
    await repository.saveForLayer(
      11,
      const StatistikKachelEinstellungen(
        ueberblick: [
          KachelEintrag(
            id: 'nur-geschlecht',
            typId: 'geschlecht',
            groesse: KachelGroesse.klein,
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      _buildTestApp(_buildReadModel(), kacheln: repository),
    );
    await _warten(tester);
    expect(find.text('Gruppen'), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const Key('statistik-bearbeiten')),
      200,
      scrollable: _statistikListe,
    );
    await tester.tap(find.byKey(const Key('statistik-bearbeiten')));
    await _warten(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('statistik-zuruecksetzen')),
      200,
      scrollable: _statistikListe,
    );
    await tester.tap(find.byKey(const Key('statistik-zuruecksetzen')));
    await _warten(tester);
    expect(find.text('Überblick zurücksetzen?'), findsOneWidget);

    await tester.tap(find.text('Abbrechen'));
    await _warten(tester);
    expect((await repository.loadForLayer(11)).ueberblick.map((e) => e.id), [
      'nur-geschlecht',
    ]);

    await tester.tap(find.byKey(const Key('statistik-zuruecksetzen')));
    await _warten(tester);
    await tester.tap(
      find.byKey(const Key('statistik-zuruecksetzen-bestaetigen')),
    );
    await _warten(tester);
    expect(
      (await repository.loadForLayer(11)).ueberblick.map((e) => e.id),
      StatistikKachelEinstellungen.standardUeberblick.map((e) => e.id),
    );
  });

  testWidgets('wechselt auf der Detailseite über den Titel die Gruppe', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de'), Locale('en')],
        locale: const Locale('de'),
        home: StatisticsGroupDetailPage(
          groupId: '21',
          debugReadModel: _buildReadModelMitZweiGruppen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Meute Nord'), findsOneWidget);

    await tester.tap(find.byKey(const Key('gruppe-wechseln')));
    await tester.pumpAndSettle();
    expect(find.text('Gruppe wechseln'), findsOneWidget);
    await tester.tap(find.byKey(const Key('gruppen-auswahl-22')));
    await tester.pumpAndSettle();

    expect(find.text('Meute Süd'), findsOneWidget);
    expect(find.text('Meute Nord'), findsNothing);
  });

  testWidgets('bleibt mit krummen Daten in allen Themen stabil', (
    tester,
  ) async {
    final heute = DateTime(2026, 9, 30);
    final readModel = StatistikBeispielStaemme.querfeld(heute: heute);
    final repository = InMemoryStatistikKachelRepository();
    await repository.saveForLayer(
      readModel.arbeitskontext.aktiverLayer.id,
      StatistikBeispielStaemme.einstellungenQuerfeld(),
    );
    await tester.pumpWidget(
      _buildTestApp(readModel, kacheln: repository, heute: heute),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Stamm Querfeld'), findsOneWidget);

    for (final thema in ['Stufen', 'Entwicklung']) {
      await tester.tap(find.text(thema));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: thema);
    }
  });
}

final _themenLeiste = find.descendant(
  of: find.byType(StatistikStammAnsicht),
  matching: find.byType(TabBar),
);

Widget _buildTestApp(
  ArbeitskontextReadModel readModel, {
  StatistikKachelRepository? kacheln,
  DateTime? heute,
  StatistikAbdeckung? abdeckung,
}) {
  final app = MaterialApp(
    onGenerateRoute: onGenerateRoute,
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('de'), Locale('en')],
    locale: const Locale('de'),
    home: Scaffold(
      body: StatisticsPage(
        debugReadModel: readModel,
        debugHeute: heute,
        debugAbdeckung: abdeckung,
      ),
    ),
  );
  if (kacheln == null) return app;
  return MultiProvider(
    providers: [
      Provider<StatistikKachelRepository>.value(value: kacheln),
      Provider<StatistikVerlaufRepository>.value(
        value: InMemoryStatistikVerlaufRepository(),
      ),
    ],
    child: app,
  );
}

// Der Bearbeiten-Modus wackelt dauerhaft; pumpAndSettle käme nie zur Ruhe.
Future<void> _warten(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder get _statistikListe => find
    .descendant(
      of: find.byType(StatistikStammAnsicht),
      matching: find.byType(Scrollable),
    )
    .last;

ArbeitskontextReadModel _buildReadModelMitZweiGruppen() {
  final basis = _buildReadModel();
  return basis.copyWith(
    mitglieder: [
      ...basis.mitglieder,
      Mitglied.peopleListItem(
        mitgliedsnummer: '3',
        vorname: 'Sina',
        nachname: 'Süd',
      ),
    ],
    gruppen: [
      ...basis.gruppen,
      const ArbeitskontextGruppe(
        id: 22,
        name: 'Meute Süd',
        layerId: 11,
        gruppenTyp: 'Group::StammGruppeWoelflinge',
      ),
    ],
    mitgliedsZuordnungen: [
      ...basis.mitgliedsZuordnungen,
      const ArbeitskontextMitgliedsZuordnung(
        mitgliedsnummer: '3',
        gruppenId: 22,
        rollenLabel: 'Mitglied',
      ),
    ],
  );
}

ArbeitskontextReadModel _buildReadModel() {
  return ArbeitskontextReadModel(
    arbeitskontext: Arbeitskontext(
      aktiverLayer: const ArbeitskontextLayer(id: 11, name: 'Stamm Testdorf'),
    ),
    mitglieder: <Mitglied>[
      Mitglied.peopleListItem(
        mitgliedsnummer: '1',
        vorname: 'Mara',
        nachname: 'Nord',
      ),
      Mitglied.peopleListItem(
        mitgliedsnummer: '2',
        vorname: 'Lena',
        nachname: 'Leitung',
      ),
    ],
    gruppen: const <ArbeitskontextGruppe>[
      ArbeitskontextGruppe(
        id: 21,
        name: 'Meute Nord',
        layerId: 11,
        gruppenTyp: 'Group::StammGruppeWoelflinge',
      ),
    ],
    mitgliedsZuordnungen: const <ArbeitskontextMitgliedsZuordnung>[
      ArbeitskontextMitgliedsZuordnung(
        mitgliedsnummer: '1',
        gruppenId: 21,
        rollenLabel: 'Mitglied',
      ),
      ArbeitskontextMitgliedsZuordnung(
        mitgliedsnummer: '2',
        gruppenId: 21,
        rollenLabel: 'Hilfsleiter',
      ),
    ],
  );
}
