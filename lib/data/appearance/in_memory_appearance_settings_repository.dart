import '../../domain/appearance/appearance_settings.dart';
import '../../domain/appearance/appearance_settings_repository.dart';

class InMemoryAppearanceSettingsRepository
    implements AppearanceSettingsRepository {
  InMemoryAppearanceSettingsRepository([
    this._settings = const AppearanceSettings(),
  ]);

  AppearanceSettings _settings;

  @override
  Future<AppearanceSettings> load() async => _settings;

  @override
  Future<void> save(AppearanceSettings settings) async {
    _settings = settings;
  }
}
