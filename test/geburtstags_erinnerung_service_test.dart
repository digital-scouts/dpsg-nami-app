import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/member/plane_geburtstags_erinnerungen_usecase.dart';
import 'package:nami/domain/taetigkeit/roles.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/services/geburtstags_erinnerung_service.dart';
import 'package:nami/services/lokale_mitteilungen.dart';

import 'support/fake_logger_service.dart';
import 'support/qualifikationen_testdaten.dart';

class _FakeMitteilungen implements LokaleMitteilungen {
  final geplant =
      <
        int,
        ({String titel, String text, DateTime zeitpunkt, String kanalName})
      >{};
  final abgebrochen = <int>[];
  var planungen = 0;
  var ohneErlaubnis = false;

  @override
  Future<void> initialisieren() async {}

  @override
  Future<List<int>> geplanteIds() async => geplant.keys.toList();

  @override
  Future<void> abbrechenBereich(int erste, int letzte) async {
    for (final id in geplant.keys.toList()) {
      if (id >= erste && id <= letzte) {
        await abbrechen(id);
      }
    }
  }

  @override
  Future<void> abbrechen(int id) async {
    abgebrochen.add(id);
    geplant.remove(id);
  }

  @override
  Future<void> planen({
    required int id,
    required String titel,
    required String text,
    required DateTime zeitpunkt,
    required String kanalName,
  }) async {
    if (ohneErlaubnis) {
      throw Exception('Source is not authorized');
    }
    planungen++;
    geplant[id] = (
      titel: titel,
      text: text,
      zeitpunkt: zeitpunkt,
      kanalName: kanalName,
    );
  }
}

const _alleStufen = <Stufe>{
  Stufe.biber,
  Stufe.woelfling,
  Stufe.jungpfadfinder,
  Stufe.pfadfinder,
  Stufe.rover,
  Stufe.leitung,
};

Mitglied _mitglied(
  String nummer,
  List<Role> rollen, {
  String vorname = 'Lena',
  String nachname = 'Beispiel',
  DateTime? geburtsdatum,
}) {
  return Mitglied(
    vorname: vorname,
    nachname: nachname,
    mitgliedsnummer: nummer,
    geburtsdatum: geburtsdatum ?? Mitglied.peoplePlaceholderDate,
    eintrittsdatum: DateTime(2020, 1, 1),
    personId: int.parse(nummer),
    roles: rollen,
  );
}

void main() {
  // Mittwoch, 07.10.2026, 8 Uhr.
  final jetzt = DateTime(2026, 10, 7, 8);

  late _FakeMitteilungen mitteilungen;
  late DateTime uhr;
  late GeburtstagsErinnerungService service;

  setUp(() {
    uhr = jetzt;
    mitteilungen = _FakeMitteilungen()
      // Fremde Erinnerungen (Datenablauf, Qualifikation) ausserhalb des
      // eigenen Bereichs.
      ..geplant[94031] = (
        titel: 'x',
        text: 'y',
        zeitpunkt: DateTime(2026),
        kanalName: 'k',
      )
      ..geplant[95000] = (
        titel: 'x',
        text: 'y',
        zeitpunkt: DateTime(2026),
        kanalName: 'k',
      );
    service = GeburtstagsErinnerungService(
      logger: FakeLoggerService(),
      mitteilungen: mitteilungen,
      jetzt: () => uhr,
    );
  });

  Map<int, ({String titel, String text, DateTime zeitpunkt, String kanalName})>
  eigene() => {
    for (final eintrag in mitteilungen.geplant.entries)
      if (eintrag.key >= GeburtstagsErinnerungService.idErste &&
          eintrag.key <= GeburtstagsErinnerungService.idLetzte)
        eintrag.key: eintrag.value,
  };

  Future<void> aktualisiere(
    ArbeitskontextReadModel? readModel, {
    Set<Stufe> stufen = _alleStufen,
    bool pushErlaubt = true,
    String sprache = 'de',
  }) => service.aktualisiere(
    readModel: readModel,
    stufen: stufen,
    pushErlaubt: pushErlaubt,
    sprache: sprache,
  );

  test(
    'plant Geburtstage im 60-Tage-Fenster, fruehester zuerst, um 9 Uhr',
    () async {
      final readModel = qualiReadModel(
        mitglieder: [
          _mitglied(
            '1',
            [mitgliedRolle('Pfadfinder')],
            vorname: 'Spaet',
            geburtsdatum: DateTime(2013, 11, 20),
          ),
          _mitglied(
            '2',
            [mitgliedRolle('Pfadfinder')],
            vorname: 'Frueh',
            geburtsdatum: DateTime(2014, 10, 9),
          ),
          // 60 Tage nach heute: ausserhalb des Fensters.
          _mitglied(
            '3',
            [mitgliedRolle('Pfadfinder')],
            vorname: 'Zuweit',
            geburtsdatum: DateTime(2013, 12, 6),
          ),
          // Letzter Tag im Fenster.
          _mitglied(
            '4',
            [mitgliedRolle('Pfadfinder')],
            vorname: 'Grenze',
            geburtsdatum: DateTime(2013, 12, 5),
          ),
          // Ohne Geburtsdatum wird uebersprungen.
          _mitglied('5', [mitgliedRolle('Pfadfinder')], vorname: 'Ohne'),
        ],
      );

      await aktualisiere(readModel);

      final geplant = eigene();
      expect(geplant.keys, [96000, 96001, 96002]);
      expect(geplant[96000]!.text, 'Frueh B. wird heute 12.');
      expect(geplant[96000]!.zeitpunkt, DateTime(2026, 10, 9, 9));
      expect(geplant[96001]!.zeitpunkt, DateTime(2026, 11, 20, 9));
      expect(geplant[96002]!.text, 'Grenze B. wird heute 13.');
      expect(geplant[96002]!.zeitpunkt, DateTime(2026, 12, 5, 9));
      expect(mitteilungen.geplant.containsKey(94031), isTrue);
      expect(mitteilungen.geplant.containsKey(95000), isTrue);
    },
  );

  test('datensparsamer Text mit Vorname, Initial und Alter', () async {
    final readModel = qualiReadModel(
      mitglieder: [
        _mitglied(
          '1',
          [mitgliedRolle('Pfadfinder')],
          vorname: 'Lena',
          nachname: 'Bergmann',
          geburtsdatum: DateTime(2014, 10, 7),
        ),
      ],
    );

    await aktualisiere(readModel);
    final de = eigene()[96000]!;
    expect(de.titel, 'Geburtstag');
    expect(de.text, 'Lena B. wird heute 12.');
    expect(de.text, isNot(contains('Bergmann')));
    expect(de.kanalName, 'Geburtstage');

    await aktualisiere(readModel, sprache: 'en');
    final en = eigene()[96000]!;
    expect(en.titel, 'Birthday');
    expect(en.text, 'Lena B. turns 12 today.');
    expect(en.kanalName, 'Birthdays');
  });

  test('Stufenfilter: Leitende zaehlen zur Leitung', () async {
    final readModel = qualiReadModel(
      mitglieder: [
        _mitglied(
          '1',
          [mitgliedRolle('Woelflinge')],
          vorname: 'Kind',
          geburtsdatum: DateTime(2018, 10, 10),
        ),
        _mitglied(
          '2',
          [leitung('Woelflinge')],
          vorname: 'Leiterin',
          geburtsdatum: DateTime(1995, 10, 11),
        ),
        _mitglied(
          '3',
          [mitgliedRolle('Rover')],
          vorname: 'Rover',
          geburtsdatum: DateTime(2006, 10, 12),
        ),
      ],
    );

    await aktualisiere(readModel, stufen: {Stufe.woelfling});
    expect(eigene().values.map((m) => m.text), ['Kind B. wird heute 8.']);

    await aktualisiere(readModel, stufen: {Stufe.leitung});
    expect(eigene().values.map((m) => m.text), ['Leiterin B. wird heute 31.']);

    await aktualisiere(readModel, stufen: const <Stufe>{});
    expect(eigene(), isEmpty);
  });

  test('plant hoechstens 30 Geburtstage, die fruehesten', () async {
    final readModel = qualiReadModel(
      mitglieder: [
        for (var i = 0; i < 40; i++)
          _mitglied(
            '${i + 1}',
            [mitgliedRolle('Pfadfinder')],
            vorname: 'P${i.toString().padLeft(2, '0')}',
            geburtsdatum: DateTime(2013, 10, 8 + i),
          ),
      ],
    );

    await aktualisiere(readModel);

    final geplant = eigene();
    expect(
      geplant,
      hasLength(PlaneGeburtstagsErinnerungenUseCase.maxMitteilungen),
    );
    expect(geplant.keys.first, 96000);
    expect(geplant.keys.last, 96029);
    expect(geplant[96000]!.text, startsWith('P00 '));
    expect(geplant[96029]!.text, startsWith('P29 '));
  });

  test('29.02. kommt in Nicht-Schaltjahren am 28.02.', () async {
    final readModel = qualiReadModel(
      mitglieder: [
        _mitglied('1', [
          mitgliedRolle('Pfadfinder'),
        ], geburtsdatum: DateTime(2012, 2, 29)),
      ],
    );

    uhr = DateTime(2027, 2, 20, 12);
    await aktualisiere(readModel);
    expect(eigene()[96000]!.zeitpunkt, DateTime(2027, 2, 28, 9));
    expect(eigene()[96000]!.text, 'Lena B. wird heute 15.');

    uhr = DateTime(2028, 2, 20, 12);
    await aktualisiere(readModel);
    expect(eigene()[96000]!.zeitpunkt, DateTime(2028, 2, 29, 9));
  });

  test('heute vor 9 Uhr noch geplant, ab 9 Uhr nicht mehr', () async {
    final readModel = qualiReadModel(
      mitglieder: [
        _mitglied('1', [
          mitgliedRolle('Pfadfinder'),
        ], geburtsdatum: DateTime(2014, 10, 7)),
      ],
    );

    uhr = DateTime(2026, 10, 7, 8, 59);
    await aktualisiere(readModel);
    expect(eigene()[96000]!.zeitpunkt, DateTime(2026, 10, 7, 9));

    uhr = DateTime(2026, 10, 7, 9);
    await aktualisiere(readModel);
    expect(eigene(), isEmpty);
  });

  test('ohne Push-Erlaubnis wird nichts geplant', () async {
    final readModel = qualiReadModel(
      mitglieder: [
        _mitglied('1', [
          mitgliedRolle('Pfadfinder'),
        ], geburtsdatum: DateTime(2014, 10, 9)),
      ],
    );
    await aktualisiere(readModel);
    expect(eigene(), isNotEmpty);

    await aktualisiere(readModel, pushErlaubt: false);

    expect(eigene(), isEmpty);
    expect(mitteilungen.geplant.keys, unorderedEquals([94031, 95000]));
  });

  test('raeumt nur den eigenen Bereich', () async {
    final readModel = qualiReadModel(
      mitglieder: [
        _mitglied('1', [
          mitgliedRolle('Pfadfinder'),
        ], geburtsdatum: DateTime(2014, 10, 9)),
      ],
    );
    await aktualisiere(readModel);
    mitteilungen.geplant[96099] = (
      titel: 'alt',
      text: 'alt',
      zeitpunkt: DateTime(2026),
      kanalName: 'k',
    );

    await service.raeumen();

    expect(mitteilungen.geplant.keys, unorderedEquals([94031, 95000]));
    expect(mitteilungen.abgebrochen, isNot(contains(94031)));
    expect(mitteilungen.abgebrochen, isNot(contains(95000)));
  });

  test('ohne Read Model wird geraeumt', () async {
    final readModel = qualiReadModel(
      mitglieder: [
        _mitglied('1', [
          mitgliedRolle('Pfadfinder'),
        ], geburtsdatum: DateTime(2014, 10, 9)),
      ],
    );
    await aktualisiere(readModel);

    await aktualisiere(null);

    expect(eigene(), isEmpty);
  });

  test('nach fehlender Erlaubnis plant derselbe Aufruf erneut', () async {
    final readModel = qualiReadModel(
      mitglieder: [
        _mitglied('1', [
          mitgliedRolle('Pfadfinder'),
        ], geburtsdatum: DateTime(2014, 10, 9)),
      ],
    );
    mitteilungen.ohneErlaubnis = true;
    await aktualisiere(readModel);
    expect(mitteilungen.planungen, 0);

    mitteilungen.ohneErlaubnis = false;
    await aktualisiere(readModel);

    expect(mitteilungen.planungen, 1);
  });

  test('gleiche Eingaben planen nicht erneut', () async {
    final readModel = qualiReadModel(
      mitglieder: [
        _mitglied('1', [
          mitgliedRolle('Pfadfinder'),
        ], geburtsdatum: DateTime(2014, 10, 9)),
      ],
    );
    await aktualisiere(readModel);
    mitteilungen.abgebrochen.clear();
    final planungen = mitteilungen.planungen;

    uhr = jetzt.add(const Duration(minutes: 30));
    await aktualisiere(readModel);

    expect(mitteilungen.abgebrochen, isEmpty);
    expect(mitteilungen.planungen, planungen);
  });

  test('Planungsfehler behalten die bisherigen Erinnerungen', () async {
    final readModel = qualiReadModel(
      mitglieder: [
        _mitglied('1', [
          mitgliedRolle('Pfadfinder'),
        ], geburtsdatum: DateTime(2014, 10, 9)),
      ],
    );
    await aktualisiere(readModel);
    final vorher = Map.of(eigene());

    mitteilungen.ohneErlaubnis = true;
    await aktualisiere(readModel, sprache: 'en');

    expect(eigene(), vorher);
  });

  test('Abmelden raeumt auch angezeigte Mitteilungen', () async {
    final readModel = qualiReadModel(
      mitglieder: [
        _mitglied('1', [
          mitgliedRolle('Pfadfinder'),
        ], geburtsdatum: DateTime(2014, 10, 9)),
      ],
    );
    await aktualisiere(readModel);

    await service.raeumen();

    expect(eigene(), isEmpty);
    expect(mitteilungen.geplant.containsKey(94031), isTrue);
  });
}
