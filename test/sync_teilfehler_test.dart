import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nami/data/arbeitskontext/hitobito_arbeitskontext_read_model_repository.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_local_repository.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/arbeitskontext/usecases/bestimme_startkontext_usecase.dart';
import 'package:nami/domain/auth/auth_profile.dart';
import 'package:nami/domain/auth/auth_session.dart';
import 'package:nami/domain/auth/auth_state.dart';
import 'package:nami/presentation/model/arbeitskontext_model.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_data_retention_policy.dart';
import 'package:nami/services/hitobito_efz_service.dart';
import 'package:nami/services/hitobito_groups_service.dart';
import 'package:nami/services/hitobito_people_service.dart';
import 'package:nami/services/hitobito_qualifications_service.dart';
import 'package:nami/services/hitobito_roles_service.dart';

import 'support/auth_session_fakes.dart';
import 'support/fake_graphiti_list_api.dart';
import 'support/fake_logger_service.dart';

/// Ein Sync mit Teilfehler darf nicht als Erfolg zaehlen: kein neuer
/// Datenstand, keine verlaengerte Datenfrist, kein gespeicherter Teilstand
/// (A-15). Echte Models und Services gegen eine Graphiti-Nachbildung, die
/// Uhr ist fest vorgegeben.
void main() {
  const stammId = 3;
  const woelflingeId = 31;
  // Mehr als eine 1000er-Seite, damit ein Abbruch nach Seite 1 moeglich ist.
  const personenImStamm = 1200;
  final start = DateTime(2026, 1, 5, 9);

  late DateTime jetzt;
  late FakeGraphitiListApi api;
  late FakeSensitiveStorageService sensitiveStorage;
  late AuthSessionModel authModel;
  late _InMemoryLocalRepository localRepository;
  late ArbeitskontextModel arbeitskontextModel;

  final config = HitobitoAuthConfig.fromBaseUrl(
    clientId: 'client',
    clientSecret: 'secret',
    baseUrl: 'https://demo.hitobito.com',
    redirectUri: 'de.jlange.nami.app:/oauth/callback',
    scopeString: 'openid email api',
  );

  GraphitiRecord person(int id) => GraphitiRecord(
    id: id,
    attributes: <String, dynamic>{
      'first_name': 'Person',
      'last_name': '$id',
      'membership_number': 100000 + id,
      'primary_group_id': woelflingeId,
    },
  );

  ArbeitskontextModel neuesArbeitskontextModel() {
    return ArbeitskontextModel(
      localRepository: localRepository,
      readModelRepository: HitobitoArbeitskontextReadModelRepository(
        groupsService: HitobitoGroupsService(
          config: config,
          httpClient: api.client,
        ),
        peopleService: HitobitoPeopleService(
          config: config,
          httpClient: api.client,
        ),
        rolesService: HitobitoRolesService(
          config: config,
          httpClient: api.client,
        ),
        efzService: HitobitoEfzService(config: config, httpClient: api.client),
        qualificationsService: HitobitoQualificationsService(
          config: config,
          httpClient: api.client,
        ),
        localRepository: localRepository,
      ),
      groupsService: HitobitoGroupsService(
        config: config,
        httpClient: api.client,
      ),
      bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
      remoteAccessExecutor: authModel.executeRemoteAccess,
      logger: FakeLoggerService(),
    );
  }

  Future<void> sync() {
    return authModel.syncHitobitoData(
      force: true,
      trigger: 'test',
      syncMembers: (_) => arbeitskontextModel.syncVollstaendig(
        session: authModel.session,
        profile: authModel.profile,
      ),
    );
  }

  Set<String> mitgliedsnummern(ArbeitskontextReadModel? readModel) => <String>{
    for (final mitglied in readModel?.mitglieder ?? const [])
      mitglied.mitgliedsnummer,
  };

  setUp(() async {
    jetzt = start;
    api = FakeGraphitiListApi()
      ..setze('groups', <GraphitiRecord>[
        const GraphitiRecord(
          id: stammId,
          attributes: <String, dynamic>{
            'name': 'Stamm Musterdorf',
            'layer': true,
            'layer_group_id': stammId,
            'type': 'Group::Stamm',
          },
        ),
        const GraphitiRecord(
          id: woelflingeId,
          attributes: <String, dynamic>{
            'name': 'Woelflinge',
            'layer': false,
            'parent_id': stammId,
            'layer_group_id': stammId,
            'type': 'Group::Woelflinge',
          },
        ),
      ])
      ..setze('people', <GraphitiRecord>[
        for (var id = 1; id <= personenImStamm; id++) person(id),
      ])
      ..setze('roles', const <GraphitiRecord>[])
      ..setze('qualifications', const <GraphitiRecord>[])
      ..setze('efz_einsichtnahmen', const <GraphitiRecord>[]);
    sensitiveStorage = FakeSensitiveStorageService();
    authModel = AuthSessionModel(
      repository: InMemoryAuthSessionRepository(),
      profileRepository: InMemoryAuthProfileRepository(),
      oauthService: FakeOauthService(
        sessionToReturn: AuthSession(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          receivedAt: start,
        ),
        profileToReturn: const AuthProfile(
          namiId: 1,
          primaryGroupId: stammId,
          roles: <AuthProfileRole>[
            AuthProfileRole(
              groupId: stammId,
              groupName: 'Stamm Musterdorf',
              roleName: 'Vorstand',
              roleClass: 'Group::Stamm::Vorstand',
              permissions: <String>['layer_and_below_read'],
            ),
          ],
        ),
      ),
      biometricLockService: FakeBiometricLockService(),
      sensitiveStorageService: sensitiveStorage,
      retentionPolicy: HitobitoDataRetentionPolicy(
        maxDataAge: const Duration(days: 90),
        refreshInterval: const Duration(hours: 24),
        nowProvider: () => jetzt,
      ),
      logger: FakeLoggerService(),
    );
    await authModel.signIn();
    localRepository = _InMemoryLocalRepository();
    arbeitskontextModel = neuesArbeitskontextModel();
  });

  test('vollstaendiger Sync zaehlt als Erfolg', () async {
    await sync();

    expect(authModel.lastSyncAttemptResult, SyncAttemptResult.success);
    expect(authModel.lastSensitiveSyncAt, start);
    expect(localRepository.cached?.mitglieder, hasLength(personenImStamm));
  });

  test('Abbruch nach Personenseite 1 ist kein Erfolg und behaelt den alten '
      'Stand', () async {
    await sync();
    final vorher = localRepository.cached;
    final nummernVorher = mitgliedsnummern(vorher);

    // Auf dem Server ist Person 1 ausgetreten und Person 1201 neu.
    api.setze('people', <GraphitiRecord>[
      for (var id = 2; id <= personenImStamm + 1; id++) person(id),
    ]);
    api.abbruchAbSeite['people'] = 2;
    jetzt = start.add(const Duration(days: 1));
    await sync();

    expect(authModel.lastSyncAttemptResult, isNot(SyncAttemptResult.success));
    expect(authModel.lastSensitiveSyncAt, start);
    expect(identical(localRepository.cached, vorher), isTrue);
    expect(mitgliedsnummern(arbeitskontextModel.readModel), nummernVorher);
    expect(arbeitskontextModel.isReady, isTrue);
    expect(arbeitskontextModel.errorMessage, isNotNull);
  });

  test('Abbruch ohne Cache speichert keinen Teilstand und zeigt den '
      'Fehlerbildschirm', () async {
    api.abbruchAbSeite['people'] = 2;

    await sync();

    expect(authModel.lastSyncAttemptResult, isNot(SyncAttemptResult.success));
    expect(authModel.lastSensitiveSyncAt, isNull);
    expect(localRepository.cached, isNull);
    expect(arbeitskontextModel.readModel, isNull);
    expect(arbeitskontextModel.hasError, isTrue);
  });

  test(
    'Gruppenfehler bei Cache mit geladenen Rollen ist kein Erfolg',
    () async {
      await sync();
      expect(localRepository.cached?.rolesSindGeladen, isTrue);

      api.dauerfehler['groups'] = 500;
      jetzt = start.add(const Duration(days: 1));
      await sync();

      expect(authModel.lastSyncAttemptResult, SyncAttemptResult.serverError);
      expect(authModel.lastSensitiveSyncAt, start);
    },
  );

  test('Sync waehrend des Starts aus dem Cache laedt trotzdem neu', () async {
    await sync();
    // App-Neustart: neues Model, das zuerst aus dem Cache startet.
    arbeitskontextModel = neuesArbeitskontextModel();
    api.requests.clear();
    jetzt = start.add(const Duration(days: 1));
    final verzoegerung = Completer<void>();
    localRepository.ladeVerzoegerung = verzoegerung.future;

    final cacheStart = arbeitskontextModel.initializeForProfile(
      authModel.profile!,
      session: authModel.session,
    );
    final laufenderSync = sync();
    await pumpEventQueue();
    verzoegerung.complete();
    await Future.wait(<Future<void>>[cacheStart, laufenderSync]);

    expect(api.anfragen('people'), greaterThan(0));
    expect(authModel.lastSyncAttemptResult, SyncAttemptResult.success);
    expect(authModel.lastSensitiveSyncAt, jetzt);
  });

  test('dauerhafter 500 an Tag 60, 120 und 200: die 90-Tage-Loeschung '
      'greift', () async {
    await sync();
    api.dauerfehler['people'] = 500;

    jetzt = start.add(const Duration(days: 60));
    await sync();
    expect(authModel.lastSyncAttemptResult, SyncAttemptResult.serverError);
    expect(authModel.lastSensitiveSyncAt, start);
    expect(authModel.state, AuthState.signedIn);

    jetzt = start.add(const Duration(days: 120));
    await sync();
    expect(authModel.state, AuthState.signedOut);
    expect(authModel.lastSensitiveSyncAt, isNull);
    expect(sensitiveStorage.lastSensitiveSyncAt, isNull);

    jetzt = start.add(const Duration(days: 200));
    await sync();
    expect(authModel.state, AuthState.signedOut);
    expect(authModel.lastSensitiveSyncAt, isNull);
    expect(sensitiveStorage.lastSensitiveSyncAt, isNull);
  });
}

class _InMemoryLocalRepository implements ArbeitskontextLocalRepository {
  ArbeitskontextReadModel? cached;
  Future<void>? ladeVerzoegerung;

  @override
  Future<void> clearCached() async {
    cached = null;
  }

  @override
  Future<ArbeitskontextReadModel?> loadLastCached() async {
    await ladeVerzoegerung;
    return cached;
  }

  @override
  Future<void> saveCached(ArbeitskontextReadModel readModel) async {
    cached = readModel;
  }
}
