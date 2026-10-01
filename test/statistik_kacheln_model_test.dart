import 'package:flutter_test/flutter_test.dart';
import 'package:nami/data/statistiks/shared_prefs_statistik_kachel_repository.dart';
import 'package:nami/domain/member_filters/member_custom_filter.dart';
import 'package:nami/domain/statistiks/statistik_kachel_einstellungen.dart';
import 'package:nami/domain/statistiks/statistik_kachel_typen.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/presentation/model/statistik_kacheln_model.dart';
import 'package:nami/presentation/statistics/statistik_stamm_ansicht.dart';

void main() {
  late InMemoryStatistikKachelRepository repository;
  late StatistikKachelnModel model;
  var n = 0;

  setUp(() async {
    repository = InMemoryStatistikKachelRepository();
    n = 0;
    model = StatistikKachelnModel(repository, neueId: () => 'neu${n++}');
    await model.ensureLoadedForLayer(1);
  });

  List<String> ids() => [for (final e in model.einstellungen.ueberblick) e.id];

  EigeneKachel eigene(String id) => EigeneKachel(
    id: id,
    titel: 'Vorstand',
    filter: MemberCustomFilterGroup(
      id: id,
      shortLabel: 'Vorstand',
      isActive: true,
      logic: MemberCustomFilterLogic.oder,
      rules: const [
        MemberCustomFilterRule(
          operator: MemberCustomFilterRuleOperator.hat,
          criterion: MemberCustomFilterCriterion.stufe(),
        ),
      ],
    ),
  );

  test('lädt je Stamm und speichert jede Änderung sofort', () async {
    expect(model.einstellungen.ueberblick, isNotEmpty);
    model.verschieben(0, 2);
    final gespeichert = await repository.loadForLayer(1);
    expect(gespeichert.ueberblick.map((e) => e.id).toList(), ids());

    await model.ensureLoadedForLayer(2);
    expect(model.layerId, 2);
    expect(
      model.einstellungen.ueberblick,
      StatistikKachelEinstellungen.standardUeberblick,
    );
    await model.ensureLoadedForLayer(1);
    expect(ids(), gespeichert.ueberblick.map((e) => e.id).toList());
  });

  test('Stammwechsel beendet das Bearbeiten', () async {
    model.bearbeitenStarten();
    expect(model.bearbeiten, isTrue);
    await model.ensureLoadedForLayer(2);
    expect(model.bearbeiten, isFalse);
  });

  test('verschieben klemmt das Ziel und ignoriert ungültige Indizes', () {
    final vorher = ids();
    model.verschieben(0, 99);
    expect(ids().last, vorher.first);
    model.verschieben(-1, 0);
    model.verschieben(99, 0);
    expect(ids().length, vorher.length);
  });

  test('groesseSetzen nimmt nur erlaubte Größen an', () {
    final gruppen = model.einstellungen.ueberblick.firstWhere(
      (e) => e.typId == StatistikKachelTypen.gruppen,
    );
    model.groesseSetzen(gruppen.id, KachelGroesse.klein);
    expect(_eintrag(model, gruppen.id).groesse, KachelGroesse.breit);
    model.groesseSetzen(gruppen.id, KachelGroesse.gross);
    expect(_eintrag(model, gruppen.id).groesse, KachelGroesse.gross);
  });

  test('entfernen und wiederherstellen an alter Stelle', () {
    final vorher = ids();
    final entfernt = model.entfernen(vorher[1])!;
    expect(ids(), isNot(contains(vorher[1])));
    model.wiederherstellen(entfernt.$1, entfernt.$2);
    expect(ids(), vorher);
    // Doppelt wiederherstellen ändert nichts.
    model.wiederherstellen(entfernt.$1, entfernt.$2);
    expect(ids(), vorher);
    expect(model.entfernen('gibt-es-nicht'), isNull);
  });

  test('hinzufuegen rastet auf eine erlaubte Größe ein', () {
    final eintrag = model.hinzufuegen(
      StatistikKachelTypen.altersstruktur,
      KachelGroesse.klein,
    )!;
    expect(eintrag.groesse, KachelGroesse.gross);
    expect(ids().last, eintrag.id);
    expect(model.hinzufuegen('unbekannt', KachelGroesse.klein), isNull);
    expect(
      model.hinzufuegen(StatistikKachelTypen.eigene, KachelGroesse.klein),
      isNull,
    );
  });

  test('dieselbe Kachel darf mehrfach vorkommen', () {
    final a = model.hinzufuegen(
      StatistikKachelTypen.personen,
      KachelGroesse.klein,
    );
    final b = model.hinzufuegen(
      StatistikKachelTypen.personen,
      KachelGroesse.breit,
    );
    expect(a!.id, isNot(b!.id));
    expect(
      model.einstellungen.ueberblick.where(
        (e) => e.typId == StatistikKachelTypen.personen,
      ),
      hasLength(2),
    );
  });

  test('eigene Kachel: neu anhängen, später nur aktualisieren', () {
    model.eigeneKachelSpeichern(eigene('kachel-a'));
    expect(model.einstellungen.eigeneKacheln, hasLength(1));
    final eintraege = model.einstellungen.ueberblick
        .where((e) => e.eigeneKachelId == 'kachel-a')
        .toList();
    expect(eintraege, hasLength(1));
    expect(eintraege.single.groesse, KachelGroesse.klein);

    model.eigeneKachelSpeichern(
      eigene('kachel-a').copyWith(titel: 'Stammesvorstand', ziel: 3),
    );
    expect(model.einstellungen.eigeneKacheln.single.titel, 'Stammesvorstand');
    expect(
      model.einstellungen.ueberblick.where(
        (e) => e.eigeneKachelId == 'kachel-a',
      ),
      hasLength(1),
    );
  });

  test('Bearbeiten beenden räumt eigene Kacheln ohne Eintrag auf', () {
    model.bearbeitenStarten();
    model.eigeneKachelSpeichern(eigene('kachel-a'));
    final eintrag = model.einstellungen.ueberblick.last;
    final entfernt = model.entfernen(eintrag.id)!;
    // Während des Bearbeitens bleibt die Definition für „Rückgängig“.
    expect(model.einstellungen.eigeneKacheln, hasLength(1));
    model.wiederherstellen(entfernt.$1, entfernt.$2);
    expect(model.einstellungen.ueberblick.last, eintrag);

    model.entfernen(eintrag.id);
    model.bearbeitenBeenden();
    expect(model.bearbeiten, isFalse);
    expect(model.einstellungen.eigeneKacheln, isEmpty);
  });

  test('Themen ein- und ausblenden, Überblick bleibt', () {
    model.themaSichtbar(StatistikThema.stufen, false);
    model.themaSichtbar(StatistikThema.entwicklung, false);
    model.themaSichtbar(StatistikThema.ueberblick, false);
    expect(model.einstellungen.stufenSichtbar, isFalse);
    expect(model.einstellungen.entwicklungSichtbar, isFalse);
    model.themaSichtbar(StatistikThema.stufen, true);
    expect(model.einstellungen.stufenSichtbar, isTrue);
  });

  test('Zielwerte speichern', () async {
    const ziele = StatistikZielwerte(
      neuProJahr: 8,
      gruppeMax: {Stufe.woelfling: 14},
    );
    model.zieleSpeichern(ziele);
    expect(model.einstellungen.ziele, ziele);
    expect((await repository.loadForLayer(1)).ziele, ziele);
  });

  test('späte Aufrufe nach dispose werfen nicht', () {
    model.bearbeitenStarten();
    model.dispose();
    expect(model.bearbeitenBeenden, returnsNormally);
  });
}

KachelEintrag _eintrag(StatistikKachelnModel model, String id) =>
    model.einstellungen.ueberblick.firstWhere((e) => e.id == id);
