import 'package:flutter_dotenv/flutter_dotenv.dart';

class BundesstatistikEnv {
  /// Basis-URL des Statistikservers; leer schaltet die Funktion ab.
  static String get serverUrl => (_env('STATS_SERVER_URL') ?? '').trim();

  static bool get isEnabled => Uri.tryParse(serverUrl)?.hasScheme ?? false;

  static Duration get sendInterval {
    final hours = int.tryParse(_env('STATS_SEND_INTERVAL_HOURS') ?? '');
    if (hours == null || hours <= 0) {
      return const Duration(days: 7);
    }
    return Duration(hours: hours);
  }

  static Duration get fetchTimeout {
    final seconds = int.tryParse(_env('STATS_FETCH_TIMEOUT_SECONDS') ?? '');
    if (seconds == null || seconds <= 0) {
      return const Duration(seconds: 10);
    }
    return Duration(seconds: seconds);
  }

  static String? _env(String key) {
    try {
      return dotenv.env[key];
    } catch (_) {
      return null;
    }
  }
}
