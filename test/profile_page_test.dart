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
import 'package:nami/domain/settings/app_settings.dart';
import 'package:nami/domain/settings/app_settings_repository.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/arbeitskontext_model.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/screens/profile_page.dart';
import 'package:nami/services/biometric_lock_service.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_data_retention_policy.dart';
import 'package:nami/services/hitobito_groups_service.dart';
import 'package:nami/services/hitobito_oauth_service.dart';
import 'package:nami/services/logger_service.dart';
import 'package:nami/services/sensitive_storage_service.dart';
import 'package:provider/provider.dart';

const _layerSwitcherListKey = ValueKey('layer_switcher_list');

void main() {
  testWidgets(
    'zeigt Profil, Rollen und Sprachbadge statt technischer Sessioninfos',
    (tester) async {
      await _pumpProfilePage(
        tester,
        profile: const AuthProfile(
          namiId: 34,
          email: 'julia@example.com',
          firstName: 'Julia',
          lastName: 'Keller',
          nickname: 'Polka',
          language: 'en',
          roles: <AuthProfileRole>[
            AuthProfileRole(
              groupId: 1,
              groupName: 'hitobito',
              roleName: 'Mitarbeiter*in GS',
              roleClass: 'Group::Bund::MitarbeiterGs',
              permissions: <String>['admin', 'contact_data'],
            ),
          ],
        ),
      );

      expect(find.text('Polka'), findsOneWidget);
      expect(find.text('Julia Keller'), findsOneWidget);
      expect(find.text('nami-id'), findsOneWidget);
      expect(find.text('34'), findsOneWidget);
      expect(find.text('julia@example.com'), findsOneWidget);
      expect(find.text('EN'), findsOneWidget);
      expect(find.text('Arbeitskontext'), findsOneWidget);
      expect(find.text('Stamm Musterdorf'), findsOneWidget);
      expect(find.text('Layer wechseln'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Anmeldestatus'),
        200,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Anmeldestatus'), findsOneWidget);
      expect(find.text('Letzte Datenbestaetigung'), findsOneWidget);
      expect(find.text('Angemeldet'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Mitarbeiter*in GS'),
        200,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Mitarbeiter*in GS'), findsOneWidget);
      expect(find.text('hitobito'), findsOneWidget);
      expect(find.textContaining('admin, contact_data'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );

  testWidgets(
    'zeigt ohne Nickname nur Name Nachname',
    (tester) async {
      await _pumpProfilePage(
        tester,
        profile: const AuthProfile(
          namiId: 35,
          email: 'max@example.com',
          firstName: 'Max',
          lastName: 'Mustermann',
          language: 'de',
        ),
      );

      expect(find.text('Max Mustermann'), findsOneWidget);
      expect(find.text('Polka'), findsNothing);
      expect(find.text('DE'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );

  testWidgets(
    'zeigt bei unbekannter Sprache DE und leeren Rollenhinweis',
    (tester) async {
      await _pumpProfilePage(
        tester,
        profile: const AuthProfile(
          namiId: 36,
          email: 'lea@example.com',
          firstName: 'Lea',
          lastName: 'Beispiel',
          language: 'fr',
          roles: <AuthProfileRole>[],
        ),
      );

      expect(find.text('Lea Beispiel'), findsOneWidget);
      expect(find.text('DE'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Keine Rollen im Profil vorhanden'),
        200,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Keine Rollen im Profil vorhanden'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );

  testWidgets(
    'zeigt bei Remote-Problemen einen cache-only Status statt Angemeldet',
    (tester) async {
      final authModel = AuthSessionModel(
        repository: _InMemoryAuthSessionRepository(),
        profileRepository: _InMemoryAuthProfileRepository(),
        oauthService: _FakeOauthService(
          sessionToReturn: AuthSession(
            accessToken: 'access-token',
            refreshToken: 'refresh-token',
            receivedAt: DateTime(2026, 3, 27),
          ),
          profileToReturn: const AuthProfile(
            namiId: 37,
            email: 'lea@example.com',
            firstName: 'Lea',
            lastName: 'Beispiel',
            language: 'de',
          ),
        ),
        biometricLockService: _FakeBiometricLockService(),
        sensitiveStorageService: _FakeSensitiveStorageService(),
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
          nowProvider: () => DateTime(2026, 3, 27, 12),
        ),
        logger: _createLogger(),
      );
      await authModel.signIn();
      authModel.reportRemoteDataIssue(
        'Profil-Anfrage fehlgeschlagen (401).',
        requiresInteractiveLogin: true,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthSessionModel>.value(value: authModel),
            ChangeNotifierProvider<ArbeitskontextModel>.value(
              value: await _buildArbeitskontextModel(authModel),
            ),
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
            home: const ProfilePage(),
          ),
        ),
      );

      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Lokale Daten aktiv, Anmeldung fuer Updates erforderlich'),
        200,
        scrollable: find.byType(Scrollable),
      );

      expect(
        find.text('Lokale Daten aktiv, Anmeldung fuer Updates erforderlich'),
        findsOneWidget,
      );
      expect(find.text('Angemeldet'), findsNothing);
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );

  testWidgets(
    'zeigt Bottom Sheet mit erreichbaren Layern und markiert den aktuellen Layer',
    (tester) async {
      await _pumpProfilePage(
        tester,
        profile: const AuthProfile(
          namiId: 38,
          firstName: 'Julia',
          lastName: 'Keller',
          language: 'de',
          primaryGroupId: 11,
        ),
      );

      await tester.tap(find.text('Layer wechseln'));
      await tester.pumpAndSettle();

      expect(find.text('Layer wechseln'), findsNWidgets(2));
      expect(find.text('Aktuell aktiv'), findsOneWidget);
      expect(find.text('Bezirk Rhein'), findsOneWidget);
    },
  );

  testWidgets(
    'zeigt bei vielen Layern auf kleinem Display ein scrollbares Bottom Sheet ohne Overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final verfuegbareLayer = List<ArbeitskontextLayer>.generate(
        11,
        (index) =>
            ArbeitskontextLayer(id: 20 + index, name: 'Layer ${index + 1}'),
      );

      await _pumpProfilePage(
        tester,
        profile: const AuthProfile(
          namiId: 40,
          firstName: 'Julia',
          lastName: 'Keller',
          language: 'de',
          primaryGroupId: 11,
        ),
        arbeitskontext: Arbeitskontext(
          aktiverLayer: const ArbeitskontextLayer(
            id: 11,
            name: 'Stamm Musterdorf',
          ),
          verfuegbareLayer: verfuegbareLayer,
        ),
        groups: <HitobitoGroupResource>[
          const HitobitoGroupResource(
            id: 11,
            name: 'Stamm Musterdorf',
            isLayer: true,
          ),
          ...verfuegbareLayer.map(
            (layer) => HitobitoGroupResource(
              id: layer.id,
              name: layer.name,
              isLayer: true,
            ),
          ),
        ],
      );

      final layerSwitcherLabel = find.text('Layer wechseln').first;
      await tester.ensureVisible(layerSwitcherLabel);
      await tester.pumpAndSettle();
      await tester.tap(layerSwitcherLabel);
      await tester.pumpAndSettle();

      final layerSwitcherScrollable = find.descendant(
        of: find.byKey(_layerSwitcherListKey),
        matching: find.byType(Scrollable),
      );

      expect(find.byKey(_layerSwitcherListKey), findsOneWidget);
      expect(layerSwitcherScrollable, findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.text('Layer 11'),
        200,
        scrollable: layerSwitcherScrollable,
      );
      await tester.pumpAndSettle();

      expect(find.text('Layer 11'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'wechselt den Layer ueber das Bottom Sheet und zeigt kurz einen Ladezustand',
    (tester) async {
      final readModelRepository = _FakeArbeitskontextReadModelRepository(
        refreshDelay: const Duration(milliseconds: 50),
      );
      await _pumpProfilePage(
        tester,
        profile: const AuthProfile(
          namiId: 39,
          firstName: 'Julia',
          lastName: 'Keller',
          language: 'de',
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
        ),
        readModelRepository: readModelRepository,
      );

      await tester.tap(find.text('Layer wechseln'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bezirk Rhein'));
      await tester.pump();

      expect(find.text('Arbeitskontext wird gewechselt'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();

      expect(find.text('Bezirk Rhein'), findsOneWidget);
      expect(find.text('Arbeitskontext wird gewechselt'), findsNothing);
      expect(
        readModelRepository.lastRefreshArbeitskontext?.aktiverLayer.id,
        20,
      );
    },
  );

  testWidgets(
    'zeigt bei technischem Fehler beim Layerwechsel eine fachliche Fehlermeldung',
    (tester) async {
      final readModelRepository = _FakeArbeitskontextReadModelRepository(
        refreshError: StateError('offline'),
      );
      await _pumpProfilePage(
        tester,
        profile: const AuthProfile(
          namiId: 41,
          firstName: 'Julia',
          lastName: 'Keller',
          language: 'de',
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
        ),
        readModelRepository: readModelRepository,
      );

      await tester.tap(find.text('Layer wechseln'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bezirk Rhein'));
      await tester.pumpAndSettle();

      expect(
        find.text(ArbeitskontextModel.layerSwitchFailedMessage),
        findsOneWidget,
      );
      expect(find.textContaining('offline'), findsNothing);
      expect(find.text('Stamm Musterdorf'), findsOneWidget);
    },
  );
}

Future<void> _pumpProfilePage(
  WidgetTester tester, {
  required AuthProfile profile,
  Arbeitskontext? arbeitskontext,
  List<HitobitoGroupResource>? groups,
  ArbeitskontextReadModelRepository? readModelRepository,
}) async {
  final authModel = AuthSessionModel(
    repository: _InMemoryAuthSessionRepository(),
    profileRepository: _InMemoryAuthProfileRepository(),
    oauthService: _FakeOauthService(
      sessionToReturn: AuthSession(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        receivedAt: DateTime(2026, 3, 27),
      ),
      profileToReturn: profile,
    ),
    biometricLockService: _FakeBiometricLockService(),
    sensitiveStorageService: _FakeSensitiveStorageService(),
    retentionPolicy: HitobitoDataRetentionPolicy(
      maxDataAge: const Duration(days: 90),
      refreshInterval: const Duration(hours: 24),
      nowProvider: () => DateTime(2026, 3, 27, 12),
    ),
    logger: _createLogger(),
  );
  await authModel.signIn();
  final arbeitskontextModel = await _buildArbeitskontextModel(
    authModel,
    arbeitskontext: arbeitskontext,
    groups: groups,
    readModelRepository: readModelRepository,
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthSessionModel>.value(value: authModel),
        ChangeNotifierProvider<ArbeitskontextModel>.value(
          value: arbeitskontextModel,
        ),
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
        home: const ProfilePage(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<ArbeitskontextModel> _buildArbeitskontextModel(
  AuthSessionModel authModel, {
  Arbeitskontext? arbeitskontext,
  List<HitobitoGroupResource>? groups,
  ArbeitskontextReadModelRepository? readModelRepository,
}) async {
  final effectiveArbeitskontext =
      arbeitskontext ??
      Arbeitskontext(
        aktiverLayer: const ArbeitskontextLayer(
          id: 11,
          name: 'Stamm Musterdorf',
        ),
        verfuegbareLayer: const <ArbeitskontextLayer>[
          ArbeitskontextLayer(id: 20, name: 'Bezirk Rhein'),
        ],
      );
  final model = ArbeitskontextModel(
    localRepository: _FakeArbeitskontextLocalRepository(
      cached: ArbeitskontextReadModel(arbeitskontext: effectiveArbeitskontext),
    ),
    readModelRepository:
        readModelRepository ?? _FakeArbeitskontextReadModelRepository(),
    groupsService: _FakeHitobitoGroupsService(
      groups:
          groups ??
          const <HitobitoGroupResource>[
            HitobitoGroupResource(
              id: 11,
              name: 'Stamm Musterdorf',
              isLayer: true,
            ),
            HitobitoGroupResource(id: 20, name: 'Bezirk Rhein', isLayer: true),
          ],
    ),
    bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
    logger: _createLogger(),
  );
  await model.syncForAuth(
    authState: authModel.state,
    session: authModel.session,
    profile: authModel.profile,
  );
  return model;
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
  @override
  Future<ArbeitskontextReadModel> loadRoles({
    required String accessToken,
    required ArbeitskontextReadModel readModel,
  }) async {
    return readModel;
  }

  _FakeArbeitskontextReadModelRepository({
    this.refreshDelay = Duration.zero,
    this.refreshError,
  });

  final Duration refreshDelay;
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
    if (refreshDelay > Duration.zero) {
      await Future<void>.delayed(refreshDelay);
    }
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

class _FakeOauthService extends HitobitoOauthService {
  _FakeOauthService({
    required this.sessionToReturn,
    required this.profileToReturn,
  }) : super(
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

  final AuthSession sessionToReturn;
  final AuthProfile profileToReturn;

  @override
  Future<AuthSession> authenticateInteractive() async => sessionToReturn;

  @override
  Future<AuthProfile> fetchProfile(AuthSession session) async =>
      profileToReturn;

  @override
  Future<AuthSession> refreshIfNeeded(
    AuthSession session, {
    Duration threshold = const Duration(minutes: 5),
  }) async {
    return session;
  }
}

class _FakeBiometricLockService extends BiometricLockService {
  _FakeBiometricLockService() : super();

  @override
  Future<bool> authenticate() async => true;

  @override
  Future<bool> isAvailable() async => false;
}

class _FakeSensitiveStorageService extends SensitiveStorageService {
  String? _principal;
  DateTime? _lastSensitiveSyncAt;
  DateTime? _lastSensitiveSyncAttemptAt;
  DateTime? _lastBackgroundedAt;

  _FakeSensitiveStorageService() : super();

  @override
  Future<String?> loadPrincipal() async => _principal;

  @override
  Future<DateTime?> loadLastSensitiveSyncAt() async => _lastSensitiveSyncAt;

  @override
  Future<DateTime?> loadLastSensitiveSyncAttemptAt() async =>
      _lastSensitiveSyncAttemptAt;

  @override
  Future<DateTime?> loadLastBackgroundedAt() async => _lastBackgroundedAt;

  @override
  Future<void> purgeSensitiveData() async {
    _principal = null;
    _lastSensitiveSyncAt = null;
    _lastSensitiveSyncAttemptAt = null;
    _lastBackgroundedAt = null;
  }

  @override
  Future<void> saveLastSensitiveSyncAt(DateTime timestamp) async {
    _lastSensitiveSyncAt = timestamp;
  }

  @override
  Future<void> saveLastSensitiveSyncAttemptAt(DateTime? timestamp) async {
    _lastSensitiveSyncAttemptAt = timestamp;
  }

  @override
  Future<void> saveLastBackgroundedAt(DateTime? timestamp) async {
    _lastBackgroundedAt = timestamp;
  }

  @override
  Future<void> savePrincipal(String? principal) async {
    _principal = principal;
  }
}

LoggerService _createLogger() => _FakeLoggerService();

class _FakeLoggerService extends LoggerService {
  _FakeLoggerService()
    : super(
        settingsRepository: _FakeAppSettingsRepository(),
        navigatorKey: GlobalKey<NavigatorState>(),
      );

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
  Future<void> trackEvent(String name, Map<String, Object?> properties) async {}

  @override
  Future<void> trackAndLog(
    String service,
    String name,
    Map<String, Object?> properties,
  ) async {}

  @override
  Future<void> debounceTrackAndLog(
    String service,
    String name,
    Map<String, Object?> properties,
  ) async {}
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
  Future<void> saveGeburstagsbenachrichtigungStufen(Set<Stufe> stufen) async {}

  @override
  Future<void> saveLanguageCode(String code) async {}

  @override
  Future<void> saveNotificationsEnabled(bool enabled) async {}

  @override
  Future<void> saveMemberListSearchResultHighlightEnabled(bool enabled) async {}

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {}
}
