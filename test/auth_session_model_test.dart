import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:nami/data/achievements/shared_prefs_achievement_repository.dart';
import 'package:nami/data/statistiks/shared_prefs_statistik_verlauf_repository.dart';
import 'package:nami/domain/achievements/achievement_definition.dart';
import 'package:nami/domain/auth/auth_profile.dart';
import 'package:nami/domain/auth/auth_session.dart';
import 'package:nami/domain/auth/auth_state.dart';
import 'package:nami/domain/statistiks/statistik_verlauf.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/services/achievement_service.dart';
import 'package:nami/services/hitobito_data_retention_policy.dart';
import 'package:nami/services/hitobito_oauth_service.dart';
import 'package:nami/services/hitobito_people_service.dart';
import 'package:nami/services/network_access_policy.dart';
import 'package:nami/services/sensitive_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/auth_session_fakes.dart';
import 'support/fake_logger_service.dart';

void main() {
  test(
    'Abmelden loescht sensible Daten, aber nicht den Statistik-Verlauf',
    () async {
      // Der Verlauf baut sich ueber Monate auf und enthaelt nur Summen; er
      // soll ein Abmelden ueberstehen. Echte Speicher, damit ein spaeteres
      // Aufraeumen im Logout hier auffaellt.
      SharedPreferences.setMockInitialValues(<String, Object>{});
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      final tempDir = await Directory.systemTemp.createTemp('logout_verlauf_');
      Hive.init(tempDir.path);
      addTearDown(() async {
        await Hive.close();
        await tempDir.delete(recursive: true);
      });

      SensitiveStorageService.resetForTest();
      final sensitiveStorage = SensitiveStorageService()..beginSession();
      final mitglieder = await sensitiveStorage.openEncryptedStringBox(
        'hitobito_people_box',
      );
      await mitglieder.put('person-1', '{"name":"Mara"}');

      final verlauf = SharedPrefsStatistikVerlaufRepository();
      const eintraege = <StatistikVerlaufEintrag>[
        StatistikVerlaufEintrag(
          monat: '2026-08',
          personen: 74,
          kinder: 56,
          leitende: 14,
        ),
        StatistikVerlaufEintrag(
          monat: '2026-09',
          personen: 75,
          kinder: 57,
          leitende: 14,
        ),
      ];
      await verlauf.saveForLayer(31, eintraege);

      final model = AuthSessionModel(
        repository: InMemoryAuthSessionRepository(
          initialSession: AuthSession(
            accessToken: 'access-token',
            refreshToken: 'refresh-token',
            receivedAt: DateTime(2026, 9, 30),
          ),
        ),
        profileRepository: InMemoryAuthProfileRepository(),
        oauthService: FakeOauthService(
          sessionToReturn: AuthSession(
            accessToken: 'access-token',
            receivedAt: DateTime(2026, 9, 30),
          ),
          profileToReturn: const AuthProfile(namiId: 31),
        ),
        biometricLockService: FakeBiometricLockService(),
        sensitiveStorageService: sensitiveStorage,
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
          nowProvider: () => DateTime(2026, 9, 30, 12),
        ),
        logger: _createLogger(),
      );

      await model.logout();

      expect(model.state, AuthState.signedOut);
      expect(await Hive.boxExists('hitobito_people_box'), isFalse);
      expect(sensitiveStorage.isSessionOpen, isFalse);
      expect(await verlauf.loadForLayer(31), eintraege);
    },
    timeout: const Timeout(Duration(seconds: 5)),
  );

  test(
    'setzt unbekannte Profilsprache nach Login auf deutsch zurueck',
    () async {
      final oauthService = FakeOauthService(
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
        repository: InMemoryAuthSessionRepository(),
        profileRepository: InMemoryAuthProfileRepository(),
        oauthService: oauthService,
        biometricLockService: FakeBiometricLockService(),
        sensitiveStorageService: FakeSensitiveStorageService(),
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
      final oauthService = FakeOauthService(
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
        repository: InMemoryAuthSessionRepository(),
        profileRepository: InMemoryAuthProfileRepository(),
        oauthService: oauthService,
        biometricLockService: FakeBiometricLockService(),
        sensitiveStorageService: FakeSensitiveStorageService(),
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
      final oauthService = FakeOauthService(
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
      final repository = InMemoryAuthSessionRepository(
        initialSession: AuthSession(
          accessToken: 'existing-token',
          receivedAt: DateTime(2026, 3, 27),
        ),
      );
      final languageChanges = <String>[];

      final model = AuthSessionModel(
        repository: repository,
        profileRepository: InMemoryAuthProfileRepository(),
        oauthService: oauthService,
        biometricLockService: FakeBiometricLockService(),
        sensitiveStorageService: FakeSensitiveStorageService(),
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
    'setzt state auf error statt eine Exception unbehandelt zu lassen, wenn initialize fehlschlaegt',
    () async {
      final repository = InMemoryAuthSessionRepository()
        ..loadError = Exception('Storage nicht verfuegbar');

      final model = AuthSessionModel(
        repository: repository,
        profileRepository: InMemoryAuthProfileRepository(),
        oauthService: FakeOauthService(
          sessionToReturn: AuthSession(
            accessToken: 'unused',
            receivedAt: DateTime(2026, 3, 27),
          ),
          profileToReturn: const AuthProfile(
            namiId: 37,
            firstName: 'Lea',
            lastName: 'Beispiel',
          ),
        ),
        biometricLockService: FakeBiometricLockService(),
        sensitiveStorageService: FakeSensitiveStorageService(),
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
          nowProvider: () => DateTime(2026, 3, 27, 12),
        ),
        logger: _createLogger(),
      );

      // Darf nicht mit einer unbehandelten Exception fehlschlagen - main.dart
      // ruft initialize() erst NACH runApp() auf; eine hier unbehandelte
      // Exception wuerde sonst (ausserhalb dieses Tests) den Nutzer ohne
      // jede Fehleranzeige zuruecklassen.
      await model.initialize();

      expect(model.state, AuthState.error);
      expect(model.errorMessage, isNotNull);
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );

  group('Session aus einer frueheren Installation', () {
    ({
      AuthSessionModel model,
      InMemoryAuthSessionRepository repository,
      FakeOauthService oauth,
      FakeLoggerService logger,
    })
    neuinstallation({required bool hasLocalData}) {
      final repository = InMemoryAuthSessionRepository(
        initialSession: AuthSession(
          accessToken: 'existing-token',
          refreshToken: 'existing-refresh-token',
          receivedAt: DateTime(2026, 3, 27),
        ),
      );
      final oauth = FakeOauthService(
        sessionToReturn: AuthSession(
          accessToken: 'unused',
          receivedAt: DateTime(2026, 3, 27),
        ),
        profileToReturn: const AuthProfile(
          namiId: 99,
          firstName: 'Lea',
          lastName: 'Beispiel',
          language: 'de',
        ),
      );
      final logger = _createLogger();
      final model = AuthSessionModel(
        repository: repository,
        profileRepository: InMemoryAuthProfileRepository(),
        oauthService: oauth,
        biometricLockService: FakeBiometricLockService(),
        sensitiveStorageService: FakeSensitiveStorageService()
          ..hasLocalData = hasLocalData,
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
          nowProvider: () => DateTime(2026, 3, 27, 12),
        ),
        logger: logger,
        // Nach einer Neuinstallation ist die App-Sperre aus, weil ihre
        // Einstellung mit den App-Daten geloescht wurde.
        isAppLockEnabled: () => false,
      );
      return (
        model: model,
        repository: repository,
        oauth: oauth,
        logger: logger,
      );
    }

    test(
      'meldet ohne lokale App-Daten niemanden an und verwirft die Session',
      () async {
        final t = neuinstallation(hasLocalData: false);

        await t.model.initialize();

        expect(t.model.state, AuthState.signedOut);
        expect(t.model.session, isNull);
        expect(t.model.profile, isNull);
        expect(await t.repository.load(), isNull);
        expect(t.oauth.refreshCallCount, 0);
        expect(t.oauth.fetchProfileCallCount, 0);
        expect(
          t.logger.entries.any(
            (entry) => entry.message.contains(
              'Uebernommene Session ohne lokale App-Daten erkannt',
            ),
          ),
          isTrue,
        );
      },
      timeout: const Timeout(Duration(seconds: 3)),
    );

    test(
      'behaelt die Session, wenn lokale App-Daten vorhanden sind',
      () async {
        final t = neuinstallation(hasLocalData: true);

        await t.model.initialize();

        expect(t.model.state, AuthState.signedIn);
        expect(t.model.session?.accessToken, 'existing-token');
      },
      timeout: const Timeout(Duration(seconds: 3)),
    );
  });

  test(
    'loggt den erwarteten 401-Fall beim Profil-Laden waehrend initialize nicht',
    () async {
      final logger = _createLogger();
      final oauthService =
          FakeOauthService(
              sessionToReturn: AuthSession(
                accessToken: 'existing-token',
                receivedAt: DateTime(2026, 3, 27),
              ),
              profileToReturn: const AuthProfile(
                namiId: 37,
                firstName: 'Lea',
                lastName: 'Beispiel',
                language: 'de',
              ),
            )
            ..fetchProfileError = const HitobitoAuthException(
              'Profil-Anfrage fehlgeschlagen (401).',
              statusCode: 401,
            );

      final model = AuthSessionModel(
        repository: InMemoryAuthSessionRepository(
          initialSession: AuthSession(
            accessToken: 'existing-token',
            receivedAt: DateTime(2026, 3, 27),
          ),
        ),
        profileRepository: InMemoryAuthProfileRepository(),
        oauthService: oauthService,
        biometricLockService: FakeBiometricLockService(),
        sensitiveStorageService: FakeSensitiveStorageService(),
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
          nowProvider: () => DateTime(2026, 3, 27, 12),
        ),
        logger: logger,
      );

      await model.initialize();

      expect(model.state, AuthState.signedIn);
      expect(model.hasRemoteAccessIssue, isTrue);
      expect(model.requiresInteractiveLogin, isTrue);
      expect(
        logger.entries.where(
          (entry) =>
              entry.message.contains('Profil konnte nicht geladen werden'),
        ),
        isEmpty,
      );
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );

  test(
    'loggt unerwartete Profil-Fehler waehrend initialize weiter',
    () async {
      final logger = _createLogger();
      final oauthService =
          FakeOauthService(
              sessionToReturn: AuthSession(
                accessToken: 'existing-token',
                receivedAt: DateTime(2026, 3, 27),
              ),
              profileToReturn: const AuthProfile(
                namiId: 38,
                firstName: 'Lea',
                lastName: 'Beispiel',
                language: 'de',
              ),
            )
            ..fetchProfileError = const HitobitoAuthException(
              'Profil-Anfrage fehlgeschlagen (500).',
              statusCode: 500,
            );

      final model = AuthSessionModel(
        repository: InMemoryAuthSessionRepository(
          initialSession: AuthSession(
            accessToken: 'existing-token',
            receivedAt: DateTime(2026, 3, 27),
          ),
        ),
        profileRepository: InMemoryAuthProfileRepository(),
        oauthService: oauthService,
        biometricLockService: FakeBiometricLockService(),
        sensitiveStorageService: FakeSensitiveStorageService(),
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
          nowProvider: () => DateTime(2026, 3, 27, 12),
        ),
        logger: logger,
      );

      await model.initialize();

      expect(model.errorMessage, 'Profil-Anfrage fehlgeschlagen (500).');
      expect(
        logger.entries.where(
          (entry) =>
              entry.message.contains('Profil konnte nicht geladen werden'),
        ),
        isNotEmpty,
      );
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
      final oauthService = FakeOauthService(
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
      final profileRepository = InMemoryAuthProfileRepository(
        profile: cachedProfile,
        lastSyncAt: DateTime(2026, 3, 27, 6),
      );

      final model = AuthSessionModel(
        repository: InMemoryAuthSessionRepository(
          initialSession: AuthSession(
            accessToken: 'existing-token',
            receivedAt: DateTime(2026, 3, 27),
          ),
        ),
        profileRepository: profileRepository,
        oauthService: oauthService,
        biometricLockService: FakeBiometricLockService(),
        sensitiveStorageService: FakeSensitiveStorageService(),
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
      final oauthService = FakeOauthService(
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
      final sensitiveStorage = FakeSensitiveStorageService();
      final memberSyncTokens = <String>[];
      final model = AuthSessionModel(
        repository: InMemoryAuthSessionRepository(),
        profileRepository: InMemoryAuthProfileRepository(),
        oauthService: oauthService,
        biometricLockService: FakeBiometricLockService(),
        sensitiveStorageService: sensitiveStorage,
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
          nowProvider: () => DateTime(2026, 3, 28, 12),
        ),
        logger: _createLogger(),
      );

      await model.signIn();
      sensitiveStorage.lastSensitiveSyncAt = DateTime(2026, 3, 27, 8);

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
    'bleibt bei wiederholtem 401 waehrend Sync signedIn und blockiert weitere Remote-Zugriffe',
    () async {
      final oauthService = FakeOauthService(
        sessionToReturn: AuthSession(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          receivedAt: DateTime(2026, 3, 27),
        ),
        profileToReturn: const AuthProfile(
          namiId: 91,
          firstName: 'Remote',
          lastName: 'Issue',
          language: 'de',
        ),
      );
      final sensitiveStorage = FakeSensitiveStorageService();
      final model = AuthSessionModel(
        repository: InMemoryAuthSessionRepository(),
        profileRepository: InMemoryAuthProfileRepository(),
        oauthService: oauthService,
        biometricLockService: FakeBiometricLockService(),
        sensitiveStorageService: sensitiveStorage,
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
          nowProvider: () => DateTime(2026, 3, 28, 12),
        ),
        logger: _createLogger(),
      );

      await model.signIn();
      await model.markSensitiveDataSynced();
      oauthService.fetchProfileError = const HitobitoAuthException(
        'Profil-Anfrage fehlgeschlagen (401).',
        statusCode: 401,
      );

      await model.syncHitobitoData(syncMembers: (_) async {}, force: true);

      expect(model.state, AuthState.signedIn);
      expect(model.hasRemoteAccessIssue, isTrue);
      expect(model.requiresInteractiveLogin, isTrue);
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );

  test(
    'retryt Mitgliedersync nach 401 einmal mit aufgefrischter Session',
    () async {
      final oauthService = FakeOauthService(
        sessionToReturn: AuthSession(
          accessToken: 'refreshed-token',
          refreshToken: 'refresh-token',
          receivedAt: DateTime(2026, 3, 28, 12),
        ),
        profileToReturn: const AuthProfile(
          namiId: 94,
          firstName: 'Retry',
          lastName: 'MemberSync',
          language: 'de',
        ),
      );
      final model = AuthSessionModel(
        repository: InMemoryAuthSessionRepository(
          initialSession: AuthSession(
            accessToken: 'stale-token',
            refreshToken: 'refresh-token',
            receivedAt: DateTime(2026, 3, 27),
          ),
        ),
        profileRepository: InMemoryAuthProfileRepository(
          profile: const AuthProfile(
            namiId: 94,
            firstName: 'Retry',
            lastName: 'MemberSync',
            language: 'de',
          ),
          lastSyncAt: DateTime(2026, 3, 28, 8),
        ),
        oauthService: oauthService,
        biometricLockService: FakeBiometricLockService(),
        sensitiveStorageService: FakeSensitiveStorageService(),
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
          nowProvider: () => DateTime(2026, 3, 28, 12),
        ),
        logger: _createLogger(),
      );
      final memberSyncTokens = <String>[];

      await model.initialize();
      await model.syncHitobitoData(
        syncMembers: (accessToken) async {
          memberSyncTokens.add(accessToken);
          if (memberSyncTokens.length == 1) {
            throw const HitobitoPeopleException(
              'People-Anfrage fehlgeschlagen (401).',
              statusCode: 401,
            );
          }
        },
      );

      expect(model.state, AuthState.signedIn);
      expect(memberSyncTokens, <String>['stale-token', 'refreshed-token']);
      expect(model.session?.accessToken, 'refreshed-token');
      expect(model.requiresInteractiveLogin, isFalse);
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );

  test(
    'markiert blockierten Netzwerkzugriff beim Sync ohne Relogin-Pflicht',
    () async {
      final oauthService = FakeOauthService(
        sessionToReturn: AuthSession(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          receivedAt: DateTime(2026, 3, 27),
        ),
        profileToReturn: const AuthProfile(
          namiId: 92,
          firstName: 'Offline',
          lastName: 'Sync',
          language: 'de',
        ),
      );
      final sensitiveStorage = FakeSensitiveStorageService();
      final model = AuthSessionModel(
        repository: InMemoryAuthSessionRepository(),
        profileRepository: InMemoryAuthProfileRepository(),
        oauthService: oauthService,
        biometricLockService: FakeBiometricLockService(),
        sensitiveStorageService: sensitiveStorage,
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
          nowProvider: () => DateTime(2026, 3, 28, 12),
        ),
        logger: _createLogger(),
        networkAccessPolicy: _BlockedNetworkAccessPolicy(
          const NetworkAccessBlockedException(
            reason: NetworkAccessBlockedReason.noMobileDataEnabled,
            connectionType: NetworkConnectionType.mobile,
            message:
                'Keine Mobilen Daten ist aktiviert. Hitobito ist nur ueber WLAN verfuegbar.',
          ),
        ),
      );

      await model.signIn();
      sensitiveStorage.lastSensitiveSyncAt = DateTime(2026, 3, 27, 8);

      await model.syncHitobitoData(
        syncMembers: (_) async {},
        force: true,
        trigger: 'debug_tools',
      );

      expect(model.state, AuthState.signedIn);
      expect(model.requiresInteractiveLogin, isFalse);
      expect(model.isRemoteAccessBlockedByNetworkPolicy, isTrue);
      expect(
        model.remoteAccessIssueMessage,
        'Keine Mobilen Daten ist aktiviert. Hitobito ist nur ueber WLAN verfuegbar.',
      );
      expect(model.lastSensitiveSyncAt, isNull);
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );

  test(
    'executeRemoteAccess versucht nach 401 und fehlgeschlagenem Refresh einen interaktiven Re-Login und macht erfolgreich weiter',
    () async {
      final oauthService =
          FakeOauthService(
              sessionToReturn: AuthSession(
                accessToken: 'interactive-token',
                refreshToken: 'interactive-refresh-token',
                receivedAt: DateTime(2026, 3, 28, 12),
              ),
              profileToReturn: const AuthProfile(
                namiId: 95,
                firstName: 'Interactive',
                lastName: 'Relogin',
                language: 'de',
              ),
            )
            ..refreshError = const HitobitoAuthException(
              'Token-Anfrage fehlgeschlagen (401).',
              statusCode: 401,
            );
      final model = AuthSessionModel(
        repository: InMemoryAuthSessionRepository(
          initialSession: AuthSession(
            accessToken: 'stale-token',
            refreshToken: 'stale-refresh-token',
            receivedAt: DateTime(2026, 3, 27),
          ),
        ),
        profileRepository: InMemoryAuthProfileRepository(
          profile: const AuthProfile(
            namiId: 95,
            firstName: 'Interactive',
            lastName: 'Relogin',
            language: 'de',
          ),
          lastSyncAt: DateTime(2026, 3, 28, 8),
        ),
        oauthService: oauthService,
        biometricLockService: FakeBiometricLockService(),
        sensitiveStorageService: FakeSensitiveStorageService(),
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
          nowProvider: () => DateTime(2026, 3, 28, 12),
        ),
        logger: _createLogger(),
      );
      final usedTokens = <String>[];

      await model.initialize();
      final result = await model.executeRemoteAccess<String>(
        trigger: 'members_load',
        action: (session) async {
          usedTokens.add(session.accessToken);
          if (usedTokens.length == 1) {
            throw const HitobitoPeopleException(
              'People-Anfrage fehlgeschlagen (401).',
              statusCode: 401,
            );
          }
          return 'ok';
        },
      );

      expect(result, 'ok');
      expect(usedTokens, <String>['stale-token', 'interactive-token']);
      expect(oauthService.refreshCallCount, 1);
      expect(oauthService.authenticateInteractiveCallCount, 1);
      expect(model.state, AuthState.signedIn);
      expect(model.session?.accessToken, 'interactive-token');
      expect(model.requiresInteractiveLogin, isFalse);
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );

  test(
    'Pull-Sync startet bei Loginbedarf interaktiven Login und synchronisiert danach weiter',
    () async {
      final oauthService = FakeOauthService(
        sessionToReturn: AuthSession(
          accessToken: 'interactive-token',
          refreshToken: 'interactive-refresh-token',
          receivedAt: DateTime(2026, 3, 28, 12),
        ),
        profileToReturn: const AuthProfile(
          namiId: 97,
          firstName: 'Pull',
          lastName: 'Refresh',
          language: 'de',
        ),
      );
      final sensitiveStorage = FakeSensitiveStorageService()
        ..lastSensitiveSyncAt = DateTime(2026, 3, 27, 8);
      final logger = _createLogger();
      final model = AuthSessionModel(
        repository: InMemoryAuthSessionRepository(
          initialSession: AuthSession(
            accessToken: 'stale-token',
            refreshToken: 'stale-refresh-token',
            receivedAt: DateTime(2026, 3, 27),
          ),
        ),
        profileRepository: InMemoryAuthProfileRepository(
          profile: const AuthProfile(
            namiId: 97,
            firstName: 'Cached',
            lastName: 'Profile',
            language: 'de',
          ),
          lastSyncAt: DateTime(2026, 3, 28, 8),
        ),
        oauthService: oauthService,
        biometricLockService: FakeBiometricLockService(),
        sensitiveStorageService: sensitiveStorage,
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
          nowProvider: () => DateTime(2026, 3, 28, 12),
        ),
        logger: logger,
      );
      final memberSyncTokens = <String>[];
      final observedStates = <AuthState>[];

      await model.initialize();
      model.reportRemoteDataIssue(
        'Profil-Anfrage fehlgeschlagen (401).',
        requiresInteractiveLogin: true,
      );
      model.addListener(() {
        observedStates.add(model.state);
      });

      await model.syncHitobitoData(
        force: true,
        trigger: 'member_list_pull_refresh',
        interactiveLoginOnRequired: true,
        syncMembers: (accessToken) async {
          memberSyncTokens.add(accessToken);
        },
      );

      expect(oauthService.authenticateInteractiveCallCount, 1);
      expect(memberSyncTokens, <String>['interactive-token']);
      expect(observedStates, isNot(contains(AuthState.authenticating)));
      expect(model.requiresInteractiveLogin, isFalse);
      expect(model.lastSensitiveSyncAt, DateTime(2026, 3, 28, 12));
      expect(
        logger.entries.any(
          (entry) => entry.message.contains(
            'Hitobito-Sync startet interaktiven Login trigger=member_list_pull_refresh',
          ),
        ),
        isTrue,
      );
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );

  test(
    'bleibt nach abgebrochenem interaktivem Relogin bei vorhandener Session und lokalem Profil signedIn',
    () async {
      final oauthService =
          FakeOauthService(
              sessionToReturn: AuthSession(
                accessToken: 'interactive-token',
                refreshToken: 'interactive-refresh-token',
                receivedAt: DateTime(2026, 3, 28, 12),
              ),
              profileToReturn: const AuthProfile(
                namiId: 96,
                firstName: 'Cached',
                lastName: 'Profile',
                language: 'de',
              ),
            )
            ..refreshError = const HitobitoAuthException(
              'Token-Anfrage fehlgeschlagen (401).',
              statusCode: 401,
            )
            ..authenticateError = HitobitoAuthException.fromPlatformException(
              PlatformException(
                code: 'CANCELED',
                message: 'User canceled login',
              ),
            );
      final cachedProfile = const AuthProfile(
        namiId: 96,
        firstName: 'Cached',
        lastName: 'Profile',
        language: 'de',
      );
      final model = AuthSessionModel(
        repository: InMemoryAuthSessionRepository(
          initialSession: AuthSession(
            accessToken: 'stale-token',
            refreshToken: 'stale-refresh-token',
            receivedAt: DateTime(2026, 3, 27),
          ),
        ),
        profileRepository: InMemoryAuthProfileRepository(
          profile: cachedProfile,
          lastSyncAt: DateTime(2026, 3, 28, 8),
        ),
        oauthService: oauthService,
        biometricLockService: FakeBiometricLockService(),
        sensitiveStorageService: FakeSensitiveStorageService(),
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
          nowProvider: () => DateTime(2026, 3, 28, 12),
        ),
        logger: _createLogger(),
      );

      await model.initialize();

      final result = await model.executeRemoteAccess<String>(
        trigger: 'members_load',
        action: (session) async {
          throw const HitobitoPeopleException(
            'People-Anfrage fehlgeschlagen (401).',
            statusCode: 401,
          );
        },
      );

      expect(result, isNull);
      expect(model.state, AuthState.signedIn);
      expect(model.profile, cachedProfile);
      expect(model.hasRemoteAccessIssue, isTrue);
      expect(model.requiresInteractiveLogin, isTrue);
      expect(model.session?.accessToken, 'stale-token');
      expect(oauthService.authenticateInteractiveCallCount, 1);
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );

  test(
    'interaktiver relogin mit Benutzerwechsel verwirft altes Profil, alten Sync-Stand und die urspruengliche Aktion',
    () async {
      final oauthService =
          FakeOauthService(
              sessionToReturn: AuthSession(
                accessToken: 'interactive-token',
                refreshToken: 'interactive-refresh-token',
                receivedAt: DateTime(2026, 3, 28, 12),
                principal: 'principal-new',
              ),
              profileToReturn: const AuthProfile(
                namiId: 222,
                firstName: 'Neu',
                lastName: 'Profil',
                language: 'de',
              ),
            )
            ..refreshError = const HitobitoAuthException(
              'Token-Anfrage fehlgeschlagen (401).',
              statusCode: 401,
            );
      final sensitiveStorage = FakeSensitiveStorageService()
        ..principal = 'principal-old'
        ..lastSensitiveSyncAt = DateTime(2026, 3, 27, 8)
        ..lastSensitiveSyncAttemptAt = DateTime(2026, 3, 27, 9);
      final model = AuthSessionModel(
        repository: InMemoryAuthSessionRepository(
          initialSession: AuthSession(
            accessToken: 'stale-token',
            refreshToken: 'stale-refresh-token',
            receivedAt: DateTime(2026, 3, 27),
            principal: 'principal-old',
          ),
        ),
        profileRepository: InMemoryAuthProfileRepository(
          profile: const AuthProfile(
            namiId: 111,
            firstName: 'Alt',
            lastName: 'Profil',
            language: 'de',
          ),
          lastSyncAt: DateTime(2026, 3, 27, 8),
        ),
        oauthService: oauthService,
        biometricLockService: FakeBiometricLockService(),
        sensitiveStorageService: sensitiveStorage,
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
          nowProvider: () => DateTime(2026, 3, 28, 12),
        ),
        logger: _createLogger(),
      );

      await model.initialize();
      final generationVorher = model.sessionGeneration;
      final aufgerufeneTokens = <String>[];
      final result = await model.executeRemoteAccess<String>(
        trigger: 'members_load',
        action: (session) async {
          aufgerufeneTokens.add(session.accessToken);
          if (session.accessToken == 'stale-token') {
            throw const HitobitoPeopleException(
              'People-Anfrage fehlgeschlagen (401).',
              statusCode: 401,
            );
          }
          return 'ok';
        },
      );

      // Die Aktion gehoert zum alten Konto und darf nicht mit der Session
      // des neuen Kontos weiterlaufen.
      expect(result, isNull);
      expect(aufgerufeneTokens, <String>['stale-token']);
      expect(model.sessionGeneration, isNot(generationVorher));
      expect(model.session?.principal, 'principal-new');
      expect(model.profile?.namiId, 222);
      expect(model.lastSensitiveSyncAt, isNull);
      expect(model.lastSensitiveSyncAttemptAt, isNull);
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );

  test(
    'loggt technisch abgefangene 401 als Retry-Hinweis ohne technischen Fehlertext',
    () async {
      final logger = _createLogger();
      final oauthService = FakeOauthService(
        sessionToReturn: AuthSession(
          accessToken: 'refreshed-token',
          refreshToken: 'refresh-token',
          receivedAt: DateTime(2026, 3, 28, 12),
        ),
        profileToReturn: const AuthProfile(
          namiId: 94,
          firstName: 'Retry',
          lastName: 'Logging',
          language: 'de',
        ),
      );
      final model = AuthSessionModel(
        repository: InMemoryAuthSessionRepository(
          initialSession: AuthSession(
            accessToken: 'stale-token',
            refreshToken: 'refresh-token',
            receivedAt: DateTime(2026, 3, 27),
          ),
        ),
        profileRepository: InMemoryAuthProfileRepository(
          profile: const AuthProfile(
            namiId: 94,
            firstName: 'Retry',
            lastName: 'Logging',
            language: 'de',
          ),
          lastSyncAt: DateTime(2026, 3, 28, 8),
        ),
        oauthService: oauthService,
        biometricLockService: FakeBiometricLockService(),
        sensitiveStorageService: FakeSensitiveStorageService(),
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
          nowProvider: () => DateTime(2026, 3, 28, 12),
        ),
        logger: logger,
      );

      await model.initialize();
      await model.executeRemoteAccess<String>(
        trigger: 'members_load',
        action: (session) async {
          if (session.accessToken == 'stale-token') {
            throw const HitobitoPeopleException(
              'People-Anfrage fehlgeschlagen (401).',
              statusCode: 401,
            );
          }
          return 'ok';
        },
      );

      expect(
        logger.entries.where(
          (entry) => entry.message.contains('Login abgelaufen, versuche Retry'),
        ),
        isNotEmpty,
      );
      expect(
        logger.entries.where(
          (entry) =>
              entry.message.contains('Session-Auffrischung fehlgeschlagen'),
        ),
        isEmpty,
      );
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );

  test(
    'bleibt bei fehlgeschlagener erneuter Anmeldung im bisherigen Zustand',
    () async {
      final oauthService = FakeOauthService(
        sessionToReturn: AuthSession(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          receivedAt: DateTime(2026, 3, 27),
        ),
        profileToReturn: const AuthProfile(
          namiId: 92,
          firstName: 'Retry',
          lastName: 'User',
          language: 'de',
        ),
      );
      final model = AuthSessionModel(
        repository: InMemoryAuthSessionRepository(),
        profileRepository: InMemoryAuthProfileRepository(),
        oauthService: oauthService,
        biometricLockService: FakeBiometricLockService(),
        sensitiveStorageService: FakeSensitiveStorageService(),
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
          nowProvider: () => DateTime(2026, 3, 28, 12),
        ),
        logger: _createLogger(),
      );

      await model.signIn();
      oauthService.authenticateError = const HitobitoAuthException(
        'OAuth Login fehlgeschlagen.',
      );

      await model.signIn();

      expect(model.state, AuthState.signedIn);
      expect(model.errorMessage, 'OAuth Login fehlgeschlagen.');
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );

  test(
    'loggt bei abgebrochener OAuth-Anmeldung keine technische PlatformException',
    () async {
      final logger = _createLogger();
      final oauthService = FakeOauthService(
        sessionToReturn: AuthSession(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          receivedAt: DateTime(2026, 3, 27),
        ),
        profileToReturn: const AuthProfile(
          namiId: 93,
          firstName: 'Cancel',
          lastName: 'User',
          language: 'de',
        ),
      );
      final model = AuthSessionModel(
        repository: InMemoryAuthSessionRepository(),
        profileRepository: InMemoryAuthProfileRepository(),
        oauthService: oauthService,
        biometricLockService: FakeBiometricLockService(),
        sensitiveStorageService: FakeSensitiveStorageService(),
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
          nowProvider: () => DateTime(2026, 3, 28, 12),
        ),
        logger: logger,
      );

      oauthService.authenticateError =
          HitobitoAuthException.fromPlatformException(
            PlatformException(code: 'CANCELED', message: 'User canceled login'),
          );

      await model.signIn();

      expect(model.errorMessage, 'Die Hitobito-Anmeldung wurde abgebrochen.');
      expect(logger.entries.where((entry) => entry.service == 'auth'), isEmpty);
      expect(
        logger.entries.where(
          (entry) => entry.message.contains('login cancelled'),
        ),
        isNotEmpty,
      );
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );

  test(
    'sperrt nach Resume erst nach konfiguriertem Timeout',
    () async {
      var now = DateTime(2026, 3, 28, 12, 0, 0);
      final model = AuthSessionModel(
        repository: InMemoryAuthSessionRepository(),
        profileRepository: InMemoryAuthProfileRepository(),
        oauthService: FakeOauthService(
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
        biometricLockService: FakeBiometricLockService(available: true),
        sensitiveStorageService: FakeSensitiveStorageService(),
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
          nowProvider: () => now,
        ),
        logger: _createLogger(),
        isAppLockEnabled: () => true,
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
        repository: InMemoryAuthSessionRepository(),
        profileRepository: InMemoryAuthProfileRepository(),
        oauthService: FakeOauthService(
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
        biometricLockService: FakeBiometricLockService(available: true),
        sensitiveStorageService: FakeSensitiveStorageService(),
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
          nowProvider: () => now,
        ),
        logger: _createLogger(),
        isAppLockEnabled: () => true,
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

  test(
    'sperrt nach Resume nicht, wenn die App-Sperre deaktiviert ist',
    () async {
      var now = DateTime(2026, 3, 28, 12, 0, 0);
      final model = AuthSessionModel(
        repository: InMemoryAuthSessionRepository(),
        profileRepository: InMemoryAuthProfileRepository(),
        oauthService: FakeOauthService(
          sessionToReturn: AuthSession(
            accessToken: 'access-token',
            refreshToken: 'refresh-token',
            receivedAt: now,
          ),
          profileToReturn: const AuthProfile(
            namiId: 90,
            firstName: 'NoLock',
            lastName: 'User',
            language: 'de',
          ),
        ),
        biometricLockService: FakeBiometricLockService(available: true),
        sensitiveStorageService: FakeSensitiveStorageService(),
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

      expect(model.state, AuthState.signedIn);
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );

  test(
    'Abmelden laesst die Erfolge des Geraets unberuehrt',
    () async {
      SharedPreferences.setMockInitialValues({});
      final now = DateTime(2026, 10, 1, 12);
      final achievements = AchievementService(
        repository: SharedPrefsAchievementRepository(),
        nowProvider: () => now,
      );
      final model = AuthSessionModel(
        repository: InMemoryAuthSessionRepository(),
        profileRepository: InMemoryAuthProfileRepository(),
        oauthService: FakeOauthService(
          sessionToReturn: AuthSession(
            accessToken: 'access-token',
            refreshToken: 'refresh-token',
            receivedAt: now,
          ),
          profileToReturn: const AuthProfile(
            namiId: 91,
            firstName: 'Erfolg',
            lastName: 'Reich',
            language: 'de',
          ),
        ),
        biometricLockService: FakeBiometricLockService(),
        sensitiveStorageService: FakeSensitiveStorageService(),
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
          nowProvider: () => now,
        ),
        logger: _createLogger(),
      );

      await model.signIn();
      await achievements.record(AchievementIds.memberEdited);
      await model.logout();

      final afterLogout = await AchievementService(
        repository: SharedPrefsAchievementRepository(),
        nowProvider: () => now,
      ).loadAll();
      expect(
        afterLogout
            .firstWhere((p) => p.id == AchievementIds.memberEdited)
            .count,
        1,
      );
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );

  group('automatische Pfade ohne interaktiven Relogin', () {
    const unauthorized = HitobitoPeopleException(
      'People-Anfrage fehlgeschlagen (401).',
      statusCode: 401,
    );

    ({AuthSessionModel model, FakeOauthService oauthService}) buildModel() {
      final oauthService = FakeOauthService(
        sessionToReturn: AuthSession(
          accessToken: 'refreshed-token',
          refreshToken: 'refreshed-refresh-token',
          receivedAt: DateTime(2026, 3, 28, 12),
        ),
        profileToReturn: const AuthProfile(
          namiId: 98,
          firstName: 'Auto',
          lastName: 'Sync',
          language: 'de',
        ),
      );
      final model = AuthSessionModel(
        repository: InMemoryAuthSessionRepository(
          initialSession: AuthSession(
            accessToken: 'stale-token',
            refreshToken: 'stale-refresh-token',
            receivedAt: DateTime(2026, 3, 27),
          ),
        ),
        profileRepository: InMemoryAuthProfileRepository(
          profile: const AuthProfile(
            namiId: 98,
            firstName: 'Auto',
            lastName: 'Sync',
            language: 'de',
          ),
          lastSyncAt: DateTime(2026, 3, 28, 8),
        ),
        oauthService: oauthService,
        biometricLockService: FakeBiometricLockService(),
        sensitiveStorageService: FakeSensitiveStorageService()
          ..lastSensitiveSyncAt = DateTime(2026, 3, 27, 8),
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
          nowProvider: () => DateTime(2026, 3, 28, 12),
        ),
        logger: _createLogger(),
      );
      return (model: model, oauthService: oauthService);
    }

    test(
      'executeRemoteAccess oeffnet nach 401 und fehlgeschlagenem Refresh keinen Login',
      () async {
        final (:model, :oauthService) = buildModel();
        oauthService.refreshError = const HitobitoAuthException(
          'Token-Anfrage fehlgeschlagen (401).',
          statusCode: 401,
        );
        await model.initialize();

        final result = await model.runWithoutInteractiveRelogin(
          () => model.executeRemoteAccess<String>(
            trigger: 'pending_retry_timer',
            action: (_) async => throw unauthorized,
          ),
        );

        expect(result, isNull);
        expect(oauthService.authenticateInteractiveCallCount, 0);
        expect(model.requiresInteractiveLogin, isTrue);
        expect(model.hasUnseenRemoteAccessIssueNotice, isTrue);
        expect(model.state, AuthState.signedIn);
      },
      timeout: const Timeout(Duration(seconds: 3)),
    );

    test(
      'executeRemoteAccess oeffnet keinen Login, wenn auch das frische Token abgelehnt wird',
      () async {
        final (:model, :oauthService) = buildModel();
        await model.initialize();
        final usedTokens = <String>[];

        final result = await model.runWithoutInteractiveRelogin(
          () => model.executeRemoteAccess<String>(
            trigger: 'pending_retry_timer',
            action: (session) async {
              usedTokens.add(session.accessToken);
              throw unauthorized;
            },
          ),
        );

        expect(result, isNull);
        expect(usedTokens, <String>['stale-token', 'refreshed-token']);
        expect(oauthService.refreshCallCount, 1);
        expect(oauthService.authenticateInteractiveCallCount, 0);
        expect(model.requiresInteractiveLogin, isTrue);
      },
      timeout: const Timeout(Duration(seconds: 3)),
    );

    test(
      'syncHitobitoData ohne Nutzeraktion oeffnet bei 401 keinen Login',
      () async {
        final (:model, :oauthService) = buildModel();
        oauthService.fetchProfileError = const HitobitoAuthException(
          'Profil-Anfrage fehlgeschlagen (401).',
          statusCode: 401,
        );
        await model.initialize();

        await model.syncHitobitoData(
          trigger: 'interval',
          userInitiated: false,
          syncMembers: (_) async {},
        );

        expect(oauthService.authenticateInteractiveCallCount, 0);
        expect(model.requiresInteractiveLogin, isTrue);
        expect(model.lastSyncAttemptResult, SyncAttemptResult.loginRequired);
      },
      timeout: const Timeout(Duration(seconds: 3)),
    );

    test(
      'Zeitueberschreitung im Sync zaehlt als Netzfehler, nicht als Login-Pflicht',
      () async {
        final (:model, :oauthService) = buildModel();
        await model.initialize();

        await model.syncHitobitoData(
          trigger: 'interval',
          userInitiated: false,
          syncMembers: (_) async =>
              throw TimeoutException('Keine Antwort von hitobito.example'),
        );

        expect(model.lastSyncAttemptResult, SyncAttemptResult.networkError);
        expect(model.requiresInteractiveLogin, isFalse);
        expect(model.isSyncingHitobitoData, isFalse);
        expect(oauthService.authenticateInteractiveCallCount, 0);
      },
      timeout: const Timeout(Duration(seconds: 3)),
    );

    test(
      'syncHitobitoData vor Ende der Initialisierung speichert keinen Versuch',
      () async {
        final sensitiveStorage = FakeSensitiveStorageService()
          ..lastSensitiveSyncAt = DateTime(2026, 3, 27, 8);
        final model = AuthSessionModel(
          repository: InMemoryAuthSessionRepository(
            initialSession: AuthSession(
              accessToken: 'stored-token',
              refreshToken: 'stored-refresh-token',
              receivedAt: DateTime(2026, 3, 27),
            ),
          ),
          profileRepository: InMemoryAuthProfileRepository(
            profile: const AuthProfile(namiId: 98, language: 'de'),
            lastSyncAt: DateTime(2026, 3, 28, 8),
          ),
          oauthService: buildModel().oauthService,
          biometricLockService: FakeBiometricLockService(),
          sensitiveStorageService: sensitiveStorage,
          retentionPolicy: HitobitoDataRetentionPolicy(
            maxDataAge: const Duration(days: 90),
            refreshInterval: const Duration(hours: 24),
            nowProvider: () => DateTime(2026, 3, 28, 12),
          ),
          logger: _createLogger(),
        );
        final memberSyncs = <String>[];

        await model.syncHitobitoData(
          trigger: 'startup',
          userInitiated: false,
          syncMembers: (token) async => memberSyncs.add(token),
        );

        expect(memberSyncs, isEmpty);
        expect(sensitiveStorage.lastSensitiveSyncAttemptAt, isNull);
        expect(model.lastSyncAttemptResult, isNull);

        await model.initialize();
        expect(model.isRefreshAttemptDue, isTrue);

        await model.syncHitobitoData(
          trigger: 'startup',
          userInitiated: false,
          syncMembers: (token) async => memberSyncs.add(token),
        );
        expect(memberSyncs, <String>['stored-token']);
      },
      timeout: const Timeout(Duration(seconds: 3)),
    );

    test(
      'syncHitobitoData durch Nutzeraktion darf bei 401 weiterhin einen Login oeffnen',
      () async {
        final (:model, :oauthService) = buildModel();
        oauthService.fetchProfileError = const HitobitoAuthException(
          'Profil-Anfrage fehlgeschlagen (401).',
          statusCode: 401,
        );
        await model.initialize();

        await model.syncHitobitoData(
          trigger: 'manual',
          syncMembers: (_) async {},
        );

        expect(oauthService.authenticateInteractiveCallCount, 1);
      },
      timeout: const Timeout(Duration(seconds: 3)),
    );
  });

  group('Loeschen lokaler Caches', () {
    AuthSessionModel buildModel({
      required FakeSensitiveStorageService sensitiveStorage,
      required Future<void> Function() purgeLocalPersonalData,
      AuthSession? initialSession,
      AuthSession? sessionToReturn,
      bool appLockEnabled = false,
      FakeOauthService? oauthService,
      NetworkAccessPolicy? networkAccessPolicy,
    }) {
      return AuthSessionModel(
        repository: InMemoryAuthSessionRepository(
          initialSession: initialSession,
        ),
        profileRepository: InMemoryAuthProfileRepository(),
        networkAccessPolicy: networkAccessPolicy,
        oauthService:
            oauthService ??
            FakeOauthService(
              sessionToReturn:
                  sessionToReturn ??
                  AuthSession(
                    accessToken: 'access-token',
                    receivedAt: DateTime(2026, 10, 7),
                  ),
              profileToReturn: const AuthProfile(namiId: 31),
            ),
        biometricLockService: FakeBiometricLockService(available: true),
        sensitiveStorageService: sensitiveStorage,
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
          nowProvider: () => DateTime(2026, 10, 7, 12),
        ),
        logger: _createLogger(),
        isAppLockEnabled: () => appLockEnabled,
        purgeLocalPersonalData: purgeLocalPersonalData,
      );
    }

    test('Abmelden widerruft die Tokens im Hintergrund', () async {
      final oauth = FakeOauthService(
        sessionToReturn: AuthSession(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          receivedAt: DateTime(2026, 10, 7),
        ),
        profileToReturn: const AuthProfile(namiId: 31),
      )..revokeAntwort = Completer<bool>();
      final model = buildModel(
        sensitiveStorage: FakeSensitiveStorageService(),
        purgeLocalPersonalData: () async {},
        oauthService: oauth,
      );
      await model.signIn();

      // Hitobito antwortet nicht: Der Logout wartet trotzdem nicht.
      await model.logout();

      expect(model.state, AuthState.signedOut);
      expect(oauth.widerrufeneSessions.single.refreshToken, 'refresh-token');
    });

    test('Abmelden offline widerruft nicht und loescht trotzdem', () async {
      final oauth = FakeOauthService(
        sessionToReturn: AuthSession(
          accessToken: 'access-token',
          receivedAt: DateTime(2026, 10, 7),
        ),
        profileToReturn: const AuthProfile(namiId: 31),
      );
      final model = buildModel(
        sensitiveStorage: FakeSensitiveStorageService(),
        purgeLocalPersonalData: () async {},
        oauthService: oauth,
        networkAccessPolicy: _BlockedNetworkAccessPolicy(
          const NetworkAccessBlockedException(
            reason: NetworkAccessBlockedReason.offline,
            connectionType: NetworkConnectionType.offline,
            message: 'offline',
          ),
        ),
      );
      await model.signIn();
      expect(model.session, isNotNull);

      await model.logout();
      await Future<void>.delayed(Duration.zero);

      expect(model.state, AuthState.signedOut);
      expect(oauth.widerrufeneSessions, isEmpty);
    });

    test('Abmelden loescht die lokalen Caches', () async {
      var aufrufe = 0;
      final model = buildModel(
        sensitiveStorage: FakeSensitiveStorageService(),
        purgeLocalPersonalData: () async => aufrufe++,
      );

      await model.logout();

      expect(aufrufe, 1);
      expect(model.state, AuthState.signedOut);
    });

    test('Fehler beim Cache-Loeschen bricht das Abmelden nicht ab', () async {
      final model = buildModel(
        sensitiveStorage: FakeSensitiveStorageService(),
        purgeLocalPersonalData: () async =>
            throw const FileSystemException('kein Zugriff'),
      );

      await model.logout();

      expect(model.state, AuthState.signedOut);
      expect(model.session, isNull);
    });

    test('Benutzerwechsel loescht die lokalen Caches', () async {
      var aufrufe = 0;
      final sensitiveStorage = FakeSensitiveStorageService()
        ..principal = 'person-alt';
      final model = buildModel(
        sensitiveStorage: sensitiveStorage,
        purgeLocalPersonalData: () async => aufrufe++,
        sessionToReturn: AuthSession(
          accessToken: 'access-token',
          receivedAt: DateTime(2026, 10, 7),
          principal: 'person-neu',
        ),
      );

      await model.signIn();

      expect(aufrufe, 1);
      expect(sensitiveStorage.principal, 'person-neu');
    });

    test(
      'Zuruecksetzen einer uebernommenen Session loescht die lokalen Caches',
      () async {
        var aufrufe = 0;
        final model = buildModel(
          sensitiveStorage: FakeSensitiveStorageService()..hasLocalData = false,
          purgeLocalPersonalData: () async => aufrufe++,
          initialSession: AuthSession(
            accessToken: 'existing-token',
            receivedAt: DateTime(2026, 10, 7),
          ),
        );

        await model.initialize();

        expect(aufrufe, 1);
        expect(model.state, AuthState.signedOut);
      },
    );
  });

  group('App-Sperre', () {
    final start = DateTime(2026, 10, 7, 12);
    final abgelaufenerLogin = const HitobitoAuthException(
      'Token-Anfrage fehlgeschlagen (401).',
      statusCode: 401,
    );

    ({
      AuthSessionModel model,
      FakeOauthService oauth,
      FakeBiometricLockService biometrie,
      FakeSensitiveStorageService storage,
      void Function(Duration) vorspulen,
      void Function(Duration) wanduhrVerstellen,
    })
    gesperrtesModell() {
      var now = start;
      var monoton = Duration.zero;
      final oauth = FakeOauthService(
        sessionToReturn: AuthSession(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          receivedAt: start,
        ),
        profileToReturn: const AuthProfile(namiId: 7),
      );
      final biometrie = FakeBiometricLockService(available: true);
      final storage = FakeSensitiveStorageService()
        ..principal = 'person-7'
        ..lastSensitiveSyncAt = start.subtract(const Duration(days: 2))
        ..lastSensitiveSyncAttemptAt = start.subtract(const Duration(days: 2));
      final model = AuthSessionModel(
        repository: InMemoryAuthSessionRepository(
          initialSession: AuthSession(
            accessToken: 'access-token',
            refreshToken: 'refresh-token',
            receivedAt: start,
          ),
        ),
        profileRepository: InMemoryAuthProfileRepository(
          profile: const AuthProfile(namiId: 7),
          lastSyncAt: start,
        ),
        oauthService: oauth,
        biometricLockService: biometrie,
        sensitiveStorageService: storage,
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
          nowProvider: () => now,
        ),
        logger: _createLogger(),
        isAppLockEnabled: () => true,
        lockTimeout: const Duration(seconds: 60),
        monotonicElapsed: () => monoton,
      );
      return (
        model: model,
        oauth: oauth,
        biometrie: biometrie,
        storage: storage,
        // Echte Zeit vergeht: Wanduhr und monotone Uhr laufen mit.
        vorspulen: (dauer) {
          now = now.add(dauer);
          monoton += dauer;
        },
        // Nur die Wanduhr springt, etwa durch Verstellen der Uhrzeit.
        wanduhrVerstellen: (dauer) => now = now.add(dauer),
      );
    }

    test(
      'automatischer Sync mit abgelaufenem Login hebt die Sperre nicht auf',
      () async {
        final t = gesperrtesModell();
        t.oauth.refreshError = abgelaufenerLogin;
        await t.model.initialize();
        expect(t.model.state, AuthState.unlockRequired);
        final versuchVorher = t.storage.lastSensitiveSyncAttemptAt;
        var mitgliederGeladen = 0;

        await t.model.syncHitobitoData(
          syncMembers: (_) async => mitgliederGeladen++,
          trigger: 'startup',
          userInitiated: false,
          force: true,
        );

        expect(t.model.state, AuthState.unlockRequired);
        expect(t.biometrie.authenticateCallCount, 0);
        expect(t.oauth.refreshCallCount, 0);
        expect(t.oauth.fetchProfileCallCount, 0);
        expect(t.oauth.authenticateInteractiveCallCount, 0);
        expect(mitgliederGeladen, 0);
        // Der Versuch zaehlt nicht, damit der Sync nach dem Entsperren
        // faellig bleibt.
        expect(t.storage.lastSensitiveSyncAttemptAt, versuchVorher);
      },
    );

    test(
      '401 eines laufenden Zugriffs nach dem Sperren hebt die Sperre nicht auf',
      () async {
        final t = gesperrtesModell();
        await t.model.initialize();
        await t.model.unlock();
        expect(t.model.state, AuthState.signedIn);
        t.biometrie.authenticateCallCount = 0;
        t.oauth.refreshError = abgelaufenerLogin;

        final antwort = Completer<void>();
        final zugriff = t.model.runWithoutInteractiveRelogin(
          () => t.model.executeRemoteAccess<String>(
            trigger: 'members_load',
            action: (_) async {
              await antwort.future;
              throw const HitobitoPeopleException(
                'People-Anfrage fehlgeschlagen (401).',
                statusCode: 401,
              );
            },
          ),
        );
        await Future<void>.delayed(Duration.zero);

        // Die App geht in den Hintergrund und kommt nach dem Timeout zurueck,
        // waehrend der Zugriff noch laeuft.
        await t.model.onAppBackgrounded();
        t.vorspulen(const Duration(minutes: 2));
        await t.model.onAppResumed();
        expect(t.model.state, AuthState.unlockRequired);

        antwort.complete();
        expect(await zugriff, isNull);

        expect(t.model.state, AuthState.unlockRequired);
        expect(t.biometrie.authenticateCallCount, 0);
        expect(t.oauth.authenticateInteractiveCallCount, 0);
      },
    );

    test('sperrt beim Resume, bevor der erste await zurueckkehrt', () async {
      final t = gesperrtesModell();
      await t.model.initialize();
      await t.model.unlock();
      await t.model.onAppBackgrounded();
      t.vorspulen(const Duration(minutes: 2));

      final resume = t.model.onAppResumed();
      // Andere Resume-Handler laufen direkt nach diesem Aufruf an.
      expect(t.model.state, AuthState.unlockRequired);
      await resume;

      expect(t.model.state, AuthState.unlockRequired);
    });

    test(
      'ohne verfuegbare Biometrie bleibt die App nach Resume nutzbar',
      () async {
        var now = start;
        final model = AuthSessionModel(
          repository: InMemoryAuthSessionRepository(),
          profileRepository: InMemoryAuthProfileRepository(),
          oauthService: FakeOauthService(
            sessionToReturn: AuthSession(
              accessToken: 'access-token',
              receivedAt: start,
            ),
            profileToReturn: const AuthProfile(namiId: 7),
          ),
          biometricLockService: FakeBiometricLockService(),
          sensitiveStorageService: FakeSensitiveStorageService(),
          retentionPolicy: HitobitoDataRetentionPolicy(
            maxDataAge: const Duration(days: 90),
            refreshInterval: const Duration(hours: 24),
            nowProvider: () => now,
          ),
          logger: _createLogger(),
          isAppLockEnabled: () => true,
        );
        await model.signIn();
        await model.onAppBackgrounded();
        now = now.add(const Duration(minutes: 2));

        await model.onAppResumed();

        expect(model.state, AuthState.signedIn);
      },
    );

    group('manipulierte Uhr (A-18)', () {
      Future<
        ({
          AuthSessionModel model,
          FakeOauthService oauth,
          FakeBiometricLockService biometrie,
          FakeSensitiveStorageService storage,
          void Function(Duration) vorspulen,
          void Function(Duration) wanduhrVerstellen,
        })
      >
      entsperrtImHintergrund() async {
        final t = gesperrtesModell();
        await t.model.initialize();
        await t.model.unlock();
        expect(t.model.state, AuthState.signedIn);
        await t.model.onAppBackgrounded();
        return t;
      }

      test('zurueckgestellte Uhr sperrt trotzdem', () async {
        final t = await entsperrtImHintergrund();
        t.vorspulen(const Duration(minutes: 5));
        t.wanduhrVerstellen(const Duration(minutes: -10));

        await t.model.onAppResumed();

        expect(t.model.state, AuthState.unlockRequired);
      });

      test(
        'Uhr knapp unter den Timeout gestellt sperrt ueber die monotone Uhr',
        () async {
          final t = await entsperrtImHintergrund();
          t.vorspulen(const Duration(minutes: 5));
          t.wanduhrVerstellen(const Duration(minutes: -4, seconds: -30));

          await t.model.onAppResumed();

          expect(t.model.state, AuthState.unlockRequired);
        },
      );

      test('kurzer Wechsel ohne Manipulation sperrt nicht', () async {
        final t = await entsperrtImHintergrund();
        t.vorspulen(const Duration(seconds: 30));

        await t.model.onAppResumed();

        expect(t.model.state, AuthState.signedIn);
      });
    });
  });
}

FakeLoggerService _createLogger() => FakeLoggerService();

class _BlockedNetworkAccessPolicy extends NetworkAccessPolicy {
  _BlockedNetworkAccessPolicy(this.error);

  final NetworkAccessBlockedException error;

  @override
  Future<void> ensureNetworkAllowed({
    required String trigger,
    String feature = 'Netzwerkzugriff',
    bool allowMobileDataOverride = false,
  }) async {
    throw error;
  }
}
