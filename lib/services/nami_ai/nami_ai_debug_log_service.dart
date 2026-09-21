import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../logging_env.dart';

typedef NamiAiLogsDirectoryProvider = Future<Directory> Function();
typedef NamiAiNowProvider = DateTime Function();

/// Single-file JSON-Lines debug log for NaMi AI requests: one line per request with the
/// prompt, the context chunks that grounded the answer, the answer (or error), and basic
/// metadata. Kept as exactly one file, pruned to the last LoggingEnv.maxDays days on every
/// write. Meant to be shared/exported by the user for debugging answer quality, not as a
/// general-purpose app log (see lib/services/logger_service.dart for that).
class NamiAiDebugLogService {
  NamiAiDebugLogService({
    NamiAiLogsDirectoryProvider? logsDirectoryProvider,
    NamiAiNowProvider? nowProvider,
  }) : _logsDirectoryProvider = logsDirectoryProvider,
       _now = nowProvider ?? DateTime.now;

  static const String _fileName = 'nami_ai_debug_log.jsonl';

  final NamiAiLogsDirectoryProvider? _logsDirectoryProvider;
  final NamiAiNowProvider _now;
  final Random _random = Random();

  PackageInfo? _cachedPackageInfo;

  Future<Directory> _defaultLogsDirectory() async {
    final dir = await getApplicationSupportDirectory();
    final logsDir = Directory('${dir.path}/nami_ai_logs');
    if (!await logsDir.exists()) {
      await logsDir.create(recursive: true);
    }
    return logsDir;
  }

  Future<Directory> _logsDirectory() async => _logsDirectoryProvider != null
      ? await _logsDirectoryProvider()
      : await _defaultLogsDirectory();

  Future<File> _logFile() async {
    final dir = await _logsDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Returns the log file, creating an empty one if it doesn't exist yet, so it can be
  /// handed to a share/open flow right away.
  Future<File> exportableLogFile() async {
    final file = await _logFile();
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    return file;
  }

  /// Writes one log line and returns its requestId, so a caller can later attach feedback via
  /// updateFeedback(). sources/unclear surface the grounding-gate result (see NamiAiAnswer),
  /// sessionId/turnIndex make follow-up questions within a held chat session identifiable in the
  /// log (turnIndex == 1: no prior context; > 1: follow-up within the same native session).
  Future<String> logEntry({
    required String prompt,
    required bool success,
    String? answer,
    List<String> contextChunks = const <String>[],
    List<Map<String, String>> sources = const <Map<String, String>>[],
    bool unclear = false,
    String? sessionId,
    int? turnIndex,
    bool contextTruncated = false,
    bool verificationFailed = false,
    List<Map<String, Object?>> attempts = const <Map<String, Object?>>[],
    String? errorCode,
    String? errorMessage,
    required int latencyMs,
  }) async {
    final now = _now();
    final packageInfo = await _packageInfo();
    final requestId = _newRequestId(now);

    final entry = <String, Object?>{
      'timestamp': now.toUtc().toIso8601String(),
      'requestId': requestId,
      'sessionId': sessionId,
      'turnIndex': turnIndex,
      'prompt': prompt,
      'outcome': success ? 'success' : 'error',
      'answer': answer,
      'contextChunks': contextChunks,
      'chunkCount': contextChunks.length,
      'sources': sources,
      'unclear': unclear,
      'contextTruncated': contextTruncated,
      'verificationFailed': verificationFailed,
      'attempts': attempts,
      'feedback': null,
      'errorCode': errorCode,
      'errorMessage': errorMessage,
      'latencyMs': latencyMs,
      'appVersion': packageInfo?.version,
      'appBuildNumber': packageInfo?.buildNumber,
      'osVersion': Platform.operatingSystemVersion,
    };

    final file = await _logFile();
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    await file.writeAsString(
      '${jsonEncode(entry)}\n',
      mode: FileMode.append,
      flush: true,
    );

    await _pruneOldEntries();
    return requestId;
  }

  /// Sets (or, on a repeated call with the same rating, clears) the 'feedback' field of the log
  /// line matching requestId. Rewrites the whole file, same approach as _pruneOldEntries() -
  /// acceptable since this log is bounded to LoggingEnv.maxDays of interactive usage.
  Future<void> updateFeedback({
    required String requestId,
    required String rating,
  }) async {
    final file = await _logFile();
    if (!await file.exists()) {
      return;
    }

    final lines = await file.readAsLines();
    if (lines.isEmpty) {
      return;
    }

    final updated = <String>[];
    for (final line in lines) {
      if (line.trim().isEmpty) {
        continue;
      }
      final decoded = _tryDecodeEntry(line);
      if (decoded != null && decoded['requestId'] == requestId) {
        final current = decoded['feedback'] as String?;
        decoded['feedback'] = current == rating ? null : rating;
        updated.add(jsonEncode(decoded));
      } else {
        updated.add(line);
      }
    }

    final content = updated.isEmpty ? '' : '${updated.join('\n')}\n';
    await file.writeAsString(content, flush: true);
  }

  /// Deletes the entire log file. The next logEntry()/exportableLogFile() call recreates it
  /// from scratch, same as if the app had never logged anything.
  Future<void> deleteAll() async {
    final file = await _logFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  Map<String, dynamic>? _tryDecodeEntry(String jsonLine) {
    try {
      final decoded = jsonDecode(jsonLine);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Malformed line: keep it verbatim rather than losing data on a parse hiccup.
    }
    return null;
  }

  Future<void> _pruneOldEntries() async {
    final file = await _logFile();
    if (!await file.exists()) {
      return;
    }

    final lines = await file.readAsLines();
    if (lines.isEmpty) {
      return;
    }

    final cutoff = _now().subtract(Duration(days: LoggingEnv.maxDays));
    final retained = <String>[];
    var droppedAny = false;

    for (final line in lines) {
      if (line.trim().isEmpty) {
        droppedAny = true;
        continue;
      }
      final timestamp = _parseTimestamp(line);
      if (timestamp != null && timestamp.isBefore(cutoff)) {
        droppedAny = true;
        continue;
      }
      retained.add(line);
    }

    if (!droppedAny) {
      return;
    }

    final content = retained.isEmpty ? '' : '${retained.join('\n')}\n';
    await file.writeAsString(content, flush: true);
  }

  DateTime? _parseTimestamp(String jsonLine) {
    try {
      final decoded = jsonDecode(jsonLine);
      if (decoded is Map && decoded['timestamp'] is String) {
        return DateTime.tryParse(decoded['timestamp'] as String);
      }
    } catch (_) {
      // Malformed line: keep it rather than silently losing data on a parse hiccup.
    }
    return null;
  }

  Future<PackageInfo?> _packageInfo() async {
    if (_cachedPackageInfo != null) {
      return _cachedPackageInfo;
    }
    try {
      _cachedPackageInfo = await PackageInfo.fromPlatform();
    } catch (_) {
      return null;
    }
    return _cachedPackageInfo;
  }

  String _newRequestId(DateTime now) {
    final randomSuffix = _random.nextInt(1 << 32).toRadixString(16);
    return '${now.microsecondsSinceEpoch.toRadixString(16)}-$randomSuffix';
  }
}
