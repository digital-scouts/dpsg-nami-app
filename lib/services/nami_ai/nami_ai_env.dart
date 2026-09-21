import 'package:flutter_dotenv/flutter_dotenv.dart';

class NamiAiEnv {
  static bool get enabled => _bool('NAMI_AI_ENABLED', fallback: false);

  static bool get requirePremium =>
      _bool('NAMI_AI_REQUIRE_PREMIUM', fallback: true);

  static bool get premiumActive =>
      _bool('NAMI_AI_PREMIUM_ACTIVE', fallback: false);

  /// Verifier-pass self-correction loop (specs/nami-ai-roadmap.md section 3.12): a second model
  /// pass checks intent match, factual grounding and irrelevant-info, retrying up to twice on
  /// failure. Default off until the first manual eval round after rollout has confirmed latency
  /// and retry rate are acceptable (worst case triples the model calls per question).
  static bool get selfCorrectionEnabled =>
      _bool('NAMI_AI_SELF_CORRECTION_ENABLED', fallback: false);

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
