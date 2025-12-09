import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nami/domain/settings/app_settings.dart';
import 'package:nami/domain/settings/app_settings_repository.dart';
import 'package:nami/services/logger_service.dart';
import 'package:nami/services/usage_tracking_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  initializeDateFormatting('de_DE', null);
  test('UsageTrackingService tracks duration and logs', () async {
    final tempDir = await Directory.systemTemp.createTemp('usage_test');
    final logFile = File('${tempDir.path}/app.log');
    if (!await logFile.exists()) {
      await logFile.create(recursive: true);
    }

    final repo = _FakeRepo(
      const AppSettings(
        themeMode: ThemeMode.system,
        languageCode: 'de',
        analyticsEnabled: true,
      ),
    );

    var now = DateTime(2025, 12, 9, 12, 0, 0);
    DateTime nowProvider() => now;
    bool hookCalled = false;

    final logger = LoggerService(
      settingsRepository: repo,
      navigatorKey: GlobalKey<NavigatorState>(),
      logFileProvider: () async => logFile,
      wiredashEventHook: (name, props) async {
        if (name == 'session_duration') {
          hookCalled = true;
        }
        await logFile.writeAsString(
          '[hook] $name ${props['seconds']}\n',
          mode: FileMode.append,
        );
      },
    );

    final usage = UsageTrackingService(
      logger: logger,
      nowProvider: nowProvider,
    );
    usage.startSession();
    now = now.add(const Duration(seconds: 42));
    await usage.endSession();

    final exists = await logFile.exists();
    expect(exists, isTrue);
    expect(hookCalled, isTrue);
  });

  test('UsageTrackingService does nothing if not started', () async {
    final tempDir = await Directory.systemTemp.createTemp('usage_test2');
    final logFile = File('${tempDir.path}/app.log');
    if (!await logFile.exists()) {
      await logFile.create(recursive: true);
    }

    final repo = _FakeRepo(
      const AppSettings(
        themeMode: ThemeMode.system,
        languageCode: 'de',
        analyticsEnabled: true,
      ),
    );

    final logger = LoggerService(
      settingsRepository: repo,
      navigatorKey: GlobalKey<NavigatorState>(),
      logFileProvider: () async => logFile,
      wiredashEventHook: (name, props) async {
        await logFile.writeAsString('[hook] $name\n', mode: FileMode.append);
      },
    );

    final usage = UsageTrackingService(logger: logger);
    await usage.endSession();

    final exists = await logFile.exists();
    final content = exists ? await logFile.readAsString() : '';
    expect(content.contains('[hook]'), isFalse);
  });

  test('Resume within threshold continues session', () async {
    final tempDir = await Directory.systemTemp.createTemp('usage_resume_test');
    final logFile = File('${tempDir.path}/app.log');
    if (!await logFile.exists()) {
      await logFile.create(recursive: true);
    }

    final repo = _FakeRepo(
      const AppSettings(
        themeMode: ThemeMode.system,
        languageCode: 'de',
        analyticsEnabled: true,
      ),
    );

    var now = DateTime(2025, 12, 9, 12, 0, 0);
    DateTime nowProvider() => now;

    final logger = LoggerService(
      settingsRepository: repo,
      navigatorKey: GlobalKey<NavigatorState>(),
      logFileProvider: () async => logFile,
    );

    final usage = UsageTrackingService(
      logger: logger,
      nowProvider: nowProvider,
    );
    usage.resumeThreshold = const Duration(minutes: 1);
    usage.startSession();
    usage.pause();
    // Simuliere echte Zeitveränderung für Debounce (>1s) inkl. Realzeit
    now = now.add(const Duration(seconds: 2));
    await Future.delayed(const Duration(milliseconds: 1200));
    now = now.add(const Duration(seconds: 30));
    await usage.resume();

    final content = await logFile.readAsString();
    // Bei kurzer Pause keine Dauer gemeldet
    expect(content.contains('session_duration props:'), isFalse);
  });

  test('Resume after threshold ends and restarts session', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'usage_resume_threshold',
    );
    final logFile = File('${tempDir.path}/app.log');
    if (!await logFile.exists()) {
      await logFile.create(recursive: true);
    }

    final repo = _FakeRepo(
      const AppSettings(
        themeMode: ThemeMode.system,
        languageCode: 'de',
        analyticsEnabled: true,
      ),
    );

    var now = DateTime(2025, 12, 9, 12, 0, 0);
    DateTime nowProvider() => now;

    final logger = LoggerService(
      settingsRepository: repo,
      navigatorKey: GlobalKey<NavigatorState>(),
      logFileProvider: () async => logFile,
    );

    final usage = UsageTrackingService(
      logger: logger,
      nowProvider: nowProvider,
    );
    usage.resumeThreshold = const Duration(minutes: 1);
    usage.startSession();
    now = now.add(const Duration(seconds: 10));
    usage.pause();
    // Warte >1s um Debounce nicht zu triggern
    now = now.add(const Duration(seconds: 2));
    await Future.delayed(const Duration(milliseconds: 1200));
    now = now.add(const Duration(minutes: 2));
    await usage.resume();

    final content = await logFile.readAsString();
    expect(content.contains('session_duration props:'), isTrue);
  });

  test('Pause snapshot persisted and flushed at next start', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final tempDir = await Directory.systemTemp.createTemp('usage_flush_test');
    final logFile = File('${tempDir.path}/app.log');
    if (!await logFile.exists()) {
      await logFile.create(recursive: true);
    }

    final repo = _FakeRepo(
      const AppSettings(
        themeMode: ThemeMode.system,
        languageCode: 'de',
        analyticsEnabled: true,
      ),
    );

    var now = DateTime(2025, 12, 9, 12, 0, 0);
    DateTime nowProvider() => now;

    final logger = LoggerService(
      settingsRepository: repo,
      navigatorKey: GlobalKey<NavigatorState>(),
      logFileProvider: () async => logFile,
    );

    final usage = UsageTrackingService(
      logger: logger,
      nowProvider: nowProvider,
    );
    usage.resumeThreshold = const Duration(minutes: 1);
    usage.startSession();
    now = now.add(const Duration(seconds: 42));
    usage.pause();
    // Warten, bis Snapshot persistiert wurde
    await Future.delayed(const Duration(milliseconds: 50));

    // simulate app restart after longer background
    now = now.add(const Duration(minutes: 2));
    final logger2 = LoggerService(
      settingsRepository: repo,
      navigatorKey: GlobalKey<NavigatorState>(),
      logFileProvider: () async => logFile,
    );
    final usage2 = UsageTrackingService(
      logger: logger2,
      nowProvider: nowProvider,
    );
    await usage2.flushPendingSession();

    final content = await logFile.readAsString();
    expect(content.contains('session_duration props:'), isTrue);
  });
}
