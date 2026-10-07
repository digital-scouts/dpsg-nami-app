/// Katalog aller Erscheinungsbild-Optionen. Die Stufe (`SupportTier`) legt
/// fest, welche Optionen hinter einem Supporter- oder Foerderer-Kauf liegen.
/// Bis zur Store-Anbindung schaltet sie der Testschalter frei
/// (siehe [SchalterSupportAccess]), im Demo-Modus [UnlockedSupportAccess].
library;

enum SupportTier { free, supporter, foerderer }

enum AppPaletteId { standard, wald, lagerfeuer, nachthimmel, hochkontrast }

enum AppearanceBackgroundId { lagerfeuer, himmel, wald }

/// Ein App-Icon-Paket enthaelt immer alle drei Tageszeiten.
enum AppIconPackage { nachtlager, lagerfeuer, kohteSee, hajk }

/// `automatisch` folgt dem Hell/Dunkel-Modus des Systems und gibt es nur
/// unter iOS.
enum AppIconVariant { morgen, abend, nacht, automatisch }

enum SupporterBadgeId {
  kompassBiber,
  kompassWoelfling,
  kompassJungpfadfinder,
  kompassPfadfinder,
  kompassRover,
  kompassNeutral,
  foerdererPolarstern,
}

class AppIconChoice {
  const AppIconChoice(this.package, this.variant);

  final AppIconPackage package;
  final AppIconVariant variant;

  /// Stabiler Schluessel fuer Persistenz und Plattform-Icon-Namen,
  /// z. B. `NachtlagerMorgen`.
  String get key => '${_pascal(package.name)}${_pascal(variant.name)}';

  static AppIconChoice? fromKey(String? key) {
    if (key == null) {
      return null;
    }
    for (final package in AppIconPackage.values) {
      for (final variant in AppIconVariant.values) {
        final choice = AppIconChoice(package, variant);
        if (choice.key == key) {
          return choice;
        }
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is AppIconChoice &&
      other.package == package &&
      other.variant == variant;

  @override
  int get hashCode => Object.hash(package, variant);

  static String _pascal(String value) =>
      value[0].toUpperCase() + value.substring(1);
}

class SupporterBadgeInfo {
  const SupporterBadgeInfo(this.id, this.assetName, this.tier);

  final SupporterBadgeId id;
  final String assetName;
  final SupportTier tier;

  String get assetPath => 'assets/supporter/badges/$assetName.svg';
}

abstract final class AppearanceCatalog {
  static const Map<AppPaletteId, SupportTier> paletteTiers = {
    AppPaletteId.standard: SupportTier.free,
    AppPaletteId.hochkontrast: SupportTier.free,
    AppPaletteId.wald: SupportTier.foerderer,
    AppPaletteId.lagerfeuer: SupportTier.foerderer,
    AppPaletteId.nachthimmel: SupportTier.foerderer,
  };

  static const Map<AppearanceBackgroundId, SupportTier> backgroundTiers = {
    AppearanceBackgroundId.lagerfeuer: SupportTier.foerderer,
    AppearanceBackgroundId.himmel: SupportTier.foerderer,
    AppearanceBackgroundId.wald: SupportTier.foerderer,
  };

  /// Jedes Icon-Paket ist ein eigener Supporter-Kauf.
  static const SupportTier iconPackageTier = SupportTier.supporter;

  static const List<SupporterBadgeInfo> badges = [
    SupporterBadgeInfo(
      SupporterBadgeId.kompassBiber,
      'kompass-biber',
      SupportTier.supporter,
    ),
    SupporterBadgeInfo(
      SupporterBadgeId.kompassWoelfling,
      'kompass-woe',
      SupportTier.supporter,
    ),
    SupporterBadgeInfo(
      SupporterBadgeId.kompassJungpfadfinder,
      'kompass-jufi',
      SupportTier.supporter,
    ),
    SupporterBadgeInfo(
      SupporterBadgeId.kompassPfadfinder,
      'kompass-pfadi',
      SupportTier.supporter,
    ),
    SupporterBadgeInfo(
      SupporterBadgeId.kompassRover,
      'kompass-rover',
      SupportTier.supporter,
    ),
    SupporterBadgeInfo(
      SupporterBadgeId.kompassNeutral,
      'kompass-neutral',
      SupportTier.supporter,
    ),
    SupporterBadgeInfo(
      SupporterBadgeId.foerdererPolarstern,
      'foerderer-polarstern',
      SupportTier.foerderer,
    ),
  ];

  static SupporterBadgeInfo badge(SupporterBadgeId id) =>
      badges.firstWhere((badge) => badge.id == id);

  static List<AppIconVariant> iconVariantsFor({required bool supportsAuto}) => [
    AppIconVariant.morgen,
    AppIconVariant.abend,
    AppIconVariant.nacht,
    if (supportsAuto) AppIconVariant.automatisch,
  ];
}
