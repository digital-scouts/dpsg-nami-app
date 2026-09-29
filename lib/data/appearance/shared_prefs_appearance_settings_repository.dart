import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/appearance/appearance_catalog.dart';
import '../../domain/appearance/appearance_settings.dart';
import '../../domain/appearance/appearance_settings_repository.dart';

class SharedPrefsAppearanceSettingsRepository
    implements AppearanceSettingsRepository {
  static const String _keyPalette = 'appearancePalette';
  static const String _keyBackground = 'appearanceBackground';
  static const String _keyBadge = 'appearanceBadge';
  static const String _keyAppIcon = 'appearanceAppIcon';

  Future<SharedPreferences> _prefs() async => SharedPreferences.getInstance();

  @override
  Future<AppearanceSettings> load() async {
    final prefs = await _prefs();
    return AppearanceSettings(
      palette:
          _byName(AppPaletteId.values, prefs.getString(_keyPalette)) ??
          AppPaletteId.standard,
      background: _byName(
        AppearanceBackgroundId.values,
        prefs.getString(_keyBackground),
      ),
      badge: _byName(SupporterBadgeId.values, prefs.getString(_keyBadge)),
      appIcon: AppIconChoice.fromKey(prefs.getString(_keyAppIcon)),
    );
  }

  @override
  Future<void> save(AppearanceSettings settings) async {
    final prefs = await _prefs();
    await prefs.setString(_keyPalette, settings.palette.name);
    await _setOrRemove(prefs, _keyBackground, settings.background?.name);
    await _setOrRemove(prefs, _keyBadge, settings.badge?.name);
    await _setOrRemove(prefs, _keyAppIcon, settings.appIcon?.key);
  }

  Future<void> _setOrRemove(
    SharedPreferences prefs,
    String key,
    String? value,
  ) async {
    if (value == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, value);
    }
  }

  T? _byName<T extends Enum>(List<T> values, String? name) {
    if (name == null) {
      return null;
    }
    for (final value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return null;
  }
}
