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
import 'package:nami/presentation/screens/settings_page.dart';
import 'package:nami/services/biometric_lock_service.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_data_retention_policy.dart';
import 'package:nami/services/hitobito_oauth_service.dart';
import 'package:nami/services/logger_service.dart';
import 'package:nami/services/sensitive_storage_service.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('zeigt Karte als Eintrag in den Einstellungen', (tester) async {
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

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthSessionModel>.value(value: authModel),
          Provider<LoggerService>.value(value: _FakeLoggerService()),
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
          home: const SettingsPage(),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Karte'), findsOneWidget);
  });

  testWidgets(
    'zeigt Hitobito-Warnung in den Einstellungen bei Remote-Problemen',
    (tester) async {
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

      authModel.reportRemoteDataIssue(
        'offline',
        requiresInteractiveLogin: true,
      );

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
            home: const SettingsPage(),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Hitobito derzeit nicht erreichbar'), findsOneWidget);
      expect(
        find.text(
          'Die App zeigt weiter lokale Daten an. Tippe hier, um dich erneut bei Hitobito anzumelden.',
        ),
        findsOneWidget,
      );
    },
  );
}

class _InMemoryAuthProfileRepository implements AuthProfileRepository {
  @override
  Future<void> clear() async {}

  @override
  Future<AuthProfile?> loadCached() async => null;

  @override
  Future<DateTime?> loadLastSyncAt() async => null;

  @override
  Future<void> save(AuthProfile profile) async {}

  @override
  Future<void> saveLastSyncAt(DateTime timestamp) async {}
}

class _InMemoryAuthSessionRepository implements AuthSessionRepository {
  @override
  Future<void> clear() async {}

  @override
  Future<AuthSession?> load() async => null;

  @override
  Future<void> save(AuthSession session) async {}
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
}

class _FakeBiometricLockService extends BiometricLockService {
  _FakeBiometricLockService() : super();

  @override
  Future<bool> isAvailable() async => false;
}

class _FakeSensitiveStorageService extends SensitiveStorageService {
  _FakeSensitiveStorageService() : super();
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
