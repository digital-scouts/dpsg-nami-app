import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/core/notifications/pull_notification.dart';
import 'package:nami/domain/auth/auth_profile.dart';
import 'package:nami/domain/auth/auth_profile_repository.dart';
import 'package:nami/domain/auth/auth_session.dart';
import 'package:nami/domain/auth/auth_session_repository.dart';
import 'package:nami/domain/settings/app_settings.dart';
import 'package:nami/domain/settings/app_settings_repository.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/notifications/notifications_hub.dart';
import 'package:nami/presentation/screens/settings_page.dart';
import 'package:nami/services/app_update_service.dart';
import 'package:nami/services/biometric_lock_service.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_data_retention_policy.dart';
import 'package:nami/services/hitobito_oauth_service.dart';
import 'package:nami/services/logger_service.dart';
import 'package:nami/services/nami_ai_access_service.dart';
import 'package:nami/services/sensitive_storage_service.dart';
import 'package:provider/provider.dart';

void main() {
  Widget buildTestApp({
    required AuthSessionModel authModel,
    FutureOr<void> Function()? onMessages,
    VoidCallback? onNamiAi,
    VoidCallback? onNamiAiPaywall,
    Future<NamiAiAccessDecision> Function()? namiAiAccessLoader,
    Future<List<AppHubNotification>> Function()?
    unreadExternalNotificationsLoader,
    List<dynamic> additionalProviders = const [],
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthSessionModel>.value(value: authModel),
        Provider<LoggerService>.value(value: _FakeLoggerService()),
        ...additionalProviders,
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
        home: SettingsPage(
          onMessages: onMessages,
          onNamiAi: onNamiAi,
          onNamiAiPaywall: onNamiAiPaywall,
          namiAiAccessLoader: namiAiAccessLoader,
          unreadExternalNotificationsLoader: unreadExternalNotificationsLoader,
        ),
      ),
    );
  }

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

    await tester.pumpWidget(buildTestApp(authModel: authModel));

    await tester.pump();

    expect(find.text('Karte'), findsOneWidget);
    expect(find.text('Rechnungen'), findsOneWidget);
    expect(find.text('Events'), findsOneWidget);
    expect(find.text('Abos'), findsOneWidget);
    expect(find.text('NaMi AI'), findsNothing);
    expect(find.text('Stufenwechsel'), findsNothing);
    expect(find.byKey(const Key('settings-messages-banner')), findsNothing);
  });

  testWidgets('oeffnet NaMi AI bei aktiviertem Zugriff', (tester) async {
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

    var openedChat = false;

    await tester.pumpWidget(
      buildTestApp(
        authModel: authModel,
        onNamiAi: () => openedChat = true,
        namiAiAccessLoader: () async =>
            const NamiAiAccessDecision(state: NamiAiAccessState.enabled),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('NaMi AI'), findsOneWidget);
    expect(find.text('AI-Chat (Test)'), findsOneWidget);

    await tester.tap(find.text('NaMi AI'));
    await tester.pump();

    expect(openedChat, isTrue);
  });

  testWidgets('oeffnet Paywall bei Membership-Lock', (tester) async {
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

    var openedPaywall = false;

    await tester.pumpWidget(
      buildTestApp(
        authModel: authModel,
        onNamiAiPaywall: () => openedPaywall = true,
        namiAiAccessLoader: () async => const NamiAiAccessDecision(
          state: NamiAiAccessState.lockedByMembership,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('NaMi AI'), findsOneWidget);
    expect(find.text('Premium erforderlich'), findsOneWidget);

    await tester.tap(find.text('NaMi AI'));
    await tester.pump();

    expect(openedPaywall, isTrue);
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

      var openedMessages = false;

      await tester.pumpWidget(
        buildTestApp(
          authModel: authModel,
          onMessages: () {
            openedMessages = true;
          },
        ),
      );

      await tester.pump();

      expect(find.byKey(const Key('settings-messages-banner')), findsOneWidget);
      expect(find.byKey(const Key('settings-messages-badge')), findsOneWidget);
      expect(find.text('Login abgelaufen'), findsOneWidget);
      expect(
        find.text(
          'Klicke, um dich neu anzumelden. Die App kann weiter lokale Daten anzeigen.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('settings-messages-banner')));
      await tester.pump();

      expect(openedMessages, isTrue);
    },
  );

  testWidgets('laedt Messages nach Rueckkehr von der Meldungsseite neu', (
    tester,
  ) async {
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
    var unreadExternal = <AppHubNotification>[
      AppHubNotification(
        id: 'external-1',
        source: AppNotificationSource.external,
        severity: AppNotificationSeverity.warn,
        title: const LocalizedString(de: 'Meldung', en: 'Message'),
        body: const LocalizedString(de: 'Bitte lesen', en: 'Please read'),
      ),
    ];

    await tester.pumpWidget(
      buildTestApp(
        authModel: authModel,
        unreadExternalNotificationsLoader: () async => unreadExternal,
        onMessages: () async {
          unreadExternal = const <AppHubNotification>[];
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-messages-banner')), findsOneWidget);
    expect(find.text('Meldung'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-messages-banner')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-messages-banner')), findsNothing);
  });

  testWidgets('zeigt bei zwei Meldungen genau einen Stapel-Layer', (
    tester,
  ) async {
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

    authModel.reportRemoteDataIssue('offline');

    final updateService = AppUpdateService(
      platformOverride: 'android',
      currentVersionProvider: () async => '1.0.0',
      manifestProvider: () async => <String, dynamic>{
        'android': <String, dynamic>{
          'latest': '1.1.0',
          'min_supported': '0.9.0',
          'store_url': 'https://example.com/app',
        },
      },
    );

    await tester.pumpWidget(
      buildTestApp(
        authModel: authModel,
        additionalProviders: [
          Provider<AppUpdateService>.value(value: updateService),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('settings-messages-stack-back-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('settings-messages-stack-back-2')),
      findsNothing,
    );
    expect(find.text('2'), findsOneWidget);
  });
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
