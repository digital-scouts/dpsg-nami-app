import 'package:flutter/material.dart';

import '../../../domain/statistiks/statistik_kachel_einstellungen.dart';
import '../../../domain/statistiks/statistik_kachel_typen.dart';

/// Rückmeldungen des Kachelrasters im Bearbeiten-Modus.
class KachelRasterBearbeitung {
  const KachelRasterBearbeitung({
    required this.onVerschieben,
    required this.onGroesse,
    required this.onEntfernen,
    this.onAntippen,
  });

  /// Eintrag an Index [von] soll an Index [nach].
  final void Function(int von, int nach) onVerschieben;
  final void Function(KachelEintrag eintrag, KachelGroesse groesse) onGroesse;
  final void Function(KachelEintrag eintrag) onEntfernen;

  /// Antippen einer eigenen Kachel, z. B. um sie zu bearbeiten.
  final void Function(KachelEintrag eintrag)? onAntippen;
}

/// Rotes Minus an der oberen linken Ecke. Das Ziel ist 48 pt groß und
/// sitzt mittig auf der Ecke.
class KachelEntfernenKnopf extends StatelessWidget {
  const KachelEntfernenKnopf({
    super.key,
    required this.label,
    required this.onPressed,
  });

  static const double ziel = 48;

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox.square(
          dimension: ziel,
          child: Center(
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFFE5383B),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 10,
                height: 2.4,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(1.2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bogen an der unteren rechten Ecke als Griff zum Ändern der Größe.
class KachelGroessenGriff extends StatelessWidget {
  const KachelGroessenGriff({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GriffPainter(Theme.of(context).colorScheme.onSurface),
      child: const SizedBox.square(dimension: 44),
    );
  }
}

class _GriffPainter extends CustomPainter {
  _GriffPainter(this.farbe);

  final Color farbe;

  @override
  void paint(Canvas canvas, Size size) {
    const r = 9.0;
    final rechts = size.width - 8;
    final unten = size.height - 8;
    final pfad = Path()
      ..moveTo(rechts, unten - r - 5)
      ..lineTo(rechts, unten - r)
      ..arcToPoint(Offset(rechts - r, unten), radius: const Radius.circular(r))
      ..lineTo(rechts - r - 5, unten);
    canvas.drawPath(
      pfad,
      Paint()
        ..color = farbe
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GriffPainter old) => old.farbe != farbe;
}

/// Umriss der neuen Größe beim Ziehen am Griff, mit Größen-Badge.
class KachelGroessenGeist extends StatelessWidget {
  const KachelGroessenGeist({super.key, required this.groesse});

  final KachelGroesse groesse;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.primary, width: 2),
        ),
        child: Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: Text(
                  groesseText(groesse),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Platz der gerade gezogenen Kachel.
class KachelPlatzhalter extends StatelessWidget {
  const KachelPlatzhalter({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
      ),
    );
  }
}

/// „2×1“ statt „2x1“.
String groesseText(KachelGroesse groesse) =>
    '${groesse.spalten}×${groesse.zeilen}';
