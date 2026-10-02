import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/taetigkeit/pfadfinder_verlauf.dart';
import '../../../domain/taetigkeit/roles.dart';
import '../../../domain/taetigkeit/stufe.dart';
import '../../statistics/statistik_farben.dart';

/// Bahnen Mitglied, Leitung und Aemter auf einer gemeinsamen Jahresachse.
/// Gleichzeitige Rollen liegen uebereinander. Stufenkuerzel stehen im Balken,
/// wenn sie passen; die Reihenfolge der Stufen traegt die Bedeutung auch ohne
/// Farbe, Balken werden nie fuer ein Label verlaengert.
class VerlaufBahnen extends StatelessWidget {
  const VerlaufBahnen({
    super.key,
    required this.verlauf,
    required this.bahnNamen,
    required this.unbekanntText,
  });

  final PfadfinderVerlauf verlauf;

  /// Beschriftungen fuer Mitglied, Leitung, Aemter.
  final ({String mitglied, String leitung, String aemter}) bahnNamen;
  final String unbekanntText;

  static const double _zeile = 14;
  static const double _zeilenAbstand = 2;
  static const double _bahnAbstand = 8;
  static const double _achse = 18;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final farben = StatistikFarben.of(context);
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.4);
    final bahnen = <(String, List<VerlaufSegment>)>[
      (
        bahnNamen.mitglied,
        verlauf.segmente.where((s) => s.art == RoleCategory.mitglied).toList(),
      ),
      (
        bahnNamen.leitung,
        verlauf.segmente.where((s) => s.art == RoleCategory.leitung).toList(),
      ),
      (
        bahnNamen.aemter,
        verlauf.segmente.where((s) => s.art == RoleCategory.sonstiges).toList(),
      ),
    ].where((bahn) => bahn.$2.isNotEmpty).toList(growable: false);

    final gepackt = [for (final bahn in bahnen) _packe(bahn.$2)];
    var hoehe = 0.0;
    for (final reihen in gepackt) {
      hoehe += reihen.anzahl * _zeile + (reihen.anzahl - 1) * _zeilenAbstand;
      hoehe += _bahnAbstand;
    }
    hoehe += _achse;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: _beschreibung(),
          child: SizedBox(
            height: hoehe,
            width: double.infinity,
            child: CustomPaint(
              painter: _BahnenPainter(
                verlauf: verlauf,
                bahnen: [
                  for (var i = 0; i < bahnen.length; i++)
                    (bahnen[i].$1, gepackt[i]),
                ],
                farben: farben,
                textFarbe: farben.textGedaempft,
                achsenFarbe: theme.colorScheme.outlineVariant,
                gitterFarbe: theme.colorScheme.outline,
                schraffurFarbe: theme.colorScheme.outline,
                schraffurFlaeche: theme.colorScheme.surfaceContainerHighest,
                amtFarbe: theme.colorScheme.outlineVariant,
                scaler: scaler,
                schrift: theme.textTheme.labelSmall ?? const TextStyle(),
                zeile: _zeile,
                zeilenAbstand: _zeilenAbstand,
                bahnAbstand: _bahnAbstand,
              ),
            ),
          ),
        ),
        if (verlauf.unbekanntBis != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 14,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: theme.colorScheme.outline),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  unbekanntText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _beschreibung() {
    return verlauf.segmente
        .map((s) {
          final name = s.stufe?.displayName ?? s.rolle.resolvedLabel ?? '';
          final art = s.art == RoleCategory.leitung ? ' (Leitung)' : '';
          return '$name$art ${s.von.year}–${s.aktiv ? 'heute' : s.bis.year}';
        })
        .join(', ');
  }

  static _Gepackt _packe(List<VerlaufSegment> segmente) {
    final enden = <DateTime>[];
    final reihen = <VerlaufSegment, int>{};
    for (final s in segmente..sort((a, b) => a.von.compareTo(b.von))) {
      var reihe = enden.indexWhere((ende) => !ende.isAfter(s.von));
      if (reihe < 0) {
        reihe = enden.length;
        enden.add(s.bis);
      } else {
        enden[reihe] = s.bis;
      }
      reihen[s] = reihe;
    }
    return _Gepackt(reihen, math.max(1, enden.length));
  }
}

class _Gepackt {
  const _Gepackt(this.reihen, this.anzahl);

  final Map<VerlaufSegment, int> reihen;
  final int anzahl;
}

class _BahnenPainter extends CustomPainter {
  _BahnenPainter({
    required this.verlauf,
    required this.bahnen,
    required this.farben,
    required this.textFarbe,
    required this.achsenFarbe,
    required this.gitterFarbe,
    required this.schraffurFarbe,
    required this.schraffurFlaeche,
    required this.amtFarbe,
    required this.scaler,
    required this.schrift,
    required this.zeile,
    required this.zeilenAbstand,
    required this.bahnAbstand,
  });

  final PfadfinderVerlauf verlauf;
  final List<(String, _Gepackt)> bahnen;
  final StatistikFarben farben;
  final Color textFarbe;
  final Color achsenFarbe;
  final Color gitterFarbe;
  final Color schraffurFarbe;
  final Color schraffurFlaeche;
  final Color amtFarbe;
  final TextScaler scaler;

  /// Grundschrift aus dem Theme, damit Familie und Fallbacks stimmen.
  final TextStyle schrift;
  final double zeile;
  final double zeilenAbstand;
  final double bahnAbstand;

  static const double _labelBreite = 58;

  @override
  void paint(Canvas canvas, Size size) {
    final von = verlauf.von.millisecondsSinceEpoch.toDouble();
    final bis = math.max(
      verlauf.bis.millisecondsSinceEpoch.toDouble(),
      von + const Duration(days: 1).inMilliseconds,
    );
    final breite = size.width - _labelBreite;
    double x(DateTime d) =>
        _labelBreite + (d.millisecondsSinceEpoch - von) / (bis - von) * breite;
    final inhaltHoehe = size.height - 18;

    _zeichneAchse(canvas, size, x, inhaltHoehe);

    var y = 0.0;
    for (final (name, gepackt) in bahnen) {
      final bahnHoehe =
          gepackt.anzahl * zeile + (gepackt.anzahl - 1) * zeilenAbstand;
      _text(
        canvas,
        name,
        Offset(0, y + bahnHoehe / 2),
        textFarbe,
        11,
        FontWeight.w600,
        maxBreite: _labelBreite - 4,
        mittig: true,
      );
      final unbekanntBis = verlauf.unbekanntBis;
      if (unbekanntBis != null) {
        _schraffur(
          canvas,
          Rect.fromLTRB(x(verlauf.von), y, x(unbekanntBis) - 2, y + bahnHoehe),
        );
      }
      for (final eintrag in gepackt.reihen.entries) {
        final s = eintrag.key;
        final oben = y + eintrag.value * (zeile + zeilenAbstand);
        final links = x(s.von);
        final rechts = math.max(links + 6, x(s.bis) - 2);
        final rect = Rect.fromLTRB(links, oben, rechts, oben + zeile);
        final stufe = s.stufe;
        final farbe = stufe == null ? amtFarbe : farben.stufe(stufe);
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
        canvas.drawRRect(rrect, Paint()..color = farbe);
        final kontur = stufe == null ? null : farben.kontur(stufe);
        if (kontur != null) {
          canvas.drawRRect(
            rrect,
            Paint()
              ..color = kontur
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        }
        if (stufe != null && stufe != Stufe.leitung) {
          _kuerzel(canvas, stufe.shortDisplayName, rect, farbe);
        }
      }
      y += bahnHoehe + bahnAbstand;
    }
  }

  void _zeichneAchse(
    Canvas canvas,
    Size size,
    double Function(DateTime) x,
    double inhaltHoehe,
  ) {
    final jahrVon = verlauf.von.year;
    final jahrBis = verlauf.bis.year;
    final spanne = jahrBis - jahrVon;
    final schritt = spanne > 14 ? 5 : (spanne > 6 ? 2 : 1);
    final gitter = Paint()
      ..color = gitterFarbe
      ..strokeWidth = 1;
    for (
      var jahr = (jahrVon / schritt).ceil() * schritt;
      jahr <= jahrBis;
      jahr += schritt
    ) {
      final tx = x(DateTime(jahr));
      if (tx < _labelBreite - 1 || tx > size.width + 1) {
        continue;
      }
      canvas.drawLine(Offset(tx, 0), Offset(tx, inhaltHoehe - 4), gitter);
      _text(
        canvas,
        '$jahr',
        Offset(tx, inhaltHoehe + 2),
        achsenFarbe,
        10,
        FontWeight.w400,
        zentriert: true,
      );
    }
  }

  void _schraffur(Canvas canvas, Rect rect) {
    if (rect.width <= 0) {
      return;
    }
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(rect, Paint()..color = schraffurFlaeche);
    final linie = Paint()
      ..color = schraffurFarbe
      ..strokeWidth = 2;
    for (var dx = -rect.height; dx < rect.width; dx += 6) {
      canvas.drawLine(
        Offset(rect.left + dx, rect.bottom),
        Offset(rect.left + dx + rect.height, rect.top),
        linie,
      );
    }
    canvas.restore();
  }

  void _kuerzel(Canvas canvas, String text, Rect rect, Color hintergrund) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: schrift.copyWith(
          fontSize: 10,
          height: 1,
          fontWeight: FontWeight.w700,
          color: StatistikFarben.schriftAuf(hintergrund),
        ),
      ),
      textScaler: scaler,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    if (painter.width + 6 > rect.width || painter.height > rect.height + 2) {
      return;
    }
    painter.paint(
      canvas,
      Offset(
        rect.center.dx - painter.width / 2,
        rect.center.dy - painter.height / 2,
      ),
    );
  }

  void _text(
    Canvas canvas,
    String text,
    Offset position,
    Color farbe,
    double groesse,
    FontWeight gewicht, {
    double? maxBreite,
    bool zentriert = false,
    bool mittig = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: schrift.copyWith(
          fontSize: groesse,
          height: 1.2,
          fontWeight: gewicht,
          color: farbe,
        ),
      ),
      textScaler: scaler,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxBreite ?? double.infinity);
    final dx = zentriert ? position.dx - painter.width / 2 : position.dx;
    final dy = mittig ? position.dy - painter.height / 2 : position.dy;
    painter.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _BahnenPainter oldDelegate) =>
      oldDelegate.verlauf != verlauf ||
      oldDelegate.farben.dunkel != farben.dunkel ||
      oldDelegate.scaler != scaler;
}
