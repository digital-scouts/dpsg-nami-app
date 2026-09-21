import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeoapifyEnv {
  static double get minConfidence =>
      _nonNegativeDouble('GEOAPIFY_MIN_CONFIDENCE', fallback: 0.5);

  // confidence bewertet den gesamten Treffer; confidence_street_level bewertet
  // zusaetzlich, wie sicher Strasse/Hausnummer getroffen wurden.
  static double get minStreetLevelConfidence =>
      _nonNegativeDouble('GEOAPIFY_MIN_STREET_LEVEL_CONFIDENCE', fallback: 0.5);

  static Duration get negativeCacheTtl => Duration(
    days: _positiveInt('GEOAPIFY_NEGATIVE_CACHE_TTL_DAYS', fallback: 7),
  );

  static bool get detailedLogEnabled =>
      _bool('GEOAPIFY_DETAILED_LOG', fallback: false);

  static double _nonNegativeDouble(String key, {required double fallback}) {
    final value = double.tryParse(_env(key) ?? '');
    if (value == null || value < 0) {
      return fallback;
    }
    return value;
  }

  static int _positiveInt(String key, {required int fallback}) {
    final value = int.tryParse(_env(key) ?? '');
    if (value == null || value <= 0) {
      return fallback;
    }
    return value;
  }

  static bool _bool(String key, {required bool fallback}) {
    final raw = _env(key)?.trim().toLowerCase();
    if (raw == null || raw.isEmpty) {
      return fallback;
    }
    return raw == 'true' || raw == '1' || raw == 'yes' || raw == 'ja';
  }

  static String? _env(String key) {
    try {
      return dotenv.env[key];
    } catch (_) {
      return null;
    }
  }
}
