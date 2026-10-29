// Geraete-Test fuer Geburtstags-Erinnerungen (#193) unter Android: plant mit
// dem echten Plugin, wartet auf die Zustellung und prueft das Neuplanen nach
// einem Zeitzonenwechsel. Uhr, Sperre und Zeitzone stellt der Aufrufer
// waehrenddessen per adb um; der Test meldet seine Phasen mit „GERAETETEST:“.
//
//   flutter test integration_test/erinnerungen_geraet_test.dart -d <emulator>
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/services/geburtstags_erinnerung_service.dart';

import '../test/support/fake_logger_service.dart';
import '../test/support/qualifikationen_testdaten.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  void melde(String text) => debugPrint('GERAETETEST: $text');

  Future<bool> warte(
    Future<bool> Function() bedingung, {
    required Duration hoechstens,
  }) async {
    // Stoppuhr statt Wanduhr, weil der Aufrufer die Uhr verstellt.
    final stopp = Stopwatch()..start();
    while (stopp.elapsed < hoechstens) {
      if (await bedingung()) {
        return true;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    return bedingung();
  }

  testWidgets('Geburtstage: planen, zustellen, Zeitzone', (tester) async {
    final plugin = FlutterLocalNotificationsPlugin();
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    melde('WARTE_AUF_ERLAUBNIS');
    final erlaubt = await warte(
      () async => await android?.areNotificationsEnabled() ?? false,
      hoechstens: const Duration(minutes: 2),
    );
    expect(erlaubt, isTrue, reason: 'Mitteilungen nicht erlaubt');

    final start = DateTime.now();
    final morgen = DateTime(start.year, start.month, start.day + 1);
    final uebermorgen = DateTime(start.year, start.month, start.day + 2);
    Mitglied kind(String nr, String vorname, DateTime tag) => Mitglied(
      vorname: vorname,
      nachname: 'Bergmann',
      mitgliedsnummer: nr,
      geburtsdatum: DateTime(tag.year - 12, tag.month, tag.day),
      eintrittsdatum: DateTime(2020, 1, 1),
      personId: int.parse(nr),
      roles: [mitgliedRolle('Pfadfinder')],
    );
    final readModel = qualiReadModel(
      mitglieder: [
        kind('1', 'Lena', morgen),
        for (final (i, name) in ['Tom', 'Max', 'Ida', 'Ben', 'Ole'].indexed)
          kind('${i + 2}', name, uebermorgen),
      ],
    );
    final service = GeburtstagsErinnerungService(logger: FakeLoggerService());

    Future<List<PendingNotificationRequest>> eigene() async =>
        (await plugin.pendingNotificationRequests())
            .where(
              (m) =>
                  m.id >= GeburtstagsErinnerungService.idErste &&
                  m.id <= GeburtstagsErinnerungService.idLetzte,
            )
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));

    Future<void> plane({DateTime? datenEnde}) => service.aktualisiere(
      readModel: readModel,
      stufen: {Stufe.pfadfinder},
      pushErlaubt: true,
      sprache: 'de',
      datenEnde: datenEnde,
    );

    await service.raeumen();

    // Datenablauf vor dem zweiten Tag: nur der erste bleibt.
    await plane(
      datenEnde: DateTime(
        uebermorgen.year,
        uebermorgen.month,
        uebermorgen.day,
        9,
      ),
    );
    var geplant = await eigene();
    melde('MIT_DATENENDE ${geplant.map((m) => '${m.id}:${m.body}').toList()}');
    expect(geplant.map((m) => m.body), ['Lena B. wird heute 12.']);

    await plane();
    geplant = await eigene();
    melde('OHNE_DATENENDE ${geplant.map((m) => '${m.id}:${m.body}').toList()}');
    expect(geplant.map((m) => m.body), [
      'Lena B. wird heute 12.',
      'Heute haben Ben B., Ida B., Max B. und 2 weitere Geburtstag.',
    ]);
    melde(
      'GEPLANT morgen=${morgen.toIso8601String()} '
      'offset=${start.timeZoneOffset} tz=${start.timeZoneName}',
    );

    // Der Aufrufer stellt jetzt die Uhr vor; die Mitteilungen kommen.
    melde('WARTE_AUF_ZUSTELLUNG');
    final zugestellt = await warte(() async {
      final aktiv = await plugin.getActiveNotifications();
      return aktiv
              .where(
                (m) =>
                    m.id != null &&
                    m.id! >= GeburtstagsErinnerungService.idErste &&
                    m.id! <= GeburtstagsErinnerungService.idLetzte,
              )
              .length >=
          2;
    }, hoechstens: const Duration(minutes: 10));
    final aktiv = await plugin.getActiveNotifications();
    melde(
      'ZUGESTELLT=$zugestellt '
      '${aktiv.map((m) => '${m.id}:${m.title}:${m.body}').toList()}',
    );
    expect(zugestellt, isTrue);

    // Der Aufrufer prueft den Sperrbildschirm und wechselt dann die
    // Zeitzone.
    final vorher = DateTime.now().timeZoneOffset;
    melde('WARTE_AUF_ZEITZONE offset=$vorher');
    final gewechselt = await warte(
      () async => DateTime.now().timeZoneOffset != vorher,
      hoechstens: const Duration(minutes: 10),
    );
    final jetzt = DateTime.now();
    melde(
      'ZEITZONE_GEWECHSELT=$gewechselt offset=${jetzt.timeZoneOffset} '
      'tz=${jetzt.timeZoneName}',
    );
    expect(gewechselt, isTrue);

    // Gleiche Eingaben, aber neue Zeitzone: der Dienst plant neu.
    final heute = DateTime(jetzt.year, jetzt.month, jetzt.day);
    final naechster = DateTime(heute.year, heute.month, heute.day + 1);
    await service.aktualisiere(
      readModel: qualiReadModel(mitglieder: [kind('1', 'Lena', naechster)]),
      stufen: {Stufe.pfadfinder},
      pushErlaubt: true,
      sprache: 'de',
      datenEnde: null,
    );
    geplant = await eigene();
    melde('NACH_ZEITZONE ${geplant.map((m) => '${m.id}:${m.body}').toList()}');
    expect(geplant, hasLength(1));

    await service.raeumen();
    melde('FERTIG');
  });
}
