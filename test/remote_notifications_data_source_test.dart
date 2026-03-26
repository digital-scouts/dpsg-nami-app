import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/core/notifications/remote_notifications_data_source.dart';
import 'package:nami/domain/settings/app_settings.dart';
import 'package:nami/domain/settings/app_settings_repository.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/services/logger_service.dart';

class _FakeSettingsRepository implements AppSettingsRepository {
  @override
  Future<AppSettings> load() async => const AppSettings(
    themeMode: ThemeMode.system,
    languageCode: 'de',
    analyticsEnabled: true,
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

void main() {
  late HttpServer server;
  late Directory tempDir;
  late File logFile;
  late LoggerService logger;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('notifications_remote_');
    logFile = File('${tempDir.path}/app.log');
    await logFile.create(recursive: true);
    logger = LoggerService(
      settingsRepository: _FakeSettingsRepository(),
      navigatorKey: GlobalKey<NavigatorState>(),
      logFileProvider: () async => logFile,
    );
  });

  tearDown(() async {
    await server.close(force: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('laedt und mapped Notifications aus einem items-Wrapper', () async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(
          '{"items":[{"id":"1","title":{"de":"Hinweis","en":"Note"},"body":{"de":"Text","en":"Body"},"type":"info"}]}',
        );
      await request.response.close();
    });

    final dataSource = RemoteNotificationsDataSource(
      'http://${server.address.host}:${server.port}/notifications.json',
      logger: logger,
    );

    final result = await dataSource.fetch();

    expect(result, hasLength(1));
    expect(result.first.id, '1');
    expect(result.first.title.de, 'Hinweis');
  });

  test('wirft bei HTTP-Fehler und schreibt ins Log', () async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.statusCode = 500;
      await request.response.close();
    });

    final dataSource = RemoteNotificationsDataSource(
      'http://${server.address.host}:${server.port}/notifications.json',
      logger: logger,
    );

    await expectLater(dataSource.fetch(), throwsException);
    final content = await logFile.readAsString();
    expect(
      content.contains('Fehler beim Laden der Notifications: 500'),
      isTrue,
    );
  });
}
