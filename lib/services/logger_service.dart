import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/settings/app_settings_repository.dart';

typedef WiredashEventHook =
    Future<void> Function(String name, Map<String, Object?> properties);

class LoggerService {
  static const int _maxEventValueLength = 1024;

  final AppSettingsRepository settingsRepository;
  final GlobalKey<NavigatorState> navigatorKey;
  final WiredashEventHook? wiredashEventHook;
  final Future<File> Function()? logFileProvider;
  final Map<String, DateTime> _debounceMap = {};
  final Map<String, Timer> _debounceTimers = {};
  final Map<String, Map<String, Object?>> _debounceLastProps = {};

  LoggerService({
    required this.settingsRepository,
    required this.navigatorKey,
    this.wiredashEventHook,
    this.logFileProvider,
  });

  Future<File> _defaultLogFile() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/app.log');
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    return file;
  }

  Future<File> _logFile() async => logFileProvider != null
      ? await logFileProvider!()
      : await _defaultLogFile();
  Future<File> getLogFile() async => _logFile();

  Future<void> log(String service, String message) async {
    final ts = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final line = '[$ts][$service] $message\n';
    if (kDebugMode) {
      // ignore: avoid_print
      print(line.trim());
    }
    final file = await _logFile();
    await file.writeAsString(line, mode: FileMode.append, flush: true);
  }

  Future<void> trackEvent(String name, Map<String, Object?> properties) async {
    final settings = await settingsRepository.load();

    if (!settings.analyticsEnabled) {
      // Telemetrie aus: keine Weitergabe an Wiredash
      return;
    }
    if (wiredashEventHook != null) {
      await wiredashEventHook!(name, _sanitizeEventProperties(properties));
    }
  }

  Map<String, Object?> _sanitizeEventProperties(
    Map<String, Object?> properties,
  ) {
    return {
      for (final entry in properties.entries)
        entry.key: _sanitizeEventValue(entry.value),
    };
  }

  Object? _sanitizeEventValue(Object? value) {
    if (value == null || value is num || value is bool) {
      return value;
    }
    if (value is String) {
      return _truncateEventString(value);
    }
    return _truncateEventString(value.toString());
  }

  String _truncateEventString(String value) {
    if (value.length <= _maxEventValueLength) {
      return value;
    }
    return '${value.substring(0, _maxEventValueLength - 3)}...';
  }

  /// Debounce: Innerhalb von 30s wird nur das letzte Event ausgeführt.
  ///
  /// Verhalten:
  /// - Jeder Aufruf verschiebt die Ausführung um 30s (ab letztem Aufruf).
  /// - Kommen weitere Aufrufe in diesem Zeitfenster, werden frühere verworfen.
  /// - Erst nach 30s Inaktivität wird `trackAndLog` mit den zuletzt
  ///   übergebenen `properties` aufgerufen.
  Future<void> debounceTrackAndLog(
    String service,
    String name,
    Map<String, Object?> properties,
  ) async {
    final key = '_debounce_${service}_$name';

    // Zuletzt übergebene Props merken (das letzte Event zählt)
    _debounceLastProps[key] = properties;

    // Bestehenden Timer abbrechen und neu starten
    final existing = _debounceTimers[key];
    if (existing != null && existing.isActive) {
      existing.cancel();
    }

    _debounceTimers[key] = Timer(const Duration(seconds: 30), () async {
      // Nach 30s Inaktivität: letztes Event senden
      final last = _debounceLastProps.remove(key) ?? properties;
      _debounceTimers.remove(key);
      _debounceMap[key] = DateTime.now();
      await trackAndLog(service, name, last);
    });
  }

  Future<void> trackAndLog(
    String service,
    String name,
    Map<String, Object?> properties,
  ) async {
    await log(service, '$name ${properties.toString()}');
    await trackEvent(name, properties);
  }
}
