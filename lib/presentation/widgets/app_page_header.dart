import 'package:flutter/material.dart';
import 'package:nami/domain/appearance/appearance_catalog.dart';
import 'package:nami/presentation/widgets/supporter_backdrop.dart';
import 'package:nami/presentation/widgets/supporter_background.dart';

/// Kopfbereich der vier Hauptseiten Mitglieder, Statistik, Stufenwechsel
/// und Einstellungen.
///
/// Jeder Header besteht aus genau zwei einzeiligen Zeilen ([primary] und
/// [secondary]). Ihre Hoehen ergeben sich fuer alle Seiten aus derselben
/// Formel (Basismass x Textskalierung), damit die Unterkante beim
/// Tab-Wechsel nicht springt. Inhalte muessen deshalb einzeilig bleiben
/// (Ellipsis, horizontal scrollen oder zu "+n" zusammenfassen).
///
/// In der App zeichnet der [SupporterBackdrop] die Flaeche des Headers
/// durchgehend vom oberen Bildschirmrand (hinter Safe Area, Banner und
/// Lade-Info) bis zur Unterkante des Headers - mit Supporter-Hintergrund
/// animiert, sonst schlicht in `surface`. Ohne Backdrop (Storybook, Tests,
/// Unterseiten mit AppBar) zeichnet der Header seine Flaeche selbst.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.primary,
    required this.secondary,
    this.background,
    this.card,
  });

  /// Obere Zeile, z. B. Suche, Kennzahlen oder Profil.
  final Widget primary;

  /// Untere Zeile, z. B. Filter-Chips, Tabs oder Rollen.
  final Widget secondary;

  /// Gewaehlter Supporter-Hintergrund; `null` fuer den schlichten Header.
  final AppearanceBackgroundId? background;

  /// Fasst beide Zeilen in einer Karte zusammen; `null` ohne Karte.
  final AppPageHeaderCard? card;

  /// Obergrenze der Textskalierung im Header, damit er auch bei sehr
  /// grossen Systemschriften bedienbar bleibt und die Liste sichtbar ist.
  static const double maxTextScaleFactor = 1.4;

  static const double _primaryBaseHeight = 48;
  static const double _secondaryBaseHeight = 34;
  static const double _verticalPadding = 12;
  static const double _rowGap = 8;
  static const double _horizontalPadding = 16;
  static const double _cardHorizontalPadding = 12;

  /// Mit Karte wandert ein Teil des vertikalen Abstands in die Karte, damit
  /// Inhalte wie der Avatar nicht an ihrem Rand kleben. Die Gesamthoehe
  /// bleibt gleich.
  static const double _cardVerticalPadding = 4;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: maxTextScaleFactor,
      child: Builder(builder: _buildHeader),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final background = this.background;
    final useBackdrop = SupporterBackdrop.maybeOf(context) != null;
    final colorScheme = Theme.of(context).colorScheme;
    // Nichtlineare Skalierung (Android 14+) auf Fliesstextgroesse bezogen.
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final header = DecoratedBox(
      decoration: BoxDecoration(
        color: useBackdrop ? Colors.transparent : colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outline)),
      ),
      child: _HeaderBackground(
        background: useBackdrop ? null : background,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            _horizontalPadding,
            _outerVerticalPadding,
            _horizontalPadding,
            _outerVerticalPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (background != null) SizedBox(height: useBackdrop ? 24 : 56),
              _buildRows(context, scale),
            ],
          ),
        ),
      ),
    );
    return useBackdrop ? SupporterBackdropAnchor(child: header) : header;
  }

  double get _outerVerticalPadding =>
      card == null ? _verticalPadding : _verticalPadding - _cardVerticalPadding;

  Widget _buildRows(BuildContext context, double scale) {
    final card = this.card;
    final inset = card == null ? 0.0 : _cardHorizontalPadding;
    final rows = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _primaryBaseHeight * scale,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: inset),
            child: primary,
          ),
        ),
        SizedBox(
          height: _rowGap,
          child: card?.divider ?? false
              ? Center(
                  child: Divider(
                    height: 1,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                )
              : null,
        ),
        SizedBox(
          height: _secondaryBaseHeight * scale,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: card?.insetSecondary ?? true ? inset : 0,
            ),
            child: secondary,
          ),
        ),
      ],
    );
    if (card == null) {
      return rows;
    }
    final onTap = card.onTap;
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: _cardVerticalPadding),
      child: rows,
    );
    return Material(
      key: card.key,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// Karte um beide Zeilen des [AppPageHeader].
class AppPageHeaderCard {
  const AppPageHeaderCard({
    this.key,
    this.onTap,
    this.divider = false,
    this.insetSecondary = true,
  });

  final Key? key;

  /// Tippen auf die ganze Karte; `null`, wenn die Zeilen eigene Ziele haben.
  final VoidCallback? onTap;

  /// Trennlinie zwischen den beiden Zeilen.
  final bool divider;

  /// `false`: die untere Zeile reicht bis an den Kartenrand, z. B. fuer
  /// Tap-Flaechen mit eigenem Innenabstand.
  final bool insetSecondary;
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
