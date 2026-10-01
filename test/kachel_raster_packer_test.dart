import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/statistiks/statistik_kachel_typen.dart';
import 'package:nami/presentation/statistics/kacheln/kachel_raster_packer.dart';

void main() {
  const k = KachelGroesse.klein;
  const b = KachelGroesse.breit;
  const g = KachelGroesse.gross;

  group('packeKacheln', () {
    test('füllt Lücken dicht auf', () {
      final p = packeKacheln([k, b, k], spalten: 2);
      expect(p.plaetze, const [
        KachelPlatz(0, 0, 1, 1),
        KachelPlatz(0, 1, 2, 1),
        KachelPlatz(1, 0, 1, 1),
      ]);
      expect(p.zeilen, 2);
    });

    test('2×2 neben 1×1 auf vier Spalten', () {
      final p = packeKacheln([g, k, k, k, k, k], spalten: 4);
      expect(p.plaetze.first, const KachelPlatz(0, 0, 2, 2));
      expect(p.plaetze[1], const KachelPlatz(2, 0, 1, 1));
      expect(p.plaetze[5], const KachelPlatz(0, 2, 1, 1));
      expect(p.zeilen, 3);
    });

    test('leer und zu breit', () {
      expect(packeKacheln(const [], spalten: 2).zeilen, 0);
      final p = packeKacheln([b], spalten: 1);
      expect(p.plaetze.single, const KachelPlatz(0, 0, 1, 1));
    });

    test(
      'Zufallsfolgen: keine Überlappung, alles im Raster, keine leere Zeile',
      () {
        final zufall = math.Random(7);
        for (var lauf = 0; lauf < 200; lauf++) {
          final spalten = zufall.nextBool() ? 2 : 4;
          final groessen = List.generate(
            zufall.nextInt(14),
            (_) => KachelGroesse.values[zufall.nextInt(3)],
          );
          final p = packeKacheln(groessen, spalten: spalten);
          final zellen = <(int, int)>{};
          for (final platz in p.plaetze) {
            expect(platz.spalte + platz.breite, lessThanOrEqualTo(spalten));
            for (var z = platz.zeile; z < platz.zeile + platz.hoehe; z++) {
              for (var s = platz.spalte; s < platz.spalte + platz.breite; s++) {
                expect(
                  zellen.add((z, s)),
                  isTrue,
                  reason: 'Überlappung $platz',
                );
              }
            }
          }
          for (var z = 0; z < p.zeilen; z++) {
            expect(zellen.any((zelle) => zelle.$1 == z), isTrue);
          }
          expect(packeKacheln(groessen, spalten: spalten).plaetze, p.plaetze);
        }
      },
    );
  });

  group('KachelRasterMetrik', () {
    test('Handy: zwei Spalten à 173 pt', () {
      final m = KachelRasterMetrik.aus(breite: 358, textSkala: 1);
      expect(m.spalten, 2);
      expect(m.spaltenBreite, 173);
      expect(m.zeilenHoehe, 150);
      expect(
        m.rechteck(const KachelPlatz(1, 1, 1, 1)),
        const Rect.fromLTWH(185, 162, 173, 150),
      );
      expect(m.hoehe(2), 312);
      expect(m.groesse(KachelGroesse.gross), const Size(358, 312));
    });

    test('Zeilenhöhe wächst mit der Schrift bis 1,4', () {
      double zeile(double skala) =>
          KachelRasterMetrik.aus(breite: 358, textSkala: skala).zeilenHoehe;
      expect(zeile(0.8), 150);
      expect(zeile(1.3), closeTo(195, 0.001));
      expect(zeile(1.4), closeTo(210, 0.001));
      expect(zeile(2.0), closeTo(210, 0.001));
      expect(zeile(double.nan), 150);
    });

    test('Tablet: vier Spalten', () {
      expect(KachelRasterMetrik.aus(breite: 820, textSkala: 1).spalten, 4);
      expect(KachelRasterMetrik.aus(breite: 0, textSkala: 1).spaltenBreite, 0);
    });
  });

  group('besteZielPosition', () {
    final metrik = KachelRasterMetrik.aus(breite: 358, textSkala: 1);

    test('bleibt, solange der eigene Platz unter dem Finger liegt', () {
      expect(
        besteZielPosition(
          groessen: [k, k, b],
          gezogen: 0,
          zeiger: const Offset(40, 40),
          metrik: metrik,
        ),
        isNull,
      );
    });

    test('wandert an den Platz unter dem Finger', () {
      expect(
        besteZielPosition(
          groessen: [k, k, b],
          gezogen: 0,
          zeiger: const Offset(250, 40),
          metrik: metrik,
        ),
        1,
      );
      // Dichte Packung: die letzte 1×1 rückt in die Lücke oben rechts.
      expect(
        besteZielPosition(
          groessen: [k, b, k, k],
          gezogen: 3,
          zeiger: const Offset(250, 40),
          metrik: metrik,
        ),
        2,
      );
    });

    test('außerhalb aller Plätze: keine Änderung', () {
      expect(
        besteZielPosition(
          groessen: [k, k],
          gezogen: 1,
          zeiger: const Offset(40, 900),
          metrik: metrik,
        ),
        isNull,
      );
    });
  });
}
