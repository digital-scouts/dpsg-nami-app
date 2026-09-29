import 'appearance_catalog.dart';

/// Vom Nutzer gewaehltes Erscheinungsbild. `null` bedeutet jeweils den
/// Standard (kein Hintergrund, kein Badge, Standard-App-Icon).
class AppearanceSettings {
  const AppearanceSettings({
    this.palette = AppPaletteId.standard,
    this.background,
    this.badge,
    this.appIcon,
  });

  final AppPaletteId palette;
  final AppearanceBackgroundId? background;
  final SupporterBadgeId? badge;
  final AppIconChoice? appIcon;

  AppearanceSettings copyWith({
    AppPaletteId? palette,
    AppearanceBackgroundId? Function()? background,
    SupporterBadgeId? Function()? badge,
    AppIconChoice? Function()? appIcon,
  }) => AppearanceSettings(
    palette: palette ?? this.palette,
    background: background != null ? background() : this.background,
    badge: badge != null ? badge() : this.badge,
    appIcon: appIcon != null ? appIcon() : this.appIcon,
  );
}
