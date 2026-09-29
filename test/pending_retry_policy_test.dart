import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/member/member_resolution.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/member/pending_person_update.dart';
import 'package:nami/domain/member/pending_retry_policy.dart';

final _sessionStartedAt = DateTime(2026, 4, 14, 8, 0);

PendingPersonUpdate _entry({
  int attemptCount = 0,
  DateTime? lastAttemptAt,
  PendingPersonUpdateStatus status = PendingPersonUpdateStatus.queued,
}) {
  final mitglied = Mitglied.peopleListItem(
    mitgliedsnummer: '4711',
    personId: 23,
    vorname: 'Julia',
    nachname: 'Keller',
  );
  return PendingPersonUpdate(
    entryId: 'person-23',
    personId: 23,
    mitgliedsnummer: '4711',
    displayName: 'Julia Keller',
    basisMitglied: mitglied,
    zielMitglied: mitglied.copyWith(vorname: 'Juliane'),
    queuedAt: DateTime(2026, 4, 14, 7, 0),
    status: status,
    attemptCount: attemptCount,
    lastAttemptAt: lastAttemptAt,
  );
}

bool _isDue(PendingPersonUpdate entry, DateTime now) {
  return PendingRetryPolicy.isAutomaticRetryDue(
    entry,
    now: now,
    sessionStartedAt: _sessionStartedAt,
  );
}

void main() {
  test('verdoppelt die Wartezeit bis maximal 60 Minuten', () {
    expect(
      <int>[
        for (var attempts = 0; attempts <= 9; attempts++)
          PendingRetryPolicy.delayAfterAttempts(attempts).inMinutes,
      ],
      <int>[0, 1, 2, 4, 8, 16, 32, 60, 60, 60],
    );
  });

  test('sendet noch nie versuchte Eintraege sofort', () {
    expect(_isDue(_entry(), _sessionStartedAt), isTrue);
  });

  test('wartet nach einem Fehlversuch die Backoff-Zeit ab', () {
    final lastAttemptAt = DateTime(2026, 4, 14, 9, 0);
    final entry = _entry(attemptCount: 3, lastAttemptAt: lastAttemptAt);

    expect(
      _isDue(entry, lastAttemptAt.add(const Duration(minutes: 3))),
      isFalse,
    );
    expect(
      _isDue(entry, lastAttemptAt.add(const Duration(minutes: 4))),
      isTrue,
    );
  });

  test('pausiert nach 10 Fehlversuchen in derselben App-Sitzung', () {
    final lastAttemptAt = DateTime(2026, 4, 14, 9, 0);
    final entry = _entry(attemptCount: 10, lastAttemptAt: lastAttemptAt);

    expect(_isDue(entry, lastAttemptAt.add(const Duration(days: 1))), isFalse);
    expect(
      PendingRetryPolicy.isAutomaticRetryPaused(
        entry,
        sessionStartedAt: _sessionStartedAt,
      ),
      isTrue,
    );
  });

  test('erlaubt nach einem Neustart genau einen weiteren Versuch', () {
    final vorNeustart = _entry(
      attemptCount: 12,
      lastAttemptAt: _sessionStartedAt.subtract(const Duration(hours: 1)),
    );
    final nachVersuch = _entry(
      attemptCount: 13,
      lastAttemptAt: _sessionStartedAt.add(const Duration(minutes: 1)),
    );
    final now = _sessionStartedAt.add(const Duration(hours: 2));

    expect(_isDue(vorNeustart, now), isTrue);
    expect(
      PendingRetryPolicy.isAutomaticRetryPaused(
        vorNeustart,
        sessionStartedAt: _sessionStartedAt,
      ),
      isFalse,
    );
    expect(_isDue(nachVersuch, now), isFalse);
  });

  test('sendet offene Problemfaelle nie automatisch', () {
    final entry = _entry(status: PendingPersonUpdateStatus.needsResolution);

    expect(_isDue(entry, _sessionStartedAt), isFalse);
    expect(
      PendingRetryPolicy.isAutomaticRetryPaused(
        entry,
        sessionStartedAt: _sessionStartedAt,
      ),
      isFalse,
    );
  });
}
