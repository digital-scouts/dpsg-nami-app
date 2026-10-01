import 'package:flutter/material.dart';

import '../../domain/taetigkeit/stufe.dart';
import '../stufe/stufe_visuals.dart';

/// Farben der Statistik-Kacheln, abgeleitet aus dem Theme.
///
/// Stufenfarben bleiben Markenfarben, mit zwei Ausnahmen für Diagramme:
/// Biber-Weiß ist auf weißen Karten unsichtbar und wird hell zu Hellgrau mit
/// Kontur; Jufi-Blau erreicht auf dunklem Grund zu wenig Kontrast und wird
/// dort aufgehellt. Geschlecht und Konfession nutzen eine eigene, auf
/// Farbsehschwäche geprüfte Palette, die mit keiner Stufe verwechselbar ist.
class StatistikFarben {
  const StatistikFarben._({
    required this.dunkel,
    required this.text,
    required this.textGedaempft,
    required this.textSchwach,
    required this.flaeche,
    required this.spur,
    required this.heute,
  });

  factory StatistikFarben.of(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dunkel = theme.brightness == Brightness.dark;
    return StatistikFarben._(
      dunkel: dunkel,
      text: scheme.onSurface,
      textGedaempft: Color.alphaBlend(
        scheme.onSurface.withValues(alpha: 0.72),
        scheme.surface,
      ),
      textSchwach: scheme.outlineVariant,
      flaeche: scheme.surface,
      spur: scheme.outline,
      heute: Color.alphaBlend(
        scheme.onSurface.withValues(alpha: dunkel ? 0.16 : 0.09),
        scheme.surface,
      ),
    );
  }

  final bool dunkel;
  final Color text;
  final Color textGedaempft;
  final Color textSchwach;

  /// Kachelfläche; auch für die 2-pt-Lücken zwischen Segmenten.
  final Color flaeche;

  /// Leere Spur hinter Balken.
  final Color spur;

  /// Neutrales Grau für „heute“ im Stufenwechsel.
  final Color heute;

  static const Color _biberHell = Color(0xFFDCDCE2);
  static const Color _biberKontur = Color(0xFFAEAEB2);
  static const Color _biberBandHell = Color(0xFFF4F4F7);
  static const Color _jufiDunkel = Color(0xFF5B7FD6);

  Color stufe(Stufe stufe) {
    if (stufe == Stufe.biber && !dunkel) return _biberHell;
    if (stufe == Stufe.jungpfadfinder && dunkel) return _jufiDunkel;
    return StufeVisuals.colorFor(stufe);
  }

  /// Kontur für Marken der Biber auf hellem Grund, sonst `null`.
  Color? kontur(Stufe stufe) =>
      stufe == Stufe.biber && !dunkel ? _biberKontur : null;

  /// Getönte Fläche für die Altersgrenze einer Stufe.
  Color grenzFlaeche(Stufe stufe) {
    if (stufe == Stufe.biber) {
      return dunkel ? const Color(0xFF2E2E3A) : _biberBandHell;
    }
    return Color.alphaBlend(this.stufe(stufe).withValues(alpha: 0.14), flaeche);
  }

  /// Geschlecht und Konfession: Violett, Aqua, Gelb, Grau.
  List<Color> get merkmal => dunkel
      ? const [
          Color(0xFF9085E9),
          Color(0xFF199E70),
          Color(0xFFC98500),
          Color(0xFF8A8A9A),
        ]
      : const [
          Color(0xFF4A3AA7),
          Color(0xFF1BAF7A),
          Color(0xFFEDA100),
          Color(0xFF8E8E93),
        ];

  /// Weiß oder Tinte auf [hintergrund], je nachdem, was mehr Kontrast hat.
  static Color schriftAuf(Color hintergrund) {
    final l = hintergrund.computeLuminance();
    final kontrastWeiss = 1.05 / (l + 0.05);
    final kontrastTinte = (l + 0.05) / 0.0588;
    return kontrastWeiss >= kontrastTinte
        ? Colors.white
        : const Color(0xFF111114);
  }
}
