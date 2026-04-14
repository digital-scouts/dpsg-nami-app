import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/auth/auth_profile.dart';
import 'package:nami/domain/auth/auth_profile_repository.dart';
import 'package:nami/domain/auth/auth_session.dart';
import 'package:nami/domain/auth/auth_session_repository.dart';
import 'package:nami/domain/settings/app_settings.dart';
import 'package:nami/domain/settings/app_settings_repository.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/screens/auth_gate_screen.dart';
import 'package:nami/services/biometric_lock_service.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_data_retention_policy.dart';
import 'package:nami/services/hitobito_oauth_service.dart';
import 'package:nami/services/logger_service.dart';
import 'package:nami/services/sensitive_storage_service.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'zeigt Lock-Overlay ueber einer gepushten Route und behaelt die Route nach Unlock',
    (tester) async {
      var now = DateTime(2026, 3, 28, 12, 0, 0);
      final authModel = AuthSessionModel(
        repository: _InMemoryAuthSessionRepository(),
        profileRepository: _InMemoryAuthProfileRepository(),
        oauthService: _FakeOauthService(
          sessionToReturn: AuthSession(
            accessToken: 'access-token',
            refreshToken: 'refresh-token',
            receivedAt: now,
          ),
        ),
        biometricLockService: _FakeBiometricLockService(),
        sensitiveStorageService: _FakeSensitiveStorageService(),
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
          nowProvider: () => now,
        ),
        logger: _FakeLoggerService(),
        isAppLockEnabled: () => true,
        lockTimeout: const Duration(seconds: 60),
      );

      await authModel.signIn();

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthSessionModel>.value(
          value: authModel,
          child: MaterialApp(
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              AppLocalizations.delegate,
            ],
            supportedLocales: const [Locale('de'), Locale('en')],
            locale: const Locale('de'),
            builder: (context, child) {
              return Stack(
                fit: StackFit.expand,
                children: [if (child != null) child, const AppLockOverlay()],
              );
            },
            home: Scaffold(
              body: Center(
                child: Builder(
                  builder: (context) => FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const Scaffold(
                            body: Center(child: Text('Zweite Seite')),
                          ),
                        ),
                      );
                    },
                    child: const Text('Weiter'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();

      expect(find.text('Zweite Seite'), findsOneWidget);
      expect(find.byKey(const Key('app_lock_overlay')), findsNothing);

      await authModel.onAppBackgrounded();
      now = now.add(const Duration(seconds: 61));
      await authModel.onAppResumed();
      await tester.pump();

      expect(find.byKey(const Key('app_lock_overlay')), findsOneWidget);
      expect(find.text('Zweite Seite'), findsOneWidget);

      await tester.tap(find.text('Jetzt entsperren'));
      await tester.pump();

      expect(find.byKey(const Key('app_lock_overlay')), findsNothing);
      expect(find.text('Zweite Seite'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );
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
  _FakeOauthService({required this.sessionToReturn})
    : super(
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

  @override
  Future<AuthSession> authenticateInteractive() async => sessionToReturn;

  @override
  Future<AuthProfile> fetchProfile(AuthSession session) async =>
      const AuthProfile(
        namiId: 1,
        firstName: 'Overlay',
        lastName: 'User',
        language: 'de',
      );

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
  Future<bool> isAvailable() async => true;
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
  Future<void> saveNotificationsEnabled(bool enabled) async {}

  @override
  Future<void> saveMemberListSearchResultHighlightEnabled(bool enabled) async {}

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {}
}
