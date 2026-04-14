import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/member/member_write_repository.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/member/pending_person_update.dart';
import 'package:nami/domain/member/pending_person_update_repository.dart';
import 'package:nami/domain/settings/app_settings.dart';
import 'package:nami/domain/settings/app_settings_repository.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/presentation/model/member_edit_model.dart';
import 'package:nami/services/logger_service.dart';

void main() {
  test(
    'laedt das Mitglied vor dem Editieren remote und aktualisiert den Read-Stand',
    () async {
      final logger = _FakeLoggerService();
      final updatedMembers = <Mitglied>[];
      final basisMitglied = Mitglied.peopleListItem(
        mitgliedsnummer: '4711',
        personId: 23,
        vorname: 'Julia',
        nachname: 'Keller',
      );
      final refreshedMember = basisMitglied.copyWith(
        vorname: 'Juliane',
        updatedAt: DateTime(2026, 4, 14, 12, 0),
      );
      final model = MemberEditModel(
        memberWriteRepository: _FakeMemberWriteRepository(
          fetchResultsByPersonId: <int, Object>{23: refreshedMember},
        ),
        pendingRepository: _InMemoryPendingPersonUpdateRepository(),
        logger: logger,
        onMemberUpdated: (member) async {
          updatedMembers.add(member);
        },
      );

      final result = await model.prepareForEdit(
        accessToken: 'token-123',
        mitglied: basisMitglied,
      );

      expect(result.success, isTrue);
      expect(result.member, refreshedMember);
      expect(updatedMembers, <Mitglied>[refreshedMember]);
      expect(
        logger.events,
        contains(
          _TrackedEvent(
            name: 'member_edit',
            properties: const <String, Object?>{
              'action': 'prepare_result',
              'trigger': 'detail_edit',
              'outcome': 'succeeded',
              'source': 'member_edit',
            },
          ),
        ),
      );
    },
  );

  test('queuet das Update bei generischem Fehler', () async {
    final pendingRepository = _InMemoryPendingPersonUpdateRepository();
    final logger = _FakeLoggerService();
    final model = MemberEditModel(
      memberWriteRepository: _FakeMemberWriteRepository(
        updateResultsByPersonId: <int, Object>{23: Exception('offline')},
      ),
      pendingRepository: pendingRepository,
      logger: logger,
      onMemberUpdated: (_) async {},
      nowProvider: () => DateTime(2026, 4, 14, 10, 30),
    );
    final basisMitglied = Mitglied.peopleListItem(
      mitgliedsnummer: '4711',
      personId: 23,
      vorname: 'Julia',
      nachname: 'Keller',
    );
    final zielMitglied = basisMitglied.copyWith(vorname: 'Juliane');

    final result = await model.submitUpdate(
      accessToken: 'token-123',
      basisMitglied: basisMitglied,
      zielMitglied: zielMitglied,
    );

    expect(result.success, isFalse);
    expect(result.wasQueued, isTrue);
    expect(result.pendingEntry, isNotNull);
    expect(model.pendingUpdates, hasLength(1));
    expect(model.pendingUpdates.single.personId, 23);
    expect(model.pendingUpdates.single.mitgliedsnummer, '4711');
    expect(model.pendingUpdates.single.queuedAt, DateTime(2026, 4, 14, 10, 30));
    expect(
      logger.events,
      contains(
        _TrackedEvent(
          name: 'member_edit',
          properties: const <String, Object?>{
            'action': 'submit_result',
            'trigger': 'manual_edit',
            'outcome': 'queued',
            'source': 'member_edit',
          },
        ),
      ),
    );
  });

  test('queuet das Update bei Auth-Fall nicht', () async {
    final pendingRepository = _InMemoryPendingPersonUpdateRepository();
    final model = MemberEditModel(
      memberWriteRepository: _FakeMemberWriteRepository(
        updateResultsByPersonId: <int, Object>{
          23: const MemberWriteAuthRequiredException('Bitte erneut anmelden.'),
        },
      ),
      pendingRepository: pendingRepository,
      logger: _FakeLoggerService(),
      onMemberUpdated: (_) async {},
      nowProvider: () => DateTime(2026, 4, 14, 10, 45),
    );
    final basisMitglied = Mitglied.peopleListItem(
      mitgliedsnummer: '4711',
      personId: 23,
      vorname: 'Julia',
      nachname: 'Keller',
    );

    final result = await model.submitUpdate(
      accessToken: 'token-123',
      basisMitglied: basisMitglied,
      zielMitglied: basisMitglied.copyWith(vorname: 'Juliane'),
    );

    expect(result.success, isFalse);
    expect(result.wasQueued, isFalse);
    expect(result.message, 'Bitte erneut anmelden.');
    expect(model.pendingUpdates, isEmpty);
  });

  test('queuet das Update bei abgelehntem 4xx-Fehler nicht', () async {
    final pendingRepository = _InMemoryPendingPersonUpdateRepository();
    final model = MemberEditModel(
      memberWriteRepository: _FakeMemberWriteRepository(
        updateResultsByPersonId: <int, Object>{
          23: const MemberWriteRejectedException('Abgelehnt.'),
        },
      ),
      pendingRepository: pendingRepository,
      logger: _FakeLoggerService(),
      onMemberUpdated: (_) async {},
      nowProvider: () => DateTime(2026, 4, 14, 10, 45),
    );
    final basisMitglied = Mitglied.peopleListItem(
      mitgliedsnummer: '4711',
      personId: 23,
      vorname: 'Julia',
      nachname: 'Keller',
    );

    final result = await model.submitUpdate(
      accessToken: 'token-123',
      basisMitglied: basisMitglied,
      zielMitglied: basisMitglied.copyWith(vorname: 'Juliane'),
    );

    expect(result.success, isFalse);
    expect(result.wasQueued, isFalse);
    expect(result.message, 'Abgelehnt.');
    expect(model.pendingUpdates, isEmpty);
  });

  test('trackt erfolgreichen Submit anonymisiert', () async {
    final logger = _FakeLoggerService();
    final basisMitglied = Mitglied.peopleListItem(
      mitgliedsnummer: '4711',
      personId: 23,
      vorname: 'Julia',
      nachname: 'Keller',
    );
    final model = MemberEditModel(
      memberWriteRepository: _FakeMemberWriteRepository(
        updateResultsByPersonId: <int, Object>{
          23: basisMitglied.copyWith(vorname: 'Juliane'),
        },
      ),
      pendingRepository: _InMemoryPendingPersonUpdateRepository(),
      logger: logger,
      onMemberUpdated: (_) async {},
      nowProvider: () => DateTime(2026, 4, 14, 10, 30),
    );

    await model.submitUpdate(
      accessToken: 'token-123',
      basisMitglied: basisMitglied,
      zielMitglied: basisMitglied.copyWith(vorname: 'Juliane'),
    );

    expect(
      logger.events,
      contains(
        _TrackedEvent(
          name: 'member_edit',
          properties: const <String, Object?>{
            'action': 'submit_result',
            'trigger': 'manual_edit',
            'outcome': 'succeeded',
            'source': 'member_edit',
          },
        ),
      ),
    );
  });

  test(
    'retryPending entfernt, behaelt und verwirft Eintraege je nach Ergebnis',
    () async {
      final pendingRepository = _InMemoryPendingPersonUpdateRepository(
        entries: <PendingPersonUpdate>[
          _pendingEntry(
            entryId: 'success-1',
            personId: 1,
            mitgliedsnummer: '1',
          ),
          _pendingEntry(
            entryId: 'conflict-2',
            personId: 2,
            mitgliedsnummer: '2',
          ),
          _pendingEntry(
            entryId: 'missing-3',
            personId: 3,
            mitgliedsnummer: '3',
          ),
          _pendingEntry(entryId: 'retain-4', personId: 4, mitgliedsnummer: '4'),
        ],
      );
      final updatedMembers = <Mitglied>[];
      final model = MemberEditModel(
        memberWriteRepository: _FakeMemberWriteRepository(
          updateResultsByPersonId: <int, Object>{
            1: _mitglied(personId: 1, mitgliedsnummer: '1', vorname: 'Erfolg'),
            2: const MemberWriteConflictException('Konflikt'),
            3: const MemberWriteUpdatedAtMissingException('updatedAt fehlt'),
            4: Exception('offline'),
          },
        ),
        pendingRepository: pendingRepository,
        logger: _FakeLoggerService(),
        onMemberUpdated: (member) async {
          updatedMembers.add(member);
        },
        nowProvider: () => DateTime(2026, 4, 14, 11, 0),
      );
      await model.loadPending();

      final summary = await model.retryPending(accessToken: 'token-123');
      final remaining = await pendingRepository.loadAll();

      expect(summary.successCount, 1);
      expect(summary.discardedCount, 2);
      expect(summary.retainedCount, 1);
      expect(updatedMembers, hasLength(1));
      expect(updatedMembers.single.personId, 1);
      expect(remaining, hasLength(1));
      expect(remaining.single.entryId, 'retain-4');
      expect(remaining.single.attemptCount, 1);
      expect(remaining.single.lastAttemptAt, DateTime(2026, 4, 14, 11, 0));
      expect(model.pendingUpdates.map((entry) => entry.entryId), <String>[
        'retain-4',
      ]);
    },
  );

  test('trackt Retry-Start und Retry-Ergebnis anonymisiert', () async {
    final logger = _FakeLoggerService();
    final pendingRepository = _InMemoryPendingPersonUpdateRepository(
      entries: <PendingPersonUpdate>[
        _pendingEntry(entryId: 'success-1', personId: 1, mitgliedsnummer: '1'),
      ],
    );
    final model = MemberEditModel(
      memberWriteRepository: _FakeMemberWriteRepository(
        updateResultsByPersonId: <int, Object>{
          1: _mitglied(personId: 1, mitgliedsnummer: '1', vorname: 'Erfolg'),
        },
      ),
      pendingRepository: pendingRepository,
      logger: logger,
      onMemberUpdated: (_) async {},
      nowProvider: () => DateTime(2026, 4, 14, 11, 0),
    );
    await model.loadPending();

    await model.retryPending(accessToken: 'token-123', trigger: 'manual_debug');

    expect(
      logger.events,
      contains(
        _TrackedEvent(
          name: 'member_edit',
          properties: const <String, Object?>{
            'action': 'retry_started',
            'trigger': 'manual_debug',
            'batch_size': 1,
            'source': 'member_edit',
          },
        ),
      ),
    );
    expect(
      logger.events,
      contains(
        _TrackedEvent(
          name: 'member_edit',
          properties: const <String, Object?>{
            'action': 'retry_result',
            'trigger': 'manual_debug',
            'outcome': 'succeeded',
            'success_count': 1,
            'retained_count': 0,
            'discarded_count': 0,
            'source': 'member_edit',
          },
        ),
      ),
    );
  });
}

PendingPersonUpdate _pendingEntry({
  required String entryId,
  required int personId,
  required String mitgliedsnummer,
}) {
  final basisMitglied = _mitglied(
    personId: personId,
    mitgliedsnummer: mitgliedsnummer,
    vorname: 'Basis $mitgliedsnummer',
  );
  return PendingPersonUpdate(
    entryId: entryId,
    personId: personId,
    mitgliedsnummer: mitgliedsnummer,
    displayName: basisMitglied.fullName,
    basisMitglied: basisMitglied,
    zielMitglied: basisMitglied.copyWith(vorname: 'Ziel $mitgliedsnummer'),
    queuedAt: DateTime(2026, 4, 14, 9, 0),
  );
}

Mitglied _mitglied({
  required int personId,
  required String mitgliedsnummer,
  String vorname = 'Julia',
  String nachname = 'Keller',
}) {
  return Mitglied.peopleListItem(
    mitgliedsnummer: mitgliedsnummer,
    personId: personId,
    vorname: vorname,
    nachname: nachname,
  );
}

class _FakeMemberWriteRepository implements MemberWriteRepository {
  _FakeMemberWriteRepository({
    this.fetchResultsByPersonId = const <int, Object>{},
    this.updateResultsByPersonId = const <int, Object>{},
  });

  final Map<int, Object> fetchResultsByPersonId;
  final Map<int, Object> updateResultsByPersonId;

  @override
  Future<Mitglied> fetchRemoteMember({
    required String accessToken,
    required int personId,
  }) async {
    final configured = fetchResultsByPersonId[personId];
    if (configured is Mitglied) {
      return configured;
    }
    if (configured != null) {
      throw configured;
    }
    return _mitglied(personId: personId, mitgliedsnummer: personId.toString());
  }

  @override
  Future<Mitglied> updateMember({
    required String accessToken,
    required Mitglied basisMitglied,
    required Mitglied zielMitglied,
  }) async {
    final personId = zielMitglied.personId ?? basisMitglied.personId ?? 0;
    final configured = updateResultsByPersonId[personId];
    if (configured is Mitglied) {
      return configured;
    }
    if (configured != null) {
      throw configured;
    }
    return zielMitglied;
  }
}

class _InMemoryPendingPersonUpdateRepository
    implements PendingPersonUpdateRepository {
  _InMemoryPendingPersonUpdateRepository({
    List<PendingPersonUpdate> entries = const <PendingPersonUpdate>[],
  }) : _entries = List<PendingPersonUpdate>.from(entries);

  final List<PendingPersonUpdate> _entries;

  @override
  Future<void> clear() async {
    _entries.clear();
  }

  @override
  Future<List<PendingPersonUpdate>> loadAll() async {
    return List<PendingPersonUpdate>.unmodifiable(_entries);
  }

  @override
  Future<void> remove(String entryId) async {
    _entries.removeWhere((entry) => entry.entryId == entryId);
  }

  @override
  Future<void> save(PendingPersonUpdate entry) async {
    final index = _entries.indexWhere(
      (existing) => existing.entryId == entry.entryId,
    );
    if (index >= 0) {
      _entries[index] = entry;
      return;
    }
    _entries.add(entry);
  }
}

class _FakeLoggerService extends LoggerService {
  _FakeLoggerService()
    : super(
        settingsRepository: _FakeAppSettingsRepository(),
        navigatorKey: GlobalKey<NavigatorState>(),
      );

  final List<String> messages = <String>[];
  final List<_TrackedEvent> events = <_TrackedEvent>[];

  @override
  Future<void> log(String service, String message) async {
    messages.add('$service|$message');
  }

  @override
  Future<void> logInfo(String service, String message) async {
    messages.add('$service|$message');
  }

  @override
  Future<void> logWarn(String service, String message) async {
    messages.add('$service|$message');
  }

  @override
  Future<void> logError(
    String service,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) async {
    messages.add('$service|$message');
  }

  @override
  Future<void> trackEvent(String name, Map<String, Object?> properties) async {
    events.add(
      _TrackedEvent(
        name: name,
        properties: Map<String, Object?>.from(properties),
      ),
    );
  }
}

class _TrackedEvent {
  const _TrackedEvent({required this.name, required this.properties});

  final String name;
  final Map<String, Object?> properties;

  @override
  bool operator ==(Object other) {
    return other is _TrackedEvent &&
        other.name == name &&
        _mapEquals(other.properties, properties);
  }

  @override
  int get hashCode => Object.hash(name, Object.hashAll(properties.entries));

  static bool _mapEquals(
    Map<String, Object?> left,
    Map<String, Object?> right,
  ) {
    if (identical(left, right)) {
      return true;
    }
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key) || right[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }
}

class _FakeAppSettingsRepository implements AppSettingsRepository {
  @override
  Future<AppSettings> load() async => const AppSettings(
    themeMode: ThemeMode.system,
    languageCode: 'de',
    analyticsEnabled: false,
  );

  @override
  Future<void> saveAnalyticsEnabled(bool enabled) async {}

  @override
  Future<void> saveBiometricLockEnabled(bool enabled) async {}

  @override
  Future<void> saveMemberListSearchResultHighlightEnabled(bool enabled) async {}

  @override
  Future<void> saveGeburstagsbenachrichtigungStufen(Set<Stufe> stufen) async {}

  @override
  Future<void> saveLanguageCode(String code) async {}

  @override
  Future<void> saveNotificationsEnabled(bool enabled) async {}

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {}
}
