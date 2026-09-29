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

/// Vorlaeufige Implementierung: alles ist freigeschaltet.
class UnlockedSupportAccess extends SupportAccess {
  const UnlockedSupportAccess();

  @override
  bool isTierUnlocked(SupportTier tier) => true;
}
