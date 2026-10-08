import 'appearance_catalog.dart';

/// Entscheidet, welche Erscheinungsbild-Optionen und Supporter-Funktionen
/// nutzbar sind. Spaeter liefert eine Store-Anbindung die Freischaltungen;
/// die UI fragt nur diese Schnittstelle ab.
abstract class SupportAccess {
  const SupportAccess();

  /// Laufendes Foerderer-Abo: schaltet alle Pakete und Funktionen frei.
  bool get foerderer;

  /// Einzeln gekaufte Design-Pakete.
  Set<SupporterPaket> get pakete;

  bool isPaketUnlocked(SupporterPaket? paket) =>
      paket == null || foerderer || pakete.contains(paket);

  bool isTierUnlocked(SupportTier tier) => switch (tier) {
    SupportTier.free => true,
    SupportTier.supporter => foerderer || pakete.isNotEmpty,
    SupportTier.foerderer => foerderer,
  };

  bool isPaletteUnlocked(AppPaletteId id) =>
      isPaketUnlocked(AppearanceCatalog.palettePakete[id]);

  bool isBackgroundUnlocked(AppearanceBackgroundId id) =>
      isPaketUnlocked(AppearanceCatalog.backgroundPakete[id]);

  bool isIconPackageUnlocked(AppIconPackage package) =>
      isPaketUnlocked(AppearanceCatalog.iconPakete[package]);

  /// Qualifikationen-Uebersicht und -Erinnerungen fuer alle Leitenden.
  bool get qualifikationenFrei => foerderer;
}

/// Auswahl des Testschalters in Debug & Tools.
enum SupporterTestZugang { keiner, wald, lagerfeuer, nachthimmel, foerderer }

/// Zugang ueber den Testschalter in Debug & Tools: simuliert genau ein
/// gekauftes Paket oder das Foerderer-Abo.
class SchalterSupportAccess extends SupportAccess {
  const SchalterSupportAccess(this.zugang);

  final SupporterTestZugang zugang;

  @override
  bool get foerderer => zugang == SupporterTestZugang.foerderer;

  @override
  Set<SupporterPaket> get pakete => switch (zugang) {
    SupporterTestZugang.wald => const {SupporterPaket.wald},
    SupporterTestZugang.lagerfeuer => const {SupporterPaket.lagerfeuer},
    SupporterTestZugang.nachthimmel => const {SupporterPaket.nachthimmel},
    SupporterTestZugang.keiner || SupporterTestZugang.foerderer => const {},
  };
}

/// Alles freigeschaltet, etwa im Demo-Modus.
class UnlockedSupportAccess extends SupportAccess {
  const UnlockedSupportAccess();

  @override
  bool get foerderer => true;

  @override
  Set<SupporterPaket> get pakete => SupporterPaket.values.toSet();
}
