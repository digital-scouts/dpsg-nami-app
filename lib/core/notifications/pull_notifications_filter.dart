import 'package:flutter/foundation.dart';

import 'pull_notification.dart';

/// Plattformkennung für das Feld `platform` der Pull-Meldungen.
String aktuellePlattformFuerMeldungen() {
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return 'ios';
    case TargetPlatform.android:
      return 'android';
    default:
      return 'all';
  }
}

/// Behält nur Meldungen, die für [platform] gelten und zu [now] aktiv sind
/// (`starts_at` erreicht, `ends_at` noch nicht überschritten).
List<PullNotification> filterAktiveMeldungen(
  List<PullNotification> notifications, {
  required DateTime now,
  required String platform,
}) {
  return notifications
      .where(
        (n) =>
            _giltFuerPlattform(n.platform, platform) &&
            !_nochNichtGestartet(n, now) &&
            !_abgelaufen(n, now),
      )
      .toList(growable: false);
}

bool _giltFuerPlattform(String meldung, String aktuelle) {
  final normalisiert = meldung.trim().toLowerCase();
  return normalisiert.isEmpty ||
      normalisiert == 'all' ||
      normalisiert == aktuelle;
}

bool _nochNichtGestartet(PullNotification n, DateTime now) {
  final startsAt = n.startsAt;
  return startsAt != null && startsAt.isAfter(now);
}

bool _abgelaufen(PullNotification n, DateTime now) {
  final endsAt = n.endsAt;
  return endsAt != null && !endsAt.isAfter(now);
}
