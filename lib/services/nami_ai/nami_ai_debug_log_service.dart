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

  Future<void> logEntry({
    required String prompt,
    required bool success,
    String? answer,
    List<String> contextChunks = const <String>[],
    String? errorCode,
    String? errorMessage,
    required int latencyMs,
  }) async {
    final now = _now();
    final packageInfo = await _packageInfo();

    final entry = <String, Object?>{
      'timestamp': now.toUtc().toIso8601String(),
      'requestId': _newRequestId(now),
      'prompt': prompt,
      'outcome': success ? 'success' : 'error',
      'answer': answer,
      'contextChunks': contextChunks,
      'chunkCount': contextChunks.length,
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
