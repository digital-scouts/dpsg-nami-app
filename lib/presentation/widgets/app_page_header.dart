import 'package:flutter/material.dart';
import 'package:nami/domain/appearance/appearance_catalog.dart';
import 'package:nami/presentation/widgets/supporter_backdrop.dart';
import 'package:nami/presentation/widgets/supporter_background.dart';

/// Kopfbereich der Hauptseiten Statistik, Stufenwechsel und Einstellungen,
/// nach dem Vorbild des Mitgliederlisten-Headers (MemberDirectory).
///
/// In der App zeichnet der [SupporterBackdrop] die Flaeche des Headers
/// durchgehend vom oberen Bildschirmrand (hinter Safe Area, Banner und
/// Lade-Info) bis zur Unterkante des Headers - mit Supporter-Hintergrund
/// animiert, sonst schlicht in `surface`. Ohne Backdrop (Storybook, Tests,
/// Unterseiten mit AppBar) zeichnet der Header seine Flaeche selbst.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({super.key, required this.child, this.background});

  final Widget child;

  /// Gewaehlter Supporter-Hintergrund; `null` fuer den schlichten Header.
  final AppearanceBackgroundId? background;

  @override
  Widget build(BuildContext context) {
    final background = this.background;
    final useBackdrop = SupporterBackdrop.maybeOf(context) != null;
    final colorScheme = Theme.of(context).colorScheme;
    final header = DecoratedBox(
      decoration: BoxDecoration(
        color: useBackdrop ? Colors.transparent : colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outline)),
      ),
      child: _HeaderBackground(
        background: useBackdrop ? null : background,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (background != null) SizedBox(height: useBackdrop ? 24 : 56),
            child,
          ],
        ),
      ),
    );
    return useBackdrop ? SupporterBackdropAnchor(child: header) : header;
  }
}

/// Legt den gewaehlten Supporter-Hintergrund hinter den Header-Inhalt.
class _HeaderBackground extends StatelessWidget {
  const _HeaderBackground({required this.background, required this.child});

  final AppearanceBackgroundId? background;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final background = this.background;
    if (background == null) {
      return child;
    }
    return Stack(
      children: [
        Positioned.fill(
          child: SupporterBackground(
            key: ValueKey('page-header-background-${background.name}'),
            background: background,
          ),
        ),
        child,
      ],
    );
  }
}
