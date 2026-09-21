import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nami/services/hitobito_traffic_log_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('writes separate request and response files', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'hitobito_traffic_log_service_test',
    );

    final service = HitobitoTrafficLogService(
      logsDirectoryProvider: () async => tempDir,
      nowProvider: () => DateTime(2026, 6, 3, 10, 0, 0),
    );

    final uri = Uri.parse('https://example.org/api/people?token=secret');

    await service.logRequest(
      source: 'people',
      method: 'POST',
      uri: uri,
      headers: const <String, String>{
        'Authorization': 'Bearer abc',
        'Accept': 'application/json',
      },
      body: '{"name":"test"}',
    );
    await service.logResponse(
      source: 'people',
      method: 'GET',
      uri: uri,
      statusCode: 200,
      headers: const <String, String>{'content-type': 'application/json'},
      body: '{"ok":true}',
    );

    final names = await service.listLogFileNames();
    expect(names.length, 2);
    final pattern = RegExp(
      r'^\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}_\d{3}_[A-Za-z]+_[a-z0-9_.-]+_(req|\d{3}|exception)\.log$',
    );
    expect(names.every((name) => pattern.hasMatch(name)), isTrue);
    expect(names.any((name) => name.contains('_Post_people_req.log')), isTrue);
    expect(names.any((name) => name.contains('_Get_people_200.log')), isTrue);

    final content = await service.readLogs();
    expect(content.contains('<redacted>'), isTrue);
    expect(content.contains('secret'), isFalse);
    expect(content.contains('status=200'), isTrue);

    await tempDir.delete(recursive: true);
  });

  test('keeps at most 100 newest files', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'hitobito_traffic_log_service_limit_test',
    );

    var tick = 0;
    final service = HitobitoTrafficLogService(
      logsDirectoryProvider: () async => tempDir,
      nowProvider: () {
        tick += 1;
        return DateTime(2026, 6, 3, 10, 0, 0, tick);
      },
    );

    final uri = Uri.parse('https://example.org/api/groups');

    for (var index = 0; index < 120; index++) {
      await service.logRequest(
        source: 'groups',
        method: 'POST',
        uri: uri,
        headers: const <String, String>{'Accept': 'application/json'},
        body: '{"index":$index}',
      );
    }

    final files = await service.listLogFiles();
    expect(files.length, HitobitoTrafficLogService.maxFiles);

    await tempDir.delete(recursive: true);
  });

  test('deletes files older than one day', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'hitobito_traffic_log_service_age_test',
    );

    DateTime now = DateTime(2026, 6, 3, 12, 0, 0);
    final service = HitobitoTrafficLogService(
      logsDirectoryProvider: () async => tempDir,
      nowProvider: () => now,
    );

    await service.logRequest(
      source: 'roles',
      method: 'POST',
      uri: Uri.parse('https://example.org/api/roles'),
      headers: const <String, String>{'Accept': 'application/json'},
      body: '{"step":1}',
    );

    final oldFile = (await service.listLogFiles()).single;
    final oldTimestamp = DateTime(2026, 6, 1, 11, 59, 59);
    await oldFile.setLastModified(oldTimestamp);

    now = DateTime(2026, 6, 3, 12, 0, 1);
    await service.logRequest(
      source: 'roles',
      method: 'POST',
      uri: Uri.parse('https://example.org/api/roles?page=2'),
      headers: const <String, String>{'Accept': 'application/json'},
      body: '{"step":2}',
    );

    final files = await service.listLogFiles();
    expect(files.length, 1);

    await tempDir.delete(recursive: true);
  });

  test('skips successful entries without body', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'hitobito_traffic_log_service_skip_empty_test',
    );

    final service = HitobitoTrafficLogService(
      logsDirectoryProvider: () async => tempDir,
      nowProvider: () => DateTime(2026, 6, 3, 10, 0, 0),
    );

    final uri = Uri.parse('https://example.org/api/groups');

    await service.logRequest(
      source: 'groups',
      method: 'GET',
      uri: uri,
      headers: const <String, String>{'Accept': 'application/json'},
    );

    await service.logResponse(
      source: 'groups',
      method: 'GET',
      uri: uri,
      statusCode: 200,
      headers: const <String, String>{'content-type': 'application/json'},
      body: '',
    );

    final files = await service.listLogFiles();
    expect(files, isEmpty);

    await tempDir.delete(recursive: true);
  });
}
