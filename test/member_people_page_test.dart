import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/auth/auth_profile.dart';
import 'package:nami/domain/auth/auth_profile_repository.dart';
import 'package:nami/domain/auth/auth_session.dart';
import 'package:nami/domain/auth/auth_session_repository.dart';
import 'package:nami/domain/member/member_people_repository.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/settings/app_settings.dart';
import 'package:nami/domain/settings/app_settings_repository.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/model/member_people_model.dart';
import 'package:nami/presentation/screens/member_people_page.dart';
import 'package:nami/services/biometric_lock_service.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_data_retention_policy.dart';
import 'package:nami/services/hitobito_oauth_service.dart';
import 'package:nami/services/logger_service.dart';
import 'package:nami/services/sensitive_storage_service.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'zeigt lokal geladene Mitgliederliste an',
    (tester) async {
      final oauthService = _FakeOauthService();
      final authModel = AuthSessionModel(
        repository: _InMemoryAuthSessionRepository(),
        profileRepository: _InMemoryAuthProfileRepository(),
        oauthService: oauthService,
        biometricLockService: _FakeBiometricLockService(),
        sensitiveStorageService: _FakeSensitiveStorageService(),
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
        ),
        logger: _FakeLoggerService(),
      );
      final repository = _FakeMemberPeopleRepository(
        cached: <Mitglied>[
          Mitglied.peopleListItem(
            mitgliedsnummer: '1',
            vorname: 'Julia',
            nachname: 'Keller',
          ),
        ],
        refreshed: <Mitglied>[
          Mitglied.peopleListItem(
            mitgliedsnummer: '2',
            vorname: 'Max',
            nachname: 'Mustermann',
          ),
        ],
        refreshDelay: const Duration(milliseconds: 10),
      );
      final peopleModel = MemberPeopleModel(
        repository: repository,
        logger: _FakeLoggerService(),
      );

      await authModel.signIn();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthSessionModel>.value(value: authModel),
            ChangeNotifierProvider<MemberPeopleModel>.value(value: peopleModel),
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
            home: const MemberPeoplePage(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('Julia Keller'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 20));

      expect(find.text('Max Mustermann'), findsOneWidget);
      expect(repository.lastRefreshAccessToken, 'token-refreshed');
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );
}

class _FakeMemberPeopleRepository implements MemberPeopleRepository {
  _FakeMemberPeopleRepository({
    required this.cached,
    required this.refreshed,
    this.refreshDelay = Duration.zero,
  });

  final List<Mitglied> cached;
  final List<Mitglied> refreshed;
  final Duration refreshDelay;
  String? lastRefreshAccessToken;

  @override
  Future<List<Mitglied>> loadCached() async => cached;

  @override
  Future<List<Mitglied>> refresh(String accessToken) async {
    lastRefreshAccessToken = accessToken;
    if (refreshDelay > Duration.zero) {
      await Future<void>.delayed(refreshDelay);
    }
    return refreshed;
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

class _InMemoryAuthSessionRepository implements AuthSessionRepository {
  AuthSession? session;

  @override
  Future<void> clear() async {
    session = null;
  }

  @override
  Future<AuthSession?> load() async => session;

  @override
  Future<void> save(AuthSession session) async {
    this.session = session;
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
  Future<AuthSession> authenticateInteractive() async => AuthSession(
    accessToken: 'token-123',
    refreshToken: 'refresh-token',
    receivedAt: DateTime(2026, 3, 27),
  );

  @override
  Future<AuthSession> refreshIfNeeded(
    AuthSession session, {
    Duration threshold = const Duration(minutes: 5),
  }) async => AuthSession(
    accessToken: 'token-refreshed',
    refreshToken: session.refreshToken,
    receivedAt: session.receivedAt,
    expiresAt: session.expiresAt,
    idToken: session.idToken,
    scopes: session.scopes,
    principal: session.principal,
    email: session.email,
    displayName: session.displayName,
  );

  @override
  Future<AuthProfile> fetchProfile(AuthSession session) async =>
      const AuthProfile(
        namiId: 1,
        firstName: 'Test',
        lastName: 'User',
        language: 'de',
      );
}

class _FakeBiometricLockService extends BiometricLockService {
  _FakeBiometricLockService() : super();

  @override
  Future<bool> isAvailable() async => false;
}

class _FakeSensitiveStorageService extends SensitiveStorageService {
  String? _principal;
  DateTime? _lastSensitiveSyncAt;
  DateTime? _lastBackgroundedAt;

  _FakeSensitiveStorageService() : super();

  @override
  Future<String?> loadPrincipal() async => _principal;

  @override
  Future<DateTime?> loadLastSensitiveSyncAt() async => _lastSensitiveSyncAt;

  @override
  Future<DateTime?> loadLastBackgroundedAt() async => _lastBackgroundedAt;

  @override
  Future<void> purgeSensitiveData() async {
    _principal = null;
    _lastSensitiveSyncAt = null;
    _lastBackgroundedAt = null;
  }

  @override
  Future<void> saveLastSensitiveSyncAt(DateTime timestamp) async {
    _lastSensitiveSyncAt = timestamp;
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

class _FakeLoggerService extends LoggerService {
  _FakeLoggerService()
    : super(
        settingsRepository: _FakeAppSettingsRepository(),
        navigatorKey: GlobalKey<NavigatorState>(),
      );

  @override
  Future<void> log(String service, String message) async {}
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
