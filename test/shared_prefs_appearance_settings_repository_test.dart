import 'package:flutter_test/flutter_test.dart';
import 'package:nami/data/appearance/shared_prefs_appearance_settings_repository.dart';
import 'package:nami/domain/appearance/appearance_catalog.dart';
import 'package:nami/domain/appearance/appearance_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('liefert ohne gespeicherte Werte den Standard', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SharedPrefsAppearanceSettingsRepository().load();

    expect(settings.palette, AppPaletteId.standard);
    expect(settings.background, isNull);
    expect(settings.badge, isNull);
    expect(settings.appIcon, isNull);
  });

  test('speichert, laedt und entfernt Werte', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SharedPrefsAppearanceSettingsRepository();

    await repository.save(
      const AppearanceSettings(
        palette: AppPaletteId.hochkontrast,
        background: AppearanceBackgroundId.lagerfeuer,
        badge: SupporterBadgeId.kompassRover,
        appIcon: AppIconChoice(AppIconPackage.waldsee, AppIconVariant.nacht),
      ),
    );
    var loaded = await repository.load();
    expect(loaded.palette, AppPaletteId.hochkontrast);
    expect(loaded.background, AppearanceBackgroundId.lagerfeuer);
    expect(loaded.badge, SupporterBadgeId.kompassRover);
    expect(loaded.appIcon?.key, 'WaldseeNacht');

    await repository.save(const AppearanceSettings());
    loaded = await repository.load();
    expect(loaded.background, isNull);
    expect(loaded.badge, isNull);
    expect(loaded.appIcon, isNull);
  });

  test('ignoriert unbekannte Werte', () async {
    SharedPreferences.setMockInitialValues({
      'appearancePalette': 'gibtEsNicht',
      'appearanceBackground': 'mond',
      'appearanceAppIcon': 'KanuMorgen',
    });
    final settings = await SharedPrefsAppearanceSettingsRepository().load();

    expect(settings.palette, AppPaletteId.standard);
    expect(settings.background, isNull);
    expect(settings.appIcon, isNull);
  });
}
