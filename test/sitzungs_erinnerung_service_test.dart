import 'package:flutter_test/flutter_test.dart';
import 'package:nami/services/lokale_mitteilungen.dart';
import 'package:nami/services/sitzungs_erinnerung_service.dart';

import 'support/fake_logger_service.dart';

class _FakeMitteilungen implements LokaleMitteilungen {
  final geplant = <int, ({String titel, String text, DateTime zeitpunkt})>{};
  var planungen = 0;

  @override
  Future<void> initialisieren() async {}

  @override
  Future<List<int>> geplanteIds() async => geplant.keys.toList();

  @override
  Future<void> abbrechen(int id) async {
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
    planungen += 1;
    geplant[id] = (titel: titel, text: text, zeitpunkt: zeitpunkt);
  }
}

void main() {
  final jetzt = DateTime(2026, 10, 8, 12);

  ({SitzungsErinnerungService dienst, _FakeMitteilungen mitteilungen}) baue() {
    final mitteilungen = _FakeMitteilungen();
    final dienst = SitzungsErinnerungService(
      logger: FakeLoggerService(),
      mitteilungen: mitteilungen,
      jetzt: () => jetzt,
    );
    return (dienst: dienst, mitteilungen: mitteilungen);
  }

  test('erinnert sechs Tage nach der letzten Erneuerung', () async {
    final (:dienst, :mitteilungen) = baue();

    await dienst.aktualisiere(
      erneuertAm: DateTime(2026, 10, 8, 9),
      pushErlaubt: true,
      sprache: 'de',
    );

    final erinnerung = mitteilungen.geplant[SitzungsErinnerungService.id]!;
    expect(erinnerung.zeitpunkt, DateTime(2026, 10, 14, 9));
    expect(erinnerung.titel, 'Angemeldet bleiben');
  });

  test('verschiebt die Erinnerung bei jeder Erneuerung', () async {
    final (:dienst, :mitteilungen) = baue();

    await dienst.aktualisiere(
      erneuertAm: DateTime(2026, 10, 7),
      pushErlaubt: true,
      sprache: 'de',
    );
    await dienst.aktualisiere(
      erneuertAm: DateTime(2026, 10, 7),
      pushErlaubt: true,
      sprache: 'de',
    );
    await dienst.aktualisiere(
      erneuertAm: DateTime(2026, 10, 8, 11),
      pushErlaubt: true,
      sprache: 'de',
    );

    expect(mitteilungen.planungen, 2);
    expect(
      mitteilungen.geplant[SitzungsErinnerungService.id]!.zeitpunkt,
      DateTime(2026, 10, 14, 11),
    );
  });

  test('entfernt die Erinnerung ohne Anmeldung oder Erlaubnis', () async {
    final (:dienst, :mitteilungen) = baue();
    await dienst.aktualisiere(
      erneuertAm: DateTime(2026, 10, 8),
      pushErlaubt: true,
      sprache: 'de',
    );

    await dienst.aktualisiere(
      erneuertAm: DateTime(2026, 10, 8),
      pushErlaubt: false,
      sprache: 'de',
    );
    expect(mitteilungen.geplant, isEmpty);

    await dienst.aktualisiere(
      erneuertAm: DateTime(2026, 10, 8),
      pushErlaubt: true,
      sprache: 'de',
    );
    await dienst.aktualisiere(
      erneuertAm: null,
      pushErlaubt: true,
      sprache: 'de',
    );
    expect(mitteilungen.geplant, isEmpty);
  });

  test('plant nichts in der Vergangenheit', () async {
    final (:dienst, :mitteilungen) = baue();

    await dienst.aktualisiere(
      erneuertAm: DateTime(2026, 10, 1),
      pushErlaubt: true,
      sprache: 'de',
    );

    expect(mitteilungen.planungen, 0);
  });
}
