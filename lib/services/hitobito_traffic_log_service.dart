import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'logging_env.dart';

typedef HitobitoTrafficLogsDirectoryProvider = Future<Directory> Function();
typedef HitobitoTrafficNowProvider = DateTime Function();

/// Protokolliert Hitobito-Anfragen als eine Zeile je Antwort:
/// `[2026-10-07 10:00:00] GET 200 people https://host/api/people?...`
///
/// Bewusst ohne Header und Bodies: Antworten enthalten Mitgliederdaten, die
/// nicht im Klartext auf dem Geraet oder in einem Log-Export landen duerfen.
class HitobitoTrafficLogService {
  static const String allLogsSelectionId = '__all__';
  static final RegExp _fileNamePattern = RegExp(
    r'^traffic-(\d{4}-\d{2}-\d{2})\.log$',
  );

  HitobitoTrafficLogService({
    HitobitoTrafficLogsDirectoryProvider? logsDirectoryProvider,
    HitobitoTrafficNowProvider? nowProvider,
    int? maxDays,
  }) : _logsDirectoryProvider = logsDirectoryProvider,
       _now = nowProvider ?? DateTime.now,
       _maxDays = maxDays;

  final HitobitoTrafficLogsDirectoryProvider? _logsDirectoryProvider;
  final HitobitoTrafficNowProvider _now;
  final int? _maxDays;
  DateTime? _lastCleanupDay;
  // Parallele Anhaenge an dieselbe Datei verlieren sonst Zeilen.
  Future<void> _writeQueue = Future<void>.value();

  int get _retentionDays => _maxDays ?? LoggingEnv.maxDays;

  Future<Directory> _defaultLogsDirectory() async {
    final dir = await getApplicationSupportDirectory();
    final logsDir = Directory('${dir.path}/hitobito_traffic_logs');
    if (!await logsDir.exists()) {
      await logsDir.create(recursive: true);
    }
    return logsDir;
  }

  Future<Directory> _logsDirectory() async => _logsDirectoryProvider != null
      ? await _logsDirectoryProvider()
      : await _defaultLogsDirectory();

  Future<void> logResponse({
    required String source,
    required String method,
    required Uri uri,
    int? statusCode,
    Object? error,
  }) {
    final ts = DateFormat('yyyy-MM-dd HH:mm:ss').format(_now());
    final status = statusCode?.toString() ?? _exceptionLabel(error);
    final line =
        '[$ts] ${method.trim().toUpperCase()} $status ${_safe(source)} '
        '${_sanitizeUri(uri)}\n';
    return _writeLine(line);
  }

  // Nur der Typ: ClientException.toString enthaelt die vollstaendige URI.
  String _exceptionLabel(Object? error) =>
      error == null ? 'exception' : 'exception:${error.runtimeType}';

  Future<void> _writeLine(String line) {
    final next = _writeQueue.then((_) => _appendLine(line));
    _writeQueue = next;
    return next;
  }

  Future<void> _appendLine(String line) async {
    // Reines Diagnose-Log: ein Dateifehler darf den eigentlichen Request nie
    // scheitern lassen.
    try {
      final dir = await _logsDirectory();
      final file = File('${dir.path}/${_fileNameForDate(_now())}');
      await file.writeAsString(line, mode: FileMode.append, flush: true);
      await _maybeCleanupLogs();
    } on FileSystemException {
      return;
    }
  }

  Future<void> _maybeCleanupLogs() async {
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    if (_lastCleanupDay == today) {
      return;
    }
    await _cleanupLogs();
    _lastCleanupDay = today;
  }

  String _fileNameForDate(DateTime day) =>
      'traffic-${DateFormat('yyyy-MM-dd').format(day)}.log';

  String _sanitizeUri(Uri uri) {
    var sanitized = uri;
    if (uri.queryParameters.isNotEmpty) {
      final parameters = <String, String>{};
      for (final entry in uri.queryParameters.entries) {
        final lower = entry.key.toLowerCase();
        parameters[entry.key] =
            lower.contains('token') || lower.contains('secret')
            ? '<redacted>'
            : entry.value;
      }
      sanitized = uri.replace(queryParameters: parameters);
    }
    // Lesbar statt %5B...%5D; Leerzeichen bleiben kodiert, damit die URI ein
    // zusammenhaengendes Feld der Zeile bleibt.
    return Uri.decodeFull(sanitized.toString()).replaceAll(' ', '%20');
  }

  String _safe(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '')
        .toLowerCase();
    return cleaned.isEmpty ? 'unknown' : cleaned;
  }

  Future<List<File>> listLogFiles() async {
    final dir = await _logsDirectory();
    if (!await dir.exists()) {
      return const <File>[];
    }

    final entities = await dir.list().toList();
    final files =
        entities
            .whereType<File>()
            .where((file) => _fileNamePattern.hasMatch(_fileBaseName(file)))
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

  /// Liefert die Zeilen chronologisch, ueber mehrere Tagesdateien hinweg.
  Future<String> readLogs({String? selectionId}) async {
    final files = (await resolveLogFiles(
      selectionId: selectionId,
    )).reversed.toList(growable: false);
    final buffer = StringBuffer();
    for (final file in files) {
      final content = await file.readAsString();
      if (content.isEmpty) {
        continue;
      }
      buffer.write(content);
      if (!content.endsWith('\n')) {
        buffer.writeln();
      }
    }
    return buffer.toString().trimRight();
  }

  Future<void> clearAllLogs() async {
    final dir = await _logsDirectory();
    if (!await dir.exists()) {
      return;
    }
    for (final file in (await dir.list().toList()).whereType<File>()) {
      await _deleteIfPresent(file);
    }
  }

  /// Entfernt Dateien aus dem frueheren Format (eine Datei je Request mit
  /// vollstaendigen Bodies). Laeuft bei jedem Start; nach der ersten
  /// Bereinigung findet sie nichts mehr.
  Future<void> deleteLegacyFiles() async {
    try {
      final dir = await _logsDirectory();
      if (!await dir.exists()) {
        return;
      }
      for (final file in (await dir.list().toList()).whereType<File>()) {
        if (!_fileNamePattern.hasMatch(_fileBaseName(file))) {
          await _deleteIfPresent(file);
        }
      }
    } on FileSystemException {
      return;
    }
  }

  Future<void> _cleanupLogs() async {
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    final earliestKeptDay = today.subtract(Duration(days: _retentionDays - 1));
    for (final file in await listLogFiles()) {
      final match = _fileNamePattern.firstMatch(_fileBaseName(file));
      final day = match == null ? null : DateTime.tryParse(match.group(1)!);
      if (day != null && day.isBefore(earliestKeptDay)) {
        await _deleteIfPresent(file);
      }
    }
  }

  Future<void> _deleteIfPresent(File file) async {
    try {
      await file.delete();
    } on PathNotFoundException {
      // Bereits von einem anderen Aufraeumen oder clearAllLogs entfernt.
    }
  }

  String _fileBaseName(File file) {
    final separator = Platform.pathSeparator;
    final parts = file.path.split(separator);
    return parts.isEmpty ? file.path : parts.last;
  }
}

/// Eine gelesene Zeile des Traffic-Logs, Gegenstueck zu
/// [HitobitoTrafficLogService.logResponse].
class HitobitoTrafficLogEntry {
  const HitobitoTrafficLogEntry({
    required this.timestamp,
    required this.method,
    required this.source,
    required this.uri,
    this.statusCode,
    this.errorType,
  });

  static final RegExp _linePattern = RegExp(
    r'^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\] (\S+) (\S+) (\S+) (\S+)$',
  );

  final DateTime timestamp;
  final String method;
  final String source;

  /// Vollstaendige URI wie geschrieben, Query lesbar dekodiert.
  final String uri;
  final int? statusCode;

  /// Typ der Exception, wenn keine Antwort ankam.
  final String? errorType;

  static HitobitoTrafficLogEntry? tryParse(String line) {
    final match = _linePattern.firstMatch(line.trim());
    if (match == null) {
      return null;
    }
    final timestamp = DateTime.tryParse(match.group(1)!.replaceFirst(' ', 'T'));
    if (timestamp == null) {
      return null;
    }
    final status = match.group(3)!;
    final statusCode = int.tryParse(status);
    if (statusCode == null && !status.startsWith('exception')) {
      return null;
    }
    final separator = status.indexOf(':');
    return HitobitoTrafficLogEntry(
      timestamp: timestamp,
      method: match.group(2)!,
      statusCode: statusCode,
      errorType: statusCode != null || separator < 0
          ? null
          : status.substring(separator + 1),
      source: match.group(4)!,
      uri: match.group(5)!,
    );
  }

  bool get isException => statusCode == null;

  bool get isError => statusCode == null || statusCode! >= 400;

  /// Pfad ohne Schema, Host und Query.
  String get path {
    final schemeEnd = uri.indexOf('://');
    final pathStart = schemeEnd < 0 ? 0 : uri.indexOf('/', schemeEnd + 3);
    final withoutHost = pathStart < 0 ? '/' : uri.substring(pathStart);
    final queryStart = withoutHost.indexOf('?');
    return queryStart < 0 ? withoutHost : withoutHost.substring(0, queryStart);
  }

  /// Query-Parameter in der Reihenfolge der URI, z. B. `page[number]=2`.
  List<String> get queryParameters {
    final queryStart = uri.indexOf('?');
    if (queryStart < 0 || queryStart == uri.length - 1) {
      return const <String>[];
    }
    return uri
        .substring(queryStart + 1)
        .split('&')
        .where((parameter) => parameter.isNotEmpty)
        .toList(growable: false);
  }

  /// Parameter, die fuer die Diagnose zaehlen; lange Feldlisten
  /// (`fields[...]`, `include`) bleiben aussen vor.
  List<String> get relevantQueryParameters => queryParameters
      .where((parameter) => !_isFieldList(parameter))
      .toList(growable: false);

  int get hiddenQueryParameterCount =>
      queryParameters.length - relevantQueryParameters.length;

  static bool _isFieldList(String parameter) =>
      parameter.startsWith('fields[') || parameter.startsWith('include=');
}
