import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

typedef HitobitoTrafficLogsDirectoryProvider = Future<Directory> Function();
typedef HitobitoTrafficNowProvider = DateTime Function();

enum HitobitoTrafficLogKind { request, response }

class HitobitoTrafficLogService {
  static const String allLogsSelectionId = '__all__';
  static const int maxFiles = 100;
  static const Duration maxAge = Duration(days: 1);

  HitobitoTrafficLogService({
    HitobitoTrafficLogsDirectoryProvider? logsDirectoryProvider,
    HitobitoTrafficNowProvider? nowProvider,
  }) : _logsDirectoryProvider = logsDirectoryProvider,
       _now = nowProvider ?? DateTime.now;

  final HitobitoTrafficLogsDirectoryProvider? _logsDirectoryProvider;
  final HitobitoTrafficNowProvider _now;
  int _sequence = 0;

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

  Future<void> logRequest({
    required String source,
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
  }) {
    if (_isEmptyBody(body)) {
      return Future<void>.value();
    }

    return _writeEntry(
      kind: HitobitoTrafficLogKind.request,
      source: source,
      method: method,
      uri: uri,
      payload: _buildRequestPayload(
        method: method,
        uri: uri,
        headers: headers,
        body: body,
      ),
    );
  }

  Future<void> logResponse({
    required String source,
    required String method,
    required Uri uri,
    int? statusCode,
    Map<String, String>? headers,
    String? body,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final hasEmptyBody = _isEmptyBody(body);
    final isSuccessfulStatus =
        statusCode != null && statusCode >= 200 && statusCode < 300;
    if (hasEmptyBody && error == null && isSuccessfulStatus) {
      return Future<void>.value();
    }

    return _writeEntry(
      kind: HitobitoTrafficLogKind.response,
      source: source,
      method: method,
      uri: uri,
      statusCode: statusCode,
      payload: _buildResponsePayload(
        method: method,
        uri: uri,
        statusCode: statusCode,
        headers: headers,
        body: body,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  Future<void> _writeEntry({
    required HitobitoTrafficLogKind kind,
    required String source,
    required String method,
    required Uri uri,
    required String payload,
    int? statusCode,
  }) async {
    final dir = await _logsDirectory();
    final fileName = _buildFileName(
      kind: kind,
      source: source,
      method: method,
      uri: uri,
      statusCode: statusCode,
    );
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(payload, flush: true);
    await _cleanupLogs();
  }

  String _buildFileName({
    required HitobitoTrafficLogKind kind,
    required String source,
    required String method,
    required Uri uri,
    int? statusCode,
  }) {
    final timestamp = DateFormat('yyyy-MM-ddTHH-mm-ss').format(_now());
    _sequence = (_sequence + 1) % 1000;
    final id = _sequence.toString().padLeft(3, '0');
    final methodLabel = _methodLabel(method);
    final shortName = _shortName(source, uri);
    final statusLabel = _statusLabel(kind: kind, statusCode: statusCode);
    return '${timestamp}_${id}_${methodLabel}_${shortName}_$statusLabel.log';
  }

  String _methodLabel(String method) {
    final upper = method.trim().toUpperCase();
    if (upper.isEmpty) {
      return 'Unknown';
    }
    return upper[0] + upper.substring(1).toLowerCase();
  }

  String _shortName(String source, Uri uri) {
    final safeSource = _safe(source);
    if (safeSource.isNotEmpty) {
      return safeSource;
    }

    final segments = uri.pathSegments;
    if (segments.isEmpty) {
      return 'root';
    }
    return _safe(segments.last);
  }

  String _statusLabel({required HitobitoTrafficLogKind kind, int? statusCode}) {
    if (statusCode != null) {
      return '$statusCode';
    }
    return kind == HitobitoTrafficLogKind.request ? 'req' : 'exception';
  }

  String _buildRequestPayload({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
  }) {
    final safeHeaders = _sanitizeHeaders(headers);
    final buffer = StringBuffer()
      ..writeln('type=request')
      ..writeln('method=${method.toUpperCase()}')
      ..writeln('uri=${_sanitizeUri(uri)}')
      ..writeln('headers:');

    for (final entry in safeHeaders.entries.toList(
      growable: false,
    )..sort((a, b) => a.key.compareTo(b.key))) {
      buffer.writeln('${entry.key}: ${entry.value}');
    }

    buffer.writeln('body:');
    buffer.writeln(body == null || body.isEmpty ? '<empty>' : body);
    return buffer.toString();
  }

  String _buildResponsePayload({
    required String method,
    required Uri uri,
    int? statusCode,
    Map<String, String>? headers,
    String? body,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final safeHeaders = headers == null
        ? const <String, String>{}
        : _sanitizeHeaders(headers);

    final buffer = StringBuffer()
      ..writeln('type=response')
      ..writeln('method=${method.toUpperCase()}')
      ..writeln('uri=${_sanitizeUri(uri)}')
      ..writeln('status=${statusCode?.toString() ?? 'exception'}')
      ..writeln('headers:');

    for (final entry in safeHeaders.entries.toList(
      growable: false,
    )..sort((a, b) => a.key.compareTo(b.key))) {
      buffer.writeln('${entry.key}: ${entry.value}');
    }

    if (error != null) {
      buffer.writeln('error: ${error.runtimeType}: $error');
      if (stackTrace != null) {
        buffer.writeln('stack_trace:');
        buffer.writeln(stackTrace);
      }
    }

    buffer.writeln('body:');
    buffer.writeln(body == null || body.isEmpty ? '<empty>' : body);
    return buffer.toString();
  }

  Map<String, String> _sanitizeHeaders(Map<String, String> headers) {
    final sanitized = <String, String>{};
    for (final entry in headers.entries) {
      final key = entry.key;
      if (key.toLowerCase() == 'authorization') {
        sanitized[key] = '<redacted>';
        continue;
      }
      sanitized[key] = entry.value;
    }
    return sanitized;
  }

  Uri _sanitizeUri(Uri uri) {
    if (uri.queryParameters.isEmpty) {
      return uri;
    }

    final sanitized = <String, String>{};
    for (final entry in uri.queryParameters.entries) {
      final lower = entry.key.toLowerCase();
      if (lower.contains('token') || lower.contains('secret')) {
        sanitized[entry.key] = '<redacted>';
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    return uri.replace(queryParameters: sanitized);
  }

  String _safe(String value) {
    return value
        .replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '')
        .toLowerCase();
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
            .where((file) => file.path.endsWith('.log'))
            .toList(growable: false)
          ..sort(
            (left, right) =>
                _fileBaseName(left).compareTo(_fileBaseName(right)),
          );
    return files;
  }

  bool _isEmptyBody(String? body) {
    if (body == null) {
      return true;
    }
    return body.trim().isEmpty;
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

  Future<void> _cleanupLogs() async {
    final files = await listLogFiles();
    if (files.isEmpty) {
      return;
    }

    final now = _now();
    final cutoff = now.subtract(maxAge);

    final retained = <File>[];
    for (final file in files) {
      final stat = await file.stat();
      if (stat.modified.isBefore(cutoff)) {
        await file.delete();
      } else {
        retained.add(file);
      }
    }

    if (retained.length <= maxFiles) {
      return;
    }

    retained.sort(
      (left, right) => _fileBaseName(left).compareTo(_fileBaseName(right)),
    );
    final overflow = retained.length - maxFiles;
    for (var index = 0; index < overflow; index++) {
      final file = retained[index];
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  String _fileBaseName(File file) {
    final separator = Platform.pathSeparator;
    final parts = file.path.split(separator);
    return parts.isEmpty ? file.path : parts.last;
  }
}
