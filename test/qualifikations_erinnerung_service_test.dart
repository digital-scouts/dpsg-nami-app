import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/member/efz_einsichtnahme.dart';
import 'package:nami/domain/qualifikation/qualifikations_einstellungen.dart';
import 'package:nami/services/lokale_mitteilungen.dart';
import 'package:nami/services/qualifikations_erinnerung_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_logger_service.dart';
import 'support/qualifikationen_testdaten.dart';

class _FakeMitteilungen implements LokaleMitteilungen {
  final geplant = <int, ({String titel, String text, DateTime zeitpunkt})>{};
  final abgebrochen = <int>[];

  @override
  Future<void> initialisieren() async {}

  @override
  Future<List<int>> geplanteIds() async => geplant.keys.toList();

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
    geplant[id] = (titel: titel, text: text, zeitpunkt: zeitpunkt);
  }
}

void main() {
  final readModel = qualiReadModel(
    mitglieder: [
      qualiMitglied('ICH', 1, [leitung('Rover')], fahrtenname: 'Funke'),
      qualiMitglied('B', 2, [leitung('Pfadfinder')]),
    ],
    efz: [
      EfzEinsichtnahme(id: 1, personId: 1, issuedOn: DateTime(2021, 11, 20)),
      EfzEinsichtnahme(id: 2, personId: 2, issuedOn: DateTime(2022, 3, 1)),
    ],
  );

  late _FakeMitteilungen mitteilungen;
  late QualifikationsErinnerungService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mitteilungen = _FakeMitteilungen()
      // Fremde Erinnerung (Datenablauf) ausserhalb des eigenen Bereichs.
      ..geplant[94031] = (titel: 'x', text: 'y', zeitpunkt: DateTime(2026));
    service = QualifikationsErinnerungService(
      logger: FakeLoggerService(),
      mitteilungen: mitteilungen,
      jetzt: () => DateTime(2026, 10, 2, 8),
    );
  });

  Future<void> aktualisiere({
    bool pushErlaubt = true,
    QualifikationsEinstellungen einstellungen =
        const QualifikationsEinstellungen(),
  }) => service.aktualisiere(
    readModel: readModel,
    einstellungen: einstellungen,
    eigenePersonId: 1,
    supporter: true,
    pushErlaubt: pushErlaubt,
    sprache: 'de',
  );

  test('plant im eigenen ID-Bereich mit deutschen Texten', () async {
    await aktualisiere();

    final eigene =
        mitteilungen.geplant[QualifikationsErinnerungService.idErste]!;
    expect(eigene.titel, 'Erweitertes Führungszeugnis läuft bald ab');
    expect(eigene.text, 'Deine Qualifikation ist gültig bis 20.11.2026.');
    expect(eigene.zeitpunkt, DateTime(2026, 10, 2, 9));
    final fremde =
        mitteilungen.geplant[QualifikationsErinnerungService.idErste + 1]!;
    expect(fremde.text, 'PersonB Test: gültig bis 01.03.2027.');
    expect(mitteilungen.geplant.containsKey(94031), isTrue);
  });

  test('raeumt nur den eigenen Bereich', () async {
    await aktualisiere();
    await service.raeumen();

    expect(mitteilungen.geplant.keys, <int>[94031]);
    expect(mitteilungen.abgebrochen, isNot(contains(94031)));
  });

  test('ohne Push-Erlaubnis wird nichts geplant', () async {
    await aktualisiere(pushErlaubt: false);

    expect(mitteilungen.geplant.keys, <int>[94031]);
  });

  test('gleiche Eingaben planen nicht erneut', () async {
    await aktualisiere();
    mitteilungen.abgebrochen.clear();

    await aktualisiere();

    expect(mitteilungen.abgebrochen, isEmpty);
  });

  test('gemeldete Ablaeufe kommen nach Neustart nicht wieder', () async {
    await aktualisiere();
    // Neuer Dienst am naechsten Tag: der eigene Termin (02.10., 9 Uhr) ist
    // vorbei und gilt als gemeldet.
    final spaeter = QualifikationsErinnerungService(
      logger: FakeLoggerService(),
      mitteilungen: mitteilungen,
      jetzt: () => DateTime(2026, 10, 3, 8),
    );

    await spaeter.aktualisiere(
      readModel: readModel,
      einstellungen: const QualifikationsEinstellungen(),
      eigenePersonId: 1,
      supporter: true,
      pushErlaubt: true,
      sprache: 'de',
    );

    final texte = mitteilungen.geplant.values.map((m) => m.titel);
    expect(texte, isNot(contains('Erweitertes Führungszeugnis läuft bald ab')));
  });
}
