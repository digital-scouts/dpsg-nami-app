import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/data/statistiks/shared_prefs_statistik_kachel_repository.dart';
import 'package:nami/data/statistiks/shared_prefs_statistik_verlauf_repository.dart';
import 'package:nami/domain/statistiks/statistik_kachel_einstellungen.dart';
import 'package:nami/domain/statistiks/statistik_kachel_typen.dart';
import 'package:nami/domain/statistiks/statistik_verlauf.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/statistik_kacheln_model.dart';
import 'package:nami/presentation/screens/statistics_page.dart';
import 'package:nami/presentation/statistics/kacheln/kachel_bearbeiten.dart';
import 'package:nami/stories/statistik/statistik_beispiel_staemme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _heute = DateTime(2026, 9, 30);

void main() {
  late InMemoryStatistikKachelRepository repository;
  late StatistikKachelnModel model;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = InMemoryStatistikKachelRepository();
    model = StatistikKachelnModel(repository);
  });

  tearDown(() => model.dispose());

  Future<void> starten(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1400);
    addTearDown(tester.view.reset);
    final readModel = StatistikBeispielStaemme.weitblick(heute: _heute);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<StatistikKachelnModel>.value(value: model),
          Provider<StatistikVerlaufRepository>.value(
            value: InMemoryStatistikVerlaufRepository(),
          ),
        ],
        child: MaterialApp(
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
              debugHeute: _heute,
              debugStichtag: DateTime(2026, 11, 1),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> bearbeiten(WidgetTester tester) async {
    final knopf = find.byKey(const Key('statistik-bearbeiten'));
    await tester.ensureVisible(knopf);
    await tester.pump();
    await tester.tap(knopf);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Wackeln läuft endlos; Übergänge daher in festen Schritten.
  Future<void> warten(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('Bearbeiten zeigt Leiste und Fertig beendet es', (tester) async {
    await starten(tester);
    await bearbeiten(tester);

    expect(model.bearbeiten, isTrue);
    expect(find.text('Überblick bearbeiten'), findsOneWidget);
    expect(find.byType(KachelEntfernenKnopf), findsWidgets);
    expect(find.byKey(const Key('statistik-zielwerte')), findsOneWidget);

    await tester.tap(find.text('Fertig'));
    await tester.pump();
    expect(model.bearbeiten, isFalse);
    expect(find.byType(KachelEntfernenKnopf), findsNothing);
  });

  testWidgets('Entfernen lässt sich rückgängig machen', (tester) async {
    await starten(tester);
    await bearbeiten(tester);
    final vorher = [for (final e in model.einstellungen.ueberblick) e.id];

    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is KachelEntfernenKnopf && w.label == 'Geschlecht entfernen',
      ),
    );
    await warten(tester);
    expect(
      model.einstellungen.ueberblick.map((e) => e.typId),
      isNot(contains(StatistikKachelTypen.geschlecht)),
    );
    expect(find.text('„Geschlecht“ entfernt.'), findsOneWidget);

    await tester.tap(find.text('Rückgängig'));
    await warten(tester);
    expect([for (final e in model.einstellungen.ueberblick) e.id], vorher);
  });

  testWidgets('Themen-Chips blenden Tabs aus und wieder ein', (tester) async {
    await starten(tester);
    await bearbeiten(tester);

    await tester.tap(find.bySemanticsLabel('Stufen ausblenden'));
    await tester.pump();
    expect(model.einstellungen.stufenSichtbar, isFalse);
    await tester.tap(find.bySemanticsLabel('Stufen einblenden'));
    await tester.pump();
    expect(model.einstellungen.stufenSichtbar, isTrue);
  });

  testWidgets('Katalog bietet nur erlaubte Größen und fügt hinzu', (
    tester,
  ) async {
    await starten(tester);
    await bearbeiten(tester);

    await tester.tap(find.byTooltip('Kachel hinzufügen'));
    await warten(tester);
    expect(find.text('Eigene Kachel erstellen'), findsOneWidget);

    // Gruppen: 2×1 und 2×2, kein 1×1.
    await tester.ensureVisible(find.text('2×1 · 2×2').first);
    await tester.tap(find.text('2×1 · 2×2').first);
    await warten(tester);
    expect(
      find.descendant(
        of: find.byType(SegmentedButton<KachelGroesse>),
        matching: find.text('1×1'),
      ),
      findsNothing,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedButton<KachelGroesse>),
        matching: find.text('2×2'),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Hinzufügen'));
    await warten(tester);

    final neu = model.einstellungen.ueberblick.last;
    expect(neu.typId, StatistikKachelTypen.gruppen);
    expect(neu.groesse, KachelGroesse.gross);
  });

  testWidgets('Stufen hat im Katalog keine Größenwahl', (tester) async {
    await starten(tester);
    await bearbeiten(tester);
    await tester.tap(find.byTooltip('Kachel hinzufügen'));
    await warten(tester);

    // Die Zeile der Stufen nennt als einzige nur „2×1“.
    await tester.ensureVisible(find.text('2×1'));
    await tester.tap(find.text('2×1'));
    await warten(tester);
    expect(find.byType(SegmentedButton<KachelGroesse>), findsNothing);
    await tester.tap(find.text('Hinzufügen'));
    await warten(tester);
    expect(model.einstellungen.ueberblick.last.groesse, KachelGroesse.breit);
  });

  testWidgets('eigene Kachel anlegen, ohne Namen erst ein Hinweis', (
    tester,
  ) async {
    await starten(tester);
    await bearbeiten(tester);
    await tester.tap(find.byTooltip('Kachel hinzufügen'));
    await warten(tester);
    await tester.tap(find.byKey(const Key('katalog-eigene-kachel')));
    await warten(tester);

    final hinzufuegen = find.widgetWithText(FilledButton, 'Kachel hinzufügen');
    await tester.ensureVisible(hinzufuegen);
    await tester.tap(hinzufuegen);
    await tester.pump();
    expect(find.text('Bitte einen Namen eingeben.'), findsOneWidget);
    expect(model.einstellungen.eigeneKacheln, isEmpty);

    await tester.enterText(
      find.byKey(const Key('eigene-kachel-name')),
      'Alle mit Stufe',
    );
    await tester.pump();
    await tester.ensureVisible(hinzufuegen);
    await tester.tap(hinzufuegen);
    await warten(tester);

    expect(model.einstellungen.eigeneKacheln.single.titel, 'Alle mit Stufe');
    final eintrag = model.einstellungen.ueberblick.last;
    expect(eintrag.typId, StatistikKachelTypen.eigene);
    expect(eintrag.eigeneKachelId, model.einstellungen.eigeneKacheln.single.id);
    // Im Raster ohne Kennzeichnung als eigene Kachel, nur mit Namen.
    expect(find.text('Alle mit Stufe'), findsOneWidget);
  });

  testWidgets('Zielwerte werden beim Tippen gespeichert, leer = keins', (
    tester,
  ) async {
    await starten(tester);
    await bearbeiten(tester);

    final eintrag = find.byKey(const Key('statistik-zielwerte'));
    await tester.ensureVisible(eintrag);
    await tester.tap(eintrag);
    await warten(tester);
    expect(find.text('Zielwerte'), findsWidgets);

    await tester.enterText(find.byKey(const Key('zielwert-woelfling')), '14');
    await tester.enterText(find.byKey(const Key('zielwert-neu')), '10');
    await tester.pump();
    expect(model.einstellungen.ziele.gruppeMax, {Stufe.woelfling: 14});
    expect(model.einstellungen.ziele.neuProJahr, 10);

    await tester.enterText(find.byKey(const Key('zielwert-neu')), '');
    await tester.pump();
    expect(model.einstellungen.ziele.neuProJahr, isNull);
    expect(
      (await repository.loadForLayer(
        StatistikBeispielStaemme.weitblickLayerId,
      )).ziele.gruppeMax,
      {Stufe.woelfling: 14},
    );
  });

  testWidgets('Wechsel zu Bundesweit beendet das Bearbeiten', (tester) async {
    await starten(tester);
    await bearbeiten(tester);
    expect(model.bearbeiten, isTrue);

    await tester.tap(find.text('Bundesweit'));
    await warten(tester);
    expect(model.bearbeiten, isFalse);
  });

  testWidgets('Standard-Belegung ohne gespeicherte Einstellungen', (
    tester,
  ) async {
    await starten(tester);
    expect(
      model.einstellungen.ueberblick,
      StatistikKachelEinstellungen.standardUeberblick,
    );
  });
}
