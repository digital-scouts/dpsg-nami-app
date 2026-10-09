import 'package:flutter_test/flutter_test.dart';
import 'package:nami/services/data_expiry_notification_service.dart';
import 'package:nami/services/lokale_mitteilungen.dart';

import 'support/fake_logger_service.dart';

class _FakeMitteilungen implements LokaleMitteilungen {
  final geplant = <int, ({String titel, String text, DateTime zeitpunkt})>{};

  @override
  Future<void> initialisieren() async {}

  @override
  Future<List<int>> geplanteIds() async => geplant.keys.toList();

  @override
  Future<void> abbrechen(int id) async => geplant.remove(id);

  @override
  Future<void> abbrechenBereich(int erste, int letzte) async {
    geplant.removeWhere((id, _) => id >= erste && id <= letzte);
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
  final jetzt = DateTime(2026, 10, 10, 12);
  late _FakeMitteilungen mitteilungen;
  late DataExpiryNotificationService service;

  setUp(() {
    mitteilungen = _FakeMitteilungen();
    service = DataExpiryNotificationService(
      logger: FakeLoggerService(),
      mitteilungen: mitteilungen,
      jetzt: () => jetzt,
    );
  });

  Future<void> aktualisiere(
    DateTime? ablauf, {
    bool pushErlaubt = true,
    String sprache = 'de',
  }) => service.updateExpiryReminder(
    ablauf: ablauf,
    pushErlaubt: pushErlaubt,
    sprache: sprache,
  );

  test('plant je Tag eine Mitteilung mit der richtigen Tageszahl', () async {
    await aktualisiere(DateTime(2026, 10, 13, 12));

    final plan = mitteilungen.geplant.values.toList();
    expect(plan.map((m) => m.zeitpunkt), [
      DateTime(2026, 10, 11, 9),
      DateTime(2026, 10, 12, 9),
      DateTime(2026, 10, 13, 9),
    ]);
    expect(plan[0].text, contains('innerhalb von 3 Tagen'));
    expect(plan[1].text, contains('innerhalb von 2 Tagen'));
    expect(plan[2].text, contains('innerhalb von 1 Tag erneut'));
  });

  test('plant weit im Voraus 7, 3, 2 und 1 Tag vor dem Ablauf', () async {
    await aktualisiere(DateTime(2026, 12, 9, 12));

    final plan = mitteilungen.geplant.values.toList();
    expect(plan.map((m) => m.zeitpunkt), [
      DateTime(2026, 12, 3, 9),
      DateTime(2026, 12, 7, 9),
      DateTime(2026, 12, 8, 9),
      DateTime(2026, 12, 9, 9),
    ]);
    expect(plan.first.text, contains('innerhalb von 7 Tagen'));
    expect(plan.last.text, contains('innerhalb von 1 Tag erneut'));
  });

  test('plant nichts nach dem Ablauf und ohne Ablauf', () async {
    await aktualisiere(DateTime(2026, 10, 13, 12));
    await aktualisiere(null);

    expect(mitteilungen.geplant, isEmpty);
  });

  test('ausgeschaltete Mitteilungen entfernen die Erinnerungen', () async {
    await aktualisiere(DateTime(2026, 10, 13, 12));
    await aktualisiere(DateTime(2026, 10, 13, 12), pushErlaubt: false);

    expect(mitteilungen.geplant, isEmpty);
  });

  test('Text folgt der App-Sprache', () async {
    await aktualisiere(DateTime(2026, 10, 11, 20), sprache: 'en');

    final plan = mitteilungen.geplant.values.single;
    expect(plan.titel, 'Local data expires soon');
    expect(
      plan.text,
      'Sign in again within 1 day to keep local data available.',
    );
  });

  test('weniger Tage entfernen uebrige Mitteilungen', () async {
    await aktualisiere(DateTime(2026, 10, 13, 12));
    await aktualisiere(DateTime(2026, 10, 11, 20));

    expect(mitteilungen.geplant.keys, [DataExpiryNotificationService.idErste]);
  });
}
