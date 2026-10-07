import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/appearance/appearance_catalog.dart';
import '../model/appearance_model.dart';
import 'supporter_background.dart';

/// Deckende Fläche der App-Sperre und des Sichtschutzes im App-Umschalter
/// (Entwurf `design/app-sperre/`, Runde 3: B3 mit Szenenhöhe S).
///
/// Ohne Supporter-Hintergrund ein Verlauf in der Primärfarbe, sonst der
/// aktive animierte Hintergrund mit der Szene auf gut der Hälfte der Höhe.
/// Mittig steht das gewählte App-Icon, darunter [inhalt] bzw. „NaMi“;
/// [unten] sitzt in Daumenreichweite.
class AppSperreFlaeche extends StatelessWidget {
  const AppSperreFlaeche({super.key, this.inhalt, this.unten});

  final Widget? inhalt;
  final Widget? unten;

  /// Anteil der Höhe, bis zu dem die Szene mitwächst (Höhe S im Entwurf).
  static const double szenenAnteil = 0.55;

  @override
  Widget build(BuildContext context) {
    final appearance = _appearance(context);
    final background = appearance?.background;
    final theme = Theme.of(context);
    final dunkel = theme.brightness == Brightness.dark;
    // Auf Verlauf und dunklen Szenen hell, auf hellen Szenen dunkel.
    final hellerText = background == null || dunkel;
    final textFarbe = hellerText ? Colors.white : theme.colorScheme.onSurface;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            if (background == null)
              DecoratedBox(decoration: _verlauf(theme))
            else
              SupporterBackground(
                key: ValueKey('app-sperre-hintergrund-${background.name}'),
                background: background,
                maxSceneHeight: constraints.maxHeight * szenenAnteil,
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _AppIcon(choice: appearance?.appIcon),
                              const SizedBox(height: 16),
                              inhalt ??
                                  Text(
                                    'NaMi',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: textFarbe,
                                      letterSpacing: 0.8,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    ?unten,
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static AppearanceModel? _appearance(BuildContext context) {
    try {
      return Provider.of<AppearanceModel>(context);
    } catch (_) {
      return null;
    }
  }

  static BoxDecoration _verlauf(ThemeData theme) {
    final primary = theme.colorScheme.primary;
    final dunkel = theme.brightness == Brightness.dark;
    final farben = dunkel
        ? [
            Color.lerp(primary, Colors.black, 0.62)!,
            Color.lerp(primary, Colors.black, 0.8)!,
            Color.lerp(primary, Colors.black, 0.9)!,
          ]
        : [
            Color.lerp(primary, Colors.white, 0.08)!,
            primary,
            Color.lerp(primary, Colors.black, 0.45)!,
          ];
    return BoxDecoration(
      gradient: LinearGradient(
        begin: const Alignment(-0.3, -1),
        end: const Alignment(0.3, 1),
        colors: farben,
        stops: const [0, 0.55, 1],
      ),
    );
  }
}

/// Glasfläche für Titel, Text und Fehlermeldung der Sperre.
class AppSperreGlas extends StatelessWidget {
  const AppSperreGlas({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: ColoredBox(
          color: surface.withValues(alpha: 0.78),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.choice});

  final AppIconChoice? choice;

  @override
  Widget build(BuildContext context) {
    final dunkel = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: const Key('app-sperre-icon'),
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(_asset(dunkel), fit: BoxFit.cover),
    );
  }

  String _asset(bool dunkel) {
    final choice = this.choice;
    if (choice == null) {
      return 'assets/icon/icon.png';
    }
    final variante = choice.variant == AppIconVariant.automatisch
        ? (dunkel ? AppIconVariant.nacht : AppIconVariant.morgen)
        : choice.variant;
    return 'assets/supporter/icons/${AppIconChoice(choice.package, variante).key}.png';
  }
}
