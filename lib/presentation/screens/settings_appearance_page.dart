import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/appearance/appearance_catalog.dart';
import '../../l10n/app_localizations.dart';
import '../model/appearance_model.dart';
import '../notifications/app_snackbar.dart';
import '../theme/theme.dart';
import '../widgets/section_header.dart';
import '../widgets/supporter_background.dart';
import '../widgets/supporter_badge.dart';

/// Einstellungen fuer das Erscheinungsbild: Hell/Dunkel, Farbpalette,
/// App-Icon, Hintergrund der Mitgliederliste und Supporter-Badge.
/// Liest und schreibt [AppearanceModel]; Hell/Dunkel kommt per Callback.
class SettingsAppearancePage extends StatefulWidget {
  const SettingsAppearancePage({
    super.key,
    this.themeMode = ThemeMode.system,
    this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  @override
  State<SettingsAppearancePage> createState() => _SettingsAppearancePageState();
}

class _SettingsAppearancePageState extends State<SettingsAppearancePage> {
  late ThemeMode _mode = widget.themeMode;

  @override
  void didUpdateWidget(covariant SettingsAppearancePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.themeMode != widget.themeMode) {
      _mode = widget.themeMode;
    }
  }

  void _setMode(ThemeMode mode) {
    if (mode == _mode) {
      return;
    }
    setState(() => _mode = mode);
    widget.onThemeModeChanged?.call(mode);
  }

  Future<void> _setIcon(AppearanceModel model, AppIconChoice? choice) async {
    final t = AppLocalizations.of(context);
    try {
      await model.setAppIcon(choice);
    } catch (_) {
      if (!mounted) {
        return;
      }
      AppSnackbar.show(
        context,
        message: t.t('appearance_icon_failed'),
        type: AppSnackbarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final model = context.watch<AppearanceModel>();

    return Scaffold(
      appBar: AppBar(title: Text(t.t('settings_appearance'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          DpsgSectionHeader(label: t.t('settings_app_section_display')),
          _AppearanceCard(
            divided: true,
            children: [
              for (final (mode, key) in const [
                (ThemeMode.system, 'settings_app_theme_system'),
                (ThemeMode.light, 'theme_light'),
                (ThemeMode.dark, 'theme_dark'),
              ])
                _RadioRow(
                  title: t.t(key),
                  selected: _mode == mode,
                  onTap: () => _setMode(mode),
                ),
            ],
          ),
          const SizedBox(height: 12),
          DpsgSectionHeader(label: t.t('appearance_section_palette')),
          _PalettePicker(model: model),
          if (model.iconChangeSupported) ...[
            const SizedBox(height: 12),
            DpsgSectionHeader(label: t.t('appearance_section_icon')),
            _IconPicker(
              model: model,
              onSelected: (choice) => _setIcon(model, choice),
            ),
          ],
          const SizedBox(height: 12),
          DpsgSectionHeader(label: t.t('appearance_section_background')),
          _BackgroundPicker(model: model),
          const SizedBox(height: 12),
          DpsgSectionHeader(label: t.t('appearance_section_badge')),
          _BadgePicker(model: model),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Palette

class _PalettePicker extends StatelessWidget {
  const _PalettePicker({required this.model});

  final AppearanceModel model;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final id in AppPaletteId.values)
          _Choice(
            key: ValueKey('appearance-palette-${id.name}'),
            selected: model.palette == id,
            locked: !model.access.isTierUnlocked(
              AppearanceCatalog.paletteTiers[id]!,
            ),
            label: t.t('appearance_palette_${id.name}'),
            onTap: () => model.setPalette(id),
            child: _PaletteSwatch(colors: appPalettes[id]!.of(brightness)),
          ),
      ],
    );
  }
}

class _PaletteSwatch extends StatelessWidget {
  const _PaletteSwatch({required this.colors});

  final AppPaletteColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 56,
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 10,
            width: 44,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const Spacer(),
          Container(
            height: 16,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Container(width: 3, color: colors.secondary),
                const SizedBox(width: 4),
                Container(width: 30, height: 4, color: colors.fg),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- App-Icon

class _IconPicker extends StatelessWidget {
  const _IconPicker({required this.model, required this.onSelected});

  final AppearanceModel model;
  final ValueChanged<AppIconChoice?> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final variants = AppearanceCatalog.iconVariantsFor(
      supportsAuto: model.supportsAutomaticIcon,
    );
    return _AppearanceCard(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Text(
            t.t('appearance_icon_hint'),
            style: theme.textTheme.bodySmall,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _Choice(
              key: const ValueKey('appearance-icon-default'),
              selected: model.appIcon == null,
              label: t.t('appearance_icon_default'),
              onTap: () => onSelected(null),
              child: const _IconThumb(asset: 'assets/icon/icon.png'),
            ),
          ),
        ),
        for (final package in AppIconPackage.values)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: Text(
                    t.t('appearance_icon_package_${package.name}'),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final variant in variants)
                      _Choice(
                        key: ValueKey(
                          'appearance-icon-${AppIconChoice(package, variant).key}',
                        ),
                        selected:
                            model.appIcon == AppIconChoice(package, variant),
                        locked: !model.access.isIconPackageUnlocked(package),
                        label: t.t('appearance_icon_variant_${variant.name}'),
                        onTap: () =>
                            onSelected(AppIconChoice(package, variant)),
                        child: _IconThumb.forChoice(
                          AppIconChoice(package, variant),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        if (model.supportsAutomaticIcon)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Text(
              t.t('appearance_icon_automatic_hint'),
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _IconThumb extends StatelessWidget {
  const _IconThumb({required this.asset}) : nightAsset = null;

  const _IconThumb._split({required this.asset, required this.nightAsset});

  /// `automatisch` zeigt Morgen und Nacht diagonal geteilt.
  factory _IconThumb.forChoice(AppIconChoice choice) {
    String thumb(AppIconVariant variant) =>
        'assets/supporter/icons/${AppIconChoice(choice.package, variant).key}.png';
    if (choice.variant == AppIconVariant.automatisch) {
      return _IconThumb._split(
        asset: thumb(AppIconVariant.morgen),
        nightAsset: thumb(AppIconVariant.nacht),
      );
    }
    return _IconThumb(asset: thumb(choice.variant));
  }

  final String asset;
  final String? nightAsset;

  static const double size = 56;

  @override
  Widget build(BuildContext context) {
    final night = nightAsset;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.225),
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(asset, fit: BoxFit.cover),
            if (night != null)
              ClipPath(
                clipper: _DiagonalClipper(),
                child: Image.asset(night, fit: BoxFit.cover),
              ),
          ],
        ),
      ),
    );
  }
}

class _DiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(size.width, 0)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// -------------------------------------------------------------- Hintergrund

class _BackgroundPicker extends StatelessWidget {
  const _BackgroundPicker({required this.model});

  final AppearanceModel model;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            t.t('appearance_background_hint'),
            style: theme.textTheme.bodySmall,
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Choice(
              key: const ValueKey('appearance-background-none'),
              selected: model.background == null,
              label: t.t('appearance_background_none'),
              onTap: () => model.setBackground(null),
              child: _BackgroundFrame(
                child: ColoredBox(color: theme.colorScheme.surface),
              ),
            ),
            for (final id in AppearanceBackgroundId.values)
              _Choice(
                key: ValueKey('appearance-background-${id.name}'),
                selected: model.background == id,
                locked: !model.access.isTierUnlocked(
                  AppearanceCatalog.backgroundTiers[id]!,
                ),
                label: t.t('appearance_background_${id.name}'),
                onTap: () => model.setBackground(id),
                child: _BackgroundFrame(
                  child: SupporterBackground(background: id),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _BackgroundFrame extends StatelessWidget {
  const _BackgroundFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(width: 150, height: 64, child: child),
    );
  }
}

// ------------------------------------------------------------------ Badge

class _BadgePicker extends StatelessWidget {
  const _BadgePicker({required this.model});

  final AppearanceModel model;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return _AppearanceCard(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Text(
            t.t('appearance_badge_claim'),
            style: theme.textTheme.titleMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
          child: Text(
            t.t('appearance_badge_hint'),
            style: theme.textTheme.bodySmall,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _Choice(
                key: const ValueKey('appearance-badge-none'),
                selected: model.badge == null,
                label: t.t('appearance_badge_none'),
                onTap: () => model.setBadge(null),
                child: SizedBox.square(
                  dimension: 44,
                  child: Icon(
                    Icons.block,
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
              ),
              for (final badge in AppearanceCatalog.badges)
                _Choice(
                  key: ValueKey('appearance-badge-${badge.assetName}'),
                  selected: model.badge == badge.id,
                  locked: !model.access.isTierUnlocked(badge.tier),
                  label: badge.tier == SupportTier.foerderer
                      ? t.t('appearance_badge_foerderer')
                      : null,
                  onTap: () => model.setBadge(badge.id),
                  child: SupporterBadge(
                    badge: badge.id,
                    size: badge.tier == SupportTier.foerderer ? 52 : 44,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- Bausteine

/// Auswaehlbare Kachel mit Rahmen, optionalem Label und Schloss.
class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
    this.label,
    this.locked = false,
  });

  final bool selected;
  final bool locked;
  final String? label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final label = this.label;
    return Semantics(
      selected: selected,
      button: true,
      label: [?label, if (locked) t.t('appearance_locked')].join(', '),
      excludeSemantics: label != null,
      child: InkWell(
        onTap: locked ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? theme.colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(opacity: locked ? 0.45 : 1, child: child),
                  if (locked)
                    Icon(
                      Icons.lock,
                      size: 18,
                      color: theme.colorScheme.onSurface,
                    ),
                ],
              ),
              if (label != null) ...[
                const SizedBox(height: 4),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard({required this.children, this.divided = false});

  final List<Widget> children;

  /// Trennlinien zwischen den Zeilen, wie in den App-Einstellungen.
  final bool divided;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      items.add(children[index]);
      if (divided && index < children.length - 1) {
        items.add(const Divider(height: 1, indent: 16));
      }
    }
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: items,
      ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  const _RadioRow({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.outline;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
            ],
          ),
        ),
      ),
    );
  }
}
