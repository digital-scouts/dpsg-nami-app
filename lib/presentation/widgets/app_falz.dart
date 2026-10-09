import 'dart:ui' show DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Senkrechter Falz eines aufgeklappten Faltgeraets (iPhone Duo, Android
/// Foldables). Liste und Detail teilen sich am Falz wie zwei Buchseiten.
///
/// Entscheidung: design/entscheidung/2026-10-09-responsive-profil-detail.md
class AppFalz {
  const AppFalz._();

  /// Lage des Falzes im Fenster als Bereich von [links] bis [rechts]
  /// (gleich bei einem Falz ohne Breite, verschieden bei einem Scharnier
  /// mit Spalt). `null`, wenn das Fenster keinen senkrechten Falz hat.
  static ({double links, double rechts})? imFenster(BuildContext context) {
    for (final feature in MediaQuery.displayFeaturesOf(context)) {
      final b = feature.bounds;
      final falz =
          feature.type == DisplayFeatureType.fold ||
          feature.type == DisplayFeatureType.hinge;
      if (falz && b.height > b.width) {
        return (links: b.left, rechts: b.right);
      }
    }
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return null;
    }
    // iOS meldet nur Zustand und Winkel des Scharniers, nicht seine Lage,
    // und als Bildschirm den Aussenbildschirm. Ein iPhone-Fenster, das quer
    // liegt und hoeher ist als jedes iPhone (440 pt), ist die Innenflaeche
    // des Duo; der Falz liegt in ihrer Mitte. iPads (ab 744 pt) haben
    // keinen Falz, auch nicht im Stage-Manager-Fenster.
    final display = View.of(context).display;
    final bildschirm = display.size / display.devicePixelRatio;
    final fenster = MediaQuery.sizeOf(context);
    final innenflaeche =
        bildschirm.shortestSide < 744 &&
        fenster.width > fenster.height &&
        fenster.shortestSide >= 600;
    if (!innenflaeche) {
      return null;
    }
    final mitte = fenster.width / 2;
    return (links: mitte, rechts: mitte);
  }
}

/// Gibt die Lage des Falzes relativ zum linken Rand von [child] weiter,
/// z. B. fuer den Inhaltsbereich neben der Seitenleiste.
class AppFalzBereich extends InheritedWidget {
  const AppFalzBereich({super.key, required this.falz, required super.child});

  /// Erzeugt den Bereich fuer einen Inhalt, der [versatz] vom linken
  /// Fensterrand beginnt.
  static Widget fuer(
    BuildContext context, {
    required double versatz,
    required Widget child,
  }) {
    final f = AppFalz.imFenster(context);
    return AppFalzBereich(
      falz: f == null
          ? null
          : (links: f.links - versatz, rechts: f.rechts - versatz),
      child: child,
    );
  }

  final ({double links, double rechts})? falz;

  static ({double links, double rechts})? von(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppFalzBereich>()?.falz;

  @override
  bool updateShouldNotify(AppFalzBereich oldWidget) => falz != oldWidget.falz;
}

/// Liste links, Detail rechts. Auf Faltgeraeten liegt die Teilung auf dem
/// Falz, sonst ist die Liste 320 bzw. 360 pt breit.
class AppListeDetail extends StatelessWidget {
  const AppListeDetail({super.key, required this.liste, required this.detail});

  /// Kleinste Breite je Seite, damit der Falz genutzt wird.
  static const double mindestbreite = 280;

  final Widget liste;
  final Widget detail;

  /// Breite der Liste und Spalt bis zum Detail bei [verfuegbar] Breite.
  static ({double liste, double spalt}) teilung(
    double verfuegbar,
    ({double links, double rechts})? falz,
  ) {
    if (falz != null &&
        falz.links >= mindestbreite &&
        verfuegbar - falz.rechts >= mindestbreite) {
      return (liste: falz.links, spalt: falz.rechts - falz.links);
    }
    return (liste: verfuegbar < 900 ? 320 : 360, spalt: 0);
  }

  @override
  Widget build(BuildContext context) {
    final falz = AppFalzBereich.von(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final t = teilung(constraints.maxWidth, falz);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: t.liste, child: liste),
            if (t.spalt > 0) SizedBox(width: t.spalt),
            Expanded(child: detail),
          ],
        );
      },
    );
  }
}
