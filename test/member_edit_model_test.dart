import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/member/member_resolution.dart';
import 'package:nami/domain/member/member_write_repository.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/member/pending_person_update.dart';
import 'package:nami/domain/member/pending_person_update_repository.dart';
import 'package:nami/domain/settings/app_settings.dart';
import 'package:nami/domain/settings/app_settings_repository.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/l10n/app_localizations.dart';
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

  test('setzt lokalen Draft beim erneuten Editieren fort', () async {
    final logger = _FakeLoggerService();
    final basisMitglied = Mitglied.peopleListItem(
      mitgliedsnummer: '4711',
      personId: 23,
      vorname: 'Julia',
      nachname: 'Keller',
    );
    final pendingRepository = _InMemoryPendingPersonUpdateRepository(
      entries: <PendingPersonUpdate>[
        PendingPersonUpdate(
          entryId: 'person-23',
          personId: 23,
          mitgliedsnummer: '4711',
          displayName: 'Julia Keller',
          basisMitglied: basisMitglied,
          zielMitglied: basisMitglied.copyWith(vorname: 'Juliane'),
          queuedAt: DateTime(2026, 4, 14, 10, 0),
        ),
      ],
    );
    final model = MemberEditModel(
      memberWriteRepository: _FakeMemberWriteRepository(
        fetchResultsByPersonId: <int, Object>{
          23: basisMitglied.copyWith(vorname: 'Remote'),
        },
      ),
      pendingRepository: pendingRepository,
      logger: logger,
      onMemberUpdated: (_) async {},
    );
    await model.loadPending();

    final result = await model.prepareForEdit(
      accessToken: 'token-123',
      mitglied: basisMitglied,
    );

    expect(result.success, isTrue);
    expect(result.member?.vorname, 'Juliane');
    expect(
      result.resolveMessage(AppLocalizations(const Locale('de'))),
      contains('Lokaler Bearbeitungsstand'),
    );
  });

  test(
    'faellt beim Vorbereiten offline auf den lokalen Stand zurueck',
    () async {
      final logger = _FakeLoggerService();
      final basisMitglied = Mitglied.peopleListItem(
        mitgliedsnummer: '4711',
        personId: 23,
        vorname: 'Julia',
        nachname: 'Keller',
      );
      final model = MemberEditModel(
        memberWriteRepository: _FakeMemberWriteRepository(
          fetchResultsByPersonId: <int, Object>{
            23: const MemberWriteNetworkBlockedException('Nur ueber WLAN.'),
          },
        ),
        pendingRepository: _InMemoryPendingPersonUpdateRepository(),
        logger: logger,
        onMemberUpdated: (_) async {},
      );

      final result = await model.prepareForEdit(
        accessToken: 'token-123',
        mitglied: basisMitglied,
      );

      expect(result.success, isTrue);
      expect(result.member, basisMitglied);
      expect(
        result.resolveMessage(AppLocalizations(const Locale('de'))),
        contains('lokal gespeicherten Daten'),
      );
    },
  );

  test(
    'faellt beim Vorbereiten mit auth_required auf den lokalen Stand zurueck',
    () async {
      final logger = _FakeLoggerService();
      final basisMitglied = Mitglied.peopleListItem(
        mitgliedsnummer: '4711',
        personId: 23,
        vorname: 'Julia',
        nachname: 'Keller',
      );
      final model = MemberEditModel(
        memberWriteRepository: _FakeMemberWriteRepository(
          fetchResultsByPersonId: <int, Object>{
            23: const MemberWriteAuthRequiredException(
              'Bitte erneut anmelden.',
            ),
          },
        ),
        pendingRepository: _InMemoryPendingPersonUpdateRepository(),
        logger: logger,
        onMemberUpdated: (_) async {},
      );

      final result = await model.prepareForEdit(
        accessToken: 'token-123',
        mitglied: basisMitglied,
      );

      expect(result.success, isTrue);
      expect(result.member, basisMitglied);
      final resolvedMessage = result.resolveMessage(
        AppLocalizations(const Locale('de')),
      );
      expect(resolvedMessage, contains('lokal gespeicherten Daten'));
      expect(resolvedMessage, contains('erneute Anmeldung erforderlich'));
      expect(
        logger.events,
        contains(
          _TrackedEvent(
            name: 'member_edit',
            properties: const <String, Object?>{
              'action': 'prepare_result',
              'trigger': 'detail_edit',
              'outcome': 'auth_required_local_fallback',
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
    expect(result.notice, MemberEditSubmitNotice.warning);
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

  test('ersetzt vorhandenen Draft derselben Person', () async {
    final pendingRepository = _InMemoryPendingPersonUpdateRepository(
      entries: <PendingPersonUpdate>[
        _pendingEntry(
          entryId: 'person-23',
          personId: 23,
          mitgliedsnummer: '4711',
        ),
      ],
    );
    final model = MemberEditModel(
      memberWriteRepository: _FakeMemberWriteRepository(
        updateResultsByPersonId: <int, Object>{
          23: const MemberWriteNetworkBlockedException('Nur ueber WLAN.'),
        },
      ),
      pendingRepository: pendingRepository,
      logger: _FakeLoggerService(),
      onMemberUpdated: (_) async {},
      nowProvider: () => DateTime(2026, 4, 14, 11, 30),
    );
    await model.loadPending();
    final basisMitglied = Mitglied.peopleListItem(
      mitgliedsnummer: '4711',
      personId: 23,
      vorname: 'Julia',
      nachname: 'Keller',
    );

    final result = await model.submitUpdate(
      accessToken: 'token-123',
      basisMitglied: basisMitglied,
      zielMitglied: basisMitglied.copyWith(vorname: 'Neu'),
    );

    expect(result.wasQueued, isTrue);
    expect(model.pendingUpdates, hasLength(1));
    expect(model.pendingUpdates.single.entryId, 'person-23');
    expect(model.pendingUpdates.single.zielMitglied.vorname, 'Neu');
  });

  test(
    'queuet das Update bei Auth-Fall lokal und markiert es als Warning',
    () async {
      final pendingRepository = _InMemoryPendingPersonUpdateRepository();
      final logger = _FakeLoggerService();
      final basisMitglied = Mitglied.peopleListItem(
        mitgliedsnummer: '4711',
        personId: 23,
        vorname: 'Julia',
        nachname: 'Keller',
      );
      final resolutionCase = MemberResolutionCase(
        remoteMitglied: basisMitglied.copyWith(vorname: 'Remote Julia'),
        source: MemberResolutionSource.manualSave,
        items: const <MemberResolutionItem>[
          MemberResolutionItem(
            problemType: MemberResolutionProblemType.conflict,
            cause: MemberResolutionCause.overlappingChange,
            target: MemberResolutionTarget(
              type: MemberResolutionTargetType.firstName,
            ),
            message: 'Vorname kollidiert.',
          ),
        ],
      );
      final model = MemberEditModel(
        memberWriteRepository: _FakeMemberWriteRepository(
          updateResultsByPersonId: <int, Object>{
            23: const MemberWriteAuthRequiredException(
              'Bitte erneut anmelden.',
            ),
          },
        ),
        pendingRepository: pendingRepository,
        logger: logger,
        onMemberUpdated: (_) async {},
        nowProvider: () => DateTime(2026, 4, 14, 10, 45),
      );

      final result = await model.submitUpdate(
        accessToken: 'token-123',
        basisMitglied: basisMitglied,
        zielMitglied: basisMitglied.copyWith(vorname: 'Juliane'),
        existingResolutionCase: resolutionCase,
      );

      expect(result.success, isFalse);
      expect(result.wasQueued, isTrue);
      expect(result.notice, MemberEditSubmitNotice.warning);
      final resolvedMessage = result.resolveMessage(
        AppLocalizations(const Locale('de')),
      );
      expect(resolvedMessage, contains('lokal gespeichert'));
      expect(resolvedMessage, contains('erneute Anmeldung erforderlich'));
      expect(result.pendingEntry, isNotNull);
      expect(model.pendingUpdates, hasLength(1));
      expect(model.pendingUpdates.single.personId, 23);
      expect(
        logger.events,
        contains(
          _TrackedEvent(
            name: 'member_edit',
            properties: const <String, Object?>{
              'action': 'submit_result',
              'trigger': 'manual_edit',
              'outcome': 'queued_auth_required',
              'source': 'member_edit',
            },
          ),
        ),
      );
      expect(
        logger.events.any(
          (event) =>
              event.name == 'member_resolution_resend_result' &&
              event.properties['outcome'] == 'queued_auth_required',
        ),
        isTrue,
      );
    },
  );

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

  test(
    'reicht feldbezogene Validierungsfehler im Submit-Result durch',
    () async {
      final pendingRepository = _InMemoryPendingPersonUpdateRepository();
      final model = MemberEditModel(
        memberWriteRepository: _FakeMemberWriteRepository(
          updateResultsByPersonId: <int, Object>{
            23: const MemberWriteValidationException(
              'Nummer ist nicht gültig',
              errors: <MemberWriteFieldValidationError>[
                MemberWriteFieldValidationError(
                  message: 'Nummer ist nicht gültig',
                  relationshipName: 'phone_numbers',
                  relationshipAttribute: 'number',
                  relationshipId: 1,
                  code: 'invalid',
                ),
              ],
            ),
          },
        ),
        pendingRepository: pendingRepository,
        logger: _FakeLoggerService(),
        onMemberUpdated: (_) async {},
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
      expect(result.notice, MemberEditSubmitNotice.error);
      expect(result.message, 'Nummer ist nicht gültig');
      expect(result.validationErrors, const <MemberWriteFieldValidationError>[
        MemberWriteFieldValidationError(
          message: 'Nummer ist nicht gültig',
          relationshipName: 'phone_numbers',
          relationshipAttribute: 'number',
          relationshipId: 1,
          code: 'invalid',
        ),
      ]);
      expect(model.pendingUpdates, isEmpty);
    },
  );

  test('trackt die Erzeugung eines Merge-Konflikt-Falls getrennt', () async {
    final logger = _FakeLoggerService();
    final basisMitglied = Mitglied.peopleListItem(
      mitgliedsnummer: '4711',
      personId: 23,
      vorname: 'Julia',
      nachname: 'Keller',
    );
    final resolutionCase = MemberResolutionCase(
      remoteMitglied: basisMitglied.copyWith(vorname: 'Remote Julia'),
      source: MemberResolutionSource.manualSave,
      items: const <MemberResolutionItem>[
        MemberResolutionItem(
          problemType: MemberResolutionProblemType.conflict,
          cause: MemberResolutionCause.overlappingChange,
          target: MemberResolutionTarget(
            type: MemberResolutionTargetType.firstName,
          ),
          message: 'Vorname kollidiert.',
        ),
      ],
    );
    final model = MemberEditModel(
      memberWriteRepository: _FakeMemberWriteRepository(
        updateResultsByPersonId: <int, Object>{
          23: MemberWriteNeedsResolutionException(
            'Konflikt',
            resolutionCase: resolutionCase,
          ),
        },
      ),
      pendingRepository: _InMemoryPendingPersonUpdateRepository(),
      logger: logger,
      onMemberUpdated: (_) async {},
    );

    await model.submitUpdate(
      accessToken: 'token-123',
      basisMitglied: basisMitglied,
      zielMitglied: basisMitglied.copyWith(vorname: 'Lokale Julia'),
    );

    expect(
      logger.events.any(
        (event) =>
            event.name == 'member_resolution_created' &&
            event.properties['resolution_category'] == 'merge_conflict' &&
            event.properties['resolution_causes'] == 'overlapping_change' &&
            event.properties['conflict_count'] == 1 &&
            event.properties['non_merge_count'] == 0,
      ),
      isTrue,
    );
  });

  test('trackt Retry-Validierung als non-merge-Problemfall', () async {
    final logger = _FakeLoggerService();
    final pendingRepository = _InMemoryPendingPersonUpdateRepository(
      entries: <PendingPersonUpdate>[
        _pendingEntry(
          entryId: 'validation-1',
          personId: 1,
          mitgliedsnummer: '1',
        ),
      ],
    );
    final model = MemberEditModel(
      memberWriteRepository: _FakeMemberWriteRepository(
        updateResultsByPersonId: <int, Object>{
          1: const MemberWriteValidationException(
            'Nummer ist nicht gueltig',
            errors: <MemberWriteFieldValidationError>[
              MemberWriteFieldValidationError(
                message: 'Nummer ist nicht gueltig',
                relationshipName: 'phone_numbers',
                relationshipAttribute: 'number',
                relationshipId: 5,
                code: 'invalid',
              ),
            ],
          ),
        },
      ),
      pendingRepository: pendingRepository,
      logger: logger,
      onMemberUpdated: (_) async {},
    );
    await model.loadPending();

    await model.retryPending(accessToken: 'token-123');

    expect(
      logger.events.any(
        (event) =>
            event.name == 'member_resolution_created' &&
            event.properties['resolution_category'] == 'non_merge_problem' &&
            event.properties['resolution_causes'] == 'server_validation' &&
            event.properties['validation_count'] == 1 &&
            event.properties['non_merge_count'] == 1,
      ),
      isTrue,
    );
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

  test('trackt Resend-Start und Resend-Erfolg fuer Problemloesungen', () async {
    final logger = _FakeLoggerService();
    final basisMitglied = Mitglied.peopleListItem(
      mitgliedsnummer: '4711',
      personId: 23,
      vorname: 'Julia',
      nachname: 'Keller',
    );
    final resolutionCase = MemberResolutionCase(
      remoteMitglied: basisMitglied.copyWith(vorname: 'Remote Julia'),
      source: MemberResolutionSource.manualSave,
      items: const <MemberResolutionItem>[
        MemberResolutionItem(
          problemType: MemberResolutionProblemType.conflict,
          cause: MemberResolutionCause.overlappingChange,
          target: MemberResolutionTarget(
            type: MemberResolutionTargetType.firstName,
          ),
          message: 'Vorname kollidiert.',
        ),
      ],
    );
    final model = MemberEditModel(
      memberWriteRepository: _FakeMemberWriteRepository(
        updateResultsByPersonId: <int, Object>{
          23: basisMitglied.copyWith(vorname: 'Lokale Julia'),
        },
      ),
      pendingRepository: _InMemoryPendingPersonUpdateRepository(),
      logger: logger,
      onMemberUpdated: (_) async {},
    );

    await model.submitUpdate(
      accessToken: 'token-123',
      basisMitglied: basisMitglied.copyWith(vorname: 'Remote Julia'),
      zielMitglied: basisMitglied.copyWith(vorname: 'Lokale Julia'),
      trigger: 'manual_resolution',
      existingResolutionCase: resolutionCase,
    );

    expect(
      logger.events.any(
        (event) =>
            event.name == 'member_resolution_resend_started' &&
            event.properties['trigger'] == 'manual_resolution',
      ),
      isTrue,
    );
    expect(
      logger.events.any(
        (event) =>
            event.name == 'member_resolution_resend_result' &&
            event.properties['outcome'] == 'success' &&
            event.properties['remaining_item_count'] == 0,
      ),
      isTrue,
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
      logger.events.any(
        (event) =>
            event.name == 'member_edit' &&
            event.properties['action'] == 'retry_result' &&
            event.properties['trigger'] == 'manual_debug' &&
            event.properties['outcome'] == 'succeeded' &&
            event.properties['success_count'] == 1 &&
            event.properties['retained_count'] == 0 &&
            event.properties['discarded_count'] == 0 &&
            event.properties['needs_resolution_count'] == 0,
      ),
      isTrue,
    );
  });

  group('erneutes Bearbeiten eines wartenden Entwurfs', () {
    final serverStand = _mitglied(
      personId: 23,
      mitgliedsnummer: '4711',
    ).copyWith(updatedAt: DateTime(2026, 4, 14, 8, 0));
    final ersterEntwurf = serverStand.copyWith(vorname: 'Juliane');
    final zweiterEntwurf = ersterEntwurf.copyWith(nachname: 'Kellermann');

    PendingPersonUpdate wartenderEintrag({
      PendingPersonUpdateStatus status = PendingPersonUpdateStatus.queued,
      MemberResolutionCase? resolutionCase,
    }) {
      return PendingPersonUpdate(
        entryId: 'person-23',
        personId: 23,
        mitgliedsnummer: '4711',
        displayName: 'Juliane Keller',
        basisMitglied: serverStand,
        zielMitglied: ersterEntwurf,
        queuedAt: DateTime(2026, 4, 14, 9, 0),
        status: status,
        resolutionCase: resolutionCase,
      );
    }

    test(
      'behaelt offline die urspruengliche Serverbasis und beide Aenderungen',
      () async {
        final pendingRepository = _InMemoryPendingPersonUpdateRepository(
          entries: <PendingPersonUpdate>[wartenderEintrag()],
        );
        final model = MemberEditModel(
          memberWriteRepository: _FakeMemberWriteRepository(
            updateResultsByPersonId: <int, Object>{
              23: const MemberWriteNetworkBlockedException('Nur ueber WLAN.'),
            },
          ),
          pendingRepository: pendingRepository,
          logger: _FakeLoggerService(),
          onMemberUpdated: (_) async {},
        );
        await model.loadPending();

        // Die Bearbeiten-Seite uebergibt den ersten Entwurf als Basis.
        final result = await model.submitUpdate(
          accessToken: 'token-123',
          basisMitglied: ersterEntwurf,
          zielMitglied: zweiterEntwurf,
        );
        final stored = (await pendingRepository.loadAll()).single;

        expect(result.wasQueued, isTrue);
        expect(stored.basisMitglied.vorname, 'Julia');
        expect(stored.zielMitglied.vorname, 'Juliane');
        expect(stored.zielMitglied.nachname, 'Kellermann');
      },
    );

    test(
      'merged beim spaeteren Retry beide Offline-Aenderungen gegen den Server',
      () async {
        final pendingRepository = _InMemoryPendingPersonUpdateRepository(
          entries: <PendingPersonUpdate>[wartenderEintrag()],
        );
        var serverErreichbar = false;
        final writeRepository = _FakeMemberWriteRepository(
          onUpdate: (basis, ziel) async {
            if (!serverErreichbar) {
              throw const MemberWriteNetworkBlockedException('Offline.');
            }
            return MemberConflictResolver.resolve(
              basisMitglied: basis,
              zielMitglied: ziel,
              remoteMitglied: serverStand,
            ).mergedMitglied;
          },
        );
        final updatedMembers = <Mitglied>[];
        final model = MemberEditModel(
          memberWriteRepository: writeRepository,
          pendingRepository: pendingRepository,
          logger: _FakeLoggerService(),
          onMemberUpdated: (member) async => updatedMembers.add(member),
        );
        await model.loadPending();

        await model.submitUpdate(
          accessToken: 'token-123',
          basisMitglied: ersterEntwurf,
          zielMitglied: zweiterEntwurf,
        );
        serverErreichbar = true;
        final summary = await model.retryPending(accessToken: 'token-123');

        expect(summary.successCount, 1);
        expect(updatedMembers.single.vorname, 'Juliane');
        expect(updatedMembers.single.nachname, 'Kellermann');
        expect(await pendingRepository.loadAll(), isEmpty);
      },
    );

    test('sendet online die urspruengliche Serverbasis', () async {
      final writeRepository = _FakeMemberWriteRepository();
      final model = MemberEditModel(
        memberWriteRepository: writeRepository,
        pendingRepository: _InMemoryPendingPersonUpdateRepository(
          entries: <PendingPersonUpdate>[wartenderEintrag()],
        ),
        logger: _FakeLoggerService(),
        onMemberUpdated: (_) async {},
      );
      await model.loadPending();

      final result = await model.submitUpdate(
        accessToken: 'token-123',
        basisMitglied: ersterEntwurf,
        zielMitglied: zweiterEntwurf,
      );

      expect(result.success, isTrue);
      expect(writeRepository.updateCalls.single.basisMitglied, serverStand);
      expect(model.pendingUpdates, isEmpty);
    });

    test(
      'nutzt beim Aufloesen eines Validierungsfalls die urspruengliche Basis',
      () async {
        final validationCase = MemberResolutionCase(
          remoteMitglied: ersterEntwurf,
          source: MemberResolutionSource.pendingRetry,
          items: const <MemberResolutionItem>[
            MemberResolutionItem(
              problemType: MemberResolutionProblemType.validation,
              target: MemberResolutionTarget(
                type: MemberResolutionTargetType.lastName,
              ),
              message: 'ist ungueltig',
            ),
          ],
        );
        final writeRepository = _FakeMemberWriteRepository();
        final model = MemberEditModel(
          memberWriteRepository: writeRepository,
          pendingRepository: _InMemoryPendingPersonUpdateRepository(
            entries: <PendingPersonUpdate>[
              wartenderEintrag(
                status: PendingPersonUpdateStatus.needsResolution,
                resolutionCase: validationCase,
              ),
            ],
          ),
          logger: _FakeLoggerService(),
          onMemberUpdated: (_) async {},
        );
        await model.loadPending();

        await model.submitUpdate(
          accessToken: 'token-123',
          basisMitglied: validationCase.remoteMitglied,
          zielMitglied: zweiterEntwurf,
          trigger: 'manual_resolution',
          existingResolutionCase: validationCase,
        );

        expect(writeRepository.updateCalls.single.basisMitglied, serverStand);
      },
    );

    test(
      'nutzt beim Aufloesen eines Merge-Konflikts den Serverstand als Basis',
      () async {
        final remoteStand = serverStand.copyWith(
          vorname: 'Jule',
          updatedAt: DateTime(2026, 4, 14, 10, 0),
        );
        final conflictCase = MemberResolutionCase(
          remoteMitglied: remoteStand,
          source: MemberResolutionSource.pendingRetry,
          items: const <MemberResolutionItem>[
            MemberResolutionItem(
              problemType: MemberResolutionProblemType.conflict,
              target: MemberResolutionTarget(
                type: MemberResolutionTargetType.firstName,
              ),
              message: 'Vorname wurde parallel geaendert.',
            ),
          ],
        );
        final writeRepository = _FakeMemberWriteRepository();
        final model = MemberEditModel(
          memberWriteRepository: writeRepository,
          pendingRepository: _InMemoryPendingPersonUpdateRepository(
            entries: <PendingPersonUpdate>[
              wartenderEintrag(
                status: PendingPersonUpdateStatus.needsResolution,
                resolutionCase: conflictCase,
              ),
            ],
          ),
          logger: _FakeLoggerService(),
          onMemberUpdated: (_) async {},
        );
        await model.loadPending();

        await model.submitUpdate(
          accessToken: 'token-123',
          basisMitglied: remoteStand,
          zielMitglied: zweiterEntwurf,
          trigger: 'manual_resolution',
          existingResolutionCase: conflictCase,
        );

        expect(writeRepository.updateCalls.single.basisMitglied, remoteStand);
      },
    );
  });

  group('parallele Retries', () {
    test('startet waehrend eines laufenden Retries keinen zweiten', () async {
      final blocker = Completer<Mitglied>();
      final writeRepository = _FakeMemberWriteRepository(
        onUpdate: (_, _) => blocker.future,
      );
      final pendingRepository = _InMemoryPendingPersonUpdateRepository(
        entries: <PendingPersonUpdate>[
          _pendingEntry(entryId: 'person-1', personId: 1, mitgliedsnummer: '1'),
        ],
      );
      final model = MemberEditModel(
        memberWriteRepository: writeRepository,
        pendingRepository: pendingRepository,
        logger: _FakeLoggerService(),
        onMemberUpdated: (_) async {},
      );
      await model.loadPending();

      final first = model.retryPending(accessToken: 'token-123');
      await _untilUpdateCalled(writeRepository);
      final second = await model.retryPending(accessToken: 'token-123');
      blocker.completeError(Exception('Timeout'));
      final firstSummary = await first;

      expect(second.results, isEmpty);
      expect(firstSummary.retainedCount, 1);
      expect(writeRepository.updateCalls, hasLength(1));
      expect((await pendingRepository.loadAll()).single.attemptCount, 1);
    });

    test(
      'ueberschreibt keinen Entwurf, der waehrend eines Retries gespeichert wird',
      () async {
        final blocker = Completer<Mitglied>();
        late final _FakeMemberWriteRepository writeRepository;
        writeRepository = _FakeMemberWriteRepository(
          onUpdate: (_, _) {
            if (writeRepository.updateCalls.length == 1) {
              return blocker.future;
            }
            throw const MemberWriteNetworkBlockedException('Offline.');
          },
        );
        final alterEintrag = _pendingEntry(
          entryId: 'person-1',
          personId: 1,
          mitgliedsnummer: '1',
        );
        final pendingRepository = _InMemoryPendingPersonUpdateRepository(
          entries: <PendingPersonUpdate>[alterEintrag],
        );
        final model = MemberEditModel(
          memberWriteRepository: writeRepository,
          pendingRepository: pendingRepository,
          logger: _FakeLoggerService(),
          onMemberUpdated: (_) async {},
        );
        await model.loadPending();

        final retry = model.retryPending(accessToken: 'token-123');
        await _untilUpdateCalled(writeRepository);
        final submit = model.submitUpdate(
          accessToken: 'token-123',
          basisMitglied: alterEintrag.zielMitglied,
          zielMitglied: alterEintrag.zielMitglied.copyWith(nachname: 'Neu'),
        );
        await pumpEventQueue();
        blocker.complete(alterEintrag.zielMitglied);
        await retry;
        final submitResult = await submit;
        final remaining = await pendingRepository.loadAll();

        expect(submitResult.wasQueued, isTrue);
        expect(remaining, hasLength(1));
        expect(remaining.single.zielMitglied.nachname, 'Neu');
      },
    );
  });

  group('submitUpdate Ergebnisse', () {
    Future<MemberEditSubmitResult> submitWith(
      Object updateResult, {
      _InMemoryPendingPersonUpdateRepository? pendingRepository,
    }) async {
      final model = MemberEditModel(
        memberWriteRepository: _FakeMemberWriteRepository(
          updateResultsByPersonId: <int, Object>{23: updateResult},
        ),
        pendingRepository:
            pendingRepository ?? _InMemoryPendingPersonUpdateRepository(),
        logger: _FakeLoggerService(),
        onMemberUpdated: (_) async {},
      );
      await model.loadPending();
      final basis = _mitglied(personId: 23, mitgliedsnummer: '4711');
      return model.submitUpdate(
        accessToken: 'token-123',
        basisMitglied: basis,
        zielMitglied: basis.copyWith(vorname: 'Juliane'),
      );
    }

    test('speichert einen Merge-Konflikt als offenen Problemfall', () async {
      final pendingRepository = _InMemoryPendingPersonUpdateRepository();
      final remote = _mitglied(
        personId: 23,
        mitgliedsnummer: '4711',
        vorname: 'Jule',
      );

      final result = await submitWith(
        MemberWriteNeedsResolutionException(
          'Konflikt',
          resolutionCase: MemberResolutionCase(
            remoteMitglied: remote,
            source: MemberResolutionSource.pendingRetry,
            items: const <MemberResolutionItem>[
              MemberResolutionItem(
                problemType: MemberResolutionProblemType.conflict,
                target: MemberResolutionTarget(
                  type: MemberResolutionTargetType.firstName,
                ),
                message: 'Vorname',
              ),
            ],
          ),
        ),
        pendingRepository: pendingRepository,
      );
      final stored = (await pendingRepository.loadAll()).single;

      expect(result.success, isFalse);
      expect(result.requiresResolution, isTrue);
      expect(result.pendingEntry?.entryId, stored.entryId);
      expect(result.notice, MemberEditSubmitNotice.warning);
      expect(stored.status, PendingPersonUpdateStatus.needsResolution);
      expect(stored.resolutionCase?.remoteMitglied, remote);
      expect(stored.resolutionCase?.source, MemberResolutionSource.manualSave);
      expect(stored.zielMitglied.vorname, 'Juliane');
    });

    test('verwirft Aenderungen ohne updatedAt ohne Queue', () async {
      final pendingRepository = _InMemoryPendingPersonUpdateRepository();

      final result = await submitWith(
        const MemberWriteUpdatedAtMissingException('updatedAt fehlt'),
        pendingRepository: pendingRepository,
      );

      expect(result.success, isFalse);
      expect(result.wasQueued, isFalse);
      expect(result.notice, MemberEditSubmitNotice.error);
      expect(await pendingRepository.loadAll(), isEmpty);
    });

    test('verwirft Aenderungen bei 409-Konflikt ohne Queue', () async {
      final pendingRepository = _InMemoryPendingPersonUpdateRepository();

      final result = await submitWith(
        const MemberWriteConflictException('Konflikt'),
        pendingRepository: pendingRepository,
      );

      expect(result.wasQueued, isFalse);
      expect(await pendingRepository.loadAll(), isEmpty);
    });

    test('unterdrueckt den Hinweis bei gesperrtem Netzwerk', () async {
      final result = await submitWith(
        const MemberWriteNetworkBlockedException('Nur ueber WLAN.'),
      );

      expect(result.wasQueued, isTrue);
      expect(result.suppressNotice, isTrue);
      expect(result.notice, MemberEditSubmitNotice.warning);
      expect(
        result.resolveMessage(AppLocalizations(const Locale('de'))),
        isNotEmpty,
      );
    });

    test(
      'merkt die Aenderung bei nicht erreichbarem Hitobito mit Hinweis vor',
      () async {
        final pendingRepository = _InMemoryPendingPersonUpdateRepository();

        final result = await submitWith(
          const MemberWriteNetworkUnavailableException('nicht erreichbar'),
          pendingRepository: pendingRepository,
        );

        expect(result.wasQueued, isTrue);
        expect(result.suppressNotice, isFalse);
        expect(result.notice, MemberEditSubmitNotice.warning);
        expect(await pendingRepository.loadAll(), hasLength(1));
      },
    );

    test('lehnt eine ungueltige personId ohne Serveraufruf ab', () async {
      final writeRepository = _FakeMemberWriteRepository();
      final model = MemberEditModel(
        memberWriteRepository: writeRepository,
        pendingRepository: _InMemoryPendingPersonUpdateRepository(),
        logger: _FakeLoggerService(),
        onMemberUpdated: (_) async {},
      );
      final ohnePersonId = Mitglied.peopleListItem(
        mitgliedsnummer: '4711',
        vorname: 'Julia',
        nachname: 'Keller',
      );

      final result = await model.submitUpdate(
        accessToken: 'token-123',
        basisMitglied: ohnePersonId,
        zielMitglied: ohnePersonId.copyWith(vorname: 'Juliane'),
      );

      expect(result.success, isFalse);
      expect(result.wasQueued, isFalse);
      expect(writeRepository.updateCalls, isEmpty);
    });
  });

  group('retryPending Ergebnisse', () {
    Future<
      ({
        PendingPersonUpdateRetrySummary summary,
        List<PendingPersonUpdate> remaining,
        _FakeLoggerService logger,
      })
    >
    retryWith(
      Map<int, Object> updateResults, {
      List<PendingPersonUpdate>? entries,
      Iterable<String>? entryIds,
      Future<void> Function(Mitglied member)? onMemberUpdated,
    }) async {
      final logger = _FakeLoggerService();
      final pendingRepository = _InMemoryPendingPersonUpdateRepository(
        entries:
            entries ??
            updateResults.keys
                .map(
                  (personId) => _pendingEntry(
                    entryId: 'person-$personId',
                    personId: personId,
                    mitgliedsnummer: '$personId',
                  ),
                )
                .toList(),
      );
      final model = MemberEditModel(
        memberWriteRepository: _FakeMemberWriteRepository(
          updateResultsByPersonId: updateResults,
        ),
        pendingRepository: pendingRepository,
        logger: logger,
        onMemberUpdated: onMemberUpdated ?? (_) async {},
        nowProvider: () => DateTime(2026, 4, 14, 11, 0),
      );
      await model.loadPending();
      final summary = await model.retryPending(
        accessToken: 'token-123',
        entryIds: entryIds,
      );
      return (
        summary: summary,
        remaining: await pendingRepository.loadAll(),
        logger: logger,
      );
    }

    test('behaelt Eintraege bei fehlender Anmeldung', () async {
      final result = await retryWith(<int, Object>{
        1: const MemberWriteAuthRequiredException('Login noetig'),
      });

      expect(result.summary.retainedCount, 1);
      expect(result.remaining.single.attemptCount, 1);
    });

    test('behaelt Eintraege bei gesperrtem Netzwerk', () async {
      final result = await retryWith(<int, Object>{
        1: const MemberWriteNetworkBlockedException('Nur ueber WLAN.'),
      });

      expect(result.summary.retainedCount, 1);
      expect(result.remaining, hasLength(1));
    });

    test('behaelt Eintraege bei nicht erreichbarem Hitobito', () async {
      final result = await retryWith(<int, Object>{
        1: const MemberWriteNetworkUnavailableException('nicht erreichbar'),
      });

      expect(result.summary.retainedCount, 1);
      expect(result.remaining, hasLength(1));
    });

    test('verwirft vom Server abgelehnte Eintraege', () async {
      final result = await retryWith(<int, Object>{
        1: const MemberWriteRejectedException('403'),
      });

      expect(result.summary.discardedCount, 1);
      expect(result.remaining, isEmpty);
    });

    test(
      'speichert Merge-Konflikte aus dem Retry als offenen Problemfall',
      () async {
        final remote = _mitglied(
          personId: 1,
          mitgliedsnummer: '1',
          vorname: 'Server',
        );
        final result = await retryWith(<int, Object>{
          1: MemberWriteNeedsResolutionException(
            'Konflikt',
            resolutionCase: MemberResolutionCase(
              remoteMitglied: remote,
              source: MemberResolutionSource.manualSave,
              items: const <MemberResolutionItem>[
                MemberResolutionItem(
                  problemType: MemberResolutionProblemType.conflict,
                  target: MemberResolutionTarget(
                    type: MemberResolutionTargetType.firstName,
                  ),
                  message: 'Vorname',
                ),
              ],
            ),
          ),
        });
        final stored = result.remaining.single;

        expect(result.summary.needsResolutionCount, 1);
        expect(stored.status, PendingPersonUpdateStatus.needsResolution);
        expect(stored.resolutionCase?.remoteMitglied, remote);
        expect(
          stored.resolutionCase?.source,
          MemberResolutionSource.pendingRetry,
        );
        expect(stored.attemptCount, 1);
      },
    );

    test(
      'speichert Validierungsfehler aus dem Retry als Problemfall',
      () async {
        final result = await retryWith(<int, Object>{
          1: const MemberWriteValidationException(
            'ungueltig',
            errors: <MemberWriteFieldValidationError>[
              MemberWriteFieldValidationError(
                message: 'E-Mail ungueltig',
                attribute: 'email',
              ),
            ],
          ),
        });
        final stored = result.remaining.single;

        expect(result.summary.needsResolutionCount, 1);
        expect(stored.status, PendingPersonUpdateStatus.needsResolution);
        expect(stored.resolutionCase?.remoteMitglied, stored.zielMitglied);
        expect(
          stored.resolutionCase?.items.single.target.type,
          MemberResolutionTargetType.primaryEmail,
        );
        expect(
          stored.resolutionCase?.items.single.problemType,
          MemberResolutionProblemType.validation,
        );
      },
    );

    test('ordnet Validierungsfehler den richtigen Feldern zu', () async {
      const cases = <(MemberWriteFieldValidationError, MemberResolutionTarget)>[
        (
          MemberWriteFieldValidationError(
            message: 'x',
            relationshipName: 'additional_emails',
            relationshipAttribute: 'email',
            relationshipId: 7,
          ),
          MemberResolutionTarget(
            type: MemberResolutionTargetType.additionalEmail,
            relationshipId: 7,
          ),
        ),
        (
          MemberWriteFieldValidationError(
            message: 'x',
            relationshipName: 'additional_addresses',
            relationshipAttribute: 'zip_code',
            relationshipId: 8,
          ),
          MemberResolutionTarget(
            type: MemberResolutionTargetType.additionalAddress,
            relationshipId: 8,
          ),
        ),
        (
          MemberWriteFieldValidationError(message: 'x', attribute: 'last_name'),
          MemberResolutionTarget(type: MemberResolutionTargetType.lastName),
        ),
        (
          MemberWriteFieldValidationError(message: 'x', attribute: 'nickname'),
          MemberResolutionTarget(type: MemberResolutionTargetType.nickname),
        ),
        (
          MemberWriteFieldValidationError(message: 'x', attribute: 'gender'),
          MemberResolutionTarget(type: MemberResolutionTargetType.gender),
        ),
        (
          MemberWriteFieldValidationError(message: 'x', attribute: 'birthday'),
          MemberResolutionTarget(type: MemberResolutionTargetType.birthday),
        ),
        (
          MemberWriteFieldValidationError(message: 'x', attribute: 'zip_code'),
          MemberResolutionTarget(
            type: MemberResolutionTargetType.primaryAddress,
          ),
        ),
        (
          MemberWriteFieldValidationError(
            message: 'x',
            attribute: 'address_care_of',
          ),
          MemberResolutionTarget(
            type: MemberResolutionTargetType.primaryAddress,
          ),
        ),
        (
          MemberWriteFieldValidationError(message: 'x', attribute: 'unbekannt'),
          MemberResolutionTarget(type: MemberResolutionTargetType.firstName),
        ),
      ];

      for (final (error, expectedTarget) in cases) {
        final result = await retryWith(<int, Object>{
          1: MemberWriteValidationException('ungueltig', errors: [error]),
        });

        expect(
          result.remaining.single.resolutionCase?.items.single.target,
          expectedTarget,
          reason: 'fuer ${error.relationshipName ?? error.attribute}',
        );
      }
    });

    test('sendet nur die angeforderten Eintraege erneut', () async {
      final result = await retryWith(
        <int, Object>{
          1: _mitglied(personId: 1, mitgliedsnummer: '1'),
          2: _mitglied(personId: 2, mitgliedsnummer: '2'),
        },
        entryIds: <String>['person-2'],
      );

      expect(result.summary.results.single.entry.entryId, 'person-2');
      expect(result.remaining.single.entryId, 'person-1');
      expect(result.remaining.single.attemptCount, 0);
    });

    test('ueberspringt offene Problemfaelle ohne Serveraufruf', () async {
      final result = await retryWith(
        <int, Object>{1: _mitglied(personId: 1, mitgliedsnummer: '1')},
        entries: <PendingPersonUpdate>[
          _pendingEntry(
            entryId: 'person-1',
            personId: 1,
            mitgliedsnummer: '1',
          ).copyWith(status: PendingPersonUpdateStatus.needsResolution),
        ],
      );

      expect(result.summary.results, isEmpty);
      expect(result.remaining.single.attemptCount, 0);
      expect(result.logger.events, isEmpty);
    });

    test('berechnet das Batch-Ergebnis fuer die Telemetrie', () async {
      final needsResolution = MemberWriteNeedsResolutionException(
        'Konflikt',
        resolutionCase: MemberResolutionCase(
          remoteMitglied: _mitglied(personId: 1, mitgliedsnummer: '1'),
          source: MemberResolutionSource.pendingRetry,
          items: const <MemberResolutionItem>[],
        ),
      );
      final cases = <String, Map<int, Object>>{
        'retained': <int, Object>{1: Exception('Timeout')},
        'discarded': <int, Object>{
          1: const MemberWriteRejectedException('403'),
        },
        'needs_resolution': <int, Object>{1: needsResolution},
        'mixed': <int, Object>{
          1: _mitglied(personId: 1, mitgliedsnummer: '1'),
          2: Exception('Timeout'),
        },
      };

      for (final MapEntry(key: expectedOutcome, value: updateResults)
          in cases.entries) {
        final result = await retryWith(updateResults);

        expect(
          result.logger.events.any(
            (event) =>
                event.properties['action'] == 'retry_result' &&
                event.properties['outcome'] == expectedOutcome,
          ),
          isTrue,
          reason: expectedOutcome,
        );
      }
    });

    test(
      'behaelt den Eintrag, wenn das lokale Aktualisieren nach erfolgreichem '
      'Schreiben fehlschlaegt (aktuelles Verhalten)',
      () async {
        final result = await retryWith(<int, Object>{
          1: _mitglied(personId: 1, mitgliedsnummer: '1'),
        }, onMemberUpdated: (_) async => throw StateError('Hive gesperrt'));

        // Die Aenderung ist bereits auf dem Server und wird beim naechsten
        // Retry trotzdem erneut gesendet.
        expect(result.summary.retainedCount, 1);
        expect(result.remaining, hasLength(1));
      },
    );
  });

  group('automatisches Senden mit Backoff', () {
    final jetzt = DateTime(2026, 4, 14, 12, 0);

    MemberEditModel modelFor(
      _InMemoryPendingPersonUpdateRepository repository,
      _FakeMemberWriteRepository writeRepository,
    ) {
      return MemberEditModel(
        memberWriteRepository: writeRepository,
        pendingRepository: repository,
        logger: _FakeLoggerService(),
        onMemberUpdated: (_) async {},
        nowProvider: () => jetzt,
      );
    }

    test('sendet automatisch nur faellige Eintraege', () async {
      final repository = _InMemoryPendingPersonUpdateRepository(
        entries: <PendingPersonUpdate>[
          _pendingEntry(entryId: 'person-1', personId: 1, mitgliedsnummer: '1'),
          _pendingEntry(
            entryId: 'person-2',
            personId: 2,
            mitgliedsnummer: '2',
          ).copyWith(
            attemptCount: 3,
            lastAttemptAt: jetzt.subtract(const Duration(minutes: 1)),
          ),
        ],
      );
      final writeRepository = _FakeMemberWriteRepository();
      final model = modelFor(repository, writeRepository);
      await model.loadPending();

      expect(model.hasDueAutomaticRetry, isTrue);
      final summary = await model.retryPending(
        accessToken: 'token-123',
        trigger: 'pending_retry_timer',
        automatic: true,
      );

      expect(summary.results.single.entry.entryId, 'person-1');
      expect(writeRepository.updateCalls, hasLength(1));
      expect(model.hasDueAutomaticRetry, isFalse);
    });

    test(
      'sendet manuell auch nicht faellige und pausierte Eintraege',
      () async {
        final repository = _InMemoryPendingPersonUpdateRepository(
          entries: <PendingPersonUpdate>[
            _pendingEntry(
              entryId: 'person-1',
              personId: 1,
              mitgliedsnummer: '1',
            ).copyWith(
              attemptCount: 10,
              lastAttemptAt: jetzt.add(const Duration(seconds: 1)),
            ),
          ],
        );
        final writeRepository = _FakeMemberWriteRepository();
        final model = modelFor(repository, writeRepository);
        await model.loadPending();

        expect(model.hasDueAutomaticRetry, isFalse);
        expect(model.isAutomaticRetryPaused('1'), isTrue);
        final summary = await model.retryPending(accessToken: 'token-123');

        expect(summary.successCount, 1);
        expect(writeRepository.updateCalls, hasLength(1));
      },
    );

    test(
      'sendet nach geleerter Box keine alten Eintraege aus dem Speicher',
      () async {
        final repository = _InMemoryPendingPersonUpdateRepository(
          entries: <PendingPersonUpdate>[
            _pendingEntry(
              entryId: 'person-1',
              personId: 1,
              mitgliedsnummer: '1',
            ),
          ],
        );
        final writeRepository = _FakeMemberWriteRepository();
        final model = modelFor(repository, writeRepository);
        await model.loadPending();

        // Logout oder Nutzerwechsel leeren die Box, ohne das Model zu
        // informieren.
        await repository.clear();
        final summary = await model.retryPending(accessToken: 'fremd');

        expect(summary.results, isEmpty);
        expect(writeRepository.updateCalls, isEmpty);
        expect(await repository.loadAll(), isEmpty);
        expect(model.pendingUpdates, isEmpty);
      },
    );
  });

  group('Abfragen zu offenen Problemfaellen', () {
    test('zaehlt und findet offene Problemfaelle', () async {
      final model = MemberEditModel(
        memberWriteRepository: _FakeMemberWriteRepository(),
        pendingRepository: _InMemoryPendingPersonUpdateRepository(
          entries: <PendingPersonUpdate>[
            _pendingEntry(
              entryId: 'person-1',
              personId: 1,
              mitgliedsnummer: '1',
            ),
            _pendingEntry(
              entryId: 'person-2',
              personId: 2,
              mitgliedsnummer: '2',
            ).copyWith(status: PendingPersonUpdateStatus.needsResolution),
          ],
        ),
        logger: _FakeLoggerService(),
        onMemberUpdated: (_) async {},
      );
      await model.loadPending();

      expect(model.openResolutionCount, 1);
      expect(model.firstResolutionEntry?.entryId, 'person-2');
      expect(model.hasPendingForMitglied('1'), isTrue);
      expect(model.hasResolutionForMitglied('1'), isFalse);
      expect(model.hasResolutionForMitglied('2'), isTrue);
      expect(model.pendingForMitglied('3'), isNull);
    });
  });

  group('prepareForEdit Fehlerpfade', () {
    Future<MemberEditPrepareResult> prepareWith(Object fetchResult) async {
      final model = MemberEditModel(
        memberWriteRepository: _FakeMemberWriteRepository(
          fetchResultsByPersonId: <int, Object>{23: fetchResult},
        ),
        pendingRepository: _InMemoryPendingPersonUpdateRepository(),
        logger: _FakeLoggerService(),
        onMemberUpdated: (_) async {},
      );
      return model.prepareForEdit(
        accessToken: 'token-123',
        mitglied: _mitglied(personId: 23, mitgliedsnummer: '4711'),
      );
    }

    test('meldet Fehler beim Laden ohne Rueckfall auf lokale Daten', () async {
      for (final error in <Object>[
        const MemberWriteRejectedException('403'),
        const MemberWriteConflictException('409'),
        const MemberWriteUpdatedAtMissingException('updatedAt fehlt'),
        const MemberWriteException('500'),
        Exception('Timeout'),
      ]) {
        final result = await prepareWith(error);

        expect(result.success, isFalse, reason: '$error');
        expect(result.member, isNull, reason: '$error');
        expect(
          result.resolveMessage(AppLocalizations(const Locale('de'))),
          isNotEmpty,
          reason: '$error',
        );
      }
    });

    test(
      'faellt bei nicht erreichbarem Hitobito auf lokale Daten zurueck',
      () async {
        final result = await prepareWith(
          const MemberWriteNetworkUnavailableException(
            'Hitobito ist gerade nicht erreichbar.',
          ),
        );

        expect(result.success, isTrue);
        expect(result.member?.mitgliedsnummer, '4711');
        expect(result.preferDeferredSaveUi, isFalse);
        expect(
          result.resolveMessage(AppLocalizations(const Locale('de'))),
          contains('lokal gespeicherten Daten'),
        );
      },
    );

    test('oeffnet einen offenen Problemfall mit Hinweis', () async {
      final entry = _pendingEntry(
        entryId: 'person-23',
        personId: 23,
        mitgliedsnummer: '4711',
      ).copyWith(status: PendingPersonUpdateStatus.needsResolution);
      final writeRepository = _FakeMemberWriteRepository();
      final model = MemberEditModel(
        memberWriteRepository: writeRepository,
        pendingRepository: _InMemoryPendingPersonUpdateRepository(
          entries: <PendingPersonUpdate>[entry],
        ),
        logger: _FakeLoggerService(),
        onMemberUpdated: (_) async {},
      );
      await model.loadPending();

      final result = await model.prepareForEdit(
        accessToken: 'token-123',
        mitglied: _mitglied(personId: 23, mitgliedsnummer: '4711'),
      );

      expect(result.success, isTrue);
      expect(result.member, entry.zielMitglied);
      expect(
        result.messageSpec?.key,
        'member_detail_resolution_required_notice',
      );
    });

    test('lehnt eine ungueltige personId ab', () async {
      final model = MemberEditModel(
        memberWriteRepository: _FakeMemberWriteRepository(),
        pendingRepository: _InMemoryPendingPersonUpdateRepository(),
        logger: _FakeLoggerService(),
        onMemberUpdated: (_) async {},
      );

      final result = await model.prepareForEdit(
        accessToken: 'token-123',
        mitglied: Mitglied.peopleListItem(
          mitgliedsnummer: '4711',
          vorname: 'Julia',
          nachname: 'Keller',
        ),
      );

      expect(result.success, isFalse);
      expect(result.messageSpec?.key, 'member_edit_invalid_person_id');
    });
  });
}

Future<void> _untilUpdateCalled(_FakeMemberWriteRepository repository) async {
  while (repository.updateCalls.isEmpty) {
    await Future<void>.delayed(Duration.zero);
  }
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

class _UpdateCall {
  const _UpdateCall({required this.basisMitglied, required this.zielMitglied});

  final Mitglied basisMitglied;
  final Mitglied zielMitglied;
}

class _FakeMemberWriteRepository implements MemberWriteRepository {
  _FakeMemberWriteRepository({
    this.fetchResultsByPersonId = const <int, Object>{},
    this.updateResultsByPersonId = const <int, Object>{},
    this.onUpdate,
  });

  final Map<int, Object> fetchResultsByPersonId;
  final Map<int, Object> updateResultsByPersonId;
  final Future<Mitglied> Function(Mitglied basis, Mitglied ziel)? onUpdate;
  final List<_UpdateCall> updateCalls = <_UpdateCall>[];

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
    updateCalls.add(
      _UpdateCall(basisMitglied: basisMitglied, zielMitglied: zielMitglied),
    );
    final handler = onUpdate;
    if (handler != null) {
      return handler(basisMitglied, zielMitglied);
    }
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
      (existing) =>
          existing.entryId == entry.entryId ||
          existing.personId == entry.personId,
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

class _FakeAppSettingsRepository extends AppSettingsRepository {
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
