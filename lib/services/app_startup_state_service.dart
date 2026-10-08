import 'package:shared_preferences/shared_preferences.dart';

typedef StartupPreferencesProvider = Future<SharedPreferences> Function();

class AppStartupStateService {
  AppStartupStateService({StartupPreferencesProvider? preferencesProvider})
    : _preferencesProvider =
          preferencesProvider ?? SharedPreferences.getInstance;

  static const String welcomeSeenKey = 'startup.welcome_seen';
  static const String lastSeenAppVersionKey = 'startup.last_seen_app_version';
  static const String anmeldungBegonnenKey = 'startup.login_started_at';

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

  /// Zeitpunkt, zu dem die App den Hitobito-Login im Browser geoeffnet hat.
  /// Beendet das System die App waehrend der Anmeldung, geht der Vorgang
  /// verloren; der naechste Start erkennt das an diesem Eintrag.
  Future<DateTime?> loadAnmeldungBegonnen() async {
    final prefs = await _preferencesProvider();
    final raw = prefs.getString(anmeldungBegonnenKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> saveAnmeldungBegonnen(DateTime? zeitpunkt) async {
    final prefs = await _preferencesProvider();
    if (zeitpunkt == null) {
      await prefs.remove(anmeldungBegonnenKey);
      return;
    }
    await prefs.setString(anmeldungBegonnenKey, zeitpunkt.toIso8601String());
  }

  Future<void> clearStartupState() async {
    final prefs = await _preferencesProvider();
    await prefs.remove(welcomeSeenKey);
    await prefs.remove(lastSeenAppVersionKey);
    await prefs.remove(anmeldungBegonnenKey);
  }
}
