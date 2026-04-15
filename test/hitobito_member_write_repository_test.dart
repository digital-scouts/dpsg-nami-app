import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/data/arbeitskontext/hitobito_person_resource.dart';
import 'package:nami/data/member/hitobito_member_write_repository.dart';
import 'package:nami/domain/auth/auth_session.dart';
import 'package:nami/domain/member/member_write_repository.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/settings/app_settings.dart';
import 'package:nami/domain/settings/app_settings_repository.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_people_service.dart';
import 'package:nami/services/logger_service.dart';

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
        'update:refreshed-token',
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
  Object? updateError;

  @override
  Future<HitobitoPersonResource> fetchPersonResourceById(
    String accessToken,
    int personId,
  ) async {
    calls.add('fetch:$accessToken');
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
