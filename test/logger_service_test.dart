import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/settings/app_settings.dart';
import 'package:nami/domain/settings/app_settings_repository.dart';
import 'package:nami/services/logger_service.dart';

class _FakeRepo implements AppSettingsRepository {
  AppSettings value;
  _FakeRepo(this.value);
  @override
  Future<AppSettings> load() async => value;
  @override
  Future<void> saveAnalyticsEnabled(bool enabled) async {
    value = value.copyWith(analyticsEnabled: enabled);
  }

  @override
  Future<void> saveLanguageCode(String code) async {
    value = value.copyWith(languageCode: code);
  }

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {
    value = value.copyWith(themeMode: mode);
  }
}

void main() {
  test('LoggerService writes to file and console', () async {
    final tempDir = await Directory.systemTemp.createTemp('logger_test');
    final logFile = File('${tempDir.path}/app.log');

    final repo = _FakeRepo(
      const AppSettings(
        themeMode: ThemeMode.system,
        languageCode: 'de',
        analyticsEnabled: true,
      ),
    );

    final service = LoggerService(
      settingsRepository: repo,
      navigatorKey: GlobalKey<NavigatorState>(),
      logFileProvider: () async => logFile,
      wiredashEventHook: (name, props) async {},
    );

    await service.log('test', 'hello');
    final content = await logFile.readAsString();
    expect(content.contains('[test] hello'), isTrue);
  });

  test('trackEvent calls wiredash when analytics enabled', () async {
    final tempDir = await Directory.systemTemp.createTemp('logger_test2');
    final logFile = File('${tempDir.path}/app.log');
    // marker handled via file content, no boolean required

    final repo = _FakeRepo(
      const AppSettings(
        themeMode: ThemeMode.system,
        languageCode: 'de',
        analyticsEnabled: true,
      ),
    );

    final service = LoggerService(
      settingsRepository: repo,
      navigatorKey: GlobalKey<NavigatorState>(),
      logFileProvider: () async => logFile,
      wiredashEventHook: (name, props) async {
        // marker
        await logFile.writeAsString('[hook] $name\n', mode: FileMode.append);
      },
    );

    await service.trackEvent('evt', {'a': 1});
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final content = await logFile.readAsString();
    expect(content.contains('[hook] evt'), isTrue);
  });

  test('trackEvent does not call wiredash when analytics disabled', () async {
    final tempDir = await Directory.systemTemp.createTemp('logger_test3');
    final logFile = File('${tempDir.path}/app.log');
    // marker handled via file content, no boolean required

    final repo = _FakeRepo(
      const AppSettings(
        themeMode: ThemeMode.system,
        languageCode: 'de',
        analyticsEnabled: false,
      ),
    );

    final service = LoggerService(
      settingsRepository: repo,
      navigatorKey: GlobalKey<NavigatorState>(),
      logFileProvider: () async => logFile,
      wiredashEventHook: (name, props) async {
        await logFile.writeAsString('[hook] $name\n', mode: FileMode.append);
      },
    );

    await service.trackEvent('evt', {'a': 1});
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final content = await logFile.readAsString();
    expect(content.contains('[hook] evt'), isFalse);
  });
}
