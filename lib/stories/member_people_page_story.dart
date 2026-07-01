import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
import 'package:nami/domain/member_filters/member_filter_repository.dart';
import 'package:nami/domain/settings/app_settings.dart';
import 'package:nami/domain/settings/app_settings_repository.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/arbeitskontext_model.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/model/member_filters_model.dart';
import 'package:nami/presentation/screens/member_people_page.dart';
import 'package:nami/services/biometric_lock_service.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_data_retention_policy.dart';
import 'package:nami/services/hitobito_groups_service.dart';
import 'package:nami/services/hitobito_oauth_service.dart';
import 'package:nami/services/logger_service.dart';
import 'package:nami/services/sensitive_storage_service.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story memberPeoplePageLoadedStory() => Story(
  name: 'Mitglieder/Screens/Liste/Geladen',
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
  name: 'Mitglieder/Screens/Liste/Leer',
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
  late final ArbeitskontextModel _arbeitskontextModel;
  late final MemberFiltersModel _memberFiltersModel;
  late final Future<void> _initializeFuture;

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
    _arbeitskontextModel = ArbeitskontextModel(
      localRepository: _FakeArbeitskontextLocalRepository(
        cached: ArbeitskontextReadModel(
          arbeitskontext: Arbeitskontext(
            aktiverLayer: const ArbeitskontextLayer(
              id: 11,
              name: 'Stamm Musterdorf',
            ),
          ),
          mitglieder: widget.cached,
        ),
      ),
      readModelRepository: _FakeArbeitskontextReadModelRepository(),
      groupsService: _FakeHitobitoGroupsService(),
      bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
      logger: _FakeLoggerService(),
    );
    _memberFiltersModel = MemberFiltersModel(_InMemoryMemberFilterRepository());
    _initializeFuture = _initialize();
  }

  Future<void> _initialize() async {
    await _authModel.signIn();
    await _arbeitskontextModel.syncForAuth(
      authState: _authModel.state,
      session: _authModel.session,
      profile: _authModel.profile,
    );
    await _memberFiltersModel.ensureLoadedForLayer(11);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthSessionModel>.value(value: _authModel),
        ChangeNotifierProvider<ArbeitskontextModel>.value(
          value: _arbeitskontextModel,
        ),
        ChangeNotifierProvider<MemberFiltersModel>.value(
          value: _memberFiltersModel,
        ),
      ],
      child: FutureBuilder<void>(
        future: _initializeFuture,
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

class _InMemoryMemberFilterRepository implements MemberFilterRepository {
  final Map<int, MemberFilterLayerSettings> _values =
      <int, MemberFilterLayerSettings>{};

  @override
  Future<MemberFilterLayerSettings> loadForLayer(int layerId) async {
    return _values[layerId] ?? const MemberFilterLayerSettings();
  }

  @override
  Future<void> saveForLayer(
    int layerId,
    MemberFilterLayerSettings settings,
  ) async {
    _values[layerId] = settings;
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
