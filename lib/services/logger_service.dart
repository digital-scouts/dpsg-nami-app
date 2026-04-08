import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/settings/app_settings_repository.dart';
import 'logging_env.dart';

typedef WiredashEventHook =
    Future<void> Function(String name, Map<String, Object?> properties);
typedef LogsDirectoryProvider = Future<Directory> Function();
typedef LogNowProvider = DateTime Function();

enum LogLevel { debug, info, warn, error }

class LoggerService {
  static const int _maxEventValueLength = 900;
  static const String allLogsSelectionId = '__all__';

  final AppSettingsRepository settingsRepository;
  final GlobalKey<NavigatorState> navigatorKey;
  final WiredashEventHook? wiredashEventHook;
  final Future<File> Function()? logFileProvider;
  final LogsDirectoryProvider? logsDirectoryProvider;
  final LogNowProvider _now;
  final Map<String, DateTime> _debounceMap = {};
  final Map<String, Timer> _debounceTimers = {};
  final Map<String, Map<String, Object?>> _debounceLastProps = {};
  DateTime? _lastCleanupAt;
  Future<void>? _cleanupFuture;

  LoggerService({
    required this.settingsRepository,
    required this.navigatorKey,
    this.wiredashEventHook,
    this.logFileProvider,
    this.logsDirectoryProvider,
    LogNowProvider? nowProvider,
  }) : _now = nowProvider ?? DateTime.now;

  Future<Directory> _defaultLogsDirectory() async {
    final dir = await getApplicationSupportDirectory();
    final logsDir = Directory('${dir.path}/logs');
    if (!await logsDir.exists()) {
      await logsDir.create(recursive: true);
    }
    return logsDir;
  }

  Future<Directory> _logsDirectory() async => logsDirectoryProvider != null
      ? await logsDirectoryProvider!()
      : await _defaultLogsDirectory();

  bool get _usesSingleLogFileOverride => logFileProvider != null;

  String _fileNameForDate(DateTime day) {
    final label = DateFormat('yyyy-MM-dd').format(day);
    return 'app-$label.log';
  }

  String _todayFileName() => _fileNameForDate(_now());

  Future<File> _defaultLogFile() async {
    final dir = await _logsDirectory();
    final file = File('${dir.path}/${_todayFileName()}');
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    return file;
  }

  Future<File> _logFile() async => logFileProvider != null
      ? await logFileProvider!()
      : await _defaultLogFile();
  Future<File> getLogFile() async => _logFile();

  Future<List<File>> listLogFiles() async {
    if (_usesSingleLogFileOverride) {
      final file = await _logFile();
      return await file.exists() ? <File>[file] : const <File>[];
    }

    final dir = await _logsDirectory();
    if (!await dir.exists()) {
      return const <File>[];
    }

    final entities = await dir.list().toList();
    final files =
        entities
            .whereType<File>()
            .where((file) => file.path.endsWith('.log'))
            .toList(growable: false)
          ..sort(
            (left, right) =>
                _fileBaseName(right).compareTo(_fileBaseName(left)),
          );
    return files;
  }

  Future<List<String>> listLogFileNames() async {
    final files = await listLogFiles();
    return files.map(_fileBaseName).toList(growable: false);
  }

  Future<List<File>> resolveLogFiles({String? selectionId}) async {
    final files = await listLogFiles();
    if (selectionId == null || selectionId == allLogsSelectionId) {
      return files;
    }

    return files
        .where((file) => _fileBaseName(file) == selectionId)
        .toList(growable: false);
  }

  Future<String> readLogs({String? selectionId}) async {
    final files = await resolveLogFiles(selectionId: selectionId);
    if (files.isEmpty) {
      return '';
    }

    if (files.length == 1) {
      return files.single.readAsString();
    }

    final buffer = StringBuffer();
    for (final file in files) {
      final name = _fileBaseName(file);
      final content = await file.readAsString();
      buffer.writeln('===== $name =====');
      if (content.isNotEmpty) {
        buffer.write(content);
        if (!content.endsWith('\n')) {
          buffer.writeln();
        }
      }
      buffer.writeln();
    }
    return buffer.toString().trimRight();
  }

  Future<void> clearAllLogs() async {
    final files = await listLogFiles();
    for (final file in files) {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> logInfo(String service, String message) {
    return _writeLogLine(LogLevel.info, service, message);
  }

  Future<void> logWarn(String service, String message) {
    return _writeLogLine(LogLevel.warn, service, message);
  }

  Future<void> logError(
    String service,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final buffer = StringBuffer(message);
    if (error != null) {
      buffer.write(' error=${error.runtimeType}: $error');
    }
    if (stackTrace != null) {
      buffer.write('\n$stackTrace');
    }
    return _writeLogLine(LogLevel.error, service, buffer.toString());
  }

  Future<void> logNavigationAction(
    String action, {
    String? route,
    String? fromRoute,
    String? toRoute,
    Map<String, Object?> properties = const <String, Object?>{},
  }) {
    final details = <String, Object?>{
      if (route != null) 'route': route,
      if (fromRoute != null) 'from': fromRoute,
      if (toRoute != null) 'to': toRoute,
      ...properties,
    };
    return logInfo('nav', _composeMessage(action, details));
  }

  Future<void> trackSettingsChanged(
    String setting,
    Map<String, Object?> properties,
  ) async {
    final payload = <String, Object?>{'setting': setting, ...properties};
    await logInfo('settings', _composeMessage('settings_changed', payload));
    await trackEvent('settings_changed', payload);
  }

  Future<void> debounceTrackSettingsChanged(
    String setting,
    Map<String, Object?> properties,
  ) async {
    final payload = <String, Object?>{'setting': setting, ...properties};
    await logInfo('settings', _composeMessage('settings_changed', payload));
    _scheduleDebouncedTrackEvent(
      service: 'settings',
      name: 'settings_changed',
      properties: payload,
    );
  }

  Future<void> trackAuthFlow(
    String action,
    String outcome, {
    Map<String, Object?> properties = const <String, Object?>{},
  }) {
    return trackEvent('auth_flow', {
      'action': action,
      'outcome': outcome,
      ...properties,
    });
  }

  Future<void> trackLayerSwitch(
    String outcome, {
    Map<String, Object?> properties = const <String, Object?>{},
  }) {
    return trackEvent('layer_switch', {'outcome': outcome, ...properties});
  }

  Future<void> trackRuntimeError({
    required String source,
    required Object error,
    StackTrace? stackTrace,
    bool isExpected = false,
    Map<String, Object?> properties = const <String, Object?>{},
  }) {
    return trackEvent('runtime_error', {
      'source': source,
      'error_type': error.runtimeType.toString(),
      'exception': error.toString(),
      'is_expected': isExpected,
      if (stackTrace != null) 'stack': stackTrace.toString(),
      ...properties,
    });
  }

  Future<void> log(String service, String message) async {
    await logInfo(service, message);
  }

  Future<void> _writeLogLine(
    LogLevel level,
    String service,
    String message,
  ) async {
    await _maybeCleanupLogs();
    final ts = DateFormat('yyyy-MM-dd HH:mm:ss').format(_now());
    final line = '[$ts] [${level.name}] [$service] $message\n';
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
    await logInfo(service, _composeMessage(name, properties));
    _scheduleDebouncedTrackEvent(
      service: service,
      name: name,
      properties: properties,
    );
  }

  void _scheduleDebouncedTrackEvent({
    required String service,
    required String name,
    required Map<String, Object?> properties,
  }) {
    final discriminator =
        properties['setting']?.toString() ??
        properties['action']?.toString() ??
        '';
    final key =
        '_debounce_${service}_$name${discriminator.isEmpty ? '' : '_$discriminator'}';

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
      await trackEvent(name, last);
    });
  }

  Future<void> trackAndLog(
    String service,
    String name,
    Map<String, Object?> properties,
  ) async {
    await logInfo(service, _composeMessage(name, properties));
    await trackEvent(name, properties);
  }

  String _composeMessage(String action, Map<String, Object?> properties) {
    final details = _formatProperties(properties);
    if (details.isEmpty) {
      return action;
    }
    return '$action $details';
  }

  String _formatProperties(Map<String, Object?> properties) {
    if (properties.isEmpty) {
      return '';
    }

    final entries = properties.entries.toList(growable: false)
      ..sort((left, right) => left.key.compareTo(right.key));
    return entries
        .map((entry) => '${entry.key}=${_sanitizeLogValue(entry.value)}')
        .join(' ');
  }

  String _sanitizeLogValue(Object? value) {
    if (value == null) {
      return 'null';
    }
    if (value is num || value is bool) {
      return value.toString();
    }
    return value.toString().replaceAll('\n', '\\n');
  }

  Future<void> _maybeCleanupLogs() async {
    if (_usesSingleLogFileOverride) {
      return;
    }

    final lastCleanupAt = _lastCleanupAt;
    final now = _now();
    if (lastCleanupAt != null &&
        now.difference(lastCleanupAt) < const Duration(minutes: 5)) {
      return;
    }

    final existingCleanup = _cleanupFuture;
    if (existingCleanup != null) {
      await existingCleanup;
      return;
    }

    final cleanup = _cleanupLogs();
    _cleanupFuture = cleanup;
    try {
      await cleanup;
      _lastCleanupAt = now;
    } finally {
      _cleanupFuture = null;
    }
  }

  Future<void> _cleanupLogs() async {
    final files = await listLogFiles();
    if (files.isEmpty) {
      return;
    }

    final today = DateTime(_now().year, _now().month, _now().day);
    final earliestKeptDay = today.subtract(
      Duration(days: LoggingEnv.maxDays - 1),
    );

    for (final file in files) {
      final day = _parseLogDate(file);
      if (day == null) {
        continue;
      }
      final isToday = _isSameDay(day, today);
      if (!isToday && day.isBefore(earliestKeptDay)) {
        await file.delete();
      }
    }

    final retainedFiles = await listLogFiles();
    var totalBytes = 0;
    final deletable = <File>[];
    for (final file in retainedFiles) {
      if (!await file.exists()) {
        continue;
      }
      final stat = await file.stat();
      totalBytes += stat.size;
      final day = _parseLogDate(file);
      if (day != null && !_isSameDay(day, today)) {
        deletable.add(file);
      }
    }

    if (totalBytes <= LoggingEnv.maxSizeBytes) {
      return;
    }

    deletable.sort((left, right) {
      final leftDay = _parseLogDate(left) ?? today;
      final rightDay = _parseLogDate(right) ?? today;
      return leftDay.compareTo(rightDay);
    });

    for (final file in deletable) {
      if (totalBytes <= LoggingEnv.maxSizeBytes) {
        break;
      }
      final stat = await file.stat();
      await file.delete();
      totalBytes -= stat.size;
    }
  }

  DateTime? _parseLogDate(File file) {
    final name = _fileBaseName(file);
    final match = RegExp(r'^app-(\d{4}-\d{2}-\d{2})\.log$').firstMatch(name);
    if (match == null) {
      return null;
    }
    return DateTime.tryParse(match.group(1)!);
  }

  String _fileBaseName(File file) {
    final separator = Platform.pathSeparator;
    final parts = file.path.split(separator);
    return parts.isEmpty ? file.path : parts.last;
  }

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }
}

class AppNavigationLoggingObserver extends NavigatorObserver {
  AppNavigationLoggingObserver({required LoggerService logger})
    : _logger = logger;

  final LoggerService _logger;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is! PageRoute<dynamic>) {
      return;
    }

    final name = route.settings.name;
    if (name == null || name.isEmpty) {
      return;
    }

    unawaited(
      _logger.logNavigationAction(
        'route_open',
        route: name,
        fromRoute: previousRoute?.settings.name,
      ),
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (route is! PageRoute<dynamic>) {
      return;
    }

    final name = route.settings.name;
    if (name == null || name.isEmpty) {
      return;
    }

    unawaited(
      _logger.logNavigationAction(
        'route_back',
        fromRoute: name,
        toRoute: previousRoute?.settings.name,
      ),
    );
  }
}
