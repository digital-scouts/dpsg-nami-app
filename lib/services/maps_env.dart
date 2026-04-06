import 'package:flutter_dotenv/flutter_dotenv.dart';

class MapsEnv {
  static double get stammOfflineRadiusKm =>
      _positiveDouble('MAPS_STAMM_OFFLINE_RADIUS_KM', fallback: 5);

  static double get memberOfflineRadiusKm =>
      _positiveDouble('MAPS_MEMBER_OFFLINE_RADIUS_KM', fallback: 0.5);

  static double _positiveDouble(String key, {required double fallback}) {
    final raw = _env(key);
    final value = double.tryParse(raw ?? '');
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
