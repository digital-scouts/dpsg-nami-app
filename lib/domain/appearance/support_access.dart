import 'appearance_catalog.dart';

/// Entscheidet, welche Erscheinungsbild-Optionen nutzbar sind. Spaeter liefert
/// eine Store-Anbindung die Freischaltungen; die UI fragt nur diese
/// Schnittstelle ab.
abstract class SupportAccess {
  const SupportAccess();

  bool isTierUnlocked(SupportTier tier);

  bool isIconPackageUnlocked(AppIconPackage package) =>
      isTierUnlocked(AppearanceCatalog.iconPackageTier);
}

/// Zugang ueber den Testschalter in Debug & Tools: freie Optionen immer,
/// alles andere nur mit Schalter.
class SchalterSupportAccess extends SupportAccess {
  const SchalterSupportAccess({required this.freigeschaltet});

  final bool freigeschaltet;

  @override
  bool isTierUnlocked(SupportTier tier) =>
      tier == SupportTier.free || freigeschaltet;
}

/// Alles freigeschaltet, etwa im Demo-Modus.
class UnlockedSupportAccess extends SupportAccess {
  const UnlockedSupportAccess();

  @override
  bool isTierUnlocked(SupportTier tier) => true;
}
