import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story memberPeoplePageLoadedStory() => Story(
  name: 'Screens/MemberPeoplePage/Loaded',
  builder: (context) => _MemberPeopleStoryShell(
    cached: <Mitglied>[
      Mitglied.peopleListItem(
        mitgliedsnummer: '1001',
        vorname: 'Julia',
        nachname: 'Keller',
      ),
      Mitglied.peopleListItem(
        mitgliedsnummer: '1002',
        vorname: 'Max',
        nachname: 'Mustermann',
      ),
    ],
  ),
);

Story memberPeoplePageEmptyStory() => Story(
  name: 'Screens/MemberPeoplePage/Empty',
  builder: (context) => _MemberPeopleStoryShell(cached: const <Mitglied>[]),
);

class _MemberPeopleStoryShell extends StatefulWidget {
  const _MemberPeopleStoryShell({required this.cached});

  final List<Mitglied> cached;

  @override
  State<_MemberPeopleStoryShell> createState() =>
      _MemberPeopleStoryShellState();
}

class _MemberPeopleStoryShellState extends State<_MemberPeopleStoryShell> {
  late final AuthSessionModel _authModel;
  late final MemberPeopleModel _peopleModel;
  late final Future<void> _signInFuture;

  @override
  void initState() {
    super.initState();
    _authModel = AuthSessionModel(
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
    _peopleModel = MemberPeopleModel(
      repository: _FakeMemberPeopleRepository(cached: widget.cached),
      logger: _FakeLoggerService(),
    );
    _signInFuture = _authModel.signIn();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthSessionModel>.value(value: _authModel),
        ChangeNotifierProvider<MemberPeopleModel>.value(value: _peopleModel),
      ],
      child: FutureBuilder<void>(
        future: _signInFuture,
        builder: (context, snapshot) {
          return MaterialApp(
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              AppLocalizations.delegate,
            ],
            supportedLocales: const [Locale('de'), Locale('en')],
            locale: const Locale('de'),
            home: const MemberPeoplePage(),
          );
        },
      ),
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

class _FakeMemberPeopleRepository implements MemberPeopleRepository {
  _FakeMemberPeopleRepository({required this.cached});

  final List<Mitglied> cached;

  @override
  Future<List<Mitglied>> loadCached() async => cached;

  @override
  Future<List<Mitglied>> refresh(String accessToken) async => cached;
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
    accessToken: 'storybook-token',
    refreshToken: 'storybook-refresh-token',
    receivedAt: DateTime(2026, 3, 27),
  );

  @override
  Future<AuthProfile> fetchProfile(AuthSession session) async =>
      const AuthProfile(
        namiId: 1,
        firstName: 'Story',
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

  _FakeSensitiveStorageService() : super();

  @override
  Future<String?> loadPrincipal() async => _principal;

  @override
  Future<DateTime?> loadLastSensitiveSyncAt() async => _lastSensitiveSyncAt;

  @override
  Future<void> purgeSensitiveData() async {
    _principal = null;
    _lastSensitiveSyncAt = null;
  }

  @override
  Future<void> saveLastSensitiveSyncAt(DateTime timestamp) async {
    _lastSensitiveSyncAt = timestamp;
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
