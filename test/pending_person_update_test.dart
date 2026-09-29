import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/member/member_resolution.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/member/pending_person_update.dart';

Mitglied _mitglied({String vorname = 'Julia'}) {
  return Mitglied(
    vorname: vorname,
    nachname: 'Keller',
    geburtsdatum: DateTime(2012, 3, 4),
    eintrittsdatum: DateTime(2020, 1, 1),
    personId: 42,
    mitgliedsnummer: 'M-42',
  );
}

MemberResolutionCase _resolutionCase() {
  return MemberResolutionCase(
    remoteMitglied: _mitglied(vorname: 'Remote'),
    source: MemberResolutionSource.manualSave,
    items: const <MemberResolutionItem>[
      MemberResolutionItem(
        problemType: MemberResolutionProblemType.conflict,
        target: MemberResolutionTarget(
          type: MemberResolutionTargetType.firstName,
        ),
        message: 'Konflikt',
      ),
    ],
  );
}

PendingPersonUpdate _update({
  MemberResolutionCase? resolutionCase,
  int attemptCount = 0,
  DateTime? lastAttemptAt,
}) {
  return PendingPersonUpdate(
    entryId: 'entry-1',
    personId: 42,
    mitgliedsnummer: 'M-42',
    displayName: 'Julia Keller',
    basisMitglied: _mitglied(),
    zielMitglied: _mitglied(vorname: 'Juliane'),
    queuedAt: DateTime.utc(2026, 9, 2, 12),
    resolutionCase: resolutionCase,
    attemptCount: attemptCount,
    lastAttemptAt: lastAttemptAt,
  );
}

Map<String, dynamic> _minimalJson() {
  return <String, dynamic>{
    'entry_id': 'entry-1',
    'person_id': 42,
    'mitgliedsnummer': 'M-42',
    'display_name': 'Julia Keller',
    'basis_mitglied': _mitglied().toPeopleListJson(),
    'ziel_mitglied': _mitglied(vorname: 'Juliane').toPeopleListJson(),
    'queued_at': '2026-09-02T12:00:00.000Z',
  };
}

void main() {
  group('PendingPersonUpdate.fromJson', () {
    test('faellt bei unbekanntem Status auf queued zurueck', () {
      final json = _minimalJson()..['status'] = 'irgendwas';

      final update = PendingPersonUpdate.fromJson(json);

      expect(update.status, PendingPersonUpdateStatus.queued);
      expect(update.needsResolution, isFalse);
    });

    test('liest needsResolution-Status', () {
      final json = _minimalJson()..['status'] = 'needsResolution';

      final update = PendingPersonUpdate.fromJson(json);

      expect(update.needsResolution, isTrue);
    });

    test('setzt Standardwerte bei fehlenden Versuchsfeldern', () {
      final update = PendingPersonUpdate.fromJson(_minimalJson());

      expect(update.attemptCount, 0);
      expect(update.lastAttemptAt, isNull);
      expect(update.resolutionCase, isNull);
      expect(update.status, PendingPersonUpdateStatus.queued);
      expect(update.queuedAt, DateTime.utc(2026, 9, 2, 12));
    });

    test('liest Versuchsfelder auch aus Strings', () {
      final json = _minimalJson()
        ..['person_id'] = '42'
        ..['attempt_count'] = '4'
        ..['last_attempt_at'] = '2026-09-03T07:15:00.000Z';

      final update = PendingPersonUpdate.fromJson(json);

      expect(update.personId, 42);
      expect(update.attemptCount, 4);
      expect(update.lastAttemptAt, DateTime.utc(2026, 9, 3, 7, 15));
    });

    test('ignoriert ungueltige Versuchsfelder', () {
      final json = _minimalJson()
        ..['attempt_count'] = 'viele'
        ..['last_attempt_at'] = 'gestern';

      final update = PendingPersonUpdate.fromJson(json);

      expect(update.attemptCount, 0);
      expect(update.lastAttemptAt, isNull);
    });

    test('nutzt Epoch als queuedAt, wenn das Feld fehlt', () {
      final json = _minimalJson()..remove('queued_at');

      final update = PendingPersonUpdate.fromJson(json);

      expect(update.queuedAt, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('wirft FormatException ohne basis_mitglied', () {
      final json = _minimalJson()..remove('basis_mitglied');

      expect(() => PendingPersonUpdate.fromJson(json), throwsFormatException);
    });

    test('wirft FormatException ohne ziel_mitglied', () {
      final json = _minimalJson()..remove('ziel_mitglied');

      expect(() => PendingPersonUpdate.fromJson(json), throwsFormatException);
    });

    test('wirft FormatException, wenn Mitgliedsdaten keine Map sind', () {
      final json = _minimalJson()..['basis_mitglied'] = 'kaputt';

      expect(() => PendingPersonUpdate.fromJson(json), throwsFormatException);
    });

    test('round trip ueber toJson erhaelt alle Felder', () {
      final original = _update(
        resolutionCase: _resolutionCase(),
        attemptCount: 2,
        lastAttemptAt: DateTime.utc(2026, 9, 3),
      ).copyWith(status: PendingPersonUpdateStatus.needsResolution);

      final restored = PendingPersonUpdate.fromJson(original.toJson());

      expect(restored.entryId, original.entryId);
      expect(restored.personId, original.personId);
      expect(restored.basisMitglied, original.basisMitglied);
      expect(restored.zielMitglied, original.zielMitglied);
      expect(restored.status, PendingPersonUpdateStatus.needsResolution);
      expect(restored.attemptCount, 2);
      expect(restored.lastAttemptAt, DateTime.utc(2026, 9, 3));
      final originalItem = original.resolutionCase!.items.single;
      final restoredItem = restored.resolutionCase!.items.single;
      expect(restoredItem.problemType, originalItem.problemType);
      expect(restoredItem.target, originalItem.target);
      expect(restoredItem.message, originalItem.message);
      // toJson schreibt die effektive Ursache, daher ist cause nach dem
      // Round trip gesetzt, obwohl sie im Original null war.
      expect(originalItem.cause, isNull);
      expect(restoredItem.cause, MemberResolutionCause.overlappingChange);
      expect(restoredItem.effectiveCause, originalItem.effectiveCause);
    });
  });

  group('PendingPersonUpdate.copyWith', () {
    test('behaelt resolutionCase und lastAttemptAt ohne Loeschflags', () {
      final original = _update(
        resolutionCase: _resolutionCase(),
        lastAttemptAt: DateTime.utc(2026, 9, 3),
      );

      final copy = original.copyWith(displayName: 'Neu');

      expect(copy.displayName, 'Neu');
      expect(copy.resolutionCase, same(original.resolutionCase));
      expect(copy.lastAttemptAt, DateTime.utc(2026, 9, 3));
    });

    test('resolutionCaseLoeschen entfernt den Klaerfall', () {
      final original = _update(resolutionCase: _resolutionCase());

      final copy = original.copyWith(resolutionCaseLoeschen: true);

      expect(copy.resolutionCase, isNull);
    });

    test('resolutionCaseLoeschen hat Vorrang vor neuem Klaerfall', () {
      final original = _update();

      final copy = original.copyWith(
        resolutionCase: _resolutionCase(),
        resolutionCaseLoeschen: true,
      );

      expect(copy.resolutionCase, isNull);
    });

    test('lastAttemptAtLoeschen entfernt den letzten Versuch', () {
      final original = _update(lastAttemptAt: DateTime.utc(2026, 9, 3));

      final copy = original.copyWith(lastAttemptAtLoeschen: true);

      expect(copy.lastAttemptAt, isNull);
    });

    test('lastAttemptAtLoeschen hat Vorrang vor neuem Zeitpunkt', () {
      final original = _update();

      final copy = original.copyWith(
        lastAttemptAt: DateTime.utc(2026, 9, 4),
        lastAttemptAtLoeschen: true,
      );

      expect(copy.lastAttemptAt, isNull);
    });
  });

  test('markAttempted erhoeht Zaehler und setzt Zeitpunkt', () {
    final original = _update(
      resolutionCase: _resolutionCase(),
      attemptCount: 1,
      lastAttemptAt: DateTime.utc(2026, 9, 3),
    );

    final attempted = original.markAttempted(DateTime.utc(2026, 9, 4, 9));

    expect(attempted.attemptCount, 2);
    expect(attempted.lastAttemptAt, DateTime.utc(2026, 9, 4, 9));
    expect(attempted.entryId, original.entryId);
    expect(attempted.resolutionCase, same(original.resolutionCase));
    expect(original.attemptCount, 1);
  });

  group('MemberResolutionTarget.fromJson', () {
    test('faellt bei unbekanntem Typ auf firstName zurueck', () {
      final target = MemberResolutionTarget.fromJson(<String, dynamic>{
        'type': 'unbekannt',
        'relationship_id': '12',
        'fingerprint': '  fp-1  ',
      });

      expect(target.type, MemberResolutionTargetType.firstName);
      expect(target.relationshipId, 12);
      expect(target.fingerprint, 'fp-1');
    });

    test('liefert Standardwerte bei fehlenden Feldern', () {
      final target = MemberResolutionTarget.fromJson(const <String, dynamic>{});

      expect(target.type, MemberResolutionTargetType.firstName);
      expect(target.relationshipId, isNull);
      expect(target.fingerprint, isNull);
      expect(target.storageKey, 'firstName:default');
    });

    test('ignoriert leeren Fingerprint und ungueltige relationshipId', () {
      final target = MemberResolutionTarget.fromJson(<String, dynamic>{
        'type': 'phone',
        'relationship_id': 'abc',
        'fingerprint': '   ',
      });

      expect(target.type, MemberResolutionTargetType.phone);
      expect(target.relationshipId, isNull);
      expect(target.fingerprint, isNull);
    });
  });

  group('MemberResolutionItem.fromJson', () {
    test('faellt bei unbekannten Enum-Werten zurueck', () {
      final item = MemberResolutionItem.fromJson(<String, dynamic>{
        'problem_type': 'unbekannt',
        'target': <String, dynamic>{'type': 'birthday'},
        'message': 'Hinweis',
        'cause': 'unbekannt',
        'code': 'x',
      });

      expect(item.problemType, MemberResolutionProblemType.conflict);
      expect(item.target.type, MemberResolutionTargetType.birthday);
      expect(item.message, 'Hinweis');
      expect(item.cause, MemberResolutionCause.unknown);
      expect(item.code, 'x');
    });

    test('liefert Standardwerte bei fehlenden Feldern', () {
      final item = MemberResolutionItem.fromJson(const <String, dynamic>{});

      expect(item.problemType, MemberResolutionProblemType.conflict);
      expect(item.target.type, MemberResolutionTargetType.firstName);
      expect(item.message, '');
      expect(item.cause, isNull);
      expect(item.code, isNull);
      expect(item.effectiveCause, MemberResolutionCause.overlappingChange);
    });

    test('leitet Ursache fuer Validierung aus dem Ziel ab', () {
      final adresse = MemberResolutionItem.fromJson(<String, dynamic>{
        'problem_type': 'validation',
        'target': <String, dynamic>{'type': 'primaryAddress'},
      });
      final email = MemberResolutionItem.fromJson(<String, dynamic>{
        'problem_type': 'validation',
        'target': <String, dynamic>{'type': 'primaryEmail'},
      });

      expect(adresse.cause, isNull);
      expect(adresse.effectiveCause, MemberResolutionCause.addressValidation);
      expect(email.effectiveCause, MemberResolutionCause.serverValidation);
    });

    test('toJson schreibt die effektive Ursache', () {
      const item = MemberResolutionItem(
        problemType: MemberResolutionProblemType.validation,
        target: MemberResolutionTarget(
          type: MemberResolutionTargetType.additionalAddress,
          relationshipId: 3,
        ),
        message: 'PLZ ungueltig',
      );

      final restored = MemberResolutionItem.fromJson(item.toJson());

      expect(restored.cause, MemberResolutionCause.addressValidation);
      expect(restored.target, item.target);
    });
  });

  group('MemberResolutionCase.fromJson', () {
    test('faellt bei unbekannter Quelle und fehlenden Items zurueck', () {
      final resolutionCase = MemberResolutionCase.fromJson(<String, dynamic>{
        'remote_mitglied': _mitglied(vorname: 'Remote').toPeopleListJson(),
        'source': 'unbekannt',
      });

      expect(resolutionCase.source, MemberResolutionSource.manualSave);
      expect(resolutionCase.items, isEmpty);
      expect(resolutionCase.remoteMitglied.vorname, 'Remote');
      expect(resolutionCase.category, MemberResolutionCategory.nonMergeProblem);
    });

    test('ueberspringt Items, die keine Map sind', () {
      final resolutionCase = MemberResolutionCase.fromJson(<String, dynamic>{
        'remote_mitglied': _mitglied().toPeopleListJson(),
        'items': <Object?>[
          'kaputt',
          42,
          <String, dynamic>{
            'problem_type': 'validation',
            'target': <String, dynamic>{'type': 'lastName'},
            'message': 'Nachname fehlt',
          },
        ],
        'source': 'pendingRetry',
      });

      expect(resolutionCase.source, MemberResolutionSource.pendingRetry);
      expect(resolutionCase.items, hasLength(1));
      expect(
        resolutionCase.items.single.problemType,
        MemberResolutionProblemType.validation,
      );
    });

    test('ignoriert items, wenn sie keine Liste sind', () {
      final resolutionCase = MemberResolutionCase.fromJson(<String, dynamic>{
        'remote_mitglied': _mitglied().toPeopleListJson(),
        'items': 'kaputt',
      });

      expect(resolutionCase.items, isEmpty);
    });

    test('wirft ohne remote_mitglied im Debug-Modus (aktuelles Verhalten)', () {
      // Mitglied.fromPeopleListJson erzeugt ohne Daten eine leere
      // Mitgliedsnummer und verletzt damit die Assertion im Konstruktor.
      expect(
        () => MemberResolutionCase.fromJson(const <String, dynamic>{}),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
