import 'dart:math' as math;
import 'dart:ui';

import '../../../domain/statistiks/statistik_kachel_typen.dart';

/// Platz einer Kachel im Raster, in Spalten und Zeilen.
class KachelPlatz {
  const KachelPlatz(this.spalte, this.zeile, this.breite, this.hoehe);

  final int spalte;
  final int zeile;
  final int breite;
  final int hoehe;

  @override
  bool operator ==(Object other) =>
      other is KachelPlatz &&
      other.spalte == spalte &&
      other.zeile == zeile &&
      other.breite == breite &&
      other.hoehe == hoehe;

  @override
  int get hashCode => Object.hash(spalte, zeile, breite, hoehe);

  @override
  String toString() => 'KachelPlatz($spalte, $zeile, $breite×$hoehe)';
}

class KachelPackung {
  const KachelPackung(this.plaetze, this.zeilen);

  /// In derselben Reihenfolge wie die Eingabe.
  final List<KachelPlatz> plaetze;
  final int zeilen;
}

/// Packt Kacheln dicht wie CSS `grid-auto-flow: row dense`: jede Kachel kommt
/// an den ersten freien Platz von oben links, an dem sie vollständig passt.
/// Spätere kleine Kacheln füllen so Lücken weiter oben. Breiten über
/// [spalten] werden gekappt.
KachelPackung packeKacheln(
  List<KachelGroesse> groessen, {
  required int spalten,
}) {
  assert(spalten > 0);
  final belegt = <List<bool>>[];
  final plaetze = <KachelPlatz>[];

  bool frei(int zeile, int spalte, int breite, int hoehe) {
    for (var z = zeile; z < zeile + hoehe; z++) {
      if (z >= belegt.length) continue;
      for (var s = spalte; s < spalte + breite; s++) {
        if (belegt[z][s]) return false;
      }
    }
    return true;
  }

  for (final groesse in groessen) {
    final breite = math.min(groesse.spalten, spalten);
    final hoehe = groesse.zeilen;
    var platz = false;
    for (var zeile = 0; !platz; zeile++) {
      for (var spalte = 0; spalte + breite <= spalten; spalte++) {
        if (!frei(zeile, spalte, breite, hoehe)) continue;
        while (belegt.length < zeile + hoehe) {
          belegt.add(List<bool>.filled(spalten, false));
        }
        for (var z = zeile; z < zeile + hoehe; z++) {
          for (var s = spalte; s < spalte + breite; s++) {
            belegt[z][s] = true;
          }
        }
        plaetze.add(KachelPlatz(spalte, zeile, breite, hoehe));
        platz = true;
        break;
      }
    }
  }
  return KachelPackung(List.unmodifiable(plaetze), belegt.length);
}

/// Maße des Rasters: Spalten aus der verfügbaren Breite, Zeilenhöhe wächst
/// mit der Textskalierung (gedeckelt wie der Seiten-Header).
class KachelRasterMetrik {
  const KachelRasterMetrik._({
    required this.spalten,
    required this.spaltenBreite,
    required this.zeilenHoehe,
  });

  factory KachelRasterMetrik.aus({
    required double breite,
    required double textSkala,
    double maxTextSkala = 1.4,
  }) {
    final spalten = breite >= tabletAbBreite ? 4 : 2;
    final skala = textSkala.isFinite
        ? textSkala.clamp(1.0, maxTextSkala).toDouble()
        : 1.0;
    return KachelRasterMetrik._(
      spalten: spalten,
      spaltenBreite: math.max(0, (breite - luecke * (spalten - 1)) / spalten),
      zeilenHoehe: basisZeilenHoehe * skala,
    );
  }

  static const double luecke = 12;
  static const double basisZeilenHoehe = 150;
  static const double tabletAbBreite = 700;

  final int spalten;
  final double spaltenBreite;
  final double zeilenHoehe;

  Rect rechteck(KachelPlatz platz) => Rect.fromLTWH(
    platz.spalte * (spaltenBreite + luecke),
    platz.zeile * (zeilenHoehe + luecke),
    platz.breite * spaltenBreite + (platz.breite - 1) * luecke,
    platz.hoehe * zeilenHoehe + (platz.hoehe - 1) * luecke,
  );

  Size groesse(KachelGroesse groesse) => Size(
    math.min(groesse.spalten, spalten) * spaltenBreite +
        (math.min(groesse.spalten, spalten) - 1) * luecke,
    groesse.zeilen * zeilenHoehe + (groesse.zeilen - 1) * luecke,
  );

  double hoehe(int zeilen) =>
      zeilen <= 0 ? 0 : zeilen * zeilenHoehe + (zeilen - 1) * luecke;
}

/// Neuer Listenindex für die gezogene Kachel [gezogen], bei dem ihr gepackter
/// Platz unter [zeiger] liegt (Rasterkoordinaten). `null`, wenn sie bleiben
/// soll – auch wenn der aktuelle Platz schon passt (verhindert Hin- und
/// Herspringen beim dichten Packen).
int? besteZielPosition({
  required List<KachelGroesse> groessen,
  required int gezogen,
  required Offset zeiger,
  required KachelRasterMetrik metrik,
}) {
  if (gezogen < 0 || gezogen >= groessen.length) return null;
  bool trifft(int ziel) {
    final reihenfolge = [...groessen];
    final g = reihenfolge.removeAt(gezogen);
    reihenfolge.insert(ziel, g);
    final packung = packeKacheln(reihenfolge, spalten: metrik.spalten);
    return metrik.rechteck(packung.plaetze[ziel]).contains(zeiger);
  }

  if (trifft(gezogen)) return null;
  int? beste;
  for (var ziel = 0; ziel < groessen.length; ziel++) {
    if (ziel == gezogen || !trifft(ziel)) continue;
    if (beste == null || (ziel - gezogen).abs() < (beste - gezogen).abs()) {
      beste = ziel;
    }
  }
  return beste;
}
