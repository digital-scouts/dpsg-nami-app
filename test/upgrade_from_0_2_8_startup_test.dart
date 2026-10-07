import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:nami/data/auth/secure_auth_profile_repository.dart';
import 'package:nami/data/auth/secure_auth_session_repository.dart';
import 'package:nami/data/settings/shared_prefs_app_settings_repository.dart';
import 'package:nami/domain/auth/auth_state.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/services/app_startup_state_service.dart';
import 'package:nami/services/biometric_lock_service.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_data_retention_policy.dart';
import 'package:nami/services/hitobito_oauth_service.dart';
import 'package:nami/services/legacy_app_data_cleanup_service.dart';
import 'package:nami/services/logger_service.dart';
import 'package:nami/services/sensitive_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/legacy_0_2_8_fixture.dart';

/// Stellt den Kaltstart aus lib/main.dart nach einem Update von 0.2.8 nach:
/// Legacy-Cleanup, danach Laden von Session und Profil.
void main() {
  late Directory tempDir;
  late _RecordingLoggerService logger;

  setUp(() async {
    SensitiveStorageService.resetForTest();
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('upgrade_0_2_8_test');
    Hive.init(tempDir.path);
    final secureStorageValues = await installLegacy028Fixture(tempDir);
    FlutterSecureStorage.setMockInitialValues(secureStorageValues);
    logger = _RecordingLoggerService();
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  AuthSessionModel buildAuthModel(SensitiveStorageService sensitiveStorage) {
    return AuthSessionModel(
      repository: SecureAuthSessionRepository(),
      profileRepository: SecureAuthProfileRepository(
        sensitiveStorageService: sensitiveStorage,
      ),
      oauthService: HitobitoOauthService(
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
      ),
      biometricLockService: _UnavailableBiometricLockService(),
      sensitiveStorageService: sensitiveStorage,
      retentionPolicy: HitobitoDataRetentionPolicy(
        maxDataAge: const Duration(days: 90),
        refreshInterval: const Duration(hours: 24),
      ),
      logger: logger,
    );
  }

  test('startet nach Update von 0.2.8 abgemeldet und ohne Altdaten', () async {
    final cleaned = await LegacyAppDataCleanupService(
      documentsDirectoryProvider: () async => tempDir,
      logger: logger,
    ).runIfNeeded();
    expect(cleaned, isTrue);

    final sensitiveStorage = SensitiveStorageService();
    final authModel = buildAuthModel(sensitiveStorage);
    await authModel.initialize();

    expect(authModel.state, AuthState.signedOut);
    expect(authModel.session, isNull);
    expect(authModel.profile, isNull);
    expect(await AppStartupStateService().hasSeenWelcome(), isFalse);

    // Eigene verschluesselte Boxen lassen sich nach dem Login anlegen und
    // oeffnen.
    sensitiveStorage.beginSession();
    final profileBox = await sensitiveStorage.openEncryptedStringBox(
      'hitobito_profile_box',
    );
    expect(profileBox.isOpen, isTrue);
    await sensitiveStorage.openSecureMetaBox();

    for (final fileName in legacy028FileNames) {
      expect(File('${tempDir.path}/$fileName').existsSync(), isFalse);
    }
    expect(
      logger.errors,
      isEmpty,
      reason: 'Beim Upgrade-Start duerfen keine Fehler geloggt werden',
    );
  });

  test(
    'laedt Default-Einstellungen, Altdaten beeinflussen sie nicht',
    () async {
      await LegacyAppDataCleanupService(
        documentsDirectoryProvider: () async => tempDir,
      ).runIfNeeded();

      final settings = await SharedPrefsAppSettingsRepository().load();

      // 0.2.8 hatte ThemeMode.dark in settingsBox; 1.0.0 startet mit Defaults.
      expect(settings.themeMode, ThemeMode.system);
      expect(settings.biometricLockEnabled, isFalse);
    },
  );
}

class _UnavailableBiometricLockService extends BiometricLockService {
  @override
  Future<bool> authenticate() async => false;

  @override
  Future<bool> isAvailable() async => false;
}

class _RecordingLoggerService extends LoggerService {
  _RecordingLoggerService()
    : super(
        settingsRepository: SharedPrefsAppSettingsRepository(),
        navigatorKey: GlobalKey<NavigatorState>(),
      );

  final List<String> errors = <String>[];

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
  }) async {
    errors.add('$service: $message $error');
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
