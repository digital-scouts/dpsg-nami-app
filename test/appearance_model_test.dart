import 'package:flutter_test/flutter_test.dart';
import 'package:nami/data/appearance/in_memory_appearance_settings_repository.dart';
import 'package:nami/domain/appearance/appearance_catalog.dart';
import 'package:nami/domain/appearance/appearance_settings.dart';
import 'package:nami/domain/appearance/support_access.dart';
import 'package:nami/presentation/model/appearance_model.dart';
import 'package:nami/services/app_icon_service.dart';

/// Nur freie und Supporter-Optionen sind nutzbar.
class _SupporterOnlyAccess extends SupportAccess {
  const _SupporterOnlyAccess();

  @override
  bool isTierUnlocked(SupportTier tier) => tier != SupportTier.foerderer;
}

void main() {
  late InMemoryAppearanceSettingsRepository repository;
  late FakeAppIconService iconService;

  AppearanceModel buildModel({
    SupportAccess access = const UnlockedSupportAccess(),
    bool supportsAutomatic = true,
  }) {
    iconService = FakeAppIconService(
      supportsAutomaticVariant: supportsAutomatic,
    );
    return AppearanceModel(
      repository: repository,
      appIconService: iconService,
      access: access,
    );
  }

  setUp(() {
    repository = InMemoryAppearanceSettingsRepository();
  });

  test('speichert Auswahl und laedt sie wieder', () async {
    final model = buildModel();
    await model.setPalette(AppPaletteId.wald);
    await model.setBackground(AppearanceBackgroundId.himmel);
    await model.setBadge(SupporterBadgeId.kompassPfadfinder);
    await model.setAppIcon(
      const AppIconChoice(AppIconPackage.hajk, AppIconVariant.abend),
    );

    final reloaded = buildModel();
    await reloaded.load();

    expect(reloaded.palette, AppPaletteId.wald);
    expect(reloaded.background, AppearanceBackgroundId.himmel);
    expect(reloaded.badge, SupporterBadgeId.kompassPfadfinder);
    expect(
      reloaded.appIcon,
      const AppIconChoice(AppIconPackage.hajk, AppIconVariant.abend),
    );
    expect(reloaded.iconChangeSupported, isTrue);
  });

  test('wendet das gewaehlte App-Icon an', () async {
    final model = buildModel();
    const choice = AppIconChoice(
      AppIconPackage.nachtlager,
      AppIconVariant.automatisch,
    );

    await model.setAppIcon(choice);

    expect(iconService.applied, choice);
    expect(iconService.applied?.key, 'NachtlagerAutomatisch');
  });

  test('Automatisch faellt ohne Systemunterstuetzung auf Standard', () async {
    final model = buildModel(supportsAutomatic: false);

    await model.setAppIcon(
      const AppIconChoice(
        AppIconPackage.nachtlager,
        AppIconVariant.automatisch,
      ),
    );

    expect(model.appIcon, isNull);
    expect(iconService.applied, isNull);
    expect(iconService.applyCount, 1);
  });

  test('gesperrte Optionen fallen auf den Standard zurueck', () async {
    repository = InMemoryAppearanceSettingsRepository(
      const AppearanceSettings(
        palette: AppPaletteId.nachthimmel,
        background: AppearanceBackgroundId.wald,
        badge: SupporterBadgeId.foerdererPolarstern,
      ),
    );
    final model = buildModel(access: const _SupporterOnlyAccess());
    await model.load();

    expect(model.palette, AppPaletteId.standard);
    expect(model.background, isNull);
    expect(model.badge, isNull);

    model.updateAccess(const UnlockedSupportAccess());

    expect(model.palette, AppPaletteId.nachthimmel);
    expect(model.background, AppearanceBackgroundId.wald);
    expect(model.badge, SupporterBadgeId.foerdererPolarstern);
  });

  test('reset stellt Standard und Standard-Icon wieder her', () async {
    final model = buildModel();
    await model.setPalette(AppPaletteId.lagerfeuer);
    await model.setAppIcon(
      const AppIconChoice(AppIconPackage.lagerfeuer, AppIconVariant.nacht),
    );

    await model.reset();

    expect(model.palette, AppPaletteId.standard);
    expect(model.appIcon, isNull);
    expect(iconService.applied, isNull);
    expect((await repository.load()).palette, AppPaletteId.standard);
  });

  test('AppIconChoice-Schluessel sind eindeutig und umkehrbar', () {
    final keys = <String>{};
    for (final package in AppIconPackage.values) {
      for (final variant in AppIconVariant.values) {
        final choice = AppIconChoice(package, variant);
        expect(keys.add(choice.key), isTrue);
        expect(AppIconChoice.fromKey(choice.key), choice);
      }
    }
    expect(AppIconChoice.fromKey('Unbekannt'), isNull);
  });
}
