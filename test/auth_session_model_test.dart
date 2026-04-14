import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:nami/services/hitobito_people_service.dart';
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
    'setzt uebernommene Session ohne Profildaten und Sync-Stand bei initialize auf signedOut zurueck',
    () async {
      final repository = _InMemoryAuthSessionRepository(
        initialSession: AuthSession(
          accessToken: 'existing-token',
          receivedAt: DateTime(2026, 3, 27),
        ),
      );
      final logger = _createLogger();
      final model = AuthSessionModel(
        repository: repository,
        profileRepository: _InMemoryAuthProfileRepository(),
        oauthService: _FakeOauthService(
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
        ),
        biometricLockService: _FakeBiometricLockService(available: true),
        sensitiveStorageService: _FakeSensitiveStorageService(),
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
          nowProvider: () => DateTime(2026, 3, 27, 12),
        ),
        logger: logger,
        isAppLockEnabled: () => true,
      );

      await model.initialize();

      expect(model.state, AuthState.signedOut);
      expect(model.session, isNull);
      expect(model.profile, isNull);
      expect(await repository.load(), isNull);
      expect(
        logger.entries.any(
          (entry) => entry.message.contains(
            'Uebernommene Session ohne restorable Profildaten erkannt',
          ),
        ),
        isTrue,
      );
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );

  test(
    'loggt den erwarteten 401-Fall beim Profil-Laden waehrend initialize nicht',
    () async {
      final logger = _createLogger();
      final oauthService =
          _FakeOauthService(
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
        repository: _InMemoryAuthSessionRepository(
          initialSession: AuthSession(
            accessToken: 'existing-token',
            receivedAt: DateTime(2026, 3, 27),
          ),
        ),
        profileRepository: _InMemoryAuthProfileRepository(),
        oauthService: oauthService,
        biometricLockService: _FakeBiometricLockService(),
        sensitiveStorageService: _FakeSensitiveStorageService(),
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
          _FakeOauthService(
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
        repository: _InMemoryAuthSessionRepository(
          initialSession: AuthSession(
            accessToken: 'existing-token',
            receivedAt: DateTime(2026, 3, 27),
          ),
        ),
        profileRepository: _InMemoryAuthProfileRepository(),
        oauthService: oauthService,
        biometricLockService: _FakeBiometricLockService(),
        sensitiveStorageService: _FakeSensitiveStorageService(),
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
    'bleibt bei wiederholtem 401 waehrend Sync signedIn und blockiert weitere Remote-Zugriffe',
    () async {
      final oauthService = _FakeOauthService(
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
      final sensitiveStorage = _FakeSensitiveStorageService();
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
      final oauthService = _FakeOauthService(
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
        repository: _InMemoryAuthSessionRepository(
          initialSession: AuthSession(
            accessToken: 'stale-token',
            refreshToken: 'refresh-token',
            receivedAt: DateTime(2026, 3, 27),
          ),
        ),
        profileRepository: _InMemoryAuthProfileRepository(
          profile: const AuthProfile(
            namiId: 94,
            firstName: 'Retry',
            lastName: 'MemberSync',
            language: 'de',
          ),
          lastSyncAt: DateTime(2026, 3, 28, 8),
        ),
        oauthService: oauthService,
        biometricLockService: _FakeBiometricLockService(),
        sensitiveStorageService: _FakeSensitiveStorageService(),
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
    'executeRemoteAccess versucht nach 401 und fehlgeschlagenem Refresh einen interaktiven Re-Login und macht erfolgreich weiter',
    () async {
      final oauthService =
          _FakeOauthService(
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
        repository: _InMemoryAuthSessionRepository(
          initialSession: AuthSession(
            accessToken: 'stale-token',
            refreshToken: 'stale-refresh-token',
            receivedAt: DateTime(2026, 3, 27),
          ),
        ),
        profileRepository: _InMemoryAuthProfileRepository(
          profile: const AuthProfile(
            namiId: 95,
            firstName: 'Interactive',
            lastName: 'Relogin',
            language: 'de',
          ),
          lastSyncAt: DateTime(2026, 3, 28, 8),
        ),
        oauthService: oauthService,
        biometricLockService: _FakeBiometricLockService(),
        sensitiveStorageService: _FakeSensitiveStorageService(),
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
    'bleibt nach abgebrochenem interaktivem Relogin bei vorhandener Session und lokalem Profil signedIn',
    () async {
      final oauthService =
          _FakeOauthService(
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
        repository: _InMemoryAuthSessionRepository(
          initialSession: AuthSession(
            accessToken: 'stale-token',
            refreshToken: 'stale-refresh-token',
            receivedAt: DateTime(2026, 3, 27),
          ),
        ),
        profileRepository: _InMemoryAuthProfileRepository(
          profile: cachedProfile,
          lastSyncAt: DateTime(2026, 3, 28, 8),
        ),
        oauthService: oauthService,
        biometricLockService: _FakeBiometricLockService(),
        sensitiveStorageService: _FakeSensitiveStorageService(),
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
    'interaktiver relogin mit Benutzerwechsel verwirft altes Profil und alten Sync-Stand',
    () async {
      final oauthService =
          _FakeOauthService(
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
      final sensitiveStorage = _FakeSensitiveStorageService()
        .._principal = 'principal-old'
        .._lastSensitiveSyncAt = DateTime(2026, 3, 27, 8)
        .._lastSensitiveSyncAttemptAt = DateTime(2026, 3, 27, 9);
      final model = AuthSessionModel(
        repository: _InMemoryAuthSessionRepository(
          initialSession: AuthSession(
            accessToken: 'stale-token',
            refreshToken: 'stale-refresh-token',
            receivedAt: DateTime(2026, 3, 27),
            principal: 'principal-old',
          ),
        ),
        profileRepository: _InMemoryAuthProfileRepository(
          profile: const AuthProfile(
            namiId: 111,
            firstName: 'Alt',
            lastName: 'Profil',
            language: 'de',
          ),
          lastSyncAt: DateTime(2026, 3, 27, 8),
        ),
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

      await model.initialize();
      final result = await model.executeRemoteAccess<String>(
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

      expect(result, 'ok');
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
      final oauthService = _FakeOauthService(
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
        repository: _InMemoryAuthSessionRepository(
          initialSession: AuthSession(
            accessToken: 'stale-token',
            refreshToken: 'refresh-token',
            receivedAt: DateTime(2026, 3, 27),
          ),
        ),
        profileRepository: _InMemoryAuthProfileRepository(
          profile: const AuthProfile(
            namiId: 94,
            firstName: 'Retry',
            lastName: 'Logging',
            language: 'de',
          ),
          lastSyncAt: DateTime(2026, 3, 28, 8),
        ),
        oauthService: oauthService,
        biometricLockService: _FakeBiometricLockService(),
        sensitiveStorageService: _FakeSensitiveStorageService(),
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
      final oauthService = _FakeOauthService(
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
        repository: _InMemoryAuthSessionRepository(),
        profileRepository: _InMemoryAuthProfileRepository(),
        oauthService: oauthService,
        biometricLockService: _FakeBiometricLockService(),
        sensitiveStorageService: _FakeSensitiveStorageService(),
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
      final oauthService = _FakeOauthService(
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
        repository: _InMemoryAuthSessionRepository(),
        profileRepository: _InMemoryAuthProfileRepository(),
        oauthService: oauthService,
        biometricLockService: _FakeBiometricLockService(),
        sensitiveStorageService: _FakeSensitiveStorageService(),
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
        repository: _InMemoryAuthSessionRepository(),
        profileRepository: _InMemoryAuthProfileRepository(),
        oauthService: _FakeOauthService(
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
  Object? authenticateError;
  Object? refreshError;
  Object? fetchProfileError;
  int authenticateInteractiveCallCount = 0;
  int refreshCallCount = 0;
  int fetchProfileCallCount = 0;

  @override
  Future<AuthSession> authenticateInteractive() async {
    authenticateInteractiveCallCount += 1;
    final error = authenticateError;
    if (error != null) {
      throw error;
    }
    return sessionToReturn;
  }

  @override
  Future<AuthSession> refresh(AuthSession session) async {
    refreshCallCount += 1;
    final error = refreshError;
    if (error != null) {
      throw error;
    }
    return sessionToReturn;
  }

  @override
  Future<AuthProfile> fetchProfile(AuthSession session) async {
    fetchProfileCallCount += 1;
    final error = fetchProfileError;
    if (error != null) {
      throw error;
    }
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

_FakeLoggerService _createLogger() => _FakeLoggerService();

class _LogEntry {
  const _LogEntry({required this.service, required this.message});

  final String service;
  final String message;
}

class _FakeLoggerService extends LoggerService {
  _FakeLoggerService()
    : super(
        settingsRepository: _FakeAppSettingsRepository(),
        navigatorKey: GlobalKey<NavigatorState>(),
      );

  final List<_LogEntry> entries = <_LogEntry>[];

  @override
  Future<void> log(String service, String message) async {
    entries.add(_LogEntry(service: service, message: message));
  }

  @override
  Future<void> logInfo(String service, String message) async {
    entries.add(_LogEntry(service: service, message: message));
  }

  @override
  Future<void> logWarn(String service, String message) async {
    entries.add(_LogEntry(service: service, message: message));
  }

  @override
  Future<void> logError(
    String service,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) async {
    final suffix = error == null ? '' : ' ${error.runtimeType}: $error';
    entries.add(_LogEntry(service: service, message: '$message$suffix'));
  }

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
