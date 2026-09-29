import 'appearance_settings.dart';

abstract class AppearanceSettingsRepository {
  Future<AppearanceSettings> load();
  Future<void> save(AppearanceSettings settings);
}
