import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logger_service.dart';
import 'store_review_client.dart';

typedef StoreReviewPreferencesProvider = Future<SharedPreferences> Function();
typedef StoreReviewPlatformProvider = TargetPlatform Function();
typedef StoreReviewDelay = Future<void> Function();

/// Fragt auf iOS einmalig den System-Bewertungsdialog an, nachdem eine
/// Person erfolgreich gespeichert wurde.
///
/// Apple erlaubt aktive Bewertungsaufforderungen nur ueber den Systemdialog.
/// Die Anfrage erfolgt hoechstens einmal pro Installation, nie im selben
/// App-Start wie der eigene Feedback-Dialog, nicht im Demo-Modus und nicht
/// auf Android. Ob der Dialog wirklich erscheint, entscheidet iOS.
class StoreReviewPromptService {
  StoreReviewPromptService({
    StoreReviewClient? client,
    StoreReviewPreferencesProvider? preferencesProvider,
    StoreReviewPlatformProvider? platformProvider,
    StoreReviewDelay? delay,
    LoggerService? logger,
    bool isDemo = false,
  }) : _client = client ?? InAppReviewStoreReviewClient(),
       _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance,
       _platform = platformProvider ?? (() => defaultTargetPlatform),
       _delay = delay ?? _defaultDelay,
       _logger = logger,
       _isDemo = isDemo;

  /// Teilt das Praefix mit dem Feedback-Dialog und wird beim App-Reset mit
  /// geloescht.
  static const String requestedKey = 'feedback_prompt.system_review_requested';

  /// Abstand zwischen Speicherbestaetigung und Systemdialog.
  static const Duration requestDelay = Duration(milliseconds: 1500);

  final StoreReviewClient _client;
  final StoreReviewPreferencesProvider _preferencesProvider;
  final StoreReviewPlatformProvider _platform;
  final StoreReviewDelay _delay;
  final LoggerService? _logger;
  final bool _isDemo;
  bool _feedbackPromptShownThisSession = false;
  bool _requestStarted = false;

  static Future<void> _defaultDelay() => Future<void>.delayed(requestDelay);

  /// Merkt sich, dass der eigene Feedback-Dialog in diesem App-Start
  /// erschienen ist. Danach fragt dieser App-Start nicht mehr an.
  void markFeedbackPromptShown() {
    _feedbackPromptShownThisSession = true;
  }

  /// Fragt den Systemdialog an, wenn alle Regeln erfuellt sind. Liefert
  /// `true`, wenn angefragt wurde.
  Future<bool> requestAfterMemberSaved() async {
    if (!await _isEligible()) {
      return false;
    }
    await _delay();
    // Waehrend der Wartezeit kann der Feedback-Dialog erschienen sein.
    final eligible = await _isEligible();
    // Ohne weiteres await sperren, damit kurz nacheinander gespeicherte
    // Personen nicht doppelt anfragen.
    if (!eligible || _requestStarted) {
      return false;
    }
    _requestStarted = true;
    try {
      if (!await _client.isAvailable()) {
        _requestStarted = false;
        return false;
      }
      // Vor der Anfrage merken, damit ein Fehler nicht zu Wiederholungen
      // fuehrt.
      final prefs = await _preferencesProvider();
      await prefs.setBool(requestedKey, true);
      await _client.requestReview();
      return true;
    } catch (error) {
      await _logger?.log('feedback', 'Systembewertung fehlgeschlagen: $error');
      return false;
    }
  }

  Future<bool> _isEligible() async {
    if (_isDemo ||
        _requestStarted ||
        _feedbackPromptShownThisSession ||
        _platform() != TargetPlatform.iOS) {
      return false;
    }
    final prefs = await _preferencesProvider();
    return !(prefs.getBool(requestedKey) ?? false);
  }
}
