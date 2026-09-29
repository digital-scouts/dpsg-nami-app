import 'pending_person_update.dart';

/// Drosselt automatische Sendeversuche fuer vorgemerkte Personenaenderungen.
///
/// Die Wartezeit verdoppelt sich nach jedem Fehlversuch (1, 2, 4, ... Minuten)
/// bis maximal [maxDelay]. Nach [maxAutomaticAttempts] Fehlversuchen pausiert
/// das automatische Senden; nach einem App-Neustart ist genau ein weiterer
/// automatischer Versuch erlaubt. Manuelles Senden ist davon unabhaengig.
class PendingRetryPolicy {
  const PendingRetryPolicy._();

  static const int maxAutomaticAttempts = 10;
  static const Duration initialDelay = Duration(minutes: 1);
  static const Duration maxDelay = Duration(minutes: 60);

  static Duration delayAfterAttempts(int attemptCount) {
    if (attemptCount <= 0) {
      return Duration.zero;
    }
    final maxMinutes = maxDelay.inMinutes;
    var minutes = initialDelay.inMinutes;
    for (var i = 1; i < attemptCount && minutes < maxMinutes; i++) {
      minutes *= 2;
    }
    return Duration(minutes: minutes < maxMinutes ? minutes : maxMinutes);
  }

  static bool isAutomaticRetryPaused(
    PendingPersonUpdate entry, {
    required DateTime sessionStartedAt,
  }) {
    if (entry.needsResolution || entry.attemptCount < maxAutomaticAttempts) {
      return false;
    }
    final lastAttemptAt = entry.lastAttemptAt;
    return lastAttemptAt != null && !lastAttemptAt.isBefore(sessionStartedAt);
  }

  static bool isAutomaticRetryDue(
    PendingPersonUpdate entry, {
    required DateTime now,
    required DateTime sessionStartedAt,
  }) {
    if (entry.needsResolution) {
      return false;
    }
    final lastAttemptAt = entry.lastAttemptAt;
    if (entry.attemptCount <= 0 || lastAttemptAt == null) {
      return true;
    }
    if (entry.attemptCount >= maxAutomaticAttempts) {
      return lastAttemptAt.isBefore(sessionStartedAt);
    }
    return !now.isBefore(
      lastAttemptAt.add(delayAfterAttempts(entry.attemptCount)),
    );
  }
}
