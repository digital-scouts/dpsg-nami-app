import 'package:shared_preferences/shared_preferences.dart';

typedef StartupPreferencesProvider = Future<SharedPreferences> Function();

class AppStartupStateService {
  AppStartupStateService({StartupPreferencesProvider? preferencesProvider})
    : _preferencesProvider =
          preferencesProvider ?? SharedPreferences.getInstance;

  static const String welcomeSeenKey = 'startup.welcome_seen';
  static const String lastSeenAppVersionKey = 'startup.last_seen_app_version';

  final StartupPreferencesProvider _preferencesProvider;

  Future<bool> hasSeenWelcome() async {
    final prefs = await _preferencesProvider();
    return prefs.getBool(welcomeSeenKey) ?? false;
  }

  Future<void> markWelcomeSeen() async {
    final prefs = await _preferencesProvider();
    await prefs.setBool(welcomeSeenKey, true);
  }

  Future<String?> loadLastSeenAppVersion() async {
    final prefs = await _preferencesProvider();
    return prefs.getString(lastSeenAppVersionKey);
  }

  Future<void> saveLastSeenAppVersion(String version) async {
    final prefs = await _preferencesProvider();
    await prefs.setString(lastSeenAppVersionKey, version);
  }

  Future<void> clearStartupState() async {
    final prefs = await _preferencesProvider();
    await prefs.remove(welcomeSeenKey);
    await prefs.remove(lastSeenAppVersionKey);
  }
}
