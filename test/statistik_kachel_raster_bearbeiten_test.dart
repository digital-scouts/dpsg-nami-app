import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/statistiks/statistik_kachel_einstellungen.dart';
import 'package:nami/domain/statistiks/statistik_kachel_typen.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/statistics/kacheln/kachel_bearbeiten.dart';
import 'package:nami/presentation/statistics/kacheln/kachel_rahmen.dart';
import 'package:nami/presentation/statistics/kacheln/kachel_raster.dart';
import 'package:nami/stories/statistik/statistik_kachel_beispiele.dart';

/// Protokoll der Rückmeldungen aus dem Raster.
class _Aufrufe {
  final verschoben = <(int, int)>[];
  final groessen = <(String, KachelGroesse)>[];
  final entfernt = <String>[];

  KachelRasterBearbeitung get bearbeitung => KachelRasterBearbeitung(
    onVerschieben: (von, nach) => verschoben.add((von, nach)),
    onGroesse: (e, g) => groessen.add((e.id, g)),
    onEntfernen: (e) => entfernt.add(e.id),
  );
}

const _eintraege = [
  KachelEintrag(
    id: 'a',
    typId: StatistikKachelTypen.personen,
    groesse: KachelGroesse.klein,
  ),
  KachelEintrag(
    id: 'b',
    typId: StatistikKachelTypen.geschlecht,
    groesse: KachelGroesse.klein,
  ),
  KachelEintrag(
    id: 'c',
    typId: StatistikKachelTypen.gruppen,
    groesse: KachelGroesse.breit,
  ),
  KachelEintrag(
    id: 'd',
    typId: StatistikKachelTypen.konfession,
    groesse: KachelGroesse.klein,
  ),
  KachelEintrag(
    id: 'e',
    typId: StatistikKachelTypen.bindung,
    groesse: KachelGroesse.klein,
  ),
  KachelEintrag(
    id: 'f',
    typId: StatistikKachelTypen.stufen,
    groesse: KachelGroesse.breit,
  ),
  KachelEintrag(
    id: 'g',
    typId: StatistikKachelTypen.stufenwechsel,
    groesse: KachelGroesse.gross,
  ),
];

Widget _app({
  required KachelRasterBearbeitung? bearbeitung,
  bool bewegungAus = false,
  List<KachelEintrag> eintraege = _eintraege,
  ScrollController? scroll,
}) {
  final daten = StatistikKachelBeispiele.daten(
    StatistikBeispielDatensatz.weitblick,
  );
  return MaterialApp(
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
        data: MediaQuery.of(context).copyWith(disableAnimations: bewegungAus),
        child: Scaffold(
          body: ListView(
            controller: scroll,
            children: [
              KachelRaster(
                eintraege: eintraege,
                daten: daten,
                bearbeitung: bearbeitung,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Drehungen direkt um die Kacheln (das Wackeln).
final _wackelTransforms = find.ancestor(
  of: find.byType(KachelRahmen),
  matching: find.byType(Transform),
);

Finder _kachel(String titel) =>
    find.ancestor(of: find.text(titel), matching: find.byType(KachelRahmen));

void _flaeche(WidgetTester tester, {double hoehe = 900}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(390, hoehe);
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('langes Drücken und Ziehen sortiert die Kachel um', (
    tester,
  ) async {
    _flaeche(tester);
    final aufrufe = _Aufrufe();
    await tester.pumpWidget(_app(bearbeitung: aufrufe.bearbeitung));
    await tester.pump();

    final start = tester.getCenter(_kachel('Personen'));
    final ziel = tester.getCenter(_kachel('Konfession'));
    final geste = await tester.startGesture(start);
    await tester.pump(
      KachelRaster.ziehenNach + const Duration(milliseconds: 40),
    );
    expect(find.byType(KachelPlatzhalter), findsOneWidget);
    await geste.moveTo(Offset.lerp(start, ziel, 0.5)!);
    await tester.pump();
    await geste.moveTo(ziel);
    await tester.pump();
    await geste.up();
    await tester.pump();

    expect(aufrufe.verschoben, hasLength(1));
    final (von, nach) = aufrufe.verschoben.single;
    expect(von, 0);
    expect(nach, greaterThan(0));
    expect(find.byType(KachelPlatzhalter), findsNothing);
  });

  testWidgets('kurzes Wischen über eine Kachel scrollt weiter', (tester) async {
    _flaeche(tester, hoehe: 600);
    final aufrufe = _Aufrufe();
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      _app(bearbeitung: aufrufe.bearbeitung, scroll: scroll),
    );
    await tester.pump();

    await tester.drag(_kachel('Personen'), const Offset(0, -250));
    await tester.pump(const Duration(milliseconds: 300));

    expect(scroll.offset, greaterThan(100));
    expect(aufrufe.verschoben, isEmpty);
  });

  testWidgets('Eckgriff zeigt Geist mit Badge und rastet ein', (tester) async {
    _flaeche(tester);
    final aufrufe = _Aufrufe();
    await tester.pumpWidget(_app(bearbeitung: aufrufe.bearbeitung));
    await tester.pump();

    final griff = find.descendant(
      of: find
          .ancestor(of: _kachel('Geschlecht'), matching: find.byType(Stack))
          .first,
      matching: find.byType(KachelGroessenGriff),
    );
    final zug = await tester.startGesture(tester.getCenter(griff));
    await tester.pump();
    await zug.moveBy(const Offset(30, 0));
    await tester.pump();
    await zug.moveBy(const Offset(120, 0));
    await tester.pump();
    expect(find.byType(KachelGroessenGeist), findsOneWidget);
    expect(find.text('2×1'), findsOneWidget);
    await zug.up();
    await tester.pump();

    expect(aufrufe.groessen, [('b', KachelGroesse.breit)]);
    expect(find.byType(KachelGroessenGeist), findsNothing);
  });

  testWidgets('Kacheln mit nur einer Größe haben keinen Griff', (tester) async {
    _flaeche(tester, hoehe: 1600);
    await tester.pumpWidget(_app(bearbeitung: _Aufrufe().bearbeitung));
    await tester.pump();

    // 7 Kacheln, Stufen gibt es nur als 2×1.
    expect(find.byType(KachelGroessenGriff), findsNWidgets(6));
    expect(find.byType(KachelEntfernenKnopf), findsNWidgets(7));
  });

  testWidgets('Minus meldet die Kachel zum Entfernen', (tester) async {
    _flaeche(tester);
    final aufrufe = _Aufrufe();
    await tester.pumpWidget(_app(bearbeitung: aufrufe.bearbeitung));
    await tester.pump();

    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is KachelEntfernenKnopf && w.label == 'Geschlecht entfernen',
      ),
    );
    await tester.pump();
    expect(aufrufe.entfernt, ['b']);
  });

  testWidgets('Semantics-Aktionen ersetzen die Gesten', (tester) async {
    _flaeche(tester);
    final semantics = tester.ensureSemantics();
    final aufrufe = _Aufrufe();
    await tester.pumpWidget(_app(bearbeitung: aufrufe.bearbeitung));
    await tester.pump();

    final knoten = tester.getSemantics(
      find
          .ancestor(
            of: _kachel('Geschlecht'),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Semantics && w.properties.customSemanticsActions != null,
            ),
          )
          .first,
    );
    final aktionen = knoten.getSemanticsData().customSemanticsActionIds!;
    String label(int id) => CustomSemanticsAction.getAction(id)!.label ?? '';
    expect(
      aktionen.map(label),
      containsAll(['Nach vorne', 'Nach hinten', 'Größe 2×1', 'Entfernen']),
    );
    expect(aktionen.map(label), isNot(contains('Größe 1×1')));

    void ausfuehren(String text) {
      final id = aktionen.firstWhere((a) => label(a) == text);
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(
          type: SemanticsAction.customAction,
          nodeId: knoten.id,
          viewId: tester.view.viewId,
          arguments: id,
        ),
      );
    }

    ausfuehren('Nach hinten');
    ausfuehren('Größe 2×1');
    ausfuehren('Entfernen');
    expect(aufrufe.verschoben, [(1, 2)]);
    expect(aufrufe.groessen, [('b', KachelGroesse.breit)]);
    expect(aufrufe.entfernt, ['b']);
    semantics.dispose();
  });

  testWidgets('Ziele erfüllen die Tap-Target-Richtlinie', (tester) async {
    _flaeche(tester, hoehe: 1600);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(bearbeitung: _Aufrufe().bearbeitung));
    await tester.pump();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('ohne Bewegung wackelt nichts und alles kommt zur Ruhe', (
    tester,
  ) async {
    _flaeche(tester);
    await tester.pumpWidget(
      _app(bearbeitung: _Aufrufe().bearbeitung, bewegungAus: true),
    );
    await tester.pumpAndSettle();

    final drehungen = tester
        .widgetList<Transform>(_wackelTransforms)
        .map((t) => t.transform.getRotation().entry(0, 1))
        .where((sin) => sin.abs() > 1e-9);
    expect(drehungen, isEmpty);
  });

  testWidgets('mit Bewegung wackeln die Kacheln leicht', (tester) async {
    _flaeche(tester);
    await tester.pumpWidget(_app(bearbeitung: _Aufrufe().bearbeitung));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 60));

    final winkel = tester
        .widgetList<Transform>(_wackelTransforms)
        .map((t) => t.transform.getRotation().entry(1, 0).abs())
        .where((sin) => sin > 1e-6)
        .toList();
    expect(winkel, isNotEmpty);
    // Höchstens 0,45°.
    expect(winkel.every((sin) => sin <= 0.0079), isTrue);
    // Wackeln wiederholt sich: kein pumpAndSettle, sauber beenden.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('ohne Bearbeitung keine Bedienelemente', (tester) async {
    _flaeche(tester);
    await tester.pumpWidget(_app(bearbeitung: null));
    await tester.pumpAndSettle();
    expect(find.byType(KachelEntfernenKnopf), findsNothing);
    expect(find.byType(KachelGroessenGriff), findsNothing);
  });
}
