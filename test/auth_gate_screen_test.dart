import 'dart:async';

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
import 'package:nami/presentation/screens/auth_gate_screen.dart';
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
    'zeigt waehrend der Initialisierung den Arbeitskontext-Ladestatus',
    (tester) async {
      final authModel = await _buildSignedInAuthModel(
        const AuthProfile(
          namiId: 10,
          roles: <AuthProfileRole>[
            AuthProfileRole(
              groupId: 11,
              groupName: 'Stamm Musterdorf',
              roleName: 'Mitglied',
              roleClass: 'Group::Mitglied',
            ),
          ],
        ),
      );
      final localRepository = _DelayedArbeitskontextLocalRepository();
      final arbeitskontextModel = ArbeitskontextModel(
        localRepository: localRepository,
        readModelRepository: _FakeArbeitskontextReadModelRepository(),
        groupsService: _FakeHitobitoGroupsService(
          groups: const <HitobitoGroupResource>[
            HitobitoGroupResource(
              id: 11,
              name: 'Stamm Musterdorf',
              isLayer: true,
            ),
          ],
        ),
        bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
        logger: _FakeLoggerService(),
      );

      final pending = arbeitskontextModel.syncForAuth(
        authState: authModel.state,
        session: authModel.session,
        profile: authModel.profile,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthSessionModel>.value(value: authModel),
            ChangeNotifierProvider<ArbeitskontextModel>.value(
              value: arbeitskontextModel,
            ),
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
            home: const AuthGateScreen(),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Arbeitskontext wird geladen'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      localRepository.complete();
      await pending;
    },
  );

  testWidgets(
    'zeigt ohne relevante Rechte einen expliziten Nicht-Berechtigt-Zustand',
    (tester) async {
      final authModel = await _buildSignedInAuthModel(
        const AuthProfile(namiId: 11),
      );
      final arbeitskontextModel = ArbeitskontextModel(
        localRepository: _ImmediateArbeitskontextLocalRepository(),
        readModelRepository: _FakeArbeitskontextReadModelRepository(),
        groupsService: _FakeHitobitoGroupsService(),
        bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
        logger: _FakeLoggerService(),
      );

      await arbeitskontextModel.syncForAuth(
        authState: authModel.state,
        session: authModel.session,
        profile: authModel.profile,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthSessionModel>.value(value: authModel),
            ChangeNotifierProvider<ArbeitskontextModel>.value(
              value: arbeitskontextModel,
            ),
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
            home: const AuthGateScreen(),
          ),
        ),
      );

      await tester.pump();

      expect(
        find.text(ArbeitskontextModel.unauthorizedMessage),
        findsNWidgets(2),
      );
      expect(find.text('Abmelden'), findsOneWidget);
      expect(find.text('Einstellungen'), findsOneWidget);
      expect(
        find.textContaining(
          'mindestens ein relevantes Layer- oder Gruppenrecht',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'laesst die Einstellungen auch ohne Login ueber die Shell erreichen',
    (tester) async {
      final authModel = AuthSessionModel(
        repository: _InMemoryAuthSessionRepository(),
        profileRepository: _InMemoryAuthProfileRepository(),
        oauthService: _FakeOauthService(
          profileToReturn: const AuthProfile(namiId: 99),
        ),
        biometricLockService: _FakeBiometricLockService(),
        sensitiveStorageService: _FakeSensitiveStorageService(),
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
        ),
        logger: _FakeLoggerService(),
      );
      final arbeitskontextModel = ArbeitskontextModel(
        localRepository: _ImmediateArbeitskontextLocalRepository(),
        readModelRepository: _FakeArbeitskontextReadModelRepository(),
        groupsService: _FakeHitobitoGroupsService(),
        bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
        logger: _FakeLoggerService(),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthSessionModel>.value(value: authModel),
            ChangeNotifierProvider<ArbeitskontextModel>.value(
              value: arbeitskontextModel,
            ),
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
            home: const AuthGateScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.text('Einstellungen'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Stamm'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    },
  );
}

Future<AuthSessionModel> _buildSignedInAuthModel(AuthProfile profile) async {
  final authModel = AuthSessionModel(
    repository: _InMemoryAuthSessionRepository(),
    profileRepository: _InMemoryAuthProfileRepository(),
    oauthService: _FakeOauthService(profileToReturn: profile),
    biometricLockService: _FakeBiometricLockService(),
    sensitiveStorageService: _FakeSensitiveStorageService(),
    retentionPolicy: HitobitoDataRetentionPolicy(
      maxDataAge: const Duration(days: 90),
      refreshInterval: const Duration(hours: 24),
      nowProvider: () => DateTime(2026, 3, 31, 12),
    ),
    logger: _FakeLoggerService(),
  );
  await authModel.signIn();
  return authModel;
}

class _ImmediateArbeitskontextLocalRepository
    implements ArbeitskontextLocalRepository {
  @override
  Future<void> clearCached() async {}

  @override
  Future<ArbeitskontextReadModel?> loadLastCached() async => null;

  @override
  Future<void> saveCached(ArbeitskontextReadModel readModel) async {}
}

class _DelayedArbeitskontextLocalRepository
    implements ArbeitskontextLocalRepository {
  final Completer<void> _completer = Completer<void>();

  void complete() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }

  @override
  Future<void> clearCached() async {}

  @override
  Future<ArbeitskontextReadModel?> loadLastCached() async {
    await _completer.future;
    return null;
  }

  @override
  Future<void> saveCached(ArbeitskontextReadModel readModel) async {}
}

class _FakeArbeitskontextReadModelRepository
    implements ArbeitskontextReadModelRepository {
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
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    receivedAt: DateTime(2026, 3, 31, 12),
  );

  @override
  Future<AuthProfile> fetchProfile(AuthSession session) async =>
      profileToReturn;

  @override
  Future<AuthSession> refresh(AuthSession session) async => session;

  @override
  Future<AuthSession> refreshIfNeeded(
    AuthSession session, {
    Duration threshold = Duration.zero,
  }) async => session;
}

class _FakeBiometricLockService extends BiometricLockService {
  _FakeBiometricLockService() : super(logger: _FakeLoggerService());

  @override
  Future<bool> authenticate() async => true;

  @override
  Future<bool> isAvailable() async => false;
}

class _FakeSensitiveStorageService extends SensitiveStorageService {
  DateTime? _lastSensitiveSyncAt;
  DateTime? _lastSensitiveSyncAttemptAt;
  DateTime? _lastBackgroundedAt;
  String? _principal;

  @override
  Future<DateTime?> loadLastBackgroundedAt() async => _lastBackgroundedAt;

  @override
  Future<DateTime?> loadLastSensitiveSyncAt() async => _lastSensitiveSyncAt;

  @override
  Future<DateTime?> loadLastSensitiveSyncAttemptAt() async =>
      _lastSensitiveSyncAttemptAt;

  @override
  Future<String?> loadPrincipal() async => _principal;

  @override
  Future<void> purgeSensitiveData() async {
    _lastSensitiveSyncAt = null;
    _lastSensitiveSyncAttemptAt = null;
    _lastBackgroundedAt = null;
    _principal = null;
  }

  @override
  Future<void> saveLastBackgroundedAt(DateTime? value) async {
    _lastBackgroundedAt = value;
  }

  @override
  Future<void> saveLastSensitiveSyncAt(DateTime? value) async {
    _lastSensitiveSyncAt = value;
  }

  @override
  Future<void> saveLastSensitiveSyncAttemptAt(DateTime? value) async {
    _lastSensitiveSyncAttemptAt = value;
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
  Future<void> saveMemberListSearchResultHighlightEnabled(bool enabled) async {}

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {}
}
