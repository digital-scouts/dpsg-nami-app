import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../../domain/statistiks/statistik_mathe.dart';
import '../statistik_farben.dart';

/// Kleine Diagramm-Bausteine der Statistik-Kacheln. Formen zeichnet ein
/// [CustomPainter]; Beschriftungen innerhalb der Diagramme nutzen den
/// `textScaler` der Umgebung, damit sie mit der Systemschrift wachsen.
/// Alle Bausteine vertragen leere Daten und eine Größe von null.

const double _luecke = 2;

/// Ein Abschnitt eines Bandes, einer Torte oder eines Rings.
class DiagrammTeil {
  const DiagrammTeil({
    required this.wert,
    required this.farbe,
    this.kontur,
    this.beschriftung,
  });

  final num wert;
  final Color farbe;
  final Color? kontur;

  /// Text im Abschnitt; erscheint nur, wenn er hineinpasst.
  final String? beschriftung;

  @override
  bool operator ==(Object other) =>
      other is DiagrammTeil &&
      other.wert == wert &&
      other.farbe == farbe &&
      other.kontur == kontur &&
      other.beschriftung == beschriftung;

  @override
  int get hashCode => Object.hash(wert, farbe, kontur, beschriftung);
}

TextPainter _text(
  String text,
  TextStyle stil,
  TextScaler textScaler, {
  double maxBreite = double.infinity,
  required TextStyle schrift,
}) => TextPainter(
  text: TextSpan(text: text, style: schrift.merge(stil)),
  textDirection: TextDirection.ltr,
  textScaler: textScaler,
  maxLines: 1,
  ellipsis: '…',
)..layout(maxWidth: math.max(0, maxBreite));

/// Nur Familie und Ersatzfamilien der Umgebung, keine Größen oder Zeilenhöhen.
TextStyle _schriftAus(BuildContext context) {
  final stil = DefaultTextStyle.of(context).style;
  return TextStyle(
    fontFamily: stil.fontFamily,
    fontFamilyFallback: stil.fontFamilyFallback,
  );
}

void _rechteck(
  Canvas canvas,
  Rect rect,
  Color farbe, {
  double radius = 3,
  Color? kontur,
}) {
  if (rect.width <= 0 || rect.height <= 0) return;
  final r = RRect.fromRectAndRadius(
    rect,
    Radius.circular(math.min(radius, math.min(rect.width, rect.height) / 2)),
  );
  canvas.drawRRect(r, Paint()..color = farbe);
  if (kontur != null) {
    canvas.drawRRect(
      r.deflate(0.5),
      Paint()
        ..color = kontur
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }
}

// ------------------------------------------------------------------ Band

/// Waagrechtes 100-%-Band mit 2 pt Lücken, optional Zahlen in den Teilen.
class DiagrammBand extends StatelessWidget {
  const DiagrammBand({
    super.key,
    required this.teile,
    this.hoehe = 12,
    this.leerFarbe,
  });

  final List<DiagrammTeil> teile;
  final double hoehe;
  final Color? leerFarbe;

  @override
  Widget build(BuildContext context) {
    final farben = StatistikFarben.of(context);
    return SizedBox(
      height: hoehe,
      width: double.infinity,
      child: CustomPaint(
        painter: _BandPainter(
          teile: teile,
          leer: leerFarbe ?? farben.spur,
          textScaler: MediaQuery.textScalerOf(context),
          schrift: _schriftAus(context),
        ),
      ),
    );
  }
}

class _BandPainter extends CustomPainter {
  _BandPainter({
    required this.teile,
    required this.leer,
    required this.textScaler,
    required this.schrift,
  });

  final List<DiagrammTeil> teile;
  final Color leer;
  final TextScaler textScaler;

  /// Schriftfamilie der Umgebung, damit Beschriftungen wie Text-Widgets
  /// aussehen.
  final TextStyle schrift;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final sichtbar = teile.where((t) => t.wert > 0).toList();
    final summe = sichtbar.fold<num>(0, (s, t) => s + t.wert);
    if (summe <= 0) {
      _rechteck(canvas, Offset.zero & size, leer);
      return;
    }
    final nutzbar = math.max(0.0, size.width - _luecke * (sichtbar.length - 1));
    var x = 0.0;
    for (final teil in sichtbar) {
      final w = nutzbar * anteil(teil.wert, summe);
      final rect = Rect.fromLTWH(x, 0, w, size.height);
      _rechteck(canvas, rect, teil.farbe, kontur: teil.kontur);
      final text = teil.beschriftung;
      if (text != null && size.height >= 12) {
        final tp = _text(
          text,
          TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: StatistikFarben.schriftAuf(teil.farbe),
          ),
          textScaler,
          schrift: schrift,
        );
        if (tp.width + 6 <= w && tp.height <= size.height) {
          tp.paint(
            canvas,
            Offset(x + (w - tp.width) / 2, (size.height - tp.height) / 2),
          );
        }
        tp.dispose();
      }
      x += w + _luecke;
    }
  }

  @override
  bool shouldRepaint(_BandPainter old) =>
      !const ListEquality<DiagrammTeil>().equals(old.teile, teile) ||
      old.leer != leer ||
      old.textScaler != textScaler ||
      old.schrift != schrift;
}

// ------------------------------------------------------ Balken mit Ziel

/// Dünner Balken auf einer Spur, optional mit Zielstrich.
class ZielBalken extends StatelessWidget {
  const ZielBalken({
    super.key,
    required this.wert,
    required this.skala,
    required this.farbe,
    this.kontur,
    this.ziel,
    this.dicke = 4,
  });

  final num wert;
  final num skala;
  final Color farbe;
  final Color? kontur;
  final num? ziel;
  final double dicke;

  @override
  Widget build(BuildContext context) {
    final farben = StatistikFarben.of(context);
    return SizedBox(
      height: dicke + 6,
      width: double.infinity,
      child: CustomPaint(
        painter: _ZielBalkenPainter(
          wert: wert,
          skala: skala,
          farbe: farbe,
          kontur: kontur,
          ziel: ziel,
          dicke: dicke,
          spur: farben.spur,
          zielFarbe: farben.textSchwach,
        ),
      ),
    );
  }
}

class _ZielBalkenPainter extends CustomPainter {
  _ZielBalkenPainter({
    required this.wert,
    required this.skala,
    required this.farbe,
    required this.kontur,
    required this.ziel,
    required this.dicke,
    required this.spur,
    required this.zielFarbe,
  });

  final num wert;
  final num skala;
  final Color farbe;
  final Color? kontur;
  final num? ziel;
  final double dicke;
  final Color spur;
  final Color zielFarbe;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final y = (size.height - dicke) / 2;
    _rechteck(
      canvas,
      Rect.fromLTWH(0, y, size.width, dicke),
      spur,
      radius: dicke / 2,
    );
    _rechteck(
      canvas,
      Rect.fromLTWH(0, y, size.width * anteil(wert, skala), dicke),
      farbe,
      radius: dicke / 2,
      kontur: kontur,
    );
    final z = ziel;
    if (z != null && z > 0) {
      final x = size.width * anteil(z, skala);
      canvas.drawRect(
        Rect.fromLTWH(x - 0.5, 0, 1, size.height),
        Paint()..color = zielFarbe,
      );
    }
  }

  @override
  bool shouldRepaint(_ZielBalkenPainter old) =>
      old.wert != wert ||
      old.skala != skala ||
      old.farbe != farbe ||
      old.kontur != kontur ||
      old.ziel != ziel ||
      old.dicke != dicke ||
      old.spur != spur;
}

// ------------------------------------------------- heute / danach

/// „heute“ als neutraler, breiter Balken, „danach“ schmal in Stufenfarbe.
class HeuteDanachBalken extends StatelessWidget {
  const HeuteDanachBalken({
    super.key,
    required this.heute,
    required this.danach,
    required this.skala,
    required this.farbe,
    this.kontur,
    this.ziel,
    this.hoehe = 16,
  });

  final num heute;
  final num danach;
  final num skala;
  final Color farbe;
  final Color? kontur;
  final num? ziel;
  final double hoehe;

  @override
  Widget build(BuildContext context) {
    final farben = StatistikFarben.of(context);
    return SizedBox(
      height: hoehe,
      width: double.infinity,
      child: CustomPaint(
        painter: _HeuteDanachPainter(
          heute: heute,
          danach: danach,
          skala: skala,
          farbe: farbe,
          kontur: kontur,
          ziel: ziel,
          heuteFarbe: farben.heute,
          zielFarbe: farben.textSchwach,
        ),
      ),
    );
  }
}

class _HeuteDanachPainter extends CustomPainter {
  _HeuteDanachPainter({
    required this.heute,
    required this.danach,
    required this.skala,
    required this.farbe,
    required this.kontur,
    required this.ziel,
    required this.heuteFarbe,
    required this.zielFarbe,
  });

  final num heute;
  final num danach;
  final num skala;
  final Color farbe;
  final Color? kontur;
  final num? ziel;
  final Color heuteFarbe;
  final Color zielFarbe;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final innen = math.max(4.0, (size.height * 0.5).roundToDouble());
    _rechteck(
      canvas,
      Rect.fromLTWH(0, 0, size.width * anteil(heute, skala), size.height),
      heuteFarbe,
    );
    _rechteck(
      canvas,
      Rect.fromLTWH(
        0,
        (size.height - innen) / 2,
        size.width * anteil(danach, skala),
        innen,
      ),
      farbe,
      radius: 2,
      kontur: kontur,
    );
    final z = ziel;
    if (z != null && z > 0) {
      final x = size.width * anteil(z, skala);
      canvas.drawRect(
        Rect.fromLTWH(x - 0.5, -2, 1, size.height + 4),
        Paint()..color = zielFarbe,
      );
    }
  }

  @override
  bool shouldRepaint(_HeuteDanachPainter old) =>
      old.heute != heute ||
      old.danach != danach ||
      old.skala != skala ||
      old.farbe != farbe ||
      old.ziel != ziel ||
      old.heuteFarbe != heuteFarbe;
}

// -------------------------------------------------- Altersstruktur

/// Eine Zeile der Altersstruktur: Stufe, Alter der Kinder, Altersgrenze.
class AltersZeile {
  const AltersZeile({
    required this.beschriftung,
    required this.alter,
    required this.min,
    required this.max,
    required this.farbe,
    required this.flaeche,
    this.kontur,
  });

  final String beschriftung;
  final List<double> alter;
  final int min;
  final int max;
  final Color farbe;
  final Color flaeche;
  final Color? kontur;

  @override
  bool operator ==(Object other) =>
      other is AltersZeile &&
      other.beschriftung == beschriftung &&
      const ListEquality<double>().equals(other.alter, alter) &&
      other.min == min &&
      other.max == max &&
      other.farbe == farbe &&
      other.flaeche == flaeche &&
      other.kontur == kontur;

  @override
  int get hashCode =>
      Object.hash(beschriftung, Object.hashAll(alter), min, max, farbe);
}

/// Säulen je Altersjahr in kleinen Vielfachen je Stufe, die Altersgrenze als
/// getönte Fläche. Füllt die verfügbare Höhe. Alter außerhalb der Achse
/// landen am Rand.
class AltersSaeulen extends StatelessWidget {
  const AltersSaeulen({
    super.key,
    required this.zeilen,
    this.von = 3,
    this.bis = 23,
  });

  final List<AltersZeile> zeilen;
  final int von;
  final int bis;

  @override
  Widget build(BuildContext context) {
    final farben = StatistikFarben.of(context);
    return CustomPaint(
      size: Size.infinite,
      painter: _AltersSaeulenPainter(
        zeilen: zeilen,
        von: von,
        bis: bis,
        text: farben.textGedaempft,
        achse: farben.textSchwach,
        linie: farben.spur,
        textScaler: MediaQuery.textScalerOf(context),
        schrift: _schriftAus(context),
      ),
    );
  }
}

class _AltersSaeulenPainter extends CustomPainter {
  _AltersSaeulenPainter({
    required this.zeilen,
    required this.von,
    required this.bis,
    required this.text,
    required this.achse,
    required this.linie,
    required this.textScaler,
    required this.schrift,
  });

  final List<AltersZeile> zeilen;
  final int von;
  final int bis;
  final Color text;
  final Color achse;
  final Color linie;
  final TextScaler textScaler;

  /// Schriftfamilie der Umgebung, damit Beschriftungen wie Text-Widgets
  /// aussehen.
  final TextStyle schrift;

  int _jahr(double alter) => alter.floor().clamp(von, bis - 1);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || zeilen.isEmpty || bis <= von) return;
    final labelStil = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: text,
    );
    final achsStil = TextStyle(fontSize: 10, color: achse);
    final labelBreite = zeilen
        .map(
          (z) => _text(
            z.beschriftung,
            labelStil,
            textScaler,
            schrift: schrift,
          ).width,
        )
        .fold<double>(0, math.max)
        .clamp(0.0, size.width * 0.3);
    final achsProbe = _text('22', achsStil, textScaler, schrift: schrift);
    final achsHoehe = achsProbe.height + 4;
    achsProbe.dispose();
    final x0 = labelBreite + 8;
    final pw = math.max(0.0, size.width - x0 - 4);
    final proJahr = pw / (bis - von);
    double x(num alter) =>
        x0 + (alter.clamp(von, bis) - von) / (bis - von) * pw;

    final zeilenHoehe = math.max(
      0.0,
      (size.height - achsHoehe) / zeilen.length,
    );
    final maxProJahr = math.max(
      1,
      zeilen
          .map((z) {
            final zaehler = <int, int>{};
            for (final a in z.alter) {
              zaehler.update(_jahr(a), (n) => n + 1, ifAbsent: () => 1);
            }
            return zaehler.values.fold<int>(0, math.max);
          })
          .fold<int>(0, math.max),
    );
    final saeulenBreite = math.max(1.0, math.min(10.0, proJahr - 3));

    for (var i = 0; i < zeilen.length; i++) {
      final z = zeilen[i];
      final oben = i * zeilenHoehe;
      final unten = oben + zeilenHoehe - 2;
      final hoeheMax = math.max(0.0, zeilenHoehe - 8);
      _rechteck(
        canvas,
        Rect.fromLTRB(x(z.min), oben + 2, x(z.max + 1), unten),
        z.flaeche,
        radius: 4,
      );
      canvas.drawRect(
        Rect.fromLTWH(x0, unten - 0.5, pw, 1),
        Paint()..color = linie,
      );
      final label = _text(
        z.beschriftung,
        labelStil,
        textScaler,
        schrift: schrift,
        maxBreite: labelBreite,
      );
      label.paint(canvas, Offset(0, oben + (zeilenHoehe - label.height) / 2));
      label.dispose();
      final zaehler = <int, int>{};
      for (final a in z.alter) {
        zaehler.update(_jahr(a), (n) => n + 1, ifAbsent: () => 1);
      }
      for (final eintrag in zaehler.entries) {
        final h = hoeheMax * eintrag.value / maxProJahr;
        final links = x(eintrag.key) + (proJahr - saeulenBreite) / 2;
        final rect = Rect.fromLTWH(links, unten - h, saeulenBreite, h);
        if (rect.height <= 0) continue;
        final r = RRect.fromRectAndCorners(
          rect,
          topLeft: Radius.circular(math.min(3, saeulenBreite / 2)),
          topRight: Radius.circular(math.min(3, saeulenBreite / 2)),
        );
        canvas.drawRRect(r, Paint()..color = z.farbe);
        if (z.kontur != null) {
          canvas.drawRRect(
            r.deflate(0.5),
            Paint()
              ..color = z.kontur!
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        }
      }
    }
    final achsY = zeilen.length * zeilenHoehe + 3;
    for (var a = (von / 2).ceil() * 2; a < bis; a += 2) {
      final tp = _text('$a', achsStil, textScaler, schrift: schrift);
      final mitte = x(a) + proJahr / 2;
      if (mitte - tp.width / 2 >= x0 - 2 &&
          mitte + tp.width / 2 <= size.width) {
        tp.paint(canvas, Offset(mitte - tp.width / 2, achsY));
      }
      tp.dispose();
    }
  }

  @override
  bool shouldRepaint(_AltersSaeulenPainter old) =>
      !const ListEquality<AltersZeile>().equals(old.zeilen, zeilen) ||
      old.von != von ||
      old.bis != bis ||
      old.text != text ||
      old.textScaler != textScaler ||
      old.schrift != schrift;
}

/// Spanne einer Stufe: Fläche = Altersgrenze, Linie = jüngste bis älteste,
/// Punkt = Median. Eigene Skala, damit die Linie über die Grenze laufen kann.
class AltersStreifen extends StatelessWidget {
  const AltersStreifen({
    super.key,
    required this.alter,
    required this.min,
    required this.max,
    required this.farbe,
    required this.flaeche,
    this.kontur,
    this.hoehe = 12,
  });

  final List<double> alter;
  final int min;
  final int max;
  final Color farbe;
  final Color flaeche;
  final Color? kontur;
  final double hoehe;

  @override
  Widget build(BuildContext context) {
    final farben = StatistikFarben.of(context);
    return SizedBox(
      height: hoehe,
      width: double.infinity,
      child: CustomPaint(
        painter: _AltersStreifenPainter(
          alter: alter,
          min: min,
          max: max,
          farbe: farbe,
          flaeche: flaeche,
          kontur: kontur,
          ring: farben.flaeche,
          linieBiber: farben.textGedaempft,
        ),
      ),
    );
  }
}

class _AltersStreifenPainter extends CustomPainter {
  _AltersStreifenPainter({
    required this.alter,
    required this.min,
    required this.max,
    required this.farbe,
    required this.flaeche,
    required this.kontur,
    required this.ring,
    required this.linieBiber,
  });

  final List<double> alter;
  final int min;
  final int max;
  final Color farbe;
  final Color flaeche;
  final Color? kontur;
  final Color ring;
  final Color linieBiber;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final werte = alter.where((a) => a.isFinite).toList();
    final lo = werte.isEmpty ? min.toDouble() : werte.reduce(math.min);
    final hi = werte.isEmpty ? max.toDouble() : werte.reduce(math.max);
    final von = math.min(min.toDouble(), lo) - 1.5;
    final bis = math.max(max + 1.0, hi) + 1.5;
    double x(double a) => (a - von) / (bis - von) * size.width;
    final m = size.height / 2;
    _rechteck(
      canvas,
      Rect.fromLTRB(x(min.toDouble()), 0, x(max + 1.0), size.height),
      flaeche,
    );
    if (werte.isEmpty) return;
    final linie = kontur != null ? linieBiber : farbe;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(x(lo), m - 1, math.max(x(lo) + 2, x(hi)), m + 1),
        const Radius.circular(1),
      ),
      Paint()..color = linie,
    );
    final mitte = median(werte) ?? lo;
    final r = (size.height / 3).clamp(3.0, 5.0);
    canvas.drawCircle(Offset(x(mitte), m), r + 2, Paint()..color = ring);
    canvas.drawCircle(Offset(x(mitte), m), r, Paint()..color = farbe);
    if (kontur != null) {
      canvas.drawCircle(
        Offset(x(mitte), m),
        r - 0.5,
        Paint()
          ..color = kontur!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_AltersStreifenPainter old) =>
      !const ListEquality<double>().equals(old.alter, alter) ||
      old.min != min ||
      old.max != max ||
      old.farbe != farbe ||
      old.flaeche != flaeche;
}

// ------------------------------------------------------ Ring und Torte

/// Ring mit Kürzeln in großen Abschnitten und der Summe in der Mitte; ohne
/// [ring] wird daraus eine Torte mit Anzahlen in den Stücken.
class MerkmalRing extends StatelessWidget {
  const MerkmalRing({
    super.key,
    required this.teile,
    this.mitte,
    this.ringAnteil = 0.27,
    this.torte = false,
  });

  final List<DiagrammTeil> teile;
  final String? mitte;

  /// Ringdicke relativ zum Durchmesser.
  final double ringAnteil;
  final bool torte;

  @override
  Widget build(BuildContext context) {
    final farben = StatistikFarben.of(context);
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: _RingPainter(
          teile: teile,
          mitte: mitte,
          ringAnteil: ringAnteil,
          torte: torte,
          luecke: farben.flaeche,
          leer: farben.spur,
          text: farben.text,
          textScaler: MediaQuery.textScalerOf(context),
          schrift: _schriftAus(context),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.teile,
    required this.mitte,
    required this.ringAnteil,
    required this.torte,
    required this.luecke,
    required this.leer,
    required this.text,
    required this.textScaler,
    required this.schrift,
  });

  final List<DiagrammTeil> teile;
  final String? mitte;
  final double ringAnteil;
  final bool torte;
  final Color luecke;
  final Color leer;
  final Color text;
  final TextScaler textScaler;

  /// Schriftfamilie der Umgebung, damit Beschriftungen wie Text-Widgets
  /// aussehen.
  final TextStyle schrift;

  @override
  void paint(Canvas canvas, Size size) {
    final d = math.min(size.width, size.height);
    if (d <= 0) return;
    final c = Offset(size.width / 2, size.height / 2);
    final ra = d / 2 - 1;
    final dicke = torte ? ra : math.max(2.0, d * ringAnteil);
    final ri = math.max(0.0, ra - dicke);
    final sichtbar = teile.where((t) => t.wert > 0).toList();
    final summe = sichtbar.fold<num>(0, (s, t) => s + t.wert);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ra - ri;
    final mittelRadius = (ra + ri) / 2;
    if (summe <= 0) {
      canvas.drawCircle(c, mittelRadius, ringPaint..color = leer);
    } else {
      var winkel = -math.pi / 2;
      final labels = <(String, Offset, Color)>[];
      for (final teil in sichtbar) {
        final w = anteil(teil.wert, summe) * math.pi * 2;
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: mittelRadius),
          winkel,
          w,
          false,
          ringPaint..color = teil.farbe,
        );
        final b = teil.beschriftung;
        if (b != null && b.isNotEmpty && anteil(teil.wert, summe) >= 0.12) {
          final am = winkel + w / 2;
          final rl = torte ? ra * 0.6 : mittelRadius;
          labels.add((
            b,
            c + Offset(math.cos(am) * rl, math.sin(am) * rl),
            StatistikFarben.schriftAuf(teil.farbe),
          ));
        }
        winkel += w;
      }
      // 2-pt-Lücken zwischen den Abschnitten.
      if (sichtbar.length > 1) {
        var grenze = -math.pi / 2;
        final linie = Paint()
          ..color = luecke
          ..strokeWidth = 2;
        for (final teil in sichtbar) {
          canvas.drawLine(
            c + Offset(math.cos(grenze) * ri, math.sin(grenze) * ri),
            c +
                Offset(
                  math.cos(grenze) * (ra + 1),
                  math.sin(grenze) * (ra + 1),
                ),
            linie,
          );
          grenze += anteil(teil.wert, summe) * math.pi * 2;
        }
      }
      for (final (b, p, farbe) in labels) {
        final tp = _text(
          b,
          TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: farbe),
          textScaler,
          schrift: schrift,
          maxBreite: dicke * 1.6,
        );
        tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
        tp.dispose();
      }
    }
    final m = mitte;
    if (m != null && ri > 6) {
      final tp = _text(
        m,
        TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: text),
        textScaler,
        schrift: schrift,
        maxBreite: ri * 1.8,
      );
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
      tp.dispose();
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      !const ListEquality<DiagrammTeil>().equals(old.teile, teile) ||
      old.mitte != mitte ||
      old.ringAnteil != ringAnteil ||
      old.torte != torte ||
      old.luecke != luecke ||
      old.text != text ||
      old.textScaler != textScaler ||
      old.schrift != schrift;
}

// ------------------------------------------------------- Plätze, Monate

/// Felder für Plätze: [besetzt] von [plaetze] gefüllt.
class PlatzFelder extends StatelessWidget {
  const PlatzFelder({super.key, required this.besetzt, required this.plaetze});

  final int besetzt;
  final int plaetze;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final n = plaetze.clamp(1, 12);
    return SizedBox(
      height: 10,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < n; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: i < besetzt ? scheme.primary : scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Kleine Säulen je Monat in der Primärfarbe.
class MonatsSaeulen extends StatelessWidget {
  const MonatsSaeulen({super.key, required this.werte, this.hoehe = 22});

  final List<int> werte;
  final double hoehe;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: hoehe,
      width: double.infinity,
      child: CustomPaint(
        painter: _MonatsSaeulenPainter(
          werte: werte,
          farbe: scheme.primary,
          linie: scheme.outline,
        ),
      ),
    );
  }
}

class _MonatsSaeulenPainter extends CustomPainter {
  _MonatsSaeulenPainter({
    required this.werte,
    required this.farbe,
    required this.linie,
  });

  final List<int> werte;
  final Color farbe;
  final Color linie;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || werte.isEmpty) return;
    final max = werte.fold<int>(0, math.max);
    final slot = size.width / werte.length;
    final w = math.max(1.0, math.min(8.0, slot - 3));
    for (var i = 0; i < werte.length; i++) {
      if (werte[i] <= 0 || max <= 0) continue;
      final h = math.max(3.0, (size.height - 1) * anteil(werte[i], max));
      _rechteck(
        canvas,
        Rect.fromLTWH(i * slot + (slot - w) / 2, size.height - 1 - h, w, h),
        farbe,
        radius: 1.5,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 0.5, size.width, 1),
      Paint()..color = linie,
    );
  }

  @override
  bool shouldRepaint(_MonatsSaeulenPainter old) =>
      !const ListEquality<int>().equals(old.werte, werte) || old.farbe != farbe;
}

/// Verlauf als Linie mit Punkten über einer Monatsachse.
class VerlaufKurve extends StatelessWidget {
  const VerlaufKurve({super.key, required this.werte, required this.monate});

  /// Werte je Achsenmonat, ältester zuerst; `null` = Monat ohne
  /// Aufzeichnung (die Linie wird dort unterbrochen).
  final List<int?> werte;

  /// Beschriftungen der Achse.
  final List<String> monate;

  @override
  Widget build(BuildContext context) {
    final farben = StatistikFarben.of(context);
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      size: Size.infinite,
      painter: _VerlaufPainter(
        werte: werte,
        monate: monate,
        farbe: scheme.primary,
        linie: farben.spur,
        achse: farben.textSchwach,
        textScaler: MediaQuery.textScalerOf(context),
        schrift: _schriftAus(context),
      ),
    );
  }
}

class _VerlaufPainter extends CustomPainter {
  _VerlaufPainter({
    required this.werte,
    required this.monate,
    required this.farbe,
    required this.linie,
    required this.achse,
    required this.textScaler,
    required this.schrift,
  });

  final List<int?> werte;
  final List<String> monate;
  final Color farbe;
  final Color linie;
  final Color achse;
  final TextScaler textScaler;

  /// Schriftfamilie der Umgebung, damit Beschriftungen wie Text-Widgets
  /// aussehen.
  final TextStyle schrift;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || monate.isEmpty) return;
    final stil = TextStyle(fontSize: 10, color: achse);
    final probe = _text('M', stil, textScaler, schrift: schrift);
    final achsHoehe = probe.height + 4;
    probe.dispose();
    final grund = math.max(0.0, size.height - achsHoehe);
    final slot = size.width / monate.length;
    canvas.drawRect(
      Rect.fromLTWH(0, grund - 0.5, size.width, 1),
      Paint()..color = linie,
    );
    for (var i = 0; i < monate.length; i++) {
      final mitte = i * slot + slot / 2;
      canvas.drawRect(
        Rect.fromLTWH(mitte - 0.5, grund - 3, 1, 5),
        Paint()..color = linie,
      );
      final tp = _text(
        monate[i],
        stil,
        textScaler,
        maxBreite: slot,
        schrift: schrift,
      );
      tp.paint(canvas, Offset(mitte - tp.width / 2, grund + 4));
      tp.dispose();
    }
    final vorhanden = werte.whereType<int>();
    if (vorhanden.isEmpty) return;
    final max = vorhanden.fold<int>(0, math.max);
    final min = vorhanden.fold<int>(max, math.min);
    final spanne = math.max(1, max - min);
    final punkte = <Offset?>[
      for (var i = 0; i < werte.length && i < monate.length; i++)
        if (werte[i] case final wert?)
          Offset(
            i * slot + slot / 2,
            8 + math.max(0.0, grund - 16) * (1 - (wert - min) / spanne),
          )
        else
          null,
    ];
    final pfad = Path();
    Offset? vorher;
    for (final p in punkte) {
      if (p != null) {
        if (vorher == null) {
          pfad.moveTo(p.dx, p.dy);
        } else {
          pfad.lineTo(p.dx, p.dy);
        }
      }
      vorher = p;
    }
    canvas.drawPath(
      pfad,
      Paint()
        ..color = farbe
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
    for (final p in punkte.nonNulls) {
      canvas.drawCircle(p, 4, Paint()..color = farbe);
    }
  }

  @override
  bool shouldRepaint(_VerlaufPainter old) =>
      !const ListEquality<int?>().equals(old.werte, werte) ||
      !const ListEquality<String>().equals(old.monate, monate) ||
      old.farbe != farbe ||
      old.textScaler != textScaler ||
      old.schrift != schrift;
}
