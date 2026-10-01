import 'package:flutter/material.dart';
import 'package:nami/domain/settings/app_settings.dart';
import 'package:nami/domain/settings/app_settings_repository.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/services/logger_service.dart';

/// Logger ohne Datei-IO und ohne Timer, der Logzeilen und Tracking-Events
/// fuer Assertions mitschreibt.
class FakeLoggerService extends LoggerService {
  FakeLoggerService()
    : super(
        settingsRepository: FakeAppSettingsRepository(),
        navigatorKey: GlobalKey<NavigatorState>(),
      );

  final List<LogEntry> entries = <LogEntry>[];
  final List<TrackedEvent> events = <TrackedEvent>[];

  /// Logzeilen im Format `service|message`.
  List<String> get messages => entries
      .map((entry) => '${entry.service}|${entry.message}')
      .toList(growable: false);

  @override
  Future<void> log(String service, String message) async {
    entries.add(LogEntry(service: service, message: message));
  }

  @override
  Future<void> logInfo(String service, String message) async {
    entries.add(LogEntry(service: service, message: message));
  }

  @override
  Future<void> logWarn(String service, String message) async {
    entries.add(LogEntry(service: service, message: message));
  }

  @override
  Future<void> logError(
    String service,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) async {
    final suffix = error == null ? '' : ' ${error.runtimeType}: $error';
    entries.add(LogEntry(service: service, message: '$message$suffix'));
  }

  @override
  Future<void> trackEvent(String name, Map<String, Object?> properties) async {
    events.add(
      TrackedEvent(
        name: name,
        properties: Map<String, Object?>.from(properties),
      ),
    );
  }

  @override
  Future<void> debounceTrackAndLog(
    String service,
    String name,
    Map<String, Object?> properties,
  ) {
    // Ohne den 30-Sekunden-Timer des echten Loggers, damit fake_async-Tests
    // keine offenen Timer hinterlassen.
    return trackAndLog(service, name, properties);
  }
}

class LogEntry {
  const LogEntry({required this.service, required this.message});

  final String service;
  final String message;
}

class TrackedEvent {
  const TrackedEvent({required this.name, required this.properties});

  final String name;
  final Map<String, Object?> properties;

  @override
  bool operator ==(Object other) {
    return other is TrackedEvent &&
        other.name == name &&
        _mapEquals(other.properties, properties);
  }

  @override
  int get hashCode => Object.hash(name, Object.hashAll(properties.entries));

  @override
  String toString() => 'TrackedEvent($name, $properties)';

  static bool _mapEquals(
    Map<String, Object?> left,
    Map<String, Object?> right,
  ) {
    if (identical(left, right)) {
      return true;
    }
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key) || right[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }
}

class FakeAppSettingsRepository extends AppSettingsRepository {
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
  Future<void> saveMemberListSearchResultHighlightEnabled(bool enabled) async {}

  @override
  Future<void> saveGeburstagsbenachrichtigungStufen(Set<Stufe> stufen) async {}

  @override
  Future<void> saveLanguageCode(String code) async {}

  @override
  Future<void> saveNotificationsEnabled(bool enabled) async {}

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {}
}
