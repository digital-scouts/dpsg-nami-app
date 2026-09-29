import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:nami/services/legacy_app_data_cleanup_service.dart';
import 'package:nami/services/sensitive_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/legacy_0_2_8_fixture.dart';

void main() {
  late Directory tempDir;
  late int cancelNotificationsCalls;
  late int deleteMapStoreCalls;

  LegacyAppDataCleanupService buildService({
    Future<void> Function()? cancelScheduledNotifications,
  }) {
    return LegacyAppDataCleanupService(
      documentsDirectoryProvider: () async => tempDir,
      cancelScheduledNotifications:
          cancelScheduledNotifications ??
          () async => cancelNotificationsCalls++,
      deleteLegacyMapStore: () async => deleteMapStoreCalls++,
    );
  }

  Future<void> installFixture() async {
    final secureStorageValues = await installLegacy028Fixture(tempDir);
    FlutterSecureStorage.setMockInitialValues(secureStorageValues);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('legacy_cleanup_test');
    Hive.init(tempDir.path);
    cancelNotificationsCalls = 0;
    deleteMapStoreCalls = 0;
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('entfernt alle Daten der App-Version 0.2.8', () async {
    await installFixture();
    const secureStorage = FlutterSecureStorage();
    expect(File('${tempDir.path}/settingsbox.hive').existsSync(), isTrue);
    expect(await secureStorage.read(key: 'key'), isNotNull);

    final cleaned = await buildService().runIfNeeded();

    expect(cleaned, isTrue);
    for (final fileName in legacy028FileNames) {
      expect(
        File('${tempDir.path}/$fileName').existsSync(),
        isFalse,
        reason: '$fileName sollte geloescht sein',
      );
    }
    expect(await secureStorage.read(key: 'key'), isNull);
    expect(await secureStorage.read(key: 'salt'), isNull);
    expect(cancelNotificationsCalls, 1);
    expect(deleteMapStoreCalls, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(LegacyAppDataCleanupService.cleanupDoneKey), isTrue);
  });

  test('laeuft nur einmal', () async {
    await installFixture();
    final service = buildService();

    expect(await service.runIfNeeded(), isTrue);
    await installFixture();
    expect(await service.runIfNeeded(), isFalse);

    expect(cancelNotificationsCalls, 1);
    expect(File('${tempDir.path}/settingsbox.hive').existsSync(), isTrue);
  });

  test('tut bei frischer Installation nichts', () async {
    final cleaned = await buildService().runIfNeeded();

    expect(cleaned, isFalse);
    expect(cancelNotificationsCalls, 0);
    expect(deleteMapStoreCalls, 0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(LegacyAppDataCleanupService.cleanupDoneKey), isTrue);
  });

  test('erkennt verbliebenen Schluessel ohne Hive-Dateien', () async {
    // iOS behaelt Keychain-Eintraege auch nach einer Deinstallation.
    FlutterSecureStorage.setMockInitialValues({'key': 'alt', 'salt': '1'});

    expect(await buildService().runIfNeeded(), isTrue);

    const secureStorage = FlutterSecureStorage();
    expect(await secureStorage.read(key: 'key'), isNull);
    expect(await secureStorage.read(key: 'salt'), isNull);
  });

  test('laesst Daten der App-Version 1.0.0 unangetastet', () async {
    await installFixture();
    final sensitiveStorage = SensitiveStorageService();
    final box = await sensitiveStorage.openEncryptedStringBox(
      'hitobito_profile_box',
    );
    await box.put('auth_profile_v1', '{}');
    const secureStorage = FlutterSecureStorage();
    await secureStorage.write(key: 'hitobito_auth_session_v1', value: '{}');
    final notificationsBox = await Hive.openBox('notifications_box');
    await notificationsBox.put('n1', 'value');
    await Hive.close();

    await buildService().runIfNeeded();

    expect(
      await secureStorage.read(key: 'hitobito_auth_session_v1'),
      isNotNull,
    );
    final reopened = await SensitiveStorageService().openEncryptedStringBox(
      'hitobito_profile_box',
    );
    expect(reopened.get('auth_profile_v1'), '{}');
    expect((await Hive.openBox('notifications_box')).get('n1'), 'value');
  });

  test('setzt Cleanup fort, wenn ein Schritt fehlschlaegt', () async {
    await installFixture();

    final cleaned = await buildService(
      cancelScheduledNotifications: () async => throw StateError('kaputt'),
    ).runIfNeeded();

    expect(cleaned, isTrue);
    expect(File('${tempDir.path}/settingsbox.hive').existsSync(), isFalse);
    expect(File('${tempDir.path}/prod.log').existsSync(), isFalse);
    expect(deleteMapStoreCalls, 1);
  });
}
