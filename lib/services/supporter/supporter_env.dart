import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupporterEnv {
  /// Schaltet die Store-Anbindung fuer Supporter-Kaeufe ein. Aus heisst: kein
  /// Kaufweg, gesperrte Optionen bleiben gesperrt (Stand vor der Anbindung).
  static bool get storeEnabled =>
      _bool('SUPPORTER_STORE_ENABLED', fallback: false);

  static bool _bool(String key, {required bool fallback}) {
    final raw = (_env(key) ?? '').trim().toLowerCase();
    if (raw == 'true' || raw == '1' || raw == 'yes') {
      return true;
    }
    if (raw == 'false' || raw == '0' || raw == 'no') {
      return false;
    }
    return fallback;
  }

  static String? _env(String key) {
    try {
      return dotenv.env[key];
    } catch (_) {
      return null;
    }
  }
}
