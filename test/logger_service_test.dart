import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/settings/app_settings.dart';
import 'package:nami/domain/settings/app_settings_repository.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/services/logger_service.dart';

class _CustomEventValue {
  @override
  String toString() => 'custom-event-value';
}

class _RecordingLoggerService extends LoggerService {
  _RecordingLoggerService({required super.settingsRepository})
    : super(navigatorKey: GlobalKey<NavigatorState>());

  final List<(String, String, Map<String, Object?>)> calls = [];

  @override
  Future<void> trackAndLog(
    String service,
    String name,
    Map<String, Object?> properties,
  ) async {
    calls.add((service, name, properties));
  }
}

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

  @override
  Future<void> saveMemberListSearchResultHighlightEnabled(bool enabled) async {
    value = value.copyWith(memberListSearchResultHighlightEnabled: enabled);
  }

  @override
  Future<void> saveGeburstagsbenachrichtigungStufen(Set<Stufe> stufen) {
    // TODO: implement saveGeburstagsbenachrichtigungStufen
    throw UnimplementedError();
  }

  @override
  Future<void> saveNotificationsEnabled(bool enabled) {
    // TODO: implement saveNotificationsEnabled
    throw UnimplementedError();
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
    final exists = await logFile.exists();
    final content = exists ? await logFile.readAsString() : '';
    expect(content.contains('[hook] evt'), isFalse);
  });

  test(
    'trackEvent converts lists and objects to strings for wiredash',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('logger_test4');
      final logFile = File('${tempDir.path}/app.log');
      Map<String, Object?>? capturedProps;

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
          capturedProps = props;
        },
      );

      await service.trackEvent('evt', {
        'list': ['a', 'b'],
        'map': {'x': 1},
        'object': _CustomEventValue(),
        'string': 'ok',
        'number': 42,
        'bool': true,
        'null': null,
      });

      expect(capturedProps, isNotNull);
      expect(capturedProps!['list'], '[a, b]');
      expect(capturedProps!['map'], '{x: 1}');
      expect(capturedProps!['object'], 'custom-event-value');
      expect(capturedProps!['string'], 'ok');
      expect(capturedProps!['number'], 42);
      expect(capturedProps!['bool'], true);
      expect(capturedProps!['null'], isNull);
    },
  );

  test('trackEvent kuerzt zu lange String-Properties fuer wiredash', () async {
    final tempDir = await Directory.systemTemp.createTemp('logger_test5');
    final logFile = File('${tempDir.path}/app.log');
    Map<String, Object?>? capturedProps;
    final longStack = List<String>.filled(300, '#0 frame').join('\n');

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
        capturedProps = props;
      },
    );

    await service.trackEvent('runtime_error', {
      'stack': longStack,
      'exception': 'kaputt',
    });

    expect(capturedProps, isNotNull);
    expect((capturedProps!['stack'] as String).length, lessThanOrEqualTo(1024));
    expect((capturedProps!['stack'] as String).endsWith('...'), isTrue);
    expect(capturedProps!['exception'], 'kaputt');
  });

  test(
    'debounceTrackAndLog sendet nur das letzte Event nach 30s Inaktivitaet',
    () {
      final repo = _FakeRepo(
        const AppSettings(
          themeMode: ThemeMode.system,
          languageCode: 'de',
          analyticsEnabled: true,
        ),
      );
      final service = _RecordingLoggerService(settingsRepository: repo);

      fakeAsync((async) {
        service.debounceTrackAndLog('settings', 'theme_changed', {
          'value': 'a',
        });
        async.elapse(const Duration(seconds: 10));
        service.debounceTrackAndLog('settings', 'theme_changed', {
          'value': 'b',
        });
        async.elapse(const Duration(seconds: 29));

        expect(service.calls, isEmpty);

        async.elapse(const Duration(seconds: 1));

        expect(service.calls, hasLength(1));
        expect(service.calls.single.$1, 'settings');
        expect(service.calls.single.$2, 'theme_changed');
        expect(service.calls.single.$3['value'], 'b');
      });
    },
  );
}
