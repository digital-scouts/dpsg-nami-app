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
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/settings/app_settings.dart';
import 'package:nami/domain/settings/app_settings_repository.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/arbeitskontext_model.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/navigation/navigation_home.page.dart';
import 'package:nami/services/biometric_lock_service.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_data_retention_policy.dart';
import 'package:nami/services/hitobito_groups_service.dart';
import 'package:nami/services/hitobito_oauth_service.dart';
import 'package:nami/services/logger_service.dart';
import 'package:nami/services/sensitive_storage_service.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'zeigt Meine Stufe, Mitglieder und Statistik ohne AppBar, aber mit SafeArea',
    (tester) async {
      final authModel = await _createSignedInAuthModel();
      final arbeitskontextModel = await _createArbeitskontextModel(
        authModel: authModel,
      );

      await tester.pumpWidget(
        _buildTestApp(
          authModel: authModel,
          arbeitskontextModel: arbeitskontextModel,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(SafeArea), findsWidgets);
      expect(find.text('Meine Stufe'), findsWidgets);

      await tester.tap(find.text('Mitglieder'));
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(SafeArea), findsWidgets);
      expect(find.text('Mitglieder'), findsWidgets);

      await tester.tap(find.text('Statistiken'));
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(SafeArea), findsWidgets);
      expect(find.text('Anzahl: 1'), findsOneWidget);

      await tester.tap(find.text('Einstellungen'));
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget);
    },
  );
}

Widget _buildTestApp({
  required AuthSessionModel authModel,
  required ArbeitskontextModel arbeitskontextModel,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthSessionModel>.value(value: authModel),
      ChangeNotifierProvider<ArbeitskontextModel>.value(
        value: arbeitskontextModel,
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de'), Locale('en')],
      locale: const Locale('de'),
      home: const NavigationHomeScreen(),
    ),
  );
}

Future<AuthSessionModel> _createSignedInAuthModel() async {
  final authModel = AuthSessionModel(
    repository: _InMemoryAuthSessionRepository(),
    profileRepository: _InMemoryAuthProfileRepository(),
    oauthService: _FakeOauthService(),
    biometricLockService: _FakeBiometricLockService(),
    sensitiveStorageService: _FakeSensitiveStorageService(),
    retentionPolicy: HitobitoDataRetentionPolicy(
      maxDataAge: const Duration(days: 90),
      refreshInterval: const Duration(hours: 24),
    ),
    logger: _FakeLoggerService(),
  );
  await authModel.signIn();
  return authModel;
}

Future<ArbeitskontextModel> _createArbeitskontextModel({
  required AuthSessionModel authModel,
}) async {
  final model = ArbeitskontextModel(
    localRepository: _FakeArbeitskontextLocalRepository(
      cached: ArbeitskontextReadModel(
        arbeitskontext: Arbeitskontext(
          aktiverLayer: const ArbeitskontextLayer(
            id: 11,
            name: 'Stamm Musterdorf',
          ),
        ),
        mitglieder: <Mitglied>[
          Mitglied.peopleListItem(
            mitgliedsnummer: '1',
            vorname: 'Julia',
            nachname: 'Keller',
          ),
        ],
      ),
    ),
    readModelRepository: _FakeArbeitskontextReadModelRepository(),
    groupsService: _FakeHitobitoGroupsService(),
    bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
    logger: _FakeLoggerService(),
  );

  await model.syncForAuth(
    authState: authModel.state,
    session: authModel.session,
    profile: authModel.profile,
  );

  return model;
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
    return readModel.copyWith(rolesSindGeladen: true);
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

class _FakeHitobitoGroupsService extends HitobitoGroupsService {
  _FakeHitobitoGroupsService()
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

  @override
  Future<List<HitobitoGroupResource>> fetchAccessibleGroups(
    String accessToken,
  ) async => const <HitobitoGroupResource>[];
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
    _lastSyncAt = DateTime(2026, 4, 7);
  }

  @override
  Future<void> saveLastSyncAt(DateTime? syncedAt) async {
    _lastSyncAt = syncedAt;
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

class _FakeOauthService extends HitobitoOauthService {
  _FakeOauthService()
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

  @override
  Future<AuthSession> authenticateInteractive() async {
    return AuthSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      receivedAt: DateTime(2026, 4, 7),
    );
  }

  @override
  Future<AuthProfile> fetchProfile(AuthSession session) async {
    return const AuthProfile(
      namiId: 7,
      firstName: 'Julia',
      lastName: 'Keller',
      language: 'de',
      primaryGroupId: 11,
      roles: <AuthProfileRole>[
        AuthProfileRole(
          groupId: 11,
          groupName: 'Stamm Musterdorf',
          roleName: 'Stammesfuehrung',
          roleClass: 'Group::Stamm::Leader',
          permissions: <String>['layer_read'],
        ),
      ],
    );
  }
}

class _FakeBiometricLockService implements BiometricLockService {
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
    _lastSensitiveSyncAt = null;
    _lastSensitiveSyncAttemptAt = null;
    _lastBackgroundedAt = null;
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
        settingsRepository: _NoopAppSettingsRepository(),
        navigatorKey: GlobalKey<NavigatorState>(),
      );

  @override
  Future<void> log(String service, String message) async {}
}

class _NoopAppSettingsRepository implements AppSettingsRepository {
  const _NoopAppSettingsRepository();

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
