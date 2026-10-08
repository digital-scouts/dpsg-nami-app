/// Katalog aller Erscheinungsbild-Optionen. Paletten, Hintergruende und
/// App-Icons gehoeren zu je einem [SupporterPaket] (Einmalkauf); das
/// Foerderer-Abo schaltet alle Pakete frei. Badges haengen an einer Stufe
/// (`SupportTier`). Bis zur Store-Anbindung schaltet der Testschalter frei
/// (siehe [SchalterSupportAccess]), im Demo-Modus [UnlockedSupportAccess].
library;

/// `supporter` gilt mit mindestens einem Paket, `foerderer` nur mit dem Abo.
enum SupportTier { free, supporter, foerderer }

/// Ein Design-Paket buendelt Palette, Hintergrund und App-Icons eines Themas.
enum SupporterPaket { waldsee, lagerfeuer, nachthimmel }

enum AppPaletteId { standard, waldsee, lagerfeuer, nachthimmel, hochkontrast }

enum AppearanceBackgroundId { lagerfeuer, nachthimmel, waldsee }

/// Ein App-Icon-Paket enthaelt immer alle drei Tageszeiten.
enum AppIconPackage { nachthimmel, lagerfeuer, waldsee }

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
  /// z. B. `NachthimmelMorgen`.
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
  /// Paletten ohne Eintrag sind frei.
  static const Map<AppPaletteId, SupporterPaket> palettePakete = {
    AppPaletteId.waldsee: SupporterPaket.waldsee,
    AppPaletteId.lagerfeuer: SupporterPaket.lagerfeuer,
    AppPaletteId.nachthimmel: SupporterPaket.nachthimmel,
  };

  static const Map<AppearanceBackgroundId, SupporterPaket> backgroundPakete = {
    AppearanceBackgroundId.waldsee: SupporterPaket.waldsee,
    AppearanceBackgroundId.lagerfeuer: SupporterPaket.lagerfeuer,
    AppearanceBackgroundId.nachthimmel: SupporterPaket.nachthimmel,
  };

  static const Map<AppIconPackage, SupporterPaket> iconPakete = {
    AppIconPackage.waldsee: SupporterPaket.waldsee,
    AppIconPackage.lagerfeuer: SupporterPaket.lagerfeuer,
    AppIconPackage.nachthimmel: SupporterPaket.nachthimmel,
  };

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
