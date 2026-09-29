import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/data/arbeitskontext/hitobito_person_resource.dart';
import 'package:nami/data/member/hitobito_member_write_repository.dart';
import 'package:nami/domain/auth/auth_session.dart';
import 'package:nami/domain/member/member_write_repository.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/settings/app_settings.dart';
import 'package:nami/domain/settings/app_settings_repository.dart';
import 'package:nami/services/hitobito_api_exception.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_people_service.dart';
import 'package:nami/domain/member/member_resolution.dart';
import 'package:nami/services/logger_service.dart';
import 'package:nami/services/network_access_policy.dart';

void main() {
  test(
    'retryt den kompletten Update-Vorgang nach 401 einmal mit neuer Session',
    () async {
      final peopleService = _FakeHitobitoPeopleService();
      final repository = HitobitoMemberWriteRepository(
        peopleService: peopleService,
        remoteAccessExecutor: _retryingExecutor,
        logger: _FakeLoggerService(),
      );
      final basisMitglied = Mitglied.peopleListItem(
        mitgliedsnummer: '4711',
        personId: 23,
        vorname: 'Julia',
        nachname: 'Keller',
      ).copyWith(updatedAt: DateTime.parse('2026-04-14T09:00:00Z'));
      final zielMitglied = basisMitglied.copyWith(vorname: 'Juliane');

      final updated = await repository.updateMember(
        accessToken: 'stale-token',
        basisMitglied: basisMitglied,
        zielMitglied: zielMitglied,
      );

      expect(updated.vorname, 'Juliane');
      expect(peopleService.calls, <String>[
        'fetch:stale-token',
        'update:stale-token',
        'fetch:refreshed-token',
      ]);
    },
  );

  test(
    'ordnet permanente 4xx-Antworten als nicht retrybare Ablehnung ein',
    () async {
      final peopleService = _FakeHitobitoPeopleService()
        ..updateError = const HitobitoPeopleException(
          'Forbidden',
          statusCode: 403,
        );
      final repository = HitobitoMemberWriteRepository(
        peopleService: peopleService,
        logger: _FakeLoggerService(),
      );
      final basisMitglied = Mitglied.peopleListItem(
        mitgliedsnummer: '4711',
        personId: 23,
        vorname: 'Julia',
        nachname: 'Keller',
      ).copyWith(updatedAt: DateTime.parse('2026-04-14T09:00:00Z'));

      await expectLater(
        () => repository.updateMember(
          accessToken: 'token-123',
          basisMitglied: basisMitglied,
          zielMitglied: basisMitglied.copyWith(vorname: 'Juliane'),
        ),
        throwsA(isA<MemberWriteRejectedException>()),
      );
    },
  );

  test('ordnet 422 mit Felddetails als Validierungsfehler ein', () async {
    final peopleService = _FakeHitobitoPeopleService()
      ..updateError = const HitobitoPeopleException(
        'Validation Error',
        statusCode: 422,
        validationErrors: <HitobitoApiValidationError>[
          HitobitoApiValidationError(
            message: 'Nummer ist nicht gültig',
            pointer: '/data/attributes/number',
            relationshipName: 'phone_numbers',
            relationshipAttribute: 'number',
            relationshipType: 'phone_numbers',
            relationshipId: 288,
            code: 'invalid',
          ),
        ],
      );
    final repository = HitobitoMemberWriteRepository(
      peopleService: peopleService,
      logger: _FakeLoggerService(),
    );
    final basisMitglied = Mitglied.peopleListItem(
      mitgliedsnummer: '4711',
      personId: 23,
      vorname: 'Julia',
      nachname: 'Keller',
    ).copyWith(updatedAt: DateTime.parse('2026-04-14T09:00:00Z'));

    await expectLater(
      () => repository.updateMember(
        accessToken: 'token-123',
        basisMitglied: basisMitglied,
        zielMitglied: basisMitglied.copyWith(vorname: 'Juliane'),
      ),
      throwsA(
        isA<MemberWriteValidationException>()
            .having(
              (error) => error.message,
              'message',
              'Nummer ist nicht gültig',
            )
            .having(
              (error) => error.errors.single.relationshipId,
              'relationshipId',
              288,
            )
            .having(
              (error) => error.errors.single.relationshipName,
              'relationshipName',
              'phone_numbers',
            )
            .having(
              (error) => error.errors.single.relationshipAttribute,
              'relationshipAttribute',
              'number',
            ),
      ),
    );
  });

  test('loggt den genauen API-Grund bei abgelehntem Personen-Update', () async {
    final logger = _FakeLoggerService();
    final peopleService = _FakeHitobitoPeopleService()
      ..updateError = const HitobitoPeopleException(
        'Aktualisierung fehlgeschlagen (400). Grund: data.attributes.exit_date is an unknown attribute [data.attributes.exit_date]',
        statusCode: 400,
      );
    final repository = HitobitoMemberWriteRepository(
      peopleService: peopleService,
      logger: logger,
    );
    final basisMitglied = Mitglied.peopleListItem(
      mitgliedsnummer: '4711',
      personId: 23,
      vorname: 'Julia',
      nachname: 'Keller',
    ).copyWith(updatedAt: DateTime.parse('2026-04-14T09:00:00Z'));

    await expectLater(
      () => repository.updateMember(
        accessToken: 'token-123',
        basisMitglied: basisMitglied,
        zielMitglied: basisMitglied.copyWith(vorname: 'Juliane'),
      ),
      throwsA(isA<MemberWriteRejectedException>()),
    );

    expect(
      logger.warnMessages,
      contains(
        contains(
          'detail="Aktualisierung fehlgeschlagen (400). Grund: data.attributes.exit_date is an unknown attribute [data.attributes.exit_date]"',
        ),
      ),
    );
  });

  test(
    'fuehrt Zusatzfeld-Aenderungen in genau einem Sammelwrite aus',
    () async {
      final peopleService = _FakeHitobitoPeopleService();
      peopleService.remoteResource = HitobitoPersonResource(
        id: 23,
        firstName: 'Julia',
        lastName: 'Keller',
        membershipNumber: 4711,
        updatedAt: DateTime.parse('2026-04-14T09:00:00Z'),
        telefonnummern: const <MitgliedKontaktTelefon>[
          MitgliedKontaktTelefon(phoneNumberId: 701, wert: '+4940123456'),
        ],
        emailAdressen: const <MitgliedKontaktEmail>[
          MitgliedKontaktEmail(
            additionalEmailId: 601,
            wert: 'julia@example.org',
            label: 'Privat',
          ),
        ],
        adressen: const <MitgliedKontaktAdresse>[
          MitgliedKontaktAdresse(
            additionalAddressId: 801,
            street: 'Altweg',
            housenumber: '4',
            zipCode: '50667',
            town: 'Koeln',
          ),
        ],
      );
      final repository = HitobitoMemberWriteRepository(
        peopleService: peopleService,
        logger: _FakeLoggerService(),
      );
      final basisMitglied = Mitglied(
        mitgliedsnummer: '4711',
        personId: 23,
        vorname: 'Julia',
        nachname: 'Keller',
        geburtsdatum: Mitglied.peoplePlaceholderDate,
        eintrittsdatum: Mitglied.peoplePlaceholderDate,
        updatedAt: DateTime.parse('2026-04-14T09:00:00Z'),
        telefonnummern: const <MitgliedKontaktTelefon>[
          MitgliedKontaktTelefon(phoneNumberId: 701, wert: '+4940123456'),
        ],
        emailAdressen: const <MitgliedKontaktEmail>[
          MitgliedKontaktEmail(
            additionalEmailId: 601,
            wert: 'julia@example.org',
            label: 'Privat',
          ),
        ],
        adressen: const <MitgliedKontaktAdresse>[
          MitgliedKontaktAdresse(
            additionalAddressId: 801,
            street: 'Altweg',
            housenumber: '4',
            zipCode: '50667',
            town: 'Koeln',
          ),
        ],
      );
      final zielMitglied = basisMitglied.copyWith(
        telefonnummern: const <MitgliedKontaktTelefon>[
          MitgliedKontaktTelefon(phoneNumberId: 701, wert: '+4940999999'),
          MitgliedKontaktTelefon(wert: '+49 170 1234567', label: 'Mobil'),
        ],
        emailAdressen: const <MitgliedKontaktEmail>[
          MitgliedKontaktEmail(
            additionalEmailId: 601,
            wert: 'julia.neu@example.org',
            label: 'Privat',
          ),
        ],
        adressen: const <MitgliedKontaktAdresse>[
          MitgliedKontaktAdresse(
            additionalAddressId: 801,
            street: 'Neuweg',
            housenumber: '5',
            zipCode: '50668',
            town: 'Koeln',
          ),
        ],
      );

      await repository.updateMember(
        accessToken: 'token-123',
        basisMitglied: basisMitglied,
        zielMitglied: zielMitglied,
      );

      expect(
        peopleService.calls.where((entry) => entry == 'update:token-123'),
        hasLength(1),
      );
      expect(peopleService.lastPhoneNumberMutations, hasLength(2));
      expect(
        peopleService.lastPhoneNumberMutations.map((m) => m.method),
        containsAll(<HitobitoRelationshipMutationMethod>[
          HitobitoRelationshipMutationMethod.update,
          HitobitoRelationshipMutationMethod.create,
        ]),
      );
      expect(peopleService.lastAdditionalEmailMutations, hasLength(1));
      expect(
        peopleService.lastAdditionalEmailMutations.single.method,
        HitobitoRelationshipMutationMethod.update,
      );
      expect(peopleService.lastAdditionalAddressMutations, hasLength(1));
      expect(
        peopleService.lastAdditionalAddressMutations.single.method,
        HitobitoRelationshipMutationMethod.update,
      );
    },
  );

  test(
    'sendet fuer serverseitig geloeschte lokale Telefonnummer ein create ohne ID',
    () async {
      final peopleService = _FakeHitobitoPeopleService()
        ..remoteResource = HitobitoPersonResource(
          id: 23,
          firstName: 'Julia',
          lastName: 'Keller',
          membershipNumber: 4711,
          updatedAt: DateTime.parse('2026-04-14T09:00:00Z'),
        );
      final repository = HitobitoMemberWriteRepository(
        peopleService: peopleService,
        logger: _FakeLoggerService(),
      );
      final basisMitglied = Mitglied.peopleListItem(
        mitgliedsnummer: '4711',
        personId: 23,
        vorname: 'Julia',
        nachname: 'Keller',
      ).copyWith(updatedAt: DateTime.parse('2026-04-14T09:00:00Z'));
      final zielMitglied = basisMitglied.copyWith(
        telefonnummern: const <MitgliedKontaktTelefon>[
          MitgliedKontaktTelefon(
            phoneNumberId: 701,
            wert: '+491701234567',
            label: 'Mobil',
          ),
        ],
      );

      await repository.updateMember(
        accessToken: 'token-123',
        basisMitglied: basisMitglied,
        zielMitglied: zielMitglied,
      );

      expect(peopleService.lastPhoneNumberMutations, hasLength(1));
      expect(
        peopleService.lastPhoneNumberMutations.single.method,
        HitobitoRelationshipMutationMethod.create,
      );
      expect(
        peopleService.lastPhoneNumberMutations.single.value,
        const MitgliedKontaktTelefon(wert: '+491701234567', label: 'Mobil'),
      );
    },
  );

  test(
    'sendet fuer serverseitig geloeschte lokale Zusatz-E-Mail ein create ohne ID',
    () async {
      final peopleService = _FakeHitobitoPeopleService()
        ..remoteResource = HitobitoPersonResource(
          id: 23,
          firstName: 'Julia',
          lastName: 'Keller',
          membershipNumber: 4711,
          updatedAt: DateTime.parse('2026-04-14T09:00:00Z'),
          emailAdressen: const <MitgliedKontaktEmail>[
            MitgliedKontaktEmail(
              wert: 'julia@example.org',
              label: Mitglied.primaryEmailLabel,
              istPrimaer: true,
            ),
          ],
        );
      final repository = HitobitoMemberWriteRepository(
        peopleService: peopleService,
        logger: _FakeLoggerService(),
      );
      final basisMitglied =
          Mitglied.peopleListItem(
            mitgliedsnummer: '4711',
            personId: 23,
            vorname: 'Julia',
            nachname: 'Keller',
          ).copyWith(
            updatedAt: DateTime.parse('2026-04-14T09:00:00Z'),
            emailAdressen: const <MitgliedKontaktEmail>[
              MitgliedKontaktEmail(
                wert: 'julia@example.org',
                label: Mitglied.primaryEmailLabel,
                istPrimaer: true,
              ),
            ],
          );
      final zielMitglied = basisMitglied.copyWith(
        emailAdressen: const <MitgliedKontaktEmail>[
          MitgliedKontaktEmail(
            wert: 'julia@example.org',
            label: Mitglied.primaryEmailLabel,
            istPrimaer: true,
          ),
          MitgliedKontaktEmail(
            additionalEmailId: 601,
            wert: 'jule@schule.example',
            label: 'Schule',
          ),
        ],
      );

      await repository.updateMember(
        accessToken: 'token-123',
        basisMitglied: basisMitglied,
        zielMitglied: zielMitglied,
      );

      expect(peopleService.lastAdditionalEmailMutations, hasLength(1));
      expect(
        peopleService.lastAdditionalEmailMutations.single.method,
        HitobitoRelationshipMutationMethod.create,
      );
      expect(
        peopleService.lastAdditionalEmailMutations.single.value,
        const MitgliedKontaktEmail(
          wert: 'jule@schule.example',
          label: 'Schule',
        ),
      );
    },
  );

  test(
    'sendet fuer serverseitig geloeschte lokale Zusatzadresse ein create ohne ID',
    () async {
      final peopleService = _FakeHitobitoPeopleService()
        ..remoteResource = HitobitoPersonResource(
          id: 23,
          firstName: 'Julia',
          lastName: 'Keller',
          membershipNumber: 4711,
          updatedAt: DateTime.parse('2026-04-14T09:00:00Z'),
          adressen: const <MitgliedKontaktAdresse>[
            MitgliedKontaktAdresse(
              additionalAddressId: 0,
              street: 'Musterweg',
              housenumber: '5',
              zipCode: '12345',
              town: 'Koeln',
            ),
          ],
        );
      final repository = HitobitoMemberWriteRepository(
        peopleService: peopleService,
        logger: _FakeLoggerService(),
      );
      final basisMitglied =
          Mitglied.peopleListItem(
            mitgliedsnummer: '4711',
            personId: 23,
            vorname: 'Julia',
            nachname: 'Keller',
          ).copyWith(
            updatedAt: DateTime.parse('2026-04-14T09:00:00Z'),
            adressen: const <MitgliedKontaktAdresse>[
              MitgliedKontaktAdresse(
                additionalAddressId: 0,
                street: 'Musterweg',
                housenumber: '5',
                zipCode: '12345',
                town: 'Koeln',
              ),
            ],
          );
      final zielMitglied = basisMitglied.copyWith(
        adressen: const <MitgliedKontaktAdresse>[
          MitgliedKontaktAdresse(
            additionalAddressId: 0,
            street: 'Musterweg',
            housenumber: '5',
            zipCode: '12345',
            town: 'Koeln',
          ),
          MitgliedKontaktAdresse(
            additionalAddressId: 801,
            label: 'Lager',
            street: 'Zeltplatz',
            housenumber: '7',
            zipCode: '50667',
            town: 'Koeln',
          ),
        ],
      );

      await repository.updateMember(
        accessToken: 'token-123',
        basisMitglied: basisMitglied,
        zielMitglied: zielMitglied,
      );

      expect(peopleService.lastAdditionalAddressMutations, hasLength(1));
      expect(
        peopleService.lastAdditionalAddressMutations.single.method,
        HitobitoRelationshipMutationMethod.create,
      );
      expect(
        peopleService.lastAdditionalAddressMutations.single.value,
        const MitgliedKontaktAdresse(
          label: 'Lager',
          street: 'Zeltplatz',
          housenumber: '7',
          zipCode: '50667',
          town: 'Koeln',
        ),
      );
    },
  );

  test('sendet beim Leeren der Hauptadresse null-Attribute und laesst '
      'die Zusatzadresse unveraendert', () async {
    const hauptadresse = MitgliedKontaktAdresse(
      additionalAddressId: 0,
      street: 'Musterweg',
      housenumber: '5',
      zipCode: '12345',
      town: 'Koeln',
    );
    const zusatzadresse = MitgliedKontaktAdresse(
      additionalAddressId: 801,
      label: 'Lager',
      street: 'Zeltplatz',
      housenumber: '7',
      zipCode: '50667',
      town: 'Bonn',
    );
    final peopleService = _FakeHitobitoPeopleService()
      ..remoteResource = HitobitoPersonResource(
        id: 23,
        firstName: 'Julia',
        lastName: 'Keller',
        membershipNumber: 4711,
        updatedAt: DateTime.parse('2026-04-14T09:00:00Z'),
        adressen: const <MitgliedKontaktAdresse>[hauptadresse, zusatzadresse],
      );
    final repository = HitobitoMemberWriteRepository(
      peopleService: peopleService,
      logger: _FakeLoggerService(),
    );
    final basisMitglied = _basisMitglied().copyWith(
      adressen: const <MitgliedKontaktAdresse>[hauptadresse, zusatzadresse],
    );
    final zielMitglied = basisMitglied.copyWith(
      adressen: const <MitgliedKontaktAdresse>[
        MitgliedKontaktAdresse(additionalAddressId: 0),
        zusatzadresse,
      ],
    );

    await repository.updateMember(
      accessToken: 'token-123',
      basisMitglied: basisMitglied,
      zielMitglied: zielMitglied,
    );

    expect(peopleService.lastChangedAttributes, <String, dynamic>{
      'street': null,
      'housenumber': null,
      'zip_code': null,
      'town': null,
    });
    expect(peopleService.lastAdditionalAddressMutations, isEmpty);
    expect(peopleService.lastUpdatedMitglied?.primaryAddress, isNull);
    expect(peopleService.lastUpdatedMitglied?.additionalAddresses, [
      zusatzadresse,
    ]);
  });

  group('updateMember Merge und Konflikte', () {
    test(
      'wirft NeedsResolution bei ueberlappender Feldaenderung und sendet keinen Write',
      () async {
        final logger = _FakeLoggerService();
        final peopleService = _FakeHitobitoPeopleService()
          ..remoteResource = _remoteResource(
            firstName: 'Jule',
            updatedAt: DateTime.parse('2026-04-14T10:00:00Z'),
          );
        final repository = HitobitoMemberWriteRepository(
          peopleService: peopleService,
          logger: logger,
        );
        final basisMitglied = _basisMitglied();

        await expectLater(
          () => repository.updateMember(
            accessToken: 'token-123',
            basisMitglied: basisMitglied,
            zielMitglied: basisMitglied.copyWith(vorname: 'Juliane'),
          ),
          throwsA(
            isA<MemberWriteNeedsResolutionException>()
                .having(
                  (error) => error.resolutionCase.items.single,
                  'item',
                  const MemberResolutionItem(
                    problemType: MemberResolutionProblemType.conflict,
                    cause: MemberResolutionCause.overlappingChange,
                    target: MemberResolutionTarget(
                      type: MemberResolutionTargetType.firstName,
                    ),
                    message:
                        'Vorname wurde lokal und in Hitobito unterschiedlich geändert.',
                  ),
                )
                .having(
                  (error) => error.resolutionCase.remoteMitglied.vorname,
                  'remoteMitglied.vorname',
                  'Jule',
                )
                .having(
                  (error) => error.resolutionCase.source,
                  'source',
                  MemberResolutionSource.manualSave,
                ),
          ),
        );

        expect(peopleService.updateCallCount, 0);
        expect(peopleService.calls, <String>['fetch:token-123']);
        expect(
          logger.warnMessages,
          contains(
            allOf(
              contains('reason=field_conflict'),
              contains('conflict_count=1'),
              contains('target_types=firstName'),
            ),
          ),
        );
      },
    );

    test(
      'uebernimmt nicht ueberlappende Remote-Aenderung und sendet nur lokale Aenderung',
      () async {
        final peopleService = _FakeHitobitoPeopleService()
          ..remoteResource = _remoteResource(
            lastName: 'Kellermann',
            updatedAt: DateTime.parse('2026-04-14T10:00:00Z'),
          );
        final repository = HitobitoMemberWriteRepository(
          peopleService: peopleService,
          logger: _FakeLoggerService(),
        );
        final basisMitglied = _basisMitglied();

        await repository.updateMember(
          accessToken: 'token-123',
          basisMitglied: basisMitglied,
          zielMitglied: basisMitglied.copyWith(vorname: 'Juliane'),
        );

        expect(peopleService.updateCallCount, 1);
        expect(peopleService.lastChangedAttributes, <String, dynamic>{
          'first_name': 'Juliane',
        });
        expect(peopleService.lastUpdatedMitglied?.vorname, 'Juliane');
        expect(peopleService.lastUpdatedMitglied?.nachname, 'Kellermann');
        expect(peopleService.lastUpdatedMitglied?.personId, 23);
        expect(peopleService.calls, <String>[
          'fetch:token-123',
          'update:token-123',
          'fetch:token-123',
        ]);
      },
    );

    test(
      'liefert Remote-Mitglied ohne Write, wenn Ziel der Basis entspricht',
      () async {
        final peopleService = _FakeHitobitoPeopleService()
          ..remoteResource = _remoteResource(lastName: 'Kellermann');
        final repository = HitobitoMemberWriteRepository(
          peopleService: peopleService,
          logger: _FakeLoggerService(),
        );
        final basisMitglied = _basisMitglied();

        final result = await repository.updateMember(
          accessToken: 'token-123',
          basisMitglied: basisMitglied,
          zielMitglied: basisMitglied,
        );

        expect(result.nachname, 'Kellermann');
        expect(peopleService.updateCallCount, 0);
        expect(peopleService.calls, <String>['fetch:token-123']);
      },
    );

    test(
      'liefert Remote-Mitglied ohne Write, wenn lokale Aenderung remote bereits gleich ist',
      () async {
        final peopleService = _FakeHitobitoPeopleService()
          ..remoteResource = _remoteResource(firstName: 'Juliane');
        final repository = HitobitoMemberWriteRepository(
          peopleService: peopleService,
          logger: _FakeLoggerService(),
        );
        final basisMitglied = _basisMitglied();

        final result = await repository.updateMember(
          accessToken: 'token-123',
          basisMitglied: basisMitglied,
          zielMitglied: basisMitglied.copyWith(vorname: 'Juliane'),
        );

        expect(result.vorname, 'Juliane');
        expect(peopleService.updateCallCount, 0);
        expect(peopleService.calls, <String>['fetch:token-123']);
      },
    );
  });

  group('updateMember Vorbedingungen', () {
    test(
      'wirft UpdatedAtMissing ohne lokales updatedAt und fragt Remote nicht ab',
      () async {
        final logger = _FakeLoggerService();
        final peopleService = _FakeHitobitoPeopleService();
        final repository = HitobitoMemberWriteRepository(
          peopleService: peopleService,
          logger: logger,
        );
        final basisMitglied = Mitglied.peopleListItem(
          mitgliedsnummer: '4711',
          personId: 23,
          vorname: 'Julia',
          nachname: 'Keller',
        );

        await expectLater(
          () => repository.updateMember(
            accessToken: 'token-123',
            basisMitglied: basisMitglied,
            zielMitglied: basisMitglied.copyWith(vorname: 'Juliane'),
          ),
          throwsA(isA<MemberWriteUpdatedAtMissingException>()),
        );
        expect(peopleService.calls, isEmpty);
        expect(
          logger.warnMessages,
          contains(contains('reason=missing_local_updated_at person_id=23')),
        );
      },
    );

    test(
      'wirft UpdatedAtMissing ohne Remote-updatedAt und sendet keinen Write',
      () async {
        final logger = _FakeLoggerService();
        final peopleService = _FakeHitobitoPeopleService()
          ..remoteResource = _remoteResource(withoutUpdatedAt: true);
        final repository = HitobitoMemberWriteRepository(
          peopleService: peopleService,
          logger: logger,
        );
        final basisMitglied = _basisMitglied();

        await expectLater(
          () => repository.updateMember(
            accessToken: 'token-123',
            basisMitglied: basisMitglied,
            zielMitglied: basisMitglied.copyWith(vorname: 'Juliane'),
          ),
          throwsA(isA<MemberWriteUpdatedAtMissingException>()),
        );
        expect(peopleService.updateCallCount, 0);
        expect(
          logger.warnMessages,
          contains(contains('reason=missing_remote_updated_at person_id=23')),
        );
      },
    );

    test(
      'wirft einfache MemberWriteException ohne Person-ID und ruft Remote nicht auf',
      () async {
        final peopleService = _FakeHitobitoPeopleService();
        final repository = HitobitoMemberWriteRepository(
          peopleService: peopleService,
          logger: _FakeLoggerService(),
        );
        final basisMitglied = Mitglied.peopleListItem(
          mitgliedsnummer: '4711',
          vorname: 'Julia',
          nachname: 'Keller',
        ).copyWith(updatedAt: DateTime.parse('2026-04-14T09:00:00Z'));

        await expectLater(
          () => repository.updateMember(
            accessToken: 'token-123',
            basisMitglied: basisMitglied,
            zielMitglied: basisMitglied.copyWith(vorname: 'Juliane'),
          ),
          throwsA(
            isA<MemberWriteException>().having(
              (error) => error.runtimeType,
              'runtimeType',
              MemberWriteException,
            ),
          ),
        );
        expect(peopleService.calls, isEmpty);
      },
    );

    test(
      'wirft einfache MemberWriteException bei nicht positiver Person-ID',
      () async {
        final peopleService = _FakeHitobitoPeopleService();
        final repository = HitobitoMemberWriteRepository(
          peopleService: peopleService,
          logger: _FakeLoggerService(),
        );
        final basisMitglied = _basisMitglied().copyWith(personId: 0);

        await expectLater(
          () => repository.updateMember(
            accessToken: 'token-123',
            basisMitglied: basisMitglied,
            zielMitglied: basisMitglied.copyWith(vorname: 'Juliane'),
          ),
          throwsA(
            isA<MemberWriteException>().having(
              (error) => error.runtimeType,
              'runtimeType',
              MemberWriteException,
            ),
          ),
        );
        expect(peopleService.calls, isEmpty);
      },
    );

    test(
      'nutzt Person-ID der Basis, wenn das Ziel keine Person-ID hat',
      () async {
        final peopleService = _FakeHitobitoPeopleService();
        final repository = HitobitoMemberWriteRepository(
          peopleService: peopleService,
          logger: _FakeLoggerService(),
        );
        final basisMitglied = _basisMitglied();
        final zielMitglied = Mitglied.peopleListItem(
          mitgliedsnummer: '4711',
          vorname: 'Juliane',
          nachname: 'Keller',
        ).copyWith(updatedAt: DateTime.parse('2026-04-14T09:00:00Z'));

        await repository.updateMember(
          accessToken: 'token-123',
          basisMitglied: basisMitglied,
          zielMitglied: zielMitglied,
        );

        expect(peopleService.updateCallCount, 1);
        expect(peopleService.lastUpdatedMitglied?.personId, 23);
      },
    );
  });

  group('updateMember Fehlerabbildung', () {
    Future<void> expectUpdateThrows(
      Object updateError,
      Matcher matcher, {
      MemberWriteRemoteAccessExecutor? executor,
    }) async {
      final peopleService = _FakeHitobitoPeopleService()
        ..updateError = updateError;
      final repository = HitobitoMemberWriteRepository(
        peopleService: peopleService,
        remoteAccessExecutor: executor,
        logger: _FakeLoggerService(),
      );
      final basisMitglied = _basisMitglied();

      await expectLater(
        () => repository.updateMember(
          accessToken: 'token-123',
          basisMitglied: basisMitglied,
          zielMitglied: basisMitglied.copyWith(vorname: 'Juliane'),
        ),
        throwsA(matcher),
      );
    }

    test(
      'ordnet NetworkAccessBlockedException als NetworkBlocked ein',
      () async {
        await expectUpdateThrows(
          const NetworkAccessBlockedException(
            reason: NetworkAccessBlockedReason.noMobileDataEnabled,
            connectionType: NetworkConnectionType.mobile,
            message: 'Mobile Daten sind deaktiviert.',
          ),
          isA<MemberWriteNetworkBlockedException>().having(
            (error) => error.message,
            'message',
            'Mobile Daten sind deaktiviert.',
          ),
        );
      },
    );

    test('ordnet 404 als nicht retrybare Ablehnung ein', () async {
      await expectUpdateThrows(
        const HitobitoPeopleException('Not Found', statusCode: 404),
        isA<MemberWriteRejectedException>(),
      );
    });

    test('ordnet 409 als Konflikt ein', () async {
      await expectUpdateThrows(
        const HitobitoPeopleException('Conflict', statusCode: 409),
        isA<MemberWriteConflictException>(),
      );
    });

    test('ordnet 422 ohne Felddetails als Ablehnung ein', () async {
      await expectUpdateThrows(
        const HitobitoPeopleException('Unprocessable', statusCode: 422),
        isA<MemberWriteRejectedException>(),
      );
    });

    test('ordnet 401 ohne Executor als AuthRequired ein', () async {
      await expectUpdateThrows(
        const HitobitoPeopleException('Unauthorized', statusCode: 401),
        isA<MemberWriteAuthRequiredException>(),
      );
    });

    test(
      'ordnet 500 als einfache MemberWriteException mit API-Meldung ein',
      () async {
        await expectUpdateThrows(
          const HitobitoPeopleException('Server kaputt', statusCode: 500),
          isA<MemberWriteException>()
              .having(
                (error) => error.runtimeType,
                'runtimeType',
                MemberWriteException,
              )
              .having((error) => error.message, 'message', 'Server kaputt'),
        );
      },
    );

    test(
      'ordnet API-Fehler ohne Statuscode als einfache MemberWriteException ein',
      () async {
        await expectUpdateThrows(
          const HitobitoPeopleException('Unbekannt'),
          isA<MemberWriteException>().having(
            (error) => error.runtimeType,
            'runtimeType',
            MemberWriteException,
          ),
        );
      },
    );

    test('ordnet Transportfehler als nicht erreichbar ein', () async {
      for (final error in <Object>[
        const SocketException('Connection reset'),
        TimeoutException('Zeitueberschreitung'),
        http.ClientException('Verbindung abgebrochen'),
      ]) {
        await expectUpdateThrows(
          error,
          isA<MemberWriteNetworkUnavailableException>(),
        );
      }
    });

    test(
      'reicht Nicht-API-Fehler unveraendert durch statt sie abzubilden',
      () async {
        await expectUpdateThrows(
          StateError('Transportfehler'),
          isA<StateError>(),
        );
      },
    );

    test('wirft AuthRequired, wenn der Executor null liefert', () async {
      final peopleService = _FakeHitobitoPeopleService();
      final repository = HitobitoMemberWriteRepository(
        peopleService: peopleService,
        remoteAccessExecutor: _nullExecutor,
        logger: _FakeLoggerService(),
      );
      final basisMitglied = _basisMitglied();

      await expectLater(
        () => repository.updateMember(
          accessToken: 'token-123',
          basisMitglied: basisMitglied,
          zielMitglied: basisMitglied.copyWith(vorname: 'Juliane'),
        ),
        throwsA(isA<MemberWriteAuthRequiredException>()),
      );
      expect(peopleService.calls, isEmpty);
    });

    test(
      'ordnet 500 nach Retry-Executor als einfache MemberWriteException ein',
      () async {
        await expectUpdateThrows(
          const HitobitoPeopleException('Server kaputt', statusCode: 500),
          isA<MemberWriteException>().having(
            (error) => error.runtimeType,
            'runtimeType',
            MemberWriteException,
          ),
          executor: _retryingExecutor,
        );
      },
    );
  });

  group('fetchRemoteMember', () {
    test('liefert das Remote-Mitglied', () async {
      final peopleService = _FakeHitobitoPeopleService()
        ..remoteResource = _remoteResource(firstName: 'Jule');
      final repository = HitobitoMemberWriteRepository(
        peopleService: peopleService,
        logger: _FakeLoggerService(),
      );

      final result = await repository.fetchRemoteMember(
        accessToken: 'token-123',
        personId: 23,
      );

      expect(result.vorname, 'Jule');
      expect(result.personId, 23);
      expect(peopleService.calls, <String>['fetch:token-123']);
    });

    test('ordnet API-Fehler wie beim Update ein und loggt sie', () async {
      final logger = _FakeLoggerService();
      final peopleService = _FakeHitobitoPeopleService()
        ..fetchError = const HitobitoPeopleException(
          'Not Found',
          statusCode: 404,
        );
      final repository = HitobitoMemberWriteRepository(
        peopleService: peopleService,
        logger: logger,
      );

      await expectLater(
        () => repository.fetchRemoteMember(
          accessToken: 'token-123',
          personId: 23,
        ),
        throwsA(isA<MemberWriteRejectedException>()),
      );
      expect(
        logger.warnMessages,
        contains(
          allOf(
            contains('Fetch verworfen reason=api_exception'),
            contains('status=404'),
          ),
        ),
      );
    });

    test(
      'ordnet 500 beim Abruf als einfache MemberWriteException ein',
      () async {
        final peopleService = _FakeHitobitoPeopleService()
          ..fetchError = const HitobitoPeopleException(
            'Server kaputt',
            statusCode: 500,
          );
        final repository = HitobitoMemberWriteRepository(
          peopleService: peopleService,
          logger: _FakeLoggerService(),
        );

        await expectLater(
          () => repository.fetchRemoteMember(
            accessToken: 'token-123',
            personId: 23,
          ),
          throwsA(
            isA<MemberWriteException>().having(
              (error) => error.runtimeType,
              'runtimeType',
              MemberWriteException,
            ),
          ),
        );
      },
    );

    test(
      'ordnet Transportfehler beim Abruf als nicht erreichbar ein',
      () async {
        final peopleService = _FakeHitobitoPeopleService()
          ..fetchError = const SocketException('Network is unreachable');
        final repository = HitobitoMemberWriteRepository(
          peopleService: peopleService,
          logger: _FakeLoggerService(),
        );

        await expectLater(
          () => repository.fetchRemoteMember(
            accessToken: 'token-123',
            personId: 23,
          ),
          throwsA(isA<MemberWriteNetworkUnavailableException>()),
        );
      },
    );

    test('ordnet NetworkAccessBlockedException beim Abruf ein', () async {
      final peopleService = _FakeHitobitoPeopleService()
        ..fetchError = const NetworkAccessBlockedException(
          reason: NetworkAccessBlockedReason.offline,
          connectionType: NetworkConnectionType.offline,
          message: 'Keine Verbindung.',
        );
      final repository = HitobitoMemberWriteRepository(
        peopleService: peopleService,
        logger: _FakeLoggerService(),
      );

      await expectLater(
        () => repository.fetchRemoteMember(
          accessToken: 'token-123',
          personId: 23,
        ),
        throwsA(isA<MemberWriteNetworkBlockedException>()),
      );
    });

    test('wirft AuthRequired, wenn der Executor null liefert', () async {
      final peopleService = _FakeHitobitoPeopleService();
      final repository = HitobitoMemberWriteRepository(
        peopleService: peopleService,
        remoteAccessExecutor: _nullExecutor,
        logger: _FakeLoggerService(),
      );

      await expectLater(
        () => repository.fetchRemoteMember(
          accessToken: 'token-123',
          personId: 23,
        ),
        throwsA(isA<MemberWriteAuthRequiredException>()),
      );
      expect(peopleService.calls, isEmpty);
    });
  });
}

Future<T?> _retryingExecutor<T>({
  required String trigger,
  required Future<T> Function(AuthSession session) action,
  bool forceRefresh = false,
}) async {
  final staleSession = AuthSession(
    accessToken: 'stale-token',
    refreshToken: 'refresh-token',
    receivedAt: DateTime(2026, 4, 14, 10),
  );
  try {
    return await action(staleSession);
  } catch (error) {
    if (error is! HitobitoPeopleException || error.statusCode != 401) {
      rethrow;
    }
  }

  final refreshedSession = AuthSession(
    accessToken: 'refreshed-token',
    refreshToken: 'refresh-token',
    receivedAt: DateTime(2026, 4, 14, 10, 1),
  );
  return action(refreshedSession);
}

Future<T?> _nullExecutor<T>({
  required String trigger,
  required Future<T> Function(AuthSession session) action,
  bool forceRefresh = false,
}) async {
  return null;
}

Mitglied _basisMitglied() => Mitglied.peopleListItem(
  mitgliedsnummer: '4711',
  personId: 23,
  vorname: 'Julia',
  nachname: 'Keller',
).copyWith(updatedAt: DateTime.parse('2026-04-14T09:00:00Z'));

HitobitoPersonResource _remoteResource({
  String firstName = 'Julia',
  String lastName = 'Keller',
  DateTime? updatedAt,
  bool withoutUpdatedAt = false,
}) => HitobitoPersonResource(
  id: 23,
  firstName: firstName,
  lastName: lastName,
  membershipNumber: 4711,
  updatedAt: withoutUpdatedAt
      ? null
      : updatedAt ?? DateTime.parse('2026-04-14T09:00:00Z'),
);

class _FakeHitobitoPeopleService extends HitobitoPeopleService {
  _FakeHitobitoPeopleService()
    : super(
        config: const HitobitoAuthConfig(
          clientId: 'client',
          clientSecret: 'secret',
          authorizationUrl: 'https://demo.hitobito.com/oauth/authorize',
          tokenUrl: 'https://demo.hitobito.com/oauth/token',
          redirectUri: 'de.jlange.nami.app:/oauth/callback',
          scopeString: 'openid email api',
          discoveryUrl: '',
          profileUrl: 'https://demo.hitobito.com/oauth/profile',
        ),
      );

  final List<String> calls = <String>[];
  List<HitobitoRelationshipMutation<MitgliedKontaktTelefon>>
  lastPhoneNumberMutations =
      const <HitobitoRelationshipMutation<MitgliedKontaktTelefon>>[];
  List<HitobitoRelationshipMutation<MitgliedKontaktEmail>>
  lastAdditionalEmailMutations =
      const <HitobitoRelationshipMutation<MitgliedKontaktEmail>>[];
  List<HitobitoRelationshipMutation<MitgliedKontaktAdresse>>
  lastAdditionalAddressMutations =
      const <HitobitoRelationshipMutation<MitgliedKontaktAdresse>>[];
  HitobitoPersonResource? remoteResource;
  Object? updateError;
  Object? fetchError;
  Map<String, dynamic>? lastChangedAttributes;
  Mitglied? lastUpdatedMitglied;

  int get updateCallCount =>
      calls.where((entry) => entry.startsWith('update:')).length;

  @override
  Future<HitobitoPersonResource> fetchPersonResourceById(
    String accessToken,
    int personId,
  ) async {
    calls.add('fetch:$accessToken');
    if (fetchError != null) {
      throw fetchError!;
    }
    final configuredResource = remoteResource;
    if (configuredResource != null) {
      return configuredResource;
    }
    return HitobitoPersonResource(
      id: personId,
      firstName: accessToken == 'refreshed-token' ? 'Juliane' : 'Julia',
      lastName: 'Keller',
      membershipNumber: 4711,
      updatedAt: DateTime.parse('2026-04-14T09:00:00Z'),
    );
  }

  @override
  Future<void> updatePerson(
    String accessToken, {
    required Mitglied mitglied,
  }) async {
    calls.add('update:$accessToken');
    if (updateError != null) {
      throw updateError!;
    }
    if (accessToken == 'stale-token') {
      throw const HitobitoPeopleException(
        'People-Anfrage fehlgeschlagen (401).',
        statusCode: 401,
      );
    }
  }

  @override
  Future<void> updatePersonWithRelationships(
    String accessToken, {
    required Mitglied mitglied,
    Map<String, dynamic>? changedAttributes,
    List<HitobitoRelationshipMutation<MitgliedKontaktTelefon>>
        phoneNumberMutations =
        const <HitobitoRelationshipMutation<MitgliedKontaktTelefon>>[],
    List<HitobitoRelationshipMutation<MitgliedKontaktEmail>>
        additionalEmailMutations =
        const <HitobitoRelationshipMutation<MitgliedKontaktEmail>>[],
    List<HitobitoRelationshipMutation<MitgliedKontaktAdresse>>
        additionalAddressMutations =
        const <HitobitoRelationshipMutation<MitgliedKontaktAdresse>>[],
  }) async {
    lastChangedAttributes = changedAttributes;
    lastUpdatedMitglied = mitglied;
    lastPhoneNumberMutations = phoneNumberMutations;
    lastAdditionalEmailMutations = additionalEmailMutations;
    lastAdditionalAddressMutations = additionalAddressMutations;
    await updatePerson(accessToken, mitglied: mitglied);
  }
}

class _FakeLoggerService extends LoggerService {
  _FakeLoggerService()
    : super(
        settingsRepository: _FakeAppSettingsRepository(),
        navigatorKey: GlobalKey<NavigatorState>(),
      );

  final List<String> warnMessages = <String>[];

  @override
  Future<void> log(String service, String message) async {}

  @override
  Future<void> logInfo(String service, String message) async {}

  @override
  Future<void> logWarn(String service, String message) async {
    warnMessages.add('$service|$message');
  }

  @override
  Future<void> logError(
    String service,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) async {}
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
  Future<void> saveGeburstagsbenachrichtigungStufen(Set stufen) async {}

  @override
  Future<void> saveLanguageCode(String code) async {}

  @override
  Future<void> saveNotificationsEnabled(bool enabled) async {}

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {}
}
