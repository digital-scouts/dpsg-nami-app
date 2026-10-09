import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/appearance/appearance_catalog.dart';
import 'app_lesebreite.dart';
import 'supporter_badge.dart';

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

/// Profil oben in der [AppSeitenleiste].
class AppSeitenleisteProfil {
  const AppSeitenleisteProfil({
    required this.name,
    required this.ziel,
    this.stamm,
    this.badge,
  });

  final String name;
  final String? stamm;
  final SupporterBadgeId? badge;
  final int ziel;
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
    this.profil,
    this.breite = schmaleBreite,
  });

  /// Ab dieser Fensterbreite ersetzt die Seitenleiste die untere Leiste.
  static const double ab = 840;

  /// Breit genug, dass "Qualifikationen" ohne Verkleinerung passt.
  static const double schmaleBreite = 88;

  /// Ab so viel freiem Platz neben dem Inhalt steht der Text neben dem
  /// Symbol.
  static const double breitAb = 200;
  static const double hoechstbreite = 320;

  static bool sichtbar(double fensterbreite) => fensterbreite >= ab;

  /// Der Inhalt hat eine feste Breite; was daneben uebrig bleibt, bekommt
  /// die Leiste (breit ab [breitAb], hoechstens [hoechstbreite]).
  static double breiteFuer(double fensterbreite) {
    final frei =
        fensterbreite - AppLesebreite.breite - 2 * AppLesebreite.blockRand;
    return frei >= breitAb ? math.min(frei, hoechstbreite) : schmaleBreite;
  }

  final List<AppSeitenleisteEintrag> oben;
  final List<AppSeitenleisteEintrag> schnellzugriff;

  /// Am unteren Rand, z. B. die Einstellungen.
  final List<AppSeitenleisteEintrag> unten;

  /// [AppSeitenleisteEintrag.ziel] des gewaehlten Eintrags.
  final int ausgewaehlt;
  final ValueChanged<int> onAuswahl;

  /// Profil ganz oben; `null` ohne Anmeldung.
  final AppSeitenleisteProfil? profil;
  final double breite;

  bool get breit => breite > schmaleBreite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profil = this.profil;
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
        width: breite,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: innen.copyWith(top: 16, bottom: 16),
                child: Column(
                  crossAxisAlignment: ausrichtung,
                  children: [
                    if (profil != null)
                      _Profil(
                        profil: profil,
                        ausgewaehlt: profil.ziel == ausgewaehlt,
                        breit: breit,
                        onTap: () => onAuswahl(profil.ziel),
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

/// Avatar mit Initiale, breit mit Name und Stamm daneben. Lange Namen
/// brechen auf zwei Zeilen um; ist das Profil gewaehlt, stehen sie ganz da.
class _Profil extends StatelessWidget {
  const _Profil({
    required this.profil,
    required this.ausgewaehlt,
    required this.breit,
    required this.onTap,
  });

  final AppSeitenleisteProfil profil;
  final bool ausgewaehlt;
  final bool breit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = profil.name.trim();
    final badge = profil.badge;
    Widget avatar = Container(
      padding: const EdgeInsets.all(2),
      decoration: ShapeDecoration(
        shape: CircleBorder(
          side: BorderSide(
            color: ausgewaehlt ? theme.colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: CircleAvatar(
        radius: 20,
        backgroundColor: theme.colorScheme.primary,
        child: Text(
          name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
    if (badge != null) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -4,
            bottom: -4,
            child: SupporterBadge(badge: badge, size: 20),
          ),
        ],
      );
    }
    final zeilen = ausgewaehlt ? null : 2;
    final inhalt = breit
        ? Row(
            children: [
              avatar,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: zeilen,
                      overflow: zeilen == null ? null : TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (profil.stamm case final stamm?)
                      Text(
                        stamm,
                        maxLines: zeilen,
                        overflow: zeilen == null ? null : TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          )
        : Center(child: avatar);
    return Semantics(
      button: true,
      selected: ausgewaehlt,
      label: [name, ?profil.stamm].join(', '),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: breit ? 8 : 0,
              vertical: 6,
            ),
            child: inhalt,
          ),
        ),
      ),
    );
  }
}
