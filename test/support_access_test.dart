import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/appearance/appearance_catalog.dart';
import 'package:nami/domain/appearance/support_access.dart';

void main() {
  const keiner = SchalterSupportAccess(SupporterTestZugang.keiner);
  const wald = SchalterSupportAccess(SupporterTestZugang.wald);
  const foerderer = SchalterSupportAccess(SupporterTestZugang.foerderer);

  test('ohne Kauf sind nur freie Optionen nutzbar', () {
    expect(keiner.isPaletteUnlocked(AppPaletteId.standard), isTrue);
    expect(keiner.isPaletteUnlocked(AppPaletteId.hochkontrast), isTrue);
    expect(keiner.isPaletteUnlocked(AppPaletteId.wald), isFalse);
    for (final id in AppearanceBackgroundId.values) {
      expect(keiner.isBackgroundUnlocked(id), isFalse);
    }
    for (final package in AppIconPackage.values) {
      expect(keiner.isIconPackageUnlocked(package), isFalse);
    }
    expect(keiner.isTierUnlocked(SupportTier.free), isTrue);
    expect(keiner.isTierUnlocked(SupportTier.supporter), isFalse);
  });

  test('Paket Wald schaltet nur sein Design und die Kompass-Badges frei', () {
    expect(wald.isPaletteUnlocked(AppPaletteId.wald), isTrue);
    expect(wald.isBackgroundUnlocked(AppearanceBackgroundId.wald), isTrue);
    expect(wald.isIconPackageUnlocked(AppIconPackage.kohteSee), isTrue);

    expect(wald.isPaletteUnlocked(AppPaletteId.lagerfeuer), isFalse);
    expect(wald.isBackgroundUnlocked(AppearanceBackgroundId.himmel), isFalse);
    expect(wald.isIconPackageUnlocked(AppIconPackage.nachtlager), isFalse);

    expect(wald.isTierUnlocked(SupportTier.supporter), isTrue);
    expect(wald.isTierUnlocked(SupportTier.foerderer), isFalse);
    expect(wald.qualifikationenFrei, isFalse);
  });

  test('jedes Paket buendelt Palette, Hintergrund und Icons', () {
    for (final paket in SupporterPaket.values) {
      expect(AppearanceCatalog.palettePakete.values, contains(paket));
      expect(AppearanceCatalog.backgroundPakete.values, contains(paket));
      expect(AppearanceCatalog.iconPakete.values, contains(paket));
    }
    expect(
      AppearanceCatalog.iconPakete.keys.toSet(),
      AppIconPackage.values.toSet(),
    );
    expect(
      AppearanceCatalog.backgroundPakete.keys.toSet(),
      AppearanceBackgroundId.values.toSet(),
    );
  });

  test('Foerderer schaltet alles frei', () {
    for (final paket in SupporterPaket.values) {
      expect(foerderer.isPaketUnlocked(paket), isTrue);
    }
    for (final tier in SupportTier.values) {
      expect(foerderer.isTierUnlocked(tier), isTrue);
    }
    expect(foerderer.qualifikationenFrei, isTrue);
  });
}
