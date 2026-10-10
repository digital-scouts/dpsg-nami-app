import 'package:flutter_test/flutter_test.dart';
import 'package:nami/services/wiredash_event_puffer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late List<(String, Map<String, Object?>)> gesendet;
  late bool erlaubt;
  late DateTime jetzt;
  late bool bereit;

  WiredashEventPuffer puffer({int maxEreignisse = 200}) {
    return WiredashEventPuffer(
      senden: (name, daten) async {
        if (!bereit) {
          throw const WiredashNichtBereit();
        }
        gesendet.add((name, daten));
      },
      sendenErlaubt: () async => erlaubt,
      nowProvider: () => jetzt,
      maxEreignisse: maxEreignisse,
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    gesendet = [];
    erlaubt = true;
    bereit = true;
    jetzt = DateTime.utc(2026, 10, 11, 12);
  });

  test('sendet direkt, wenn Senden erlaubt ist', () async {
    await puffer().erfasse('a', {'x': 1});

    expect(gesendet.single.$1, 'a');
    expect(gesendet.single.$2, {'x': 1});
  });

  test('haelt Ereignisse ohne WLAN zurueck und sendet sie spaeter', () async {
    final p = puffer();
    erlaubt = false;
    await p.erfasse('a', {'x': 1});
    await p.erfasse('b', const {});
    expect(gesendet, isEmpty);

    jetzt = jetzt.add(const Duration(minutes: 5));
    erlaubt = true;
    await p.sendeAusstehende();

    expect(gesendet.map((e) => e.$1), ['a', 'b']);
    expect(gesendet.first.$2, {
      'x': 1,
      'occurred_at': '2026-10-11T12:00:00.000Z',
    });
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(WiredashEventPuffer.speicherSchluessel), isFalse);
  });

  test('sendet Vorgemerktes vor dem neuen Ereignis', () async {
    final p = puffer();
    erlaubt = false;
    await p.erfasse('alt', const {});
    erlaubt = true;
    await p.erfasse('neu', const {});

    expect(gesendet.map((e) => e.$1), ['alt', 'neu']);
  });

  test('verwirft Ereignisse, die aelter als drei Tage sind', () async {
    final p = puffer();
    erlaubt = false;
    await p.erfasse('alt', const {});
    jetzt = jetzt.add(const Duration(days: 4));
    await p.erfasse('frisch', const {});

    erlaubt = true;
    await p.sendeAusstehende();

    expect(gesendet.map((e) => e.$1), ['frisch']);
  });

  test('behaelt nur die neuesten Ereignisse bis zur Obergrenze', () async {
    final p = puffer(maxEreignisse: 2);
    erlaubt = false;
    for (final name in ['a', 'b', 'c']) {
      await p.erfasse(name, const {});
    }

    erlaubt = true;
    await p.sendeAusstehende();

    expect(gesendet.map((e) => e.$1), ['b', 'c']);
  });

  test('ergaenzt occurred_at nicht ueber zehn Parameter hinaus', () async {
    final p = puffer();
    erlaubt = false;
    final zehn = {for (var i = 0; i < 10; i++) 'k$i': i};
    await p.erfasse('voll', zehn);

    erlaubt = true;
    await p.sendeAusstehende();

    expect(gesendet.single.$2, zehn);
  });

  test('merkt vor, solange Wiredash nicht bereit ist', () async {
    final p = puffer();
    bereit = false;
    await p.erfasse('frueh', const {});
    expect(gesendet, isEmpty);

    bereit = true;
    await p.sendeAusstehende();

    expect(gesendet.map((e) => e.$1), ['frueh']);
  });
}
