import 'package:flutter_test/flutter_test.dart';
import 'package:nami/data/bundesstatistik/shared_prefs_bundesstatistik_teilnahme_repository.dart';
import 'package:nami/domain/bundesstatistik/bundesstatistik_teilnahme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('speichert Einwilligungen und Sendestaende je Stamm', () async {
    final repository = SharedPrefsBundesstatistikTeilnahmeRepository();
    final teilnahme = BundesstatistikTeilnahme.leer
        .mitEinwilligung('42', '11', DateTime.utc(2026, 6, 1))
        .mitEinwilligung('42', '12', DateTime.utc(2026, 6, 2))
        .mitGesendetemSnapshot(
          am: DateTime.utc(2026, 6, 3),
          stammId: '11',
          snapshotJson: '{"stamm_id":"11"}',
        );

    await repository.save(teilnahme);
    final geladen = await repository.load();

    expect(geladen.einwilligungFuer, '42');
    expect(geladen.einwilligungen, {
      '11': DateTime.utc(2026, 6, 1),
      '12': DateTime.utc(2026, 6, 2),
    });
    expect(geladen.sendestaende['11']?.am, DateTime.utc(2026, 6, 3));
    expect(geladen.sendestaende['11']?.snapshotJson, '{"stamm_id":"11"}');
    expect(geladen.zuletztGesendetAm, DateTime.utc(2026, 6, 3));
  });

  test('uebernimmt den frueheren Stand mit genau einem Stamm', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bundesstatistikEinwilligungFuer': '42',
      'bundesstatistikEinwilligungAm': '2026-05-01T00:00:00.000Z',
      'bundesstatistikZuletztGesendetAm': '2026-05-02T00:00:00.000Z',
      'bundesstatistikZuletztGesendeterStammId': '11',
      'bundesstatistikZuletztGesendeterSnapshot': '{"stamm_id":"11"}',
    });
    final repository = SharedPrefsBundesstatistikTeilnahmeRepository();

    final geladen = await repository.load();

    expect(geladen.hatEinwilligungFuer('42', '11'), isTrue);
    expect(geladen.hatEinwilligungFuer('42', '12'), isFalse);
    expect(geladen.sendestaende['11']?.am, DateTime.utc(2026, 5, 2));

    await repository.save(geladen);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('bundesstatistikZuletztGesendeterStammId'), isNull);
    expect((await repository.load()).hatEinwilligungFuer('42', '11'), isTrue);
  });

  test(
    'vergisst nach neuen Credentials den Sendezeitpunkt, nicht den Payload',
    () {
      final teilnahme = BundesstatistikTeilnahme.leer
          .mitGesendetemSnapshot(
            am: DateTime.utc(2026, 6, 3),
            stammId: '11',
            snapshotJson: '{}',
          )
          .ohneSendestand();

      expect(teilnahme.zuletztGesendetAm, isNull);
      expect(teilnahme.sendestaende['11']?.snapshotJson, '{}');
    },
  );
}
