import 'package:flutter_dotenv/flutter_dotenv.dart';

class NamiAiEnv {
  static bool get enabled => _bool('NAMI_AI_ENABLED', fallback: false);

  static int get minIosMajorVersion =>
      _int('NAMI_AI_MIN_IOS_MAJOR', fallback: 27);

  static String get deviceGateMode =>
      (_env('NAMI_AI_DEVICE_GATE_MODE') ?? 'whitelist').trim().toLowerCase();

  static List<String> get deviceWhitelist =>
      _list('NAMI_AI_DEVICE_WHITELIST', fallback: _defaultDeviceWhitelist);

  static List<String> get appleIntelligenceWhitelist => _list(
    'NAMI_AI_APPLE_INTELLIGENCE_WHITELIST',
    fallback: _defaultDeviceWhitelist,
  );

  static bool get requirePremium =>
      _bool('NAMI_AI_REQUIRE_PREMIUM', fallback: true);

  static bool get premiumActive =>
      _bool('NAMI_AI_PREMIUM_ACTIVE', fallback: false);

  static const List<String> _defaultDeviceWhitelist = <String>[
    'iPhone16,*',
    'iPhone17,*',
  ];

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

  static int _int(String key, {required int fallback}) {
    final value = int.tryParse((_env(key) ?? '').trim());
    if (value == null || value <= 0) {
      return fallback;
    }
    return value;
  }

  static List<String> _list(String key, {required List<String> fallback}) {
    final raw = (_env(key) ?? '').trim();
    if (raw.isEmpty) {
      return fallback;
    }
    final values = raw
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
    if (values.isEmpty) {
      return fallback;
    }
    return values;
  }

  static String? _env(String key) {
    try {
      return dotenv.env[key];
    } catch (_) {
      return null;
    }
  }
}
