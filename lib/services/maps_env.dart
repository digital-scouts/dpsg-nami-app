import 'package:flutter_dotenv/flutter_dotenv.dart';

class MapsEnv {
  static const String defaultTileUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static double get stammOfflineRadiusKm =>
      _positiveDouble('MAPS_STAMM_OFFLINE_RADIUS_KM', fallback: 5);

    static double get stammMinVisibleZoom =>
      _nonNegativeDouble('MAPS_STAMM_MIN_VISIBLE_ZOOM', fallback: 0);

  static double get memberOfflineRadiusKm =>
      _positiveDouble('MAPS_MEMBER_OFFLINE_RADIUS_KM', fallback: 0.5);

  static String get mapTilerKey => (_env('MAPTILER_KEY') ?? '').trim();

  static String get mapTileUrlTemplate {
    final configured = (_env('MAP_TILE_URL') ?? '').trim();
    if (configured.isEmpty) {
      return defaultTileUrlTemplate;
    }

    if (configured.contains('{key}')) {
      final key = mapTilerKey;
      if (key.isEmpty) {
        return defaultTileUrlTemplate;
      }
      return configured.replaceAll('{key}', key);
    }

    return configured;
  }

  static bool get isUsingTileFallback {
    final configured = (_env('MAP_TILE_URL') ?? '').trim();
    final requiresKey = configured.contains('{key}');
    return configured.isEmpty || (requiresKey && mapTilerKey.isEmpty);
  }

  static double _positiveDouble(String key, {required double fallback}) {
    final raw = _env(key);
    final value = double.tryParse(raw ?? '');
    if (value == null || value <= 0) {
      return fallback;
    }
    return value;
  }

  static double _nonNegativeDouble(String key, {required double fallback}) {
    final raw = _env(key);
    final value = double.tryParse(raw ?? '');
    if (value == null || value < 0) {
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
