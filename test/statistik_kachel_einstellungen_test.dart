import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nami/data/statistiks/shared_prefs_statistik_kachel_repository.dart';
import 'package:nami/domain/statistiks/statistik_kachel_einstellungen.dart';
import 'package:nami/domain/statistiks/statistik_kachel_typen.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/stories/statistik/statistik_beispiel_staemme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StatistikKachelEinstellungen', () {
    test('Standard: feste Belegung, alle Tabs sichtbar, keine Ziele', () {
      const e = StatistikKachelEinstellungen();
      expect(e.ueberblick.map((k) => k.typId), [
        StatistikKachelTypen.gruppen,
        StatistikKachelTypen.stufenwechsel,
        StatistikKachelTypen.bindung,
        StatistikKachelTypen.geschlecht,
        StatistikKachelTypen.konfession,
        StatistikKachelTypen.standorte,
      ]);
      expect(e.stufenSichtbar && e.entwicklungSichtbar, isTrue);
      expect(e.ziele, StatistikZielwerte.leer);
      expect(e.eigeneKacheln, isEmpty);
    });

    test('übersteht den Weg über JSON unverändert', () {
      final original = StatistikBeispielStaemme.einstellungenWeitblick()
          .copyWith(entwicklungSichtbar: false);
      final json = jsonDecode(jsonEncode(original.toJson()));
      expect(StatistikKachelEinstellungen.fromJson(json), original);
    });

    test('kaputtes JSON ergibt den Standard', () {
      expect(
        StatistikKachelEinstellungen.fromJson('kaputt'),
        const StatistikKachelEinstellungen(),
      );
      expect(
        StatistikKachelEinstellungen.fromJson(<String, dynamic>{}),
        const StatistikKachelEinstellungen(),
      );
    });

    test(
      'unbekannte Kacheln fallen weg, Größen rasten ein, IDs bleiben eindeutig',
      () {
        final e = StatistikKachelEinstellungen.fromJson(<String, dynamic>{
          'ueberblick': [
            {'id': 'a', 'typ': 'gibtEsNicht', 'groesse': '1x1'},
            {
              'id': 'b',
              'typ': StatistikKachelTypen.altersstruktur,
              'groesse': '1x1',
            },
            {
              'id': 'c',
              'typ': StatistikKachelTypen.geschlecht,
              'groesse': '2x2',
            },
            {
              'id': 'c',
              'typ': StatistikKachelTypen.konfession,
              'groesse': '1x1',
            },
            {
              'id': 'd',
              'typ': StatistikKachelTypen.stufen,
              'groesse': 'riesig',
            },
            {
              'id': 'e',
              'typ': StatistikKachelTypen.eigene,
              'groesse': '1x1',
              'eigeneKachelId': 'fehlt',
            },
            'kein Objekt',
          ],
        });
        expect(e.ueberblick.map((k) => (k.id, k.groesse)), [
          // Altersstruktur gibt es als 2×1 und 2×2; 1×1 rastet auf 2×1 ein.
          ('b', KachelGroesse.breit),
          ('c', KachelGroesse.breit),
          ('d', KachelGroesse.breit),
        ]);
      },
    );

    test('ungültige Zielwerte werden verworfen', () {
      final ziele = StatistikZielwerte.fromJson(<String, dynamic>{
        'neuProJahr': 0,
        'gruppeMax': {'woelfling': 14, 'rover': -2, 'leitung': 5, 'quatsch': 3},
      });
      expect(ziele.neuProJahr, isNull);
      expect(ziele.gruppeMax, {Stufe.woelfling: 14});
      expect(ziele.zielFuerStufe(Stufe.woelfling, 2), 28);
      expect(ziele.zielFuerStufe(Stufe.woelfling, 0), 14);
      expect(ziele.zielFuerStufe(Stufe.biber, 1), isNull);
    });

    test('nächste erlaubte Größe bevorzugt gleiche Breite', () {
      expect(
        naechsteErlaubteGroesse(
          StatistikKachelTypen.groessenFuer(StatistikKachelTypen.geschlecht),
          2,
          2,
        ),
        KachelGroesse.breit,
      );
      expect(
        naechsteErlaubteGroesse(
          StatistikKachelTypen.groessenFuer(
            StatistikKachelTypen.altersstruktur,
          ),
          1,
          1,
        ),
        KachelGroesse.breit,
      );
    });
  });

  group('SharedPrefsStatistikKachelRepository', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('lädt Standard für einen leeren Layer', () async {
      final repo = SharedPrefsStatistikKachelRepository();
      expect(await repo.loadForLayer(7), const StatistikKachelEinstellungen());
    });

    test('speichert je Layer getrennt', () async {
      final repo = SharedPrefsStatistikKachelRepository();
      final weitblick = StatistikBeispielStaemme.einstellungenWeitblick();
      await repo.saveForLayer(31, weitblick);

      expect(await repo.loadForLayer(31), weitblick);
      expect(await repo.loadForLayer(32), const StatistikKachelEinstellungen());
    });

    test('kaputter Speicherwert ergibt den Standard', () async {
      SharedPreferences.setMockInitialValues({'statistikKacheln:5': '{kaputt'});
      final repo = SharedPrefsStatistikKachelRepository();
      expect(await repo.loadForLayer(5), const StatistikKachelEinstellungen());
    });
  });
}
