import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nami/services/nami_ai/nami_ai_debug_log_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('logEntry writes exactly one file with one JSON line', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'nami_ai_debug_log_service_test',
    );

    final service = NamiAiDebugLogService(
      logsDirectoryProvider: () async => tempDir,
      nowProvider: () => DateTime.utc(2026, 6, 3, 10, 0, 0),
    );

    final requestId = await service.logEntry(
      prompt: 'Wie oft muss die Stammesversammlung stattfinden?',
      success: true,
      answer: 'Mindestens einmal im Jahr.',
      contextChunks: const ['satzung_stamm#23'],
      sources: const [
        {
          'docTitle': 'Satzung Stamm',
          'sectionNumber': '23',
          'docStand': 'Mai 2024',
        },
      ],
      sessionId: 'session-1',
      turnIndex: 1,
      latencyMs: 842,
    );

    final entries = await tempDir.list().toList();
    expect(entries.length, 1);
    expect(entries.single.path, endsWith('nami_ai_debug_log.jsonl'));

    final lines = await File(
      entries.single.path,
    ).readAsLines().then((l) => l.where((line) => line.trim().isNotEmpty));
    expect(lines.length, 1);

    final decoded = jsonDecode(lines.single) as Map<String, dynamic>;
    expect(
      decoded['prompt'],
      'Wie oft muss die Stammesversammlung stattfinden?',
    );
    expect(decoded['outcome'], 'success');
    expect(decoded['answer'], 'Mindestens einmal im Jahr.');
    expect(decoded['contextChunks'], ['satzung_stamm#23']);
    expect(decoded['chunkCount'], 1);
    expect(decoded['sources'], [
      {
        'docTitle': 'Satzung Stamm',
        'sectionNumber': '23',
        'docStand': 'Mai 2024',
      },
    ]);
    expect(decoded['unclear'], false);
    expect(decoded['sessionId'], 'session-1');
    expect(decoded['turnIndex'], 1);
    expect(decoded['contextTruncated'], false);
    expect(decoded['feedback'], isNull);
    expect(decoded['errorCode'], isNull);
    expect(decoded['latencyMs'], 842);
    expect(decoded['timestamp'], '2026-06-03T10:00:00.000Z');
    expect(decoded['requestId'], isNotEmpty);
    expect(decoded['requestId'], requestId);
    expect(decoded['osVersion'], isNotEmpty);

    await tempDir.delete(recursive: true);
  });

  test('multiple entries append to the same single file', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'nami_ai_debug_log_service_append_test',
    );

    var tick = 0;
    final service = NamiAiDebugLogService(
      logsDirectoryProvider: () async => tempDir,
      nowProvider: () {
        tick += 1;
        return DateTime.utc(2026, 6, 3, 10, 0, tick);
      },
    );

    for (var i = 0; i < 5; i++) {
      await service.logEntry(
        prompt: 'Frage $i',
        success: true,
        answer: 'Antwort $i',
        latencyMs: 100 + i,
      );
    }

    final entries = await tempDir.list().toList();
    expect(entries.length, 1);

    final lines = await File(
      entries.single.path,
    ).readAsLines().then((l) => l.where((line) => line.trim().isNotEmpty));
    expect(lines.length, 5);

    await tempDir.delete(recursive: true);
  });

  test('records error entries with error code and message', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'nami_ai_debug_log_service_error_test',
    );

    final service = NamiAiDebugLogService(
      logsDirectoryProvider: () async => tempDir,
      nowProvider: () => DateTime.utc(2026, 6, 3, 10, 0, 0),
    );

    await service.logEntry(
      prompt: 'Frage',
      success: false,
      errorCode: 'ai_device_not_eligible',
      errorMessage: 'Dieses Gerät unterstützt Apple Intelligence nicht.',
      latencyMs: 12,
    );

    final file = File('${tempDir.path}/nami_ai_debug_log.jsonl');
    final line = (await file.readAsLines()).single;
    final decoded = jsonDecode(line) as Map<String, dynamic>;

    expect(decoded['outcome'], 'error');
    expect(decoded['answer'], isNull);
    expect(decoded['contextChunks'], isEmpty);
    expect(decoded['errorCode'], 'ai_device_not_eligible');
    expect(
      decoded['errorMessage'],
      'Dieses Gerät unterstützt Apple Intelligence nicht.',
    );

    await tempDir.delete(recursive: true);
  });

  test('prunes entries older than LoggingEnv.maxDays (7 days)', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'nami_ai_debug_log_service_prune_test',
    );

    DateTime now = DateTime.utc(2026, 6, 3, 12, 0, 0);
    final service = NamiAiDebugLogService(
      logsDirectoryProvider: () async => tempDir,
      nowProvider: () => now,
    );

    // 10 days old: should be pruned once a new entry triggers cleanup.
    now = DateTime.utc(2026, 5, 24, 12, 0, 0);
    await service.logEntry(
      prompt: 'Alte Frage',
      success: true,
      answer: 'Alte Antwort',
      latencyMs: 1,
    );

    // 2 days old: should be retained.
    now = DateTime.utc(2026, 6, 1, 12, 0, 0);
    await service.logEntry(
      prompt: 'Neuere Frage',
      success: true,
      answer: 'Neuere Antwort',
      latencyMs: 1,
    );

    // Triggers pruning as of "today".
    now = DateTime.utc(2026, 6, 3, 12, 0, 0);
    await service.logEntry(
      prompt: 'Heutige Frage',
      success: true,
      answer: 'Heutige Antwort',
      latencyMs: 1,
    );

    final file = File('${tempDir.path}/nami_ai_debug_log.jsonl');
    final lines = (await file.readAsLines())
        .where((line) => line.trim().isNotEmpty)
        .map((line) => jsonDecode(line) as Map<String, dynamic>)
        .toList();

    expect(lines.length, 2);
    expect(lines.any((entry) => entry['prompt'] == 'Alte Frage'), isFalse);
    expect(lines.any((entry) => entry['prompt'] == 'Neuere Frage'), isTrue);
    expect(lines.any((entry) => entry['prompt'] == 'Heutige Frage'), isTrue);

    await tempDir.delete(recursive: true);
  });

  test(
    'updateFeedback sets the feedback field of the matching entry',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'nami_ai_debug_log_service_feedback_test',
      );

      final service = NamiAiDebugLogService(
        logsDirectoryProvider: () async => tempDir,
        nowProvider: () => DateTime.utc(2026, 6, 3, 10, 0, 0),
      );

      final requestId = await service.logEntry(
        prompt: 'Frage',
        success: true,
        answer: 'Antwort',
        latencyMs: 5,
      );

      await service.updateFeedback(requestId: requestId, rating: 'up');

      final file = File('${tempDir.path}/nami_ai_debug_log.jsonl');
      final decoded =
          jsonDecode((await file.readAsLines()).single) as Map<String, dynamic>;
      expect(decoded['feedback'], 'up');

      await tempDir.delete(recursive: true);
    },
  );

  test('updateFeedback with the same rating again clears it (undo)', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'nami_ai_debug_log_service_feedback_undo_test',
    );

    final service = NamiAiDebugLogService(
      logsDirectoryProvider: () async => tempDir,
      nowProvider: () => DateTime.utc(2026, 6, 3, 10, 0, 0),
    );

    final requestId = await service.logEntry(
      prompt: 'Frage',
      success: true,
      answer: 'Antwort',
      latencyMs: 5,
    );

    await service.updateFeedback(requestId: requestId, rating: 'down');
    await service.updateFeedback(requestId: requestId, rating: 'down');

    final file = File('${tempDir.path}/nami_ai_debug_log.jsonl');
    final decoded =
        jsonDecode((await file.readAsLines()).single) as Map<String, dynamic>;
    expect(decoded['feedback'], isNull);

    await tempDir.delete(recursive: true);
  });

  test('updateFeedback only touches the matching requestId', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'nami_ai_debug_log_service_feedback_multi_test',
    );

    var tick = 0;
    final service = NamiAiDebugLogService(
      logsDirectoryProvider: () async => tempDir,
      nowProvider: () {
        tick += 1;
        return DateTime.utc(2026, 6, 3, 10, 0, tick);
      },
    );

    final firstId = await service.logEntry(
      prompt: 'Erste Frage',
      success: true,
      answer: 'Erste Antwort',
      latencyMs: 5,
    );
    await service.logEntry(
      prompt: 'Zweite Frage',
      success: true,
      answer: 'Zweite Antwort',
      latencyMs: 5,
    );

    await service.updateFeedback(requestId: firstId, rating: 'up');

    final file = File('${tempDir.path}/nami_ai_debug_log.jsonl');
    final decodedLines = (await file.readAsLines())
        .map((line) => jsonDecode(line) as Map<String, dynamic>)
        .toList();

    expect(
      decodedLines.firstWhere((e) => e['prompt'] == 'Erste Frage')['feedback'],
      'up',
    );
    expect(
      decodedLines.firstWhere((e) => e['prompt'] == 'Zweite Frage')['feedback'],
      isNull,
    );

    await tempDir.delete(recursive: true);
  });

  test(
    'updateFeedback for an unknown requestId leaves the file unchanged',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'nami_ai_debug_log_service_feedback_unknown_test',
      );

      final service = NamiAiDebugLogService(
        logsDirectoryProvider: () async => tempDir,
        nowProvider: () => DateTime.utc(2026, 6, 3, 10, 0, 0),
      );

      await service.logEntry(
        prompt: 'Frage',
        success: true,
        answer: 'Antwort',
        latencyMs: 5,
      );

      await service.updateFeedback(requestId: 'unbekannt', rating: 'up');

      final file = File('${tempDir.path}/nami_ai_debug_log.jsonl');
      final decoded =
          jsonDecode((await file.readAsLines()).single) as Map<String, dynamic>;
      expect(decoded['feedback'], isNull);

      await tempDir.delete(recursive: true);
    },
  );
}
