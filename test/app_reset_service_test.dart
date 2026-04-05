import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:nami/domain/auth/auth_session.dart';
import 'package:nami/domain/auth/auth_session_repository.dart';
import 'package:nami/services/app_reset_service.dart';
import 'package:nami/services/sensitive_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'foo': 'bar'});
    tempDir = await Directory.systemTemp.createTemp('app_reset_service_test');
    Hive.init(tempDir.path);

    final notificationsBox = await Hive.openBox('notifications_box');
    await notificationsBox.put('n1', 'value');
    final metaBox = await Hive.openBox('notifications_meta_box');
    await metaBox.put('last_fetch_at', '2026-04-05T12:00:00.000');
    final ackBox = await Hive.openBox('notifications_ack_box');
    await ackBox.put('id', true);
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'loescht SharedPreferences, Session, sensitive Daten und Notification-Boxen',
    () async {
      final authRepository = _FakeAuthSessionRepository();
      final sensitiveStorage = _FakeSensitiveStorageService();
      final logFile = File('${tempDir.path}/app.log');
      await logFile.writeAsString('debug-log');

      final service = AppResetService(
        authSessionRepository: authRepository,
        sensitiveStorageService: sensitiveStorage,
        logFileProvider: () async => logFile,
      );

      await service.resetAllData();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
      expect(authRepository.clearCalled, isTrue);
      expect(sensitiveStorage.purgeCalled, isTrue);
      expect(await logFile.exists(), isFalse);

      final notificationsBox = await Hive.openBox('notifications_box');
      final metaBox = await Hive.openBox('notifications_meta_box');
      final ackBox = await Hive.openBox('notifications_ack_box');
      expect(notificationsBox.isEmpty, isTrue);
      expect(metaBox.isEmpty, isTrue);
      expect(ackBox.isEmpty, isTrue);
    },
  );
}

class _FakeAuthSessionRepository implements AuthSessionRepository {
  bool clearCalled = false;

  @override
  Future<void> clear() async {
    clearCalled = true;
  }

  @override
  Future<AuthSession?> load() async => null;

  @override
  Future<void> save(AuthSession session) async {}
}

class _FakeSensitiveStorageService extends SensitiveStorageService {
  bool purgeCalled = false;

  @override
  Future<void> purgeSensitiveData() async {
    purgeCalled = true;
  }
}
