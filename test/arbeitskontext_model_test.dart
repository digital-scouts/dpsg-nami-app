import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/data/arbeitskontext/hitobito_group_resource.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_local_repository.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model_repository.dart';
import 'package:nami/domain/arbeitskontext/usecases/bestimme_startkontext_usecase.dart';
import 'package:nami/domain/auth/auth_profile.dart';
import 'package:nami/domain/auth/auth_session.dart';
import 'package:nami/domain/auth/auth_state.dart';
import 'package:nami/domain/settings/app_settings.dart';
import 'package:nami/domain/settings/app_settings_repository.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/presentation/model/arbeitskontext_model.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_groups_service.dart';
import 'package:nami/services/logger_service.dart';

void main() {
  test(
    'stellt zuerst den lokal gespeicherten Arbeitskontext wieder her',
    () async {
      final cached = ArbeitskontextReadModel(
        arbeitskontext: Arbeitskontext(
          aktiverLayer: const ArbeitskontextLayer(id: 42, name: 'Bezirk Sieg'),
          verfuegbareLayer: const <ArbeitskontextLayer>[
            ArbeitskontextLayer(id: 11, name: 'Stamm Musterdorf'),
          ],
        ),
      );
      final model = ArbeitskontextModel(
        localRepository: _FakeArbeitskontextLocalRepository(cached: cached),
        readModelRepository: _FakeArbeitskontextReadModelRepository(),
        groupsService: _FakeHitobitoGroupsService(),
        bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
        logger: _FakeLoggerService(),
      );

      await model.syncForAuth(
        authState: AuthState.signedIn,
        session: AuthSession(
          accessToken: 'token-1',
          receivedAt: DateTime(2026, 3, 31),
        ),
        profile: const AuthProfile(
          namiId: 1,
          roles: <AuthProfileRole>[
            AuthProfileRole(
              groupId: 11,
              groupName: 'Stamm Musterdorf',
              roleName: 'Mitglied',
              roleClass: 'Group::Mitglied',
            ),
          ],
        ),
      );

      expect(model.isReady, isTrue);
      expect(model.readModel, cached);
      expect(model.arbeitskontext?.aktiverLayer.id, 42);
    },
  );

  test(
    'leitet ohne Cache einen Startkontext deterministisch aus Rollen ab',
    () async {
      final model = ArbeitskontextModel(
        localRepository: _FakeArbeitskontextLocalRepository(),
        readModelRepository: _FakeArbeitskontextReadModelRepository(),
        groupsService: _FakeHitobitoGroupsService(
          groups: const <HitobitoGroupResource>[
            HitobitoGroupResource(id: 20, name: 'Bezirk Rhein', isLayer: true),
            HitobitoGroupResource(
              id: 11,
              name: 'Stamm Auenland',
              isLayer: true,
            ),
          ],
        ),
        bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
        logger: _FakeLoggerService(),
      );

      await model.syncForAuth(
        authState: AuthState.signedIn,
        session: AuthSession(
          accessToken: 'token-2',
          receivedAt: DateTime(2026, 3, 31),
        ),
        profile: const AuthProfile(
          namiId: 2,
          primaryGroupId: 20,
          roles: <AuthProfileRole>[
            AuthProfileRole(
              groupId: 20,
              groupName: 'Bezirk Rhein',
              roleName: 'Bezirksleitung',
              roleClass: 'Group::Bezirk::Leitung',
              permissions: <String>['layer_read'],
            ),
          ],
        ),
      );

      expect(model.isReady, isTrue);
      expect(model.arbeitskontext?.aktiverLayer.id, 20);
      expect(model.arbeitskontext?.aktiverLayer.name, 'Bezirk Rhein');
      expect(model.readModel?.mitglieder, isEmpty);
      expect(model.readModel?.gruppen, isEmpty);
    },
  );

  test(
    'meldet einen expliziten Zustand ohne App-Berechtigung, wenn kein relevanter Layer ableitbar ist',
    () async {
      final model = ArbeitskontextModel(
        localRepository: _FakeArbeitskontextLocalRepository(),
        readModelRepository: _FakeArbeitskontextReadModelRepository(),
        groupsService: _FakeHitobitoGroupsService(),
        bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
        logger: _FakeLoggerService(),
      );

      await model.syncForAuth(
        authState: AuthState.signedIn,
        session: AuthSession(
          accessToken: 'token-3',
          receivedAt: DateTime(2026, 3, 31),
        ),
        profile: const AuthProfile(namiId: 3),
      );

      expect(model.isUnauthorized, isTrue);
      expect(model.errorMessage, ArbeitskontextModel.unauthorizedMessage);
    },
  );

  test(
    'setzt den Arbeitskontext bei Sign-out wieder in den Initialzustand',
    () async {
      final model = ArbeitskontextModel(
        localRepository: _FakeArbeitskontextLocalRepository(),
        readModelRepository: _FakeArbeitskontextReadModelRepository(),
        groupsService: _FakeHitobitoGroupsService(
          groups: const <HitobitoGroupResource>[
            HitobitoGroupResource(
              id: 11,
              name: 'Stamm Musterdorf',
              isLayer: true,
            ),
          ],
        ),
        bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
        logger: _FakeLoggerService(),
      );

      await model.syncForAuth(
        authState: AuthState.signedIn,
        session: AuthSession(
          accessToken: 'token-4',
          receivedAt: DateTime(2026, 3, 31),
        ),
        profile: const AuthProfile(
          namiId: 4,
          primaryGroupId: 11,
          roles: <AuthProfileRole>[
            AuthProfileRole(
              groupId: 11,
              groupName: 'Stamm Musterdorf',
              roleName: 'Leitung',
              roleClass: 'Group::Stamm::Leitung',
              permissions: <String>['layer_read'],
            ),
          ],
        ),
      );
      await model.syncForAuth(
        authState: AuthState.signedOut,
        session: null,
        profile: null,
      );

      expect(model.status, ArbeitskontextStatus.initial);
      expect(model.arbeitskontext, isNull);
      expect(model.readModel, isNull);
      expect(model.errorMessage, isNull);
    },
  );

  test(
    'wechselt zu einem erreichbaren Layer und behaelt den neuen Kontext',
    () async {
      final readModelRepository = _FakeArbeitskontextReadModelRepository();
      final model = ArbeitskontextModel(
        localRepository: _FakeArbeitskontextLocalRepository(),
        readModelRepository: readModelRepository,
        groupsService: _FakeHitobitoGroupsService(
          groups: const <HitobitoGroupResource>[
            HitobitoGroupResource(
              id: 11,
              name: 'Stamm Musterdorf',
              isLayer: true,
            ),
            HitobitoGroupResource(id: 20, name: 'Bezirk Rhein', isLayer: true),
          ],
        ),
        bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
        logger: _FakeLoggerService(),
      );
      final session = AuthSession(
        accessToken: 'token-5',
        receivedAt: DateTime(2026, 3, 31),
      );
      const profile = AuthProfile(
        namiId: 5,
        primaryGroupId: 11,
        roles: <AuthProfileRole>[
          AuthProfileRole(
            groupId: 11,
            groupName: 'Stamm Musterdorf',
            roleName: 'Leitung Stamm',
            roleClass: 'Group::Stamm::Leitung',
            permissions: <String>['layer_read'],
          ),
          AuthProfileRole(
            groupId: 20,
            groupName: 'Bezirk Rhein',
            roleName: 'Leitung Bezirk',
            roleClass: 'Group::Bezirk::Leitung',
            permissions: <String>['layer_read'],
          ),
        ],
      );

      await model.syncForAuth(
        authState: AuthState.signedIn,
        session: session,
        profile: profile,
      );

      final success = await model.switchToLayer(
        targetLayer: const ArbeitskontextLayer(id: 20, name: 'Bezirk Rhein'),
        session: session,
        profile: profile,
      );

      expect(success, isTrue);
      expect(model.isSwitchingLayer, isFalse);
      expect(model.arbeitskontext?.aktiverLayer.id, 20);
      expect(
        readModelRepository.lastRefreshArbeitskontext?.aktiverLayer.id,
        20,
      );
    },
  );

  test(
    'behaelt den bisherigen Kontext bei fehlgeschlagenem Layerwechsel',
    () async {
      final logger = _FakeLoggerService();
      final readModelRepository = _FakeArbeitskontextReadModelRepository(
        refreshError: StateError('offline'),
      );
      final cached = ArbeitskontextReadModel(
        arbeitskontext: Arbeitskontext(
          aktiverLayer: const ArbeitskontextLayer(
            id: 11,
            name: 'Stamm Musterdorf',
          ),
          verfuegbareLayer: const <ArbeitskontextLayer>[
            ArbeitskontextLayer(id: 20, name: 'Bezirk Rhein'),
          ],
        ),
      );
      final model = ArbeitskontextModel(
        localRepository: _FakeArbeitskontextLocalRepository(cached: cached),
        readModelRepository: readModelRepository,
        groupsService: _FakeHitobitoGroupsService(
          groups: const <HitobitoGroupResource>[
            HitobitoGroupResource(
              id: 11,
              name: 'Stamm Musterdorf',
              isLayer: true,
            ),
            HitobitoGroupResource(id: 20, name: 'Bezirk Rhein', isLayer: true),
          ],
        ),
        bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
        logger: logger,
      );
      final session = AuthSession(
        accessToken: 'token-6',
        receivedAt: DateTime(2026, 3, 31),
      );
      const profile = AuthProfile(
        namiId: 6,
        primaryGroupId: 11,
        roles: <AuthProfileRole>[
          AuthProfileRole(
            groupId: 11,
            groupName: 'Stamm Musterdorf',
            roleName: 'Leitung Stamm',
            roleClass: 'Group::Stamm::Leitung',
            permissions: <String>['layer_read'],
          ),
          AuthProfileRole(
            groupId: 20,
            groupName: 'Bezirk Rhein',
            roleName: 'Leitung Bezirk',
            roleClass: 'Group::Bezirk::Leitung',
            permissions: <String>['layer_read'],
          ),
        ],
      );

      await model.syncForAuth(
        authState: AuthState.signedIn,
        session: session,
        profile: profile,
      );

      final success = await model.switchToLayer(
        targetLayer: const ArbeitskontextLayer(id: 20, name: 'Bezirk Rhein'),
        session: session,
        profile: profile,
      );

      expect(success, isFalse);
      expect(model.arbeitskontext?.aktiverLayer.id, 11);
      expect(model.errorMessage, ArbeitskontextModel.layerSwitchFailedMessage);
      expect(model.isSwitchingLayer, isFalse);
      expect(
        logger.messages,
        contains(
          contains('Arbeitskontext-Wechsel fehlgeschlagen: Bad state: offline'),
        ),
      );
    },
  );

  test(
    'group_and_below_read macht genau den zugehoerigen Layer relevant',
    () async {
      final model = ArbeitskontextModel(
        localRepository: _FakeArbeitskontextLocalRepository(),
        readModelRepository: _FakeArbeitskontextReadModelRepository(),
        groupsService: _FakeHitobitoGroupsService(
          groups: const <HitobitoGroupResource>[
            HitobitoGroupResource(id: 10, name: 'Bezirk Rhein', isLayer: true),
            HitobitoGroupResource(
              id: 11,
              name: 'Stamm Musterdorf',
              isLayer: true,
              parentId: 10,
              layerGroupId: 11,
            ),
            HitobitoGroupResource(
              id: 101,
              name: 'Vorstand',
              isLayer: false,
              parentId: 10,
              layerGroupId: 10,
            ),
          ],
        ),
        bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
        logger: _FakeLoggerService(),
      );

      await model.syncForAuth(
        authState: AuthState.signedIn,
        session: AuthSession(
          accessToken: 'token-7',
          receivedAt: DateTime(2026, 3, 31),
        ),
        profile: const AuthProfile(
          namiId: 7,
          primaryGroupId: 101,
          roles: <AuthProfileRole>[
            AuthProfileRole(
              groupId: 101,
              groupName: 'Vorstand',
              roleName: 'Vorsitz',
              roleClass: 'Group::Bezirk::Vorstand',
              permissions: <String>['group_and_below_read'],
            ),
          ],
        ),
      );

      expect(model.isReady, isTrue);
      expect(model.arbeitskontext?.aktiverLayer.id, 10);
      expect(model.arbeitskontext?.verfuegbareLayer, isEmpty);
    },
  );
}

class _FakeArbeitskontextLocalRepository
    implements ArbeitskontextLocalRepository {
  _FakeArbeitskontextLocalRepository({this.cached});

  final ArbeitskontextReadModel? cached;

  @override
  Future<void> clearCached() async {}

  @override
  Future<ArbeitskontextReadModel?> loadLastCached() async => cached;

  @override
  Future<void> saveCached(ArbeitskontextReadModel readModel) async {}
}

class _FakeArbeitskontextReadModelRepository
    implements ArbeitskontextReadModelRepository {
  _FakeArbeitskontextReadModelRepository({this.refreshError});

  final Object? refreshError;
  Arbeitskontext? lastRefreshArbeitskontext;

  @override
  Future<ArbeitskontextReadModel> loadCached(
    Arbeitskontext arbeitskontext,
  ) async {
    return ArbeitskontextReadModel(arbeitskontext: arbeitskontext);
  }

  @override
  Future<ArbeitskontextReadModel> refresh({
    required String accessToken,
    required Arbeitskontext arbeitskontext,
  }) async {
    lastRefreshArbeitskontext = arbeitskontext;
    if (refreshError != null) {
      throw refreshError!;
    }
    return ArbeitskontextReadModel(arbeitskontext: arbeitskontext);
  }
}

class _FakeHitobitoGroupsService extends HitobitoGroupsService {
  _FakeHitobitoGroupsService({
    List<HitobitoGroupResource> groups = const <HitobitoGroupResource>[],
  }) : _groups = groups,
       super(
         config: const HitobitoAuthConfig(
           clientId: 'client',
           clientSecret: 'secret',
           authorizationUrl: 'https://demo.hitobito.com/oauth/authorize',
           tokenUrl: 'https://demo.hitobito.com/oauth/token',
           redirectUri: 'de.jlange.nami.app:/oauth/callback',
           scopeString: 'openid email',
           discoveryUrl: '',
           profileUrl: 'https://demo.hitobito.com/oauth/profile',
         ),
       );

  final List<HitobitoGroupResource> _groups;

  @override
  Future<List<HitobitoGroupResource>> fetchAccessibleGroups(
    String accessToken,
  ) async => _groups;
}

class _FakeLoggerService extends LoggerService {
  _FakeLoggerService()
    : super(
        settingsRepository: _FakeAppSettingsRepository(),
        navigatorKey: GlobalKey<NavigatorState>(),
      );

  final List<String> messages = <String>[];

  @override
  Future<void> log(String service, String message) async {
    messages.add(message);
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
  Future<void> saveGeburstagsbenachrichtigungStufen(Set<Stufe> stufen) async {}

  @override
  Future<void> saveLanguageCode(String code) async {}

  @override
  Future<void> saveNotificationsEnabled(bool enabled) async {}

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {}
}
