import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/statistiks/berechne_stamm_statistik_usecase.dart';
import 'package:nami/domain/statistiks/stamm_statistik.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/stories/statistik/statistik_beispiel_staemme.dart';
import 'package:nami/stories/store/store_showcase_data.dart';

void main() {
  final heute = DateTime(2026, 9, 30);
  final stichtag = DateTime(2026, 11, 1);
  const usecase = BerechneStammStatistikUseCase();

  StammStatistik berechne(ArbeitskontextReadModel readModel) =>
      usecase(readModel, heute: heute, stichtag: stichtag);

  void erwarteEndlich(StammStatistik s) {
    for (final stufe in s.stufen) {
      expect(stufe.alter.every((a) => a.isFinite && a >= 0), isTrue);
      expect(stufe.kinder, greaterThanOrEqualTo(0));
    }
    for (final wert in [
      s.bindung.medianJahreKinder,
      s.bindung.medianJahreLeitende,
    ]) {
      if (wert != null) expect(wert.isFinite && wert >= 0, isTrue);
    }
    for (final stufe in s.prognose?.stufen ?? const <StufenwechselStufe>[]) {
      expect(stufe.danach, greaterThanOrEqualTo(0));
    }
  }

  test('Silberfels: Zählung wie in der Store-Szene', () {
    final s = berechne(StoreShowcaseData.readModel(today: heute));

    expect(s.stammName, 'Stamm Silberfels');
    expect(s.personen, 26);
    expect(s.kinder, 21);
    expect(s.leitende, 5);
    expect(s.sonstige, 0);
    expect(s.stufen.map((x) => x.stufe), BerechneStammStatistikUseCase.stufen);
    expect(s.stufen.map((x) => x.kinder), [3, 6, 5, 4, 3]);
    expect(s.stufen.map((x) => x.leitende), [1, 1, 1, 1, 1]);
    erwarteEndlich(s);
  });

  test('Weitblick: Personen, Stufen, Gruppen und Sonstige', () {
    final s = berechne(StatistikBeispielStaemme.weitblick(heute: heute));

    expect(s.personen, 75);
    expect(s.kinder, 57);
    expect(s.leitende, 14);
    expect(s.sonstige, 4);
    expect(s.stufen.map((x) => x.kinder), [7, 20, 13, 10, 7]);
    expect(s.stufe(Stufe.woelfling).gruppen.map((g) => g.name), [
      'Meute Sternschnuppe',
      'Meute Wirbelwind',
    ]);
    expect(s.groessteGruppe, 13);
    expect(s.bindung.neuInZwoelfMonaten, greaterThanOrEqualTo(9));
    expect(s.bindung.eintritteJeMonat, hasLength(12));
    expect(s.bindung.eintritteJeMonat.last.monat, heute.month);
    erwarteEndlich(s);
  });

  test('Prognose: Abgänge und Zugänge passen zusammen', () {
    final s = berechne(StatistikBeispielStaemme.weitblick(heute: heute));
    final prognose = s.prognose!;

    expect(prognose.stichtag, stichtag);
    expect(prognose.anzahl, greaterThan(0));
    final zu = prognose.stufen.fold<int>(0, (sum, x) => sum + x.zu);
    final abOhneRover = prognose.stufen
        .where((x) => x.stufe != Stufe.rover)
        .fold<int>(0, (sum, x) => sum + x.ab);
    expect(zu, prognose.anzahl);
    expect(abOhneRover, prognose.anzahl);
    expect(prognose.stufe(Stufe.biber).zu, 0);
    // Der 21-jährige Rover wird zum Stichtag zu alt für die Runde.
    expect(prognose.stufe(Stufe.rover).ab, greaterThanOrEqualTo(1));
  });

  test('ohne geladene Rollen oder Stichtag gibt es keine Prognose', () {
    final readModel = StoreShowcaseData.readModel(today: heute);
    expect(usecase(readModel, heute: heute).prognose, isNull);

    final ohneRollen = ArbeitskontextReadModel(
      arbeitskontext: readModel.arbeitskontext,
      mitglieder: readModel.mitglieder,
      gruppen: readModel.gruppen,
      mitgliedsZuordnungen: readModel.mitgliedsZuordnungen,
    );
    expect(
      usecase(ohneRollen, heute: heute, stichtag: stichtag).prognose,
      isNull,
    );
  });

  test('Querfeld: krumme Daten brechen nichts', () {
    final s = berechne(StatistikBeispielStaemme.querfeld(heute: heute));

    expect(s.personen, 55);
    expect(s.ohneGeburtsdatum, 3);
    expect(s.stufe(Stufe.biber).kinder, 0);
    expect(s.stufe(Stufe.woelfling).kinder, 38);
    // Drei Platzhalter-Geburtsdaten fehlen in der Altersauswertung.
    expect(s.stufe(Stufe.woelfling).alter, hasLength(35));
    final trupps = s.stufe(Stufe.jungpfadfinder).gruppen;
    expect(trupps.single.name, 'Trupp Leer');
    expect(trupps.single.kinder, 0);
    expect(trupps.single.leitende, 2);
    // Ein Trupp ohne jede Zuordnung erscheint nicht.
    expect(
      s.stufe(Stufe.pfadfinder).gruppen.map((g) => g.name),
      isNot(contains('Trupp Drei')),
    );
    // Eintritte in der Zukunft zählen nicht als neu.
    expect(s.bindung.eintritteJeMonat.every((m) => m.anzahl >= 0), isTrue);
    expect(
      s.geschlecht[GeschlechtKategorie.ohneAngabe],
      greaterThan(s.kinder ~/ 2),
    );
    erwarteEndlich(s);
  });

  test('leerer Stamm: alles null, keine Ausnahme', () {
    final s = usecase(
      ArbeitskontextReadModel(
        arbeitskontext: Arbeitskontext(
          aktiverLayer: const ArbeitskontextLayer(id: 1, name: 'Leer'),
        ),
        rolesSindGeladen: true,
      ),
      heute: heute,
      stichtag: stichtag,
    );

    expect(s.personen, 0);
    expect(s.stufen, hasLength(5));
    expect(s.groessteGruppe, 0);
    expect(s.bindung.medianJahreKinder, isNull);
    expect(s.prognose!.anzahl, 0);
    expect(s.prognose!.stufen.every((x) => x.danach == 0), isTrue);
  });

  test('Geschlecht wird aus freien Angaben eingeordnet', () {
    expect(GeschlechtKategorie.aus('W'), GeschlechtKategorie.weiblich);
    expect(GeschlechtKategorie.aus(' female '), GeschlechtKategorie.weiblich);
    expect(GeschlechtKategorie.aus('männlich'), GeschlechtKategorie.maennlich);
    expect(GeschlechtKategorie.aus('d'), GeschlechtKategorie.divers);
    expect(GeschlechtKategorie.aus(null), GeschlechtKategorie.ohneAngabe);
    expect(GeschlechtKategorie.aus('x'), GeschlechtKategorie.ohneAngabe);
  });
}

extension on StufenwechselPrognose {
  StufenwechselStufe stufe(Stufe stufe) =>
      stufen.firstWhere((x) => x.stufe == stufe);
}
