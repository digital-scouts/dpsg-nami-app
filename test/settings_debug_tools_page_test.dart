import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/data/arbeitskontext/hitobito_group_resource.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_local_repository.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model_repository.dart';
import 'package:nami/domain/arbeitskontext/usecases/bestimme_startkontext_usecase.dart';
import 'package:nami/domain/auth/auth_profile.dart';
import 'package:nami/domain/auth/auth_profile_repository.dart';
import 'package:nami/domain/auth/auth_session.dart';
import 'package:nami/domain/auth/auth_session_repository.dart';
import 'package:nami/domain/auth/auth_state.dart';
import 'package:nami/domain/maps/stamm_map_marker.dart';
import 'package:nami/domain/maps/stamm_map_marker_repository.dart';
import 'package:nami/domain/settings/app_settings.dart';
import 'package:nami/domain/settings/app_settings_repository.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/arbeitskontext_model.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/screens/settings_debug_tools_page.dart';
import 'package:nami/services/biometric_lock_service.dart';
import 'package:nami/services/hitobito_auth_config_controller.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_data_retention_policy.dart';
import 'package:nami/services/hitobito_groups_service.dart';
import 'package:nami/services/hitobito_oauth_service.dart';
import 'package:nami/services/hitobito_people_service.dart';
import 'package:nami/services/logger_service.dart';
import 'package:nami/services/map_tile_cache_service.dart';
import 'package:nami/services/network_access_policy.dart';
import 'package:nami/services/sensitive_storage_service.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'schliesst das OAuth-Modal nach erfolgreicher Pruefung und speichert den Override',
    (tester) async {
      final logger = _FakeLoggerService();
      final mutableOauthService = _MutableOauthService();
      final groupsService = _FakeHitobitoGroupsService();
      final peopleService = HitobitoPeopleService(config: groupsService.config);
      final configController = HitobitoAuthConfigController(
        sensitiveStorageService: _FakeSensitiveStorageService(),
        oauthService: mutableOauthService,
        groupsService: groupsService,
        peopleService: peopleService,
        logger: logger,
        envConfig: groupsService.config,
      );
      await configController.initialize();

      final authModel = AuthSessionModel(
        repository: _InMemoryAuthSessionRepository(),
        profileRepository: _InMemoryAuthProfileRepository(),
        oauthService: mutableOauthService,
        biometricLockService: _FakeBiometricLockService(),
        sensitiveStorageService: _FakeSensitiveStorageService(),
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
        ),
        logger: logger,
      );
      final arbeitskontextModel = ArbeitskontextModel(
        localRepository: _ImmediateArbeitskontextLocalRepository(),
        readModelRepository: _FakeArbeitskontextReadModelRepository(),
        groupsService: groupsService,
        bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
        logger: logger,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthSessionModel>.value(value: authModel),
            ChangeNotifierProvider<ArbeitskontextModel>.value(
              value: arbeitskontextModel,
            ),
            ChangeNotifierProvider<HitobitoAuthConfigController>.value(
              value: configController,
            ),
            Provider<LoggerService>.value(value: logger),
          ],
          child: MaterialApp(
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              AppLocalizations.delegate,
            ],
            supportedLocales: const [Locale('de'), Locale('en')],
            locale: const Locale('de'),
            home: DebugToolsPage(
              oauthServiceFactory: (controller, logger) =>
                  _VerifyingOauthService(controller.config),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await _scrollDownUntilFinderExists(
        tester,
        find.byKey(const Key('debug_oauth_override_button')),
      );
      final oauthButton = find.byKey(const Key('debug_oauth_override_button'));
      await tester.ensureVisible(oauthButton);
      tester.widget<FilledButton>(oauthButton).onPressed!.call();
      await tester.pumpAndSettle();

      expect(find.text('Hitobito OAuth prüfen'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Client ID'),
        'new-client',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Client Secret'),
        'new-secret',
      );
      await tester.tap(find.text('Prüfen'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Hitobito OAuth prüfen'), findsNothing);
      expect(configController.hasOverride, isTrue);
      expect(configController.config.clientId, 'new-client');
      expect(authModel.state, isNot(AuthState.signedOut));
    },
  );

  testWidgets('fragt vor dem Zuruecksetzen nach und fuehrt den Reset aus', (
    tester,
  ) async {
    final logger = _FakeLoggerService();
    final groupsService = _FakeHitobitoGroupsService();
    final peopleService = HitobitoPeopleService(config: groupsService.config);
    final configController = HitobitoAuthConfigController(
      sensitiveStorageService: _FakeSensitiveStorageService(),
      oauthService: _MutableOauthService(),
      groupsService: groupsService,
      peopleService: peopleService,
      logger: logger,
      envConfig: groupsService.config,
    );
    await configController.initialize();

    final authModel = AuthSessionModel(
      repository: _InMemoryAuthSessionRepository(),
      profileRepository: _InMemoryAuthProfileRepository(),
      oauthService: _MutableOauthService(),
      biometricLockService: _FakeBiometricLockService(),
      sensitiveStorageService: _FakeSensitiveStorageService(),
      retentionPolicy: HitobitoDataRetentionPolicy(
        maxDataAge: const Duration(days: 90),
        refreshInterval: const Duration(hours: 24),
      ),
      logger: logger,
    );
    final arbeitskontextModel = ArbeitskontextModel(
      localRepository: _ImmediateArbeitskontextLocalRepository(),
      readModelRepository: _FakeArbeitskontextReadModelRepository(),
      groupsService: groupsService,
      bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
      logger: logger,
    );
    var resetCalled = false;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthSessionModel>.value(value: authModel),
          ChangeNotifierProvider<ArbeitskontextModel>.value(
            value: arbeitskontextModel,
          ),
          ChangeNotifierProvider<HitobitoAuthConfigController>.value(
            value: configController,
          ),
          Provider<LoggerService>.value(value: logger),
        ],
        child: MaterialApp(
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            AppLocalizations.delegate,
          ],
          supportedLocales: const [Locale('de'), Locale('en')],
          locale: const Locale('de'),
          home: DebugToolsPage(
            onResetAllData: () async {
              resetCalled = true;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    final resetButton = find.byKey(const Key('debug_reset_app_button'));
    await _scrollDownUntilFinderExists(tester, resetButton);
    await tester.ensureVisible(resetButton);
    tester.widget<FilledButton>(resetButton).onPressed!.call();
    await tester.pumpAndSettle();

    expect(find.text('Alle Daten löschen?'), findsOneWidget);

    await tester.tap(find.text('Jetzt löschen'));
    await tester.pumpAndSettle();

    expect(resetCalled, isTrue);
  });

  testWidgets('laedt Stammesuche manuell nach', (tester) async {
    final logger = _FakeLoggerService();
    final groupsService = _FakeHitobitoGroupsService();
    final peopleService = HitobitoPeopleService(config: groupsService.config);
    final configController = HitobitoAuthConfigController(
      sensitiveStorageService: _FakeSensitiveStorageService(),
      oauthService: _MutableOauthService(),
      groupsService: groupsService,
      peopleService: peopleService,
      logger: logger,
      envConfig: groupsService.config,
    );
    await configController.initialize();

    final authModel = AuthSessionModel(
      repository: _InMemoryAuthSessionRepository(),
      profileRepository: _InMemoryAuthProfileRepository(),
      oauthService: _MutableOauthService(),
      biometricLockService: _FakeBiometricLockService(),
      sensitiveStorageService: _FakeSensitiveStorageService(),
      retentionPolicy: HitobitoDataRetentionPolicy(
        maxDataAge: const Duration(days: 90),
        refreshInterval: const Duration(hours: 24),
      ),
      logger: logger,
    );
    final arbeitskontextModel = ArbeitskontextModel(
      localRepository: _ImmediateArbeitskontextLocalRepository(),
      readModelRepository: _FakeArbeitskontextReadModelRepository(),
      groupsService: groupsService,
      bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
      logger: logger,
    );
    final stammRepository = _FakeStammMapRepository();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthSessionModel>.value(value: authModel),
          ChangeNotifierProvider<ArbeitskontextModel>.value(
            value: arbeitskontextModel,
          ),
          ChangeNotifierProvider<HitobitoAuthConfigController>.value(
            value: configController,
          ),
          Provider<LoggerService>.value(value: logger),
        ],
        child: MaterialApp(
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            AppLocalizations.delegate,
          ],
          supportedLocales: const [Locale('de'), Locale('en')],
          locale: const Locale('de'),
          home: DebugToolsPage(stammMapRepository: stammRepository),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _scrollDownUntilFinderExists(
      tester,
      find.byKey(const Key('debug_refresh_stamm_markers_button')),
    );
    final stammRefreshButton = find.byKey(
      const Key('debug_refresh_stamm_markers_button'),
    );
    await tester.ensureVisible(stammRefreshButton);

    tester.widget<FilledButton>(stammRefreshButton).onPressed!.call();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(stammRepository.forceRefreshCalls, 1);
    expect(logger.debugActions, contains('refresh_stamm_markers'));
    expect(
      find.text('Stammesuche aktualisiert: 1 Marker geladen.'),
      findsOneWidget,
    );
  });

  testWidgets('loescht Kartendaten manuell', (tester) async {
    final logger = _FakeLoggerService();
    final groupsService = _FakeHitobitoGroupsService();
    final peopleService = HitobitoPeopleService(config: groupsService.config);
    final configController = HitobitoAuthConfigController(
      sensitiveStorageService: _FakeSensitiveStorageService(),
      oauthService: _MutableOauthService(),
      groupsService: groupsService,
      peopleService: peopleService,
      logger: logger,
      envConfig: groupsService.config,
    );
    await configController.initialize();

    final authModel = AuthSessionModel(
      repository: _InMemoryAuthSessionRepository(),
      profileRepository: _InMemoryAuthProfileRepository(),
      oauthService: _MutableOauthService(),
      biometricLockService: _FakeBiometricLockService(),
      sensitiveStorageService: _FakeSensitiveStorageService(),
      retentionPolicy: HitobitoDataRetentionPolicy(
        maxDataAge: const Duration(days: 90),
        refreshInterval: const Duration(hours: 24),
      ),
      logger: logger,
    );
    final arbeitskontextModel = ArbeitskontextModel(
      localRepository: _ImmediateArbeitskontextLocalRepository(),
      readModelRepository: _FakeArbeitskontextReadModelRepository(),
      groupsService: groupsService,
      bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
      logger: logger,
    );
    final mapTileCacheService = _FakeMapTileCacheService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthSessionModel>.value(value: authModel),
          ChangeNotifierProvider<ArbeitskontextModel>.value(
            value: arbeitskontextModel,
          ),
          ChangeNotifierProvider<HitobitoAuthConfigController>.value(
            value: configController,
          ),
          Provider<LoggerService>.value(value: logger),
          Provider<MapTileCacheService>.value(value: mapTileCacheService),
        ],
        child: MaterialApp(
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            AppLocalizations.delegate,
          ],
          supportedLocales: const [Locale('de'), Locale('en')],
          locale: const Locale('de'),
          home: const DebugToolsPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _scrollDownUntilFinderExists(
      tester,
      find.byKey(const Key('debug_delete_map_cache_button')),
    );
    final deleteMapCacheButton = find.byKey(
      const Key('debug_delete_map_cache_button'),
    );
    await tester.ensureVisible(deleteMapCacheButton);

    tester.widget<FilledButton>(deleteMapCacheButton).onPressed!.call();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(mapTileCacheService.deleteRootCalls, 1);
    expect(logger.debugActions, contains('delete_map_cache'));
    expect(find.text('Kartendaten gelöscht'), findsOneWidget);
  });

  testWidgets(
    'zeigt beim manuellen Sync einen WLAN-Hinweis statt generischer Fehlermeldung',
    (tester) async {
      final logger = _FakeLoggerService();
      final groupsService = _FakeHitobitoGroupsService();
      final peopleService = HitobitoPeopleService(config: groupsService.config);
      final configController = HitobitoAuthConfigController(
        sensitiveStorageService: _FakeSensitiveStorageService(),
        oauthService: _MutableOauthService(),
        groupsService: groupsService,
        peopleService: peopleService,
        logger: logger,
        envConfig: groupsService.config,
      );
      await configController.initialize();

      final authModel = AuthSessionModel(
        repository: _InMemoryAuthSessionRepository(),
        profileRepository: _InMemoryAuthProfileRepository(),
        oauthService: _MutableOauthService(),
        biometricLockService: _FakeBiometricLockService(),
        sensitiveStorageService: _FakeSensitiveStorageService(),
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
        ),
        logger: logger,
        networkAccessPolicy: _BlockedNetworkAccessPolicy(
          const NetworkAccessBlockedException(
            reason: NetworkAccessBlockedReason.noMobileDataEnabled,
            connectionType: NetworkConnectionType.mobile,
            message:
                'Keine Mobilen Daten ist aktiviert. Hitobito ist nur ueber WLAN verfuegbar.',
          ),
        ),
      );
      final arbeitskontextModel = ArbeitskontextModel(
        localRepository: _ImmediateArbeitskontextLocalRepository(),
        readModelRepository: _FakeArbeitskontextReadModelRepository(),
        groupsService: groupsService,
        bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
        logger: logger,
      );

      await authModel.signIn();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthSessionModel>.value(value: authModel),
            ChangeNotifierProvider<ArbeitskontextModel>.value(
              value: arbeitskontextModel,
            ),
            ChangeNotifierProvider<HitobitoAuthConfigController>.value(
              value: configController,
            ),
            Provider<LoggerService>.value(value: logger),
          ],
          child: MaterialApp(
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              AppLocalizations.delegate,
            ],
            supportedLocales: const [Locale('de'), Locale('en')],
            locale: const Locale('de'),
            home: const DebugToolsPage(),
          ),
        ),
      );

      await _pumpBriefly(tester);
      final syncButtonLabel = find.text('Daten jetzt aktualisieren');
      await _scrollDownUntilFinderExists(tester, syncButtonLabel);
      await tester.ensureVisible(syncButtonLabel);
      await tester.tap(syncButtonLabel);
      await tester.pump();
      await _pumpBriefly(tester);

      expect(
        find.text(
          'Keine Mobilen Daten ist aktiviert. Hitobito ist nur ueber WLAN verfuegbar.',
        ),
        findsOneWidget,
      );
    },
    timeout: const Timeout(Duration(seconds: 5)),
  );
}

Future<void> _scrollDownUntilFinderExists(
  WidgetTester tester,
  Finder finder,
) async {
  for (var i = 0; i < 12; i++) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await _pumpBriefly(tester);
  }

  expect(finder, findsWidgets);
}

Future<void> _pumpBriefly(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

class _MutableOauthService extends HitobitoOauthService {
  _MutableOauthService()
    : super(
        config: HitobitoAuthConfig.fromBaseUrl(
          clientId: 'env-client',
          clientSecret: 'env-secret',
          baseUrl: 'https://demo.hitobito.com',
          redirectUri: 'de.jlange.nami.app:/oauth/callback',
        ),
      );

  @override
  Future<AuthSession> authenticateInteractive() async => AuthSession(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    receivedAt: DateTime(2026, 4, 1, 12),
  );

  @override
  Future<AuthProfile> fetchProfile(AuthSession session) async =>
      const AuthProfile(
        namiId: 7,
        firstName: 'Debug',
        lastName: 'User',
        language: 'de',
        roles: <AuthProfileRole>[
          AuthProfileRole(
            groupId: 11,
            groupName: 'Stamm Musterdorf',
            roleName: 'Leitung',
            roleClass: 'Group::Stamm::Leitung',
            permissions: <String>['layer_read'],
          ),
        ],
        primaryGroupId: 11,
      );

  @override
  Future<AuthSession> refresh(AuthSession session) async => session;

  @override
  Future<AuthSession> refreshIfNeeded(
    AuthSession session, {
    Duration threshold = Duration.zero,
  }) async => session;
}

class _VerifyingOauthService extends HitobitoOauthService {
  _VerifyingOauthService(HitobitoAuthConfig config) : super(config: config);

  @override
  Future<AuthSession> authenticateInteractive() async => AuthSession(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    receivedAt: DateTime(2026, 4, 1, 12),
  );
}

class _FakeHitobitoGroupsService extends HitobitoGroupsService {
  _FakeHitobitoGroupsService()
    : super(
        config: HitobitoAuthConfig.fromBaseUrl(
          clientId: 'env-client',
          clientSecret: 'env-secret',
          baseUrl: 'https://demo.hitobito.com',
          redirectUri: 'de.jlange.nami.app:/oauth/callback',
        ),
      );

  @override
  Future<List<HitobitoGroupResource>> fetchAccessibleGroups(
    String accessToken,
  ) async => const <HitobitoGroupResource>[
    HitobitoGroupResource(id: 11, name: 'Stamm Musterdorf', isLayer: true),
  ];
}

class _ImmediateArbeitskontextLocalRepository
    implements ArbeitskontextLocalRepository {
  @override
  Future<void> clearCached() async {}

  @override
  Future<ArbeitskontextReadModel?> loadLastCached() async => null;

  @override
  Future<void> saveCached(ArbeitskontextReadModel readModel) async {}
}

class _FakeArbeitskontextReadModelRepository
    implements ArbeitskontextReadModelRepository {
  @override
  Future<ArbeitskontextReadModel> loadRoles({
    required String accessToken,
    required ArbeitskontextReadModel readModel,
  }) async {
    return readModel;
  }

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
    return ArbeitskontextReadModel(arbeitskontext: arbeitskontext);
  }
}

class _InMemoryAuthProfileRepository implements AuthProfileRepository {
  AuthProfile? _profile;
  DateTime? _lastSyncAt;

  @override
  Future<void> clear() async {
    _profile = null;
    _lastSyncAt = null;
  }

  @override
  Future<AuthProfile?> loadCached() async => _profile;

  @override
  Future<DateTime?> loadLastSyncAt() async => _lastSyncAt;

  @override
  Future<void> save(AuthProfile profile) async {
    _profile = profile;
  }

  @override
  Future<void> saveLastSyncAt(DateTime timestamp) async {
    _lastSyncAt = timestamp;
  }
}

class _FakeStammMapRepository implements StammMapMarkerRepository {
  int forceRefreshCalls = 0;

  @override
  Future<StammMapMarkerSnapshot> forceRefresh() async {
    forceRefreshCalls++;
    return StammMapMarkerSnapshot(
      markers: const [
        StammMapMarker(
          id: '1',
          name: 'Teststamm',
          latitude: 53.0,
          longitude: 10.0,
          city: 'Hamburg',
          postalCode: '20095',
        ),
      ],
      fetchedAt: DateTime(2026, 4, 8),
      source: StammMapMarkerSource.remote,
    );
  }

  @override
  Future<StammMapMarkerSnapshot> loadCachedOrFallback() async {
    return StammMapMarkerSnapshot(
      markers: const [],
      fetchedAt: DateTime(2026, 4, 1),
      source: StammMapMarkerSource.asset,
    );
  }

  @override
  Future<StammMapMarkerSnapshot?> refreshIfDue() async {
    return null;
  }
}

class _FakeMapTileCacheService extends MapTileCacheService {
  _FakeMapTileCacheService() : super(logger: _FakeLoggerService());

  int deleteRootCalls = 0;

  @override
  Future<double> realSizeKiB() async => 2048;

  @override
  Future<void> deleteRoot() async {
    deleteRootCalls++;
  }
}

class _BlockedNetworkAccessPolicy extends NetworkAccessPolicy {
  _BlockedNetworkAccessPolicy(this.error);

  final NetworkAccessBlockedException error;

  @override
  Future<void> ensureNetworkAllowed({
    required String trigger,
    String feature = 'Netzwerkzugriff',
  }) async {
    throw error;
  }
}

class _InMemoryAuthSessionRepository implements AuthSessionRepository {
  AuthSession? _session;

  @override
  Future<void> clear() async {
    _session = null;
  }

  @override
  Future<AuthSession?> load() async => _session;

  @override
  Future<void> save(AuthSession session) async {
    _session = session;
  }
}

class _FakeBiometricLockService extends BiometricLockService {
  _FakeBiometricLockService() : super(logger: _FakeLoggerService());

  @override
  Future<bool> isAvailable() async => false;
}

class _FakeSensitiveStorageService extends SensitiveStorageService {
  String? _clientId;
  String? _clientSecret;
  String? _principal;
  DateTime? _lastBackgroundedAt;
  DateTime? _lastSensitiveSyncAt;
  DateTime? _lastSensitiveSyncAttemptAt;

  @override
  Future<void> clearHitobitoOauthOverride() async {
    _clientId = null;
    _clientSecret = null;
  }

  @override
  Future<String?> loadHitobitoOauthClientId() async => _clientId;

  @override
  Future<String?> loadHitobitoOauthClientSecret() async => _clientSecret;

  @override
  Future<String?> loadPrincipal() async => _principal;

  @override
  Future<DateTime?> loadLastBackgroundedAt() async => _lastBackgroundedAt;

  @override
  Future<DateTime?> loadLastSensitiveSyncAt() async => _lastSensitiveSyncAt;

  @override
  Future<DateTime?> loadLastSensitiveSyncAttemptAt() async =>
      _lastSensitiveSyncAttemptAt;

  @override
  Future<void> purgeSensitiveData() async {
    _principal = null;
    _lastBackgroundedAt = null;
    _lastSensitiveSyncAt = null;
    _lastSensitiveSyncAttemptAt = null;
  }

  @override
  Future<void> saveHitobitoOauthClientId(String? value) async {
    _clientId = value;
  }

  @override
  Future<void> saveHitobitoOauthClientSecret(String? value) async {
    _clientSecret = value;
  }

  @override
  Future<void> saveLastBackgroundedAt(DateTime? timestamp) async {
    _lastBackgroundedAt = timestamp;
  }

  @override
  Future<void> saveLastSensitiveSyncAt(DateTime? timestamp) async {
    _lastSensitiveSyncAt = timestamp;
  }

  @override
  Future<void> saveLastSensitiveSyncAttemptAt(DateTime? timestamp) async {
    _lastSensitiveSyncAttemptAt = timestamp;
  }

  @override
  Future<void> savePrincipal(String? principal) async {
    _principal = principal;
  }
}

class _FakeLoggerService extends LoggerService {
  _FakeLoggerService()
    : super(
        settingsRepository: _FakeAppSettingsRepository(),
        navigatorKey: GlobalKey<NavigatorState>(),
      );

  final List<String> debugActions = <String>[];

  @override
  Future<void> log(String service, String message) async {}

  @override
  Future<void> logInfo(String service, String message) async {}

  @override
  Future<void> logWarn(String service, String message) async {}

  @override
  Future<void> logError(
    String service,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) async {}

  @override
  Future<void> trackAndLog(
    String service,
    String name,
    Map<String, Object?> properties,
  ) async {
    if (service == 'debug_tools' && name == 'debug_action') {
      final action = properties['action']?.toString();
      if (action != null) {
        debugActions.add(action);
      }
    }
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
  Future<void> saveGeburstagsbenachrichtigungStufen(Set<Stufe> stufen) async {}

  @override
  Future<void> saveLanguageCode(String code) async {}

  @override
  Future<void> saveMemberListSearchResultHighlightEnabled(bool enabled) async {}

  @override
  Future<void> saveNotificationsEnabled(bool enabled) async {}

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {}
}
