import 'package:flutter/material.dart';

/// Ein Eintrag der [AppSeitenleiste].
class AppSeitenleisteEintrag {
  const AppSeitenleisteEintrag({
    required this.icon,
    required this.label,
    required this.ziel,
    this.gesperrt = false,
  });

  final IconData icon;
  final String label;

  /// Index des Ziels in der Shell, z. B. 0-3 fuer die Hauptbereiche.
  final int ziel;

  /// Zeigt ein Schloss am Symbol, z. B. fuer Supporter-Funktionen.
  final bool gesperrt;
}

/// Navigation am linken Rand fuer breite Fenster (Duo aufgeklappt, iPad quer,
/// iPad 13" hoch). Oben die Hauptbereiche, mit Abstand darunter der
/// Schnellzugriff, am unteren Rand die Einstellungen. Schmal mit Beschriftung
/// unter dem Symbol, ab [breitAb] breit mit Text daneben. Ohne eigene
/// Flaeche, direkt auf dem Seitenhintergrund.
///
/// Entscheidung: design/entscheidung/2026-10-09-responsive-navigation.md
class AppSeitenleiste extends StatelessWidget {
  const AppSeitenleiste({
    super.key,
    required this.oben,
    required this.schnellzugriff,
    required this.unten,
    required this.ausgewaehlt,
    required this.onAuswahl,
    this.breit = false,
  });

  /// Ab dieser Fensterbreite ersetzt die Seitenleiste die untere Leiste.
  static const double ab = 840;

  /// Ab dieser Fensterbreite steht der Text neben dem Symbol.
  static const double breitAb = 1200;

  /// Breit genug, dass "Qualifikationen" ohne Verkleinerung passt.
  static const double schmaleBreite = 88;
  static const double breiteBreite = 220;

  static bool sichtbar(double fensterbreite) => fensterbreite >= ab;

  final List<AppSeitenleisteEintrag> oben;
  final List<AppSeitenleisteEintrag> schnellzugriff;

  /// Am unteren Rand, z. B. die Einstellungen.
  final List<AppSeitenleisteEintrag> unten;

  /// [AppSeitenleisteEintrag.ziel] des gewaehlten Eintrags.
  final int ausgewaehlt;
  final ValueChanged<int> onAuswahl;
  final bool breit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget eintrag(AppSeitenleisteEintrag e) => _Eintrag(
      eintrag: e,
      ausgewaehlt: e.ziel == ausgewaehlt,
      breit: breit,
      onTap: () => onAuswahl(e.ziel),
    );
    final ausrichtung = breit
        ? CrossAxisAlignment.stretch
        : CrossAxisAlignment.center;
    final innen = EdgeInsets.symmetric(horizontal: breit ? 12 : 4);
    return SafeArea(
      right: false,
      child: SizedBox(
        width: breit ? breiteBreite : schmaleBreite,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: innen.copyWith(top: 16, bottom: 16),
                child: Column(
                  crossAxisAlignment: ausrichtung,
                  children: [
                    if (breit)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                        child: Text(
                          'NaMi',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    for (final e in oben) eintrag(e),
                    if (schnellzugriff.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      if (breit)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                          child: Text(
                            'Schnellzugriff',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      for (final e in schnellzugriff) eintrag(e),
                    ],
                  ],
                ),
              ),
            ),
            if (unten.isNotEmpty)
              Padding(
                padding: innen.copyWith(bottom: 12),
                child: Column(
                  crossAxisAlignment: ausrichtung,
                  children: [for (final e in unten) eintrag(e)],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Eintrag extends StatelessWidget {
  const _Eintrag({
    required this.eintrag,
    required this.ausgewaehlt,
    required this.breit,
    required this.onTap,
  });

  final AppSeitenleisteEintrag eintrag;
  final bool ausgewaehlt;
  final bool breit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final farbe = ausgewaehlt
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    final pille = theme.colorScheme.primary.withValues(alpha: 0.12);
    Widget symbol = Icon(eintrag.icon, color: farbe, size: 24);
    if (eintrag.gesperrt) {
      symbol = Badge(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        padding: const EdgeInsets.all(2),
        label: Icon(
          Icons.lock,
          size: 10,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        child: symbol,
      );
    }
    final textStil =
        (breit ? theme.textTheme.bodyLarge : theme.textTheme.labelSmall)
            ?.copyWith(
              color: farbe,
              fontWeight: ausgewaehlt ? FontWeight.w600 : null,
              letterSpacing: breit ? null : 0,
            );

    final inhalt = breit
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: ShapeDecoration(
              color: ausgewaehlt ? pille : null,
              shape: const StadiumBorder(),
            ),
            child: Row(
              children: [
                symbol,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    eintrag.label,
                    style: textStil,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: ausgewaehlt ? pille : null,
                    shape: const StadiumBorder(),
                  ),
                  child: symbol,
                ),
                const SizedBox(height: 4),
                // Erst bei grosser Systemschrift wird verkleinert.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(eintrag.label, style: textStil, maxLines: 1),
                ),
              ],
            ),
          );

    return Semantics(
      button: true,
      selected: ausgewaehlt,
      label: eintrag.label,
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.only(bottom: breit ? 4 : 6),
        child: InkWell(
          customBorder: breit
              ? const StadiumBorder()
              : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onTap: onTap,
          child: inhalt,
        ),
      ),
    );
  }
}
