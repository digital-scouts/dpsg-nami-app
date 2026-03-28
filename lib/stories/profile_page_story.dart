import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nami/domain/auth/auth_profile.dart';
import 'package:nami/domain/auth/auth_profile_repository.dart';
import 'package:nami/domain/auth/auth_session.dart';
import 'package:nami/domain/auth/auth_session_repository.dart';
import 'package:nami/domain/settings/app_settings.dart';
import 'package:nami/domain/settings/app_settings_repository.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/screens/profile_page.dart';
import 'package:nami/services/biometric_lock_service.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_data_retention_policy.dart';
import 'package:nami/services/hitobito_oauth_service.dart';
import 'package:nami/services/logger_service.dart';
import 'package:nami/services/sensitive_storage_service.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story profilePageStory() => Story(
  name: 'Screens/ProfilePage/WithNicknameAndRoles',
  builder: (context) => _ProfileStoryShell(
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
  ),
);

Story profilePageWithoutNicknameStory() => Story(
  name: 'Screens/ProfilePage/WithoutNicknameNoRoles',
  builder: (context) => _ProfileStoryShell(
    profile: const AuthProfile(
      namiId: 35,
      email: 'max@example.com',
      firstName: 'Max',
      lastName: 'Mustermann',
      language: 'de',
    ),
  ),
);

Story profilePageUnknownLanguageStory() => Story(
  name: 'Screens/ProfilePage/UnknownLanguageFallback',
  builder: (context) => _ProfileStoryShell(
    profile: const AuthProfile(
      namiId: 36,
      email: 'lea@example.com',
      firstName: 'Lea',
      lastName: 'Beispiel',
      language: 'fr',
    ),
  ),
);

class _ProfileStoryShell extends StatefulWidget {
  const _ProfileStoryShell({required this.profile});

  final AuthProfile profile;

  @override
  State<_ProfileStoryShell> createState() => _ProfileStoryShellState();
}

class _ProfileStoryShellState extends State<_ProfileStoryShell> {
  late final AuthSessionModel _authModel;
  late final Future<void> _signInFuture;

  @override
  void initState() {
    super.initState();
    _authModel = AuthSessionModel(
      repository: _InMemoryAuthSessionRepository(),
      profileRepository: _InMemoryAuthProfileRepository(),
      oauthService: _FakeOauthService(profileToReturn: widget.profile),
      biometricLockService: _FakeBiometricLockService(),
      sensitiveStorageService: _FakeSensitiveStorageService(),
      retentionPolicy: HitobitoDataRetentionPolicy(
        maxDataAge: const Duration(days: 90),
        refreshInterval: const Duration(hours: 24),
      ),
      logger: _FakeLoggerService(),
    );
    _signInFuture = _authModel.signIn();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _signInFuture,
      builder: (context, snapshot) {
        return ChangeNotifierProvider<AuthSessionModel>.value(
          value: _authModel,
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
        );
      },
    );
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
  _FakeOauthService({required this.profileToReturn})
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

  final AuthProfile profileToReturn;

  @override
  Future<AuthSession> authenticateInteractive() async => AuthSession(
    accessToken: 'storybook-token',
    refreshToken: 'storybook-refresh-token',
    receivedAt: DateTime(2026, 3, 27),
  );

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
