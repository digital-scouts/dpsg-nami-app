import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:nami/data/member/secure_pending_person_update_repository.dart';
import 'package:nami/domain/member/member_resolution.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/member/pending_person_update.dart';
import 'package:nami/services/sensitive_storage_service.dart';

const String _cacheKey = 'pending_person_updates_v1';

Mitglied _mitglied({
  required int personId,
  String vorname = 'Julia',
  String nachname = 'Keller',
  List<MitgliedKontaktTelefon>? telefonnummern,
  List<MitgliedKontaktEmail>? emailAdressen,
  List<MitgliedKontaktAdresse>? adressen,
}) {
  return Mitglied(
    vorname: vorname,
    nachname: nachname,
    fahrtenname: 'Jule',
    geburtsdatum: DateTime(2012, 3, 4),
    eintrittsdatum: DateTime(2020, 1, 1),
    updatedAt: DateTime.utc(2026, 9, 1, 8),
    personId: personId,
    primaryGroupId: 7,
    mitgliedsnummer: 'M-$personId',
    gender: 'w',
    telefonnummern: telefonnummern,
    emailAdressen: emailAdressen,
    adressen: adressen,
  );
}

PendingPersonUpdate _update({
  required String entryId,
  required int personId,
  String zielVorname = 'Julia',
  PendingPersonUpdateStatus status = PendingPersonUpdateStatus.queued,
  MemberResolutionCase? resolutionCase,
  int attemptCount = 0,
  DateTime? lastAttemptAt,
}) {
  return PendingPersonUpdate(
    entryId: entryId,
    personId: personId,
    mitgliedsnummer: 'M-$personId',
    displayName: 'Person $personId',
    basisMitglied: _mitglied(personId: personId),
    zielMitglied: _mitglied(personId: personId, vorname: zielVorname),
    queuedAt: DateTime.utc(2026, 9, 2, 12, 30),
    status: status,
    resolutionCase: resolutionCase,
    attemptCount: attemptCount,
    lastAttemptAt: lastAttemptAt,
  );
}

void main() {
  late Directory tempDir;
  late SensitiveStorageService sensitiveStorageService;
  late SecurePendingPersonUpdateRepository repository;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    tempDir = await Directory.systemTemp.createTemp(
      'secure_pending_person_update_repository_',
    );
    Hive.init(tempDir.path);
    sensitiveStorageService = SensitiveStorageService();
    repository = SecurePendingPersonUpdateRepository(
      sensitiveStorageService: sensitiveStorageService,
    );
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> writeRaw(String raw) async {
    final box = await sensitiveStorageService.openEncryptedStringBox(
      SecurePendingPersonUpdateRepository.boxName,
    );
    await box.put(_cacheKey, raw);
  }

  test(
    'loadAll liefert eine leere Liste ohne gespeicherte Eintraege',
    () async {
      final entries = await repository.loadAll();

      expect(entries, isEmpty);
    },
  );

  test(
    'speichert und laedt einen Eintrag inkl. Klaerfall nach Neustart',
    () async {
      final basis = _mitglied(
        personId: 42,
        telefonnummern: const <MitgliedKontaktTelefon>[
          MitgliedKontaktTelefon(
            phoneNumberId: 11,
            wert: '+49 170 1234567',
            label: Mitglied.phoneMobileLabel,
          ),
        ],
        emailAdressen: const <MitgliedKontaktEmail>[
          MitgliedKontaktEmail(
            wert: 'julia@example.org',
            label: Mitglied.primaryEmailLabel,
            istPrimaer: true,
          ),
          MitgliedKontaktEmail(
            additionalEmailId: 21,
            wert: 'eltern@example.org',
            label: Mitglied.secondaryEmailLabel,
          ),
        ],
        adressen: const <MitgliedKontaktAdresse>[
          MitgliedKontaktAdresse(
            additionalAddressId: 0,
            street: 'Hauptstrasse',
            housenumber: '1',
            zipCode: '12345',
            town: 'Musterstadt',
            country: 'DE',
          ),
          MitgliedKontaktAdresse(
            additionalAddressId: 31,
            label: 'Ferien',
            street: 'Seeweg',
            housenumber: '5a',
            zipCode: '54321',
            town: 'Seedorf',
          ),
        ],
      );
      final ziel = basis.copyWith(
        vorname: 'Juliane',
        telefonnummern: const <MitgliedKontaktTelefon>[
          MitgliedKontaktTelefon(
            phoneNumberId: 11,
            wert: '+49 170 7654321',
            label: Mitglied.phoneMobileLabel,
          ),
          MitgliedKontaktTelefon(
            wert: '0228 123456',
            label: Mitglied.phoneLandlineLabel,
          ),
        ],
      );
      final remote = basis.copyWith(vorname: 'Jule');
      final resolutionCase = MemberResolutionCase(
        remoteMitglied: remote,
        source: MemberResolutionSource.pendingRetry,
        items: const <MemberResolutionItem>[
          MemberResolutionItem(
            problemType: MemberResolutionProblemType.conflict,
            cause: MemberResolutionCause.overlappingChange,
            target: MemberResolutionTarget(
              type: MemberResolutionTargetType.firstName,
            ),
            message: 'Vorname unterschiedlich geaendert.',
          ),
          MemberResolutionItem(
            problemType: MemberResolutionProblemType.conflict,
            cause: MemberResolutionCause.overlappingChange,
            target: MemberResolutionTarget(
              type: MemberResolutionTargetType.phone,
              relationshipId: 11,
            ),
            message: 'Telefonnummer unterschiedlich geaendert.',
          ),
          MemberResolutionItem(
            problemType: MemberResolutionProblemType.validation,
            cause: MemberResolutionCause.addressValidation,
            target: MemberResolutionTarget(
              type: MemberResolutionTargetType.additionalAddress,
              fingerprint: 'seeweg-5a',
            ),
            message: 'PLZ ist ungueltig.',
            code: 'invalid_zip',
          ),
        ],
      );
      final entry = PendingPersonUpdate(
        entryId: 'entry-42',
        personId: 42,
        mitgliedsnummer: 'M-42',
        displayName: 'Julia Keller',
        basisMitglied: basis,
        zielMitglied: ziel,
        queuedAt: DateTime.utc(2026, 9, 2, 12, 30),
        status: PendingPersonUpdateStatus.needsResolution,
        resolutionCase: resolutionCase,
        attemptCount: 3,
        lastAttemptAt: DateTime.utc(2026, 9, 3, 7, 15),
      );

      await repository.save(entry);
      await Hive.close();

      final restarted = SecurePendingPersonUpdateRepository(
        sensitiveStorageService: SensitiveStorageService(),
      );
      final loaded = await restarted.loadAll();

      expect(loaded, hasLength(1));
      final loadedEntry = loaded.single;
      expect(loadedEntry.entryId, 'entry-42');
      expect(loadedEntry.personId, 42);
      expect(loadedEntry.mitgliedsnummer, 'M-42');
      expect(loadedEntry.displayName, 'Julia Keller');
      expect(loadedEntry.queuedAt, DateTime.utc(2026, 9, 2, 12, 30));
      expect(loadedEntry.status, PendingPersonUpdateStatus.needsResolution);
      expect(loadedEntry.needsResolution, isTrue);
      expect(loadedEntry.attemptCount, 3);
      expect(loadedEntry.lastAttemptAt, DateTime.utc(2026, 9, 3, 7, 15));
      expect(loadedEntry.basisMitglied, basis);
      expect(loadedEntry.zielMitglied, ziel);
      expect(loadedEntry.zielMitglied.telefonnummern, hasLength(2));
      expect(loadedEntry.basisMitglied.emailAdressen, hasLength(2));
      expect(loadedEntry.basisMitglied.adressen, hasLength(2));
      expect(loadedEntry.basisUpdatedAt, DateTime.utc(2026, 9, 1, 8));

      final loadedCase = loadedEntry.resolutionCase;
      expect(loadedCase, isNotNull);
      expect(loadedCase!.source, MemberResolutionSource.pendingRetry);
      expect(loadedCase.remoteMitglied, remote);
      expect(loadedCase.items, resolutionCase.items);
      expect(loadedCase.category, MemberResolutionCategory.mixed);
      expect(loadedCase.items[1].target.relationshipId, 11);
      expect(loadedCase.items[2].target.fingerprint, 'seeweg-5a');
      expect(loadedCase.items[2].code, 'invalid_zip');
    },
  );

  test('save ersetzt Eintrag mit derselben entryId', () async {
    await repository.save(_update(entryId: 'entry-1', personId: 1));
    await repository.save(
      _update(entryId: 'entry-1', personId: 1, zielVorname: 'Neu'),
    );

    final entries = await repository.loadAll();

    expect(entries, hasLength(1));
    expect(entries.single.zielMitglied.vorname, 'Neu');
  });

  test('save ersetzt Eintrag derselben Person mit anderer entryId', () async {
    await repository.save(_update(entryId: 'entry-a', personId: 5));
    await repository.save(
      _update(entryId: 'entry-b', personId: 5, zielVorname: 'Neu'),
    );

    final entries = await repository.loadAll();

    expect(entries, hasLength(1));
    expect(entries.single.entryId, 'entry-b');
    expect(entries.single.zielMitglied.vorname, 'Neu');
  });

  test(
    'save behaelt verschiedene Personen und erhaelt die Reihenfolge',
    () async {
      await repository.save(_update(entryId: 'entry-1', personId: 1));
      await repository.save(_update(entryId: 'entry-2', personId: 2));
      await repository.save(_update(entryId: 'entry-3', personId: 3));
      await repository.save(
        _update(entryId: 'entry-2b', personId: 2, zielVorname: 'Neu'),
      );

      final entries = await repository.loadAll();

      expect(entries.map((entry) => entry.entryId).toList(), <String>[
        'entry-1',
        'entry-2b',
        'entry-3',
      ]);
      expect(entries[1].zielMitglied.vorname, 'Neu');
    },
  );

  test('remove entfernt nur den Eintrag mit der entryId', () async {
    await repository.save(_update(entryId: 'entry-1', personId: 1));
    await repository.save(_update(entryId: 'entry-2', personId: 2));

    await repository.remove('entry-1');
    await repository.remove('unbekannt');

    final entries = await repository.loadAll();
    expect(entries.map((entry) => entry.entryId).toList(), <String>['entry-2']);
  });

  test('clear entfernt alle Eintraege', () async {
    await repository.save(_update(entryId: 'entry-1', personId: 1));
    await repository.save(_update(entryId: 'entry-2', personId: 2));

    await repository.clear();

    expect(await repository.loadAll(), isEmpty);
  });

  test(
    'verwirft einzelne defekte Eintraege und behaelt die uebrigen',
    () async {
      final valid1 = _update(entryId: 'entry-1', personId: 1).toJson();
      final valid2 = _update(entryId: 'entry-2', personId: 2).toJson();
      final ohneBasis = Map<String, dynamic>.of(
        _update(entryId: 'entry-3', personId: 3).toJson(),
      )..remove('basis_mitglied');
      final ohnePersonId = Map<String, dynamic>.of(
        _update(entryId: 'entry-4', personId: 4).toJson(),
      )..['person_id'] = 0;
      final negativePersonId = Map<String, dynamic>.of(
        _update(entryId: 'entry-5', personId: 5).toJson(),
      )..['person_id'] = -5;
      final leereEntryId = Map<String, dynamic>.of(
        _update(entryId: 'entry-6', personId: 6).toJson(),
      )..['entry_id'] = '';
      await writeRaw(
        jsonEncode(<Object?>[
          valid1,
          ohneBasis,
          'kein Objekt',
          ohnePersonId,
          negativePersonId,
          leereEntryId,
          valid2,
        ]),
      );

      final entries = await repository.loadAll();

      expect(entries.map((entry) => entry.entryId).toList(), <String>[
        'entry-1',
        'entry-2',
      ]);
    },
  );

  test(
    'liefert leere Liste, wenn gespeichertes JSON keine Liste ist',
    () async {
      await writeRaw(jsonEncode(<String, dynamic>{'entry_id': 'entry-1'}));

      expect(await repository.loadAll(), isEmpty);
    },
  );

  test('liefert leere Liste bei leerem gespeichertem String', () async {
    await writeRaw('');

    expect(await repository.loadAll(), isEmpty);
  });

  test('behandelt korruptes JSON als leer und kann danach speichern', () async {
    await writeRaw('{kein gueltiges json');

    expect(await repository.loadAll(), isEmpty);
    await repository.remove('entry-1');
    await repository.save(_update(entryId: 'entry-1', personId: 1));

    final entries = await repository.loadAll();
    expect(entries.single.entryId, 'entry-1');
  });
}
