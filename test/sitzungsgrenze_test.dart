import 'dart:async';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:nami/data/arbeitskontext/hitobito_group_resource.dart';
import 'package:nami/data/arbeitskontext/secure_arbeitskontext_local_repository.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_local_repository.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model_repository.dart';
import 'package:nami/domain/arbeitskontext/usecases/bestimme_startkontext_usecase.dart';
import 'package:nami/domain/auth/auth_profile.dart';
import 'package:nami/domain/auth/auth_session.dart';
import 'package:nami/domain/auth/auth_state.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/presentation/model/arbeitskontext_model.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/services/hitobito_data_retention_policy.dart';
import 'package:nami/services/hitobito_groups_service.dart';
import 'package:nami/services/sensitive_storage_service.dart';

import 'support/auth_session_fakes.dart';
import 'support/fake_logger_service.dart';
import 'support/hitobito_jsonapi_fixtures.dart';

/// Ein Vorgang, der eine Sitzung ueberdauert, darf in der naechsten weder
/// Daten speichern noch anzeigen.
void main() {
  final jetzt = DateTime(2026, 10, 7, 12);

  group('Logout waehrend eines laufenden Refresh', () {
    late Directory tempDir;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      SensitiveStorageService.resetForTest();
      tempDir = await Directory.systemTemp.createTemp('sitzungsgrenze_');
      Hive.init(tempDir.path);
    });

    tearDown(() async {
      SensitiveStorageService.resetForTest();
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    test('legt weder Box noch Schluessel neu an', () async {
      final storage = SensitiveStorageService();
      // Bestehende Anmeldung aus einer frueheren App-Sitzung.
      storage.beginSession();
      await storage.savePrincipal('person-a');
      await storage.saveLastSensitiveSyncAt(jetzt);

      final authModel = AuthSessionModel(
        repository: InMemoryAuthSessionRepository(
          initialSession: _session('token-a', principal: 'person-a'),
        ),
        profileRepository: InMemoryAuthProfileRepository(
          profile: _profilA,
          lastSyncAt: jetzt,
        ),
        oauthService: FakeOauthService(
          sessionToReturn: _session('token-a', principal: 'person-a'),
          profileToReturn: _profilA,
        ),
        biometricLockService: FakeBiometricLockService(),
        sensitiveStorageService: storage,
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
          nowProvider: () => jetzt,
        ),
        logger: FakeLoggerService(),
      );
      final readModelRepository = _SteuerbaresReadModelRepository();
      final refreshA = readModelRepository.blockiere('token-a');
      final arbeitskontextModel = ArbeitskontextModel(
        localRepository: SecureArbeitskontextLocalRepository(
          sensitiveStorageService: storage,
        ),
        readModelRepository: readModelRepository,
        groupsService: _FakeGroupsService(),
        bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
        remoteAccessExecutor: authModel.executeRemoteAccess,
        sessionGeneration: () => authModel.sessionGeneration,
        logger: FakeLoggerService(),
      );

      await authModel.initialize();
      expect(authModel.state, AuthState.signedIn);
      final laden = arbeitskontextModel.syncForAuth(
        authState: authModel.state,
        session: authModel.session,
        profile: authModel.profile,
      );
      await readModelRepository.gestartet('token-a');

      await authModel.logout();
      await arbeitskontextModel.syncForAuth(
        authState: authModel.state,
        session: authModel.session,
        profile: authModel.profile,
      );
      refreshA.complete();
      await laden;

      expect(await Hive.boxExists('hitobito_arbeitskontext_box'), isFalse);
      expect(
        await Hive.boxExists(SensitiveStorageService.secureMetaBoxName),
        isFalse,
      );
      expect(
        await const FlutterSecureStorage().read(
          key: 'hitobito_hive_encryption_key',
        ),
        isNull,
      );
      expect(arbeitskontextModel.readModel, isNull);
      expect(arbeitskontextModel.status, ArbeitskontextStatus.initial);
    });
  });

  group('Kontowechsel waehrend eines laufenden Refresh', () {
    test('verwirft das Ergebnis des alten Kontos ohne Mischen', () async {
      var generation = 0;
      final localRepository = _AufzeichnendesLocalRepository();
      final readModelRepository = _SteuerbaresReadModelRepository();
      final refreshA = readModelRepository.blockiere('token-a');
      final model = ArbeitskontextModel(
        localRepository: localRepository,
        readModelRepository: readModelRepository,
        groupsService: _FakeGroupsService(),
        bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
        sessionGeneration: () => generation,
        logger: FakeLoggerService(),
      );

      final ladenA = model.syncForAuth(
        authState: AuthState.signedIn,
        session: _session('token-a'),
        profile: _profilA,
      );
      await readModelRepository.gestartet('token-a');

      // Anderes Konto meldet sich an, waehrend der Vorgang von A noch laeuft.
      generation += 1;
      await model.syncForAuth(
        authState: AuthState.signedIn,
        session: _session('token-b'),
        profile: _profilB,
      );
      expect(model.isReady, isTrue);

      refreshA.complete();
      await ladenA;

      expect(
        model.readModel?.mitglieder.map((m) => m.mitgliedsnummer),
        <String>['b-1'],
      );
      expect(model.arbeitskontext?.aktiverLayer.id, 66);
      expect(
        localRepository.gespeichert.map(
          (readModel) => readModel.arbeitskontext.aktiverLayer.id,
        ),
        <int>[66],
      );
    });
  });
}

AuthSession _session(String token, {String? principal}) => AuthSession(
  accessToken: token,
  receivedAt: DateTime(2026, 10, 7),
  principal: principal,
);

const _profilA = AuthProfile(
  namiId: 1,
  primaryGroupId: 55,
  roles: <AuthProfileRole>[
    AuthProfileRole(
      groupId: 55,
      groupName: 'Stamm Talrand',
      roleName: 'Leitung',
      roleClass: 'Group::Stamm::Leitung',
      permissions: <String>['layer_read'],
    ),
  ],
);

const _profilB = AuthProfile(
  namiId: 2,
  primaryGroupId: 66,
  roles: <AuthProfileRole>[
    AuthProfileRole(
      groupId: 66,
      groupName: 'Stamm Bergblick',
      roleName: 'Leitung',
      roleClass: 'Group::Stamm::Leitung',
      permissions: <String>['layer_read'],
    ),
  ],
);

class _FakeGroupsService extends HitobitoGroupsService {
  _FakeGroupsService() : super(config: testHitobitoAuthConfig);

  @override
  Future<List<HitobitoGroupResource>> fetchAccessibleGroups(
    String accessToken,
  ) async {
    return const <HitobitoGroupResource>[
      HitobitoGroupResource(id: 55, name: 'Stamm Talrand', isLayer: true),
      HitobitoGroupResource(id: 66, name: 'Stamm Bergblick', isLayer: true),
    ];
  }
}

/// Liefert je Layer genau ein Mitglied und haelt `refresh` fuer einzelne
/// Tokens an, bis der Test sie freigibt.
class _SteuerbaresReadModelRepository
    implements ArbeitskontextReadModelRepository {
  final Map<String, Completer<void>> _blockiert = <String, Completer<void>>{};
  final Map<String, Completer<void>> _gestartet = <String, Completer<void>>{};

  Completer<void> blockiere(String token) {
    return _blockiert[token] = Completer<void>();
  }

  Future<void> gestartet(String token) {
    return (_gestartet[token] ??= Completer<void>()).future;
  }

  @override
  Future<ArbeitskontextReadModel> refresh({
    required String accessToken,
    required Arbeitskontext arbeitskontext,
    List<HitobitoGroupResource>? accessibleGroups,
    void Function(ArbeitskontextReadModel partial)? onProgress,
  }) async {
    final gestartet = _gestartet[accessToken] ??= Completer<void>();
    if (!gestartet.isCompleted) {
      gestartet.complete();
    }
    final layerId = arbeitskontext.aktiverLayer.id;
    final mitglied = Mitglied.peopleListItem(
      mitgliedsnummer: layerId == 55 ? 'a-1' : 'b-1',
      personId: layerId,
      vorname: 'Person',
      nachname: '$layerId',
    );
    final readModel = ArbeitskontextReadModel(
      arbeitskontext: arbeitskontext,
      mitglieder: <Mitglied>[mitglied],
    );
    onProgress?.call(readModel);
    await _blockiert[accessToken]?.future;
    return readModel;
  }

  @override
  Future<ArbeitskontextReadModel> loadRoles({
    required String accessToken,
    required ArbeitskontextReadModel readModel,
  }) async {
    return readModel.copyWith(rolesSindGeladen: true);
  }

  @override
  Future<ArbeitskontextReadModel> loadCached(
    Arbeitskontext arbeitskontext,
  ) async {
    return ArbeitskontextReadModel(arbeitskontext: arbeitskontext);
  }
}

class _AufzeichnendesLocalRepository implements ArbeitskontextLocalRepository {
  final List<ArbeitskontextReadModel> gespeichert = <ArbeitskontextReadModel>[];

  @override
  Future<void> clearCached() async {}

  @override
  Future<ArbeitskontextReadModel?> loadLastCached() async => null;

  @override
  Future<void> saveCached(ArbeitskontextReadModel readModel) async {
    gespeichert.add(readModel);
  }
}
