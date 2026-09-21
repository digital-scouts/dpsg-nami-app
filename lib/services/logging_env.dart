import 'package:flutter_dotenv/flutter_dotenv.dart';

class LoggingEnv {
  static int get maxDays => _positiveInt('LOG_MAX_DAYS', fallback: 7);

  static int get maxSizeMb => _positiveInt('LOG_MAX_SIZE_MB', fallback: 1);

  static int get maxSizeBytes => maxSizeMb * 1024 * 1024;

  static int _positiveInt(String key, {required int fallback}) {
    final raw = _env(key);
    final value = int.tryParse(raw ?? '');
    if (value == null || value <= 0) {
      return fallback;
    }
    return value;
  }

  static String? _env(String key) {
    try {
      return dotenv.env[key];
    } catch (_) {
      return null;
    }
  }
}
