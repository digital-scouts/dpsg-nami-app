import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppUpdateEnv {
  static String get url => _env('APP_UPDATE_URL') ?? '';

  static Duration get minFetchInterval {
    final hoursRaw = _env('APP_UPDATE_MIN_FETCH_INTERVAL_HOURS');
    final hours = int.tryParse(hoursRaw ?? '');
    if (hours == null || hours < 0) {
      return const Duration(hours: 12);
    }
    return Duration(hours: hours);
  }

  static Duration get fetchTimeout {
    final secondsRaw = _env('APP_UPDATE_FETCH_TIMEOUT_SECONDS');
    final seconds = int.tryParse(secondsRaw ?? '');
    if (seconds == null || seconds <= 0) {
      return const Duration(seconds: 5);
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
