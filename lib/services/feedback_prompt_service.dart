import 'package:shared_preferences/shared_preferences.dart';

typedef FeedbackPromptPreferencesProvider =
    Future<SharedPreferences> Function();
typedef FeedbackPromptNowProvider = DateTime Function();

/// Steuert, wann der einmalige Feedback-/Bewertungsdialog erscheint.
///
/// Der Dialog erscheint fruehestens [initialDelay] nach der ersten Nutzung,
/// nach "Spaeter" erneut nach [snoozeDuration] und insgesamt hoechstens
/// [maxShowCount] Mal. Nach Feedback oder Bewertung nie wieder.
class FeedbackPromptService {
  FeedbackPromptService({
    FeedbackPromptPreferencesProvider? preferencesProvider,
    FeedbackPromptNowProvider? nowProvider,
  }) : _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance,
       _now = nowProvider ?? DateTime.now;

  static const String firstSeenKey = 'feedback_prompt.first_seen_iso';
  static const String shownCountKey = 'feedback_prompt.shown_count';
  static const String nextEligibleKey = 'feedback_prompt.next_eligible_iso';
  static const String completedKey = 'feedback_prompt.completed';

  static const Duration initialDelay = Duration(days: 7);
  static const Duration snoozeDuration = Duration(days: 14);
  static const int maxShowCount = 2;

  final FeedbackPromptPreferencesProvider _preferencesProvider;
  final FeedbackPromptNowProvider _now;

  /// Merkt sich den Zeitpunkt der ersten Nutzung, falls noch nicht gesetzt.
  Future<void> recordFirstUse() async {
    final prefs = await _preferencesProvider();
    if (DateTime.tryParse(prefs.getString(firstSeenKey) ?? '') == null) {
      await prefs.setString(firstSeenKey, _now().toIso8601String());
    }
  }

  Future<bool> shouldShow() async {
    final prefs = await _preferencesProvider();
    final now = _now();

    final firstSeen = DateTime.tryParse(prefs.getString(firstSeenKey) ?? '');
    if (firstSeen == null) {
      await recordFirstUse();
      return false;
    }
    if (prefs.getBool(completedKey) ?? false) {
      return false;
    }
    if ((prefs.getInt(shownCountKey) ?? 0) >= maxShowCount) {
      return false;
    }
    if (now.isBefore(firstSeen.add(initialDelay))) {
      return false;
    }
    final nextEligible = DateTime.tryParse(
      prefs.getString(nextEligibleKey) ?? '',
    );
    if (nextEligible != null && now.isBefore(nextEligible)) {
      return false;
    }
    return true;
  }

  Future<void> markShown() async {
    final prefs = await _preferencesProvider();
    final count = prefs.getInt(shownCountKey) ?? 0;
    await prefs.setInt(shownCountKey, count + 1);
  }

  Future<void> markSnoozed() async {
    final prefs = await _preferencesProvider();
    await prefs.setString(
      nextEligibleKey,
      _now().add(snoozeDuration).toIso8601String(),
    );
  }

  Future<void> markCompleted() async {
    final prefs = await _preferencesProvider();
    await prefs.setBool(completedKey, true);
  }
}
