import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/auth/auth_profile.dart';
import 'package:nami/domain/auth/auth_profile_repository.dart';
import 'package:nami/domain/auth/auth_session.dart';
import 'package:nami/domain/auth/auth_session_repository.dart';
import 'package:nami/domain/auth/auth_state.dart';
import 'package:nami/domain/settings/app_settings.dart';
import 'package:nami/domain/settings/app_settings_repository.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/services/biometric_lock_service.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_data_retention_policy.dart';
import 'package:nami/services/hitobito_oauth_service.dart';
import 'package:nami/services/logger_service.dart';
import 'package:nami/services/sensitive_storage_service.dart';

void main() {
  test(
    'setzt unbekannte Profilsprache nach Login auf deutsch zurueck',
    () async {
      final oauthService = _FakeOauthService(
        sessionToReturn: AuthSession(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          receivedAt: DateTime(2026, 3, 27),
        ),
        profileToReturn: const AuthProfile(
          namiId: 34,
          firstName: 'Julia',
          lastName: 'Keller',
          nickname: 'Polka',
          language: 'fr',
        ),
      );
      final languageChanges = <String>[];

      final model = AuthSessionModel(
        repository: _InMemoryAuthSessionRepository(),
        profileRepository: _InMemoryAuthProfileRepository(),
        oauthService: oauthService,
        biometricLockService: _FakeBiometricLockService(),
        sensitiveStorageService: _FakeSensitiveStorageService(),
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
          nowProvider: () => DateTime(2026, 3, 27, 12),
        ),
        logger: _createLogger(),
        onPreferredLanguageChanged: (languageCode) async {
          languageChanges.add(languageCode);
        },
      );

      await model.signIn();

      expect(model.profile, isNotNull);
      expect(model.profile!.normalizedLanguage, 'de');
      expect(languageChanges, <String>['de']);
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );

  test(
    'uebernimmt englische Profilsprache nach Login',
    () async {
      final oauthService = _FakeOauthService(
        sessionToReturn: AuthSession(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          receivedAt: DateTime(2026, 3, 27),
        ),
        profileToReturn: const AuthProfile(
          namiId: 35,
          firstName: 'Julia',
          lastName: 'Keller',
          language: 'en',
        ),
      );
      final languageChanges = <String>[];

      final model = AuthSessionModel(
        repository: _InMemoryAuthSessionRepository(),
        profileRepository: _InMemoryAuthProfileRepository(),
        oauthService: oauthService,
        biometricLockService: _FakeBiometricLockService(),
        sensitiveStorageService: _FakeSensitiveStorageService(),
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
          nowProvider: () => DateTime(2026, 3, 27, 12),
        ),
        logger: _createLogger(),
        onPreferredLanguageChanged: (languageCode) async {
          languageChanges.add(languageCode);
        },
      );

      await model.signIn();

      expect(model.profile, isNotNull);
      expect(model.profile!.normalizedLanguage, 'en');
      expect(languageChanges, <String>['en']);
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );

  test(
    'laedt Profil und synchronisiert Sprache bei vorhandener Session waehrend initialize',
    () async {
      final oauthService = _FakeOauthService(
        sessionToReturn: AuthSession(
          accessToken: 'unused',
          receivedAt: DateTime(2026, 3, 27),
        ),
        profileToReturn: const AuthProfile(
          namiId: 36,
          firstName: 'Lea',
          lastName: 'Beispiel',
          language: 'en',
        ),
      );
      final repository = _InMemoryAuthSessionRepository(
        initialSession: AuthSession(
          accessToken: 'existing-token',
          receivedAt: DateTime(2026, 3, 27),
        ),
      );
      final languageChanges = <String>[];

      final model = AuthSessionModel(
        repository: repository,
        profileRepository: _InMemoryAuthProfileRepository(),
        oauthService: oauthService,
        biometricLockService: _FakeBiometricLockService(),
        sensitiveStorageService: _FakeSensitiveStorageService(),
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
          nowProvider: () => DateTime(2026, 3, 27, 12),
        ),
        logger: _createLogger(),
        onPreferredLanguageChanged: (languageCode) async {
          languageChanges.add(languageCode);
        },
      );

      await model.initialize();

      expect(model.session, isNotNull);
      expect(model.profile, isNotNull);
      expect(model.profile!.namiId, 36);
      expect(languageChanges, <String>['en']);
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );

  test(
    'laedt gecachtes Profil bei initialize ohne sofortigen Remote-Refresh',
    () async {
      final cachedProfile = const AuthProfile(
        namiId: 41,
        firstName: 'Cache',
        lastName: 'Only',
        language: 'de',
      );
      final oauthService = _FakeOauthService(
        sessionToReturn: AuthSession(
          accessToken: 'unused',
          receivedAt: DateTime(2026, 3, 27),
        ),
        profileToReturn: const AuthProfile(
          namiId: 99,
          firstName: 'Remote',
          lastName: 'Profile',
          language: 'en',
        ),
      );
      final profileRepository = _InMemoryAuthProfileRepository(
        profile: cachedProfile,
        lastSyncAt: DateTime(2026, 3, 27, 6),
      );

      final model = AuthSessionModel(
        repository: _InMemoryAuthSessionRepository(
          initialSession: AuthSession(
            accessToken: 'existing-token',
            receivedAt: DateTime(2026, 3, 27),
          ),
        ),
        profileRepository: profileRepository,
        oauthService: oauthService,
        biometricLockService: _FakeBiometricLockService(),
        sensitiveStorageService: _FakeSensitiveStorageService(),
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
          nowProvider: () => DateTime(2026, 3, 27, 12),
        ),
        logger: _createLogger(),
      );

      await model.initialize();

      expect(model.profile?.namiId, 41);
      expect(oauthService.fetchProfileCallCount, 0);
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );

  test(
    'syncHitobitoData aktualisiert Profil, Mitglieder und Sync-Zeitpunkt',
    () async {
      final oauthService = _FakeOauthService(
        sessionToReturn: AuthSession(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          receivedAt: DateTime(2026, 3, 27),
        ),
        profileToReturn: const AuthProfile(
          namiId: 77,
          firstName: 'Sync',
          lastName: 'User',
          language: 'de',
        ),
      );
      final sensitiveStorage = _FakeSensitiveStorageService();
      final memberSyncTokens = <String>[];
      final model = AuthSessionModel(
        repository: _InMemoryAuthSessionRepository(),
        profileRepository: _InMemoryAuthProfileRepository(),
        oauthService: oauthService,
        biometricLockService: _FakeBiometricLockService(),
        sensitiveStorageService: sensitiveStorage,
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
          nowProvider: () => DateTime(2026, 3, 28, 12),
        ),
        logger: _createLogger(),
      );

      await model.signIn();
      sensitiveStorage._lastSensitiveSyncAt = DateTime(2026, 3, 27, 8);

      await model.syncHitobitoData(
        syncMembers: (accessToken) async {
          memberSyncTokens.add(accessToken);
        },
        force: true,
      );

      expect(model.profile?.namiId, 77);
      expect(memberSyncTokens, <String>['access-token']);
      expect(model.lastSensitiveSyncAt, DateTime(2026, 3, 28, 12));
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );

  test(
    'sperrt nach Resume erst nach konfiguriertem Timeout',
    () async {
      var now = DateTime(2026, 3, 28, 12, 0, 0);
      final model = AuthSessionModel(
        repository: _InMemoryAuthSessionRepository(),
        profileRepository: _InMemoryAuthProfileRepository(),
        oauthService: _FakeOauthService(
          sessionToReturn: AuthSession(
            accessToken: 'access-token',
            refreshToken: 'refresh-token',
            receivedAt: now,
          ),
          profileToReturn: const AuthProfile(
            namiId: 88,
            firstName: 'Lock',
            lastName: 'User',
            language: 'de',
          ),
        ),
        biometricLockService: _FakeBiometricLockService(available: true),
        sensitiveStorageService: _FakeSensitiveStorageService(),
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
          nowProvider: () => now,
        ),
        logger: _createLogger(),
        lockTimeout: const Duration(seconds: 60),
      );

      await model.signIn();
      await model.onAppBackgrounded();
      now = now.add(const Duration(seconds: 30));

      await model.onAppResumed();

      expect(model.state, AuthState.signedIn);

      await model.onAppBackgrounded();
      now = now.add(const Duration(seconds: 61));

      await model.onAppResumed();

      expect(model.state, AuthState.unlockRequired);
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );

  test(
    'entsperren loescht den Hintergrundzeitpunkt und sperrt nicht sofort erneut',
    () async {
      var now = DateTime(2026, 3, 28, 12, 0, 0);
      final model = AuthSessionModel(
        repository: _InMemoryAuthSessionRepository(),
        profileRepository: _InMemoryAuthProfileRepository(),
        oauthService: _FakeOauthService(
          sessionToReturn: AuthSession(
            accessToken: 'access-token',
            refreshToken: 'refresh-token',
            receivedAt: now,
          ),
          profileToReturn: const AuthProfile(
            namiId: 89,
            firstName: 'Unlock',
            lastName: 'User',
            language: 'de',
          ),
        ),
        biometricLockService: _FakeBiometricLockService(available: true),
        sensitiveStorageService: _FakeSensitiveStorageService(),
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
          nowProvider: () => now,
        ),
        logger: _createLogger(),
        lockTimeout: const Duration(seconds: 60),
      );

      await model.signIn();
      await model.onAppBackgrounded();
      now = now.add(const Duration(seconds: 61));
      await model.onAppResumed();

      expect(model.state, AuthState.unlockRequired);

      await model.unlock();
      await model.onAppResumed();

      expect(model.state, AuthState.signedIn);
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );
}

class _InMemoryAuthProfileRepository implements AuthProfileRepository {
  _InMemoryAuthProfileRepository({this.profile, this.lastSyncAt});

  AuthProfile? profile;
  DateTime? lastSyncAt;

  @override
  Future<void> clear() async {
    profile = null;
    lastSyncAt = null;
  }

  @override
  Future<AuthProfile?> loadCached() async => profile;

  @override
  Future<DateTime?> loadLastSyncAt() async => lastSyncAt;

  @override
  Future<void> save(AuthProfile profile) async {
    this.profile = profile;
  }

  @override
  Future<void> saveLastSyncAt(DateTime timestamp) async {
    lastSyncAt = timestamp;
  }
}

class _InMemoryAuthSessionRepository implements AuthSessionRepository {
  _InMemoryAuthSessionRepository({AuthSession? initialSession})
    : _session = initialSession;

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
  int fetchProfileCallCount = 0;

  @override
  Future<AuthSession> authenticateInteractive() async => sessionToReturn;

  @override
  Future<AuthSession> refresh(AuthSession session) async => sessionToReturn;

  @override
  Future<AuthProfile> fetchProfile(AuthSession session) async {
    fetchProfileCallCount += 1;
    return profileToReturn;
  }

  @override
  Future<AuthSession> refreshIfNeeded(
    AuthSession session, {
    Duration threshold = const Duration(minutes: 5),
  }) async {
    return session;
  }
}

class _FakeBiometricLockService extends BiometricLockService {
  _FakeBiometricLockService({this.available = false}) : super();

  final bool available;

  @override
  Future<bool> authenticate() async => true;

  @override
  Future<bool> isAvailable() async => available;
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
  Future<void> saveGeburstagsbenachrichtigungStufen(Set<Stufe> stufen) async {}

  @override
  Future<void> saveLanguageCode(String code) async {}

  @override
  Future<void> saveNotificationsEnabled(bool enabled) async {}

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {}
}
