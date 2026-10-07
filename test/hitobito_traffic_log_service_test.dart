import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nami/services/hitobito_traffic_log_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'hitobito_traffic_log_service_test',
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('schreibt eine Zeile je Antwort in eine Tagesdatei', () async {
    final service = HitobitoTrafficLogService(
      logsDirectoryProvider: () async => tempDir,
      nowProvider: () => DateTime(2026, 6, 3, 10, 0, 0),
      maxDays: 7,
    );

    await service.logResponse(
      source: 'people',
      method: 'get',
      uri: Uri.parse(
        'https://example.org/api/people?filter[primary_group_id]=12&page[number]=2',
      ),
      statusCode: 200,
    );
    await service.logResponse(
      source: 'groups',
      method: 'GET',
      uri: Uri.parse('https://example.org/api/groups'),
      statusCode: 500,
    );

    expect(await service.listLogFileNames(), <String>[
      'traffic-2026-06-03.log',
    ]);
    expect(
      await service.readLogs(),
      '[2026-06-03 10:00:00] GET 200 people '
      'https://example.org/api/people?filter[primary_group_id]=12&page[number]=2\n'
      '[2026-06-03 10:00:00] GET 500 groups https://example.org/api/groups',
    );
  });

  test('schwaerzt Token-Parameter und loggt Fehler nur mit Typ', () async {
    final service = HitobitoTrafficLogService(
      logsDirectoryProvider: () async => tempDir,
      nowProvider: () => DateTime(2026, 6, 3, 10, 0, 0),
      maxDays: 7,
    );
    final uri = Uri.parse('https://example.org/api/people?token=geheim');

    await service.logResponse(
      source: 'people',
      method: 'GET',
      uri: uri,
      error: http.ClientException('Verbindung abgebrochen', uri),
    );

    final content = await service.readLogs();
    expect(content, contains('GET exception:ClientException people'));
    expect(content, contains('token=<redacted>'));
    expect(content, isNot(contains('geheim')));
    expect(content, isNot(contains('Verbindung abgebrochen')));
  });

  test('loescht Tagesdateien ausserhalb der Aufbewahrungsfrist', () async {
    var now = DateTime(2026, 6, 1, 12, 0, 0);
    final service = HitobitoTrafficLogService(
      logsDirectoryProvider: () async => tempDir,
      nowProvider: () => now,
      maxDays: 2,
    );
    final uri = Uri.parse('https://example.org/api/roles');

    await service.logResponse(
      source: 'roles',
      method: 'GET',
      uri: uri,
      statusCode: 200,
    );
    now = DateTime(2026, 6, 2, 12, 0, 0);
    await service.logResponse(
      source: 'roles',
      method: 'GET',
      uri: uri,
      statusCode: 200,
    );
    now = DateTime(2026, 6, 3, 12, 0, 0);
    await service.logResponse(
      source: 'roles',
      method: 'GET',
      uri: uri,
      statusCode: 200,
    );

    expect(await service.listLogFileNames(), <String>[
      'traffic-2026-06-03.log',
      'traffic-2026-06-02.log',
    ]);
  });

  test('schreibt parallel ohne Fehler und ohne verlorene Zeilen', () async {
    final service = HitobitoTrafficLogService(
      logsDirectoryProvider: () async => tempDir,
      nowProvider: () => DateTime(2026, 6, 3, 10, 0, 0),
      maxDays: 7,
    );
    final uri = Uri.parse('https://example.org/api/people');

    await Future.wait(<Future<void>>[
      for (var index = 0; index < 50; index++)
        service.logResponse(
          source: 'people',
          method: 'GET',
          uri: uri,
          statusCode: 200,
        ),
    ]);

    final lines = (await service.readLogs()).split('\n');
    expect(lines, hasLength(50));
  });

  test('deleteLegacyFiles entfernt Dateien im alten Format', () async {
    final legacy = File(
      '${tempDir.path}/2026-06-01T10-00-00_001_Get_people_200.log',
    );
    await legacy.writeAsString('type=response\nbody:\n{"first_name":"Max"}');
    final current = File('${tempDir.path}/traffic-2026-06-01.log');
    await current.writeAsString(
      '[2026-06-01 10:00:00] GET 200 people https://example.org/api/people\n',
    );
    final service = HitobitoTrafficLogService(
      logsDirectoryProvider: () async => tempDir,
      nowProvider: () => DateTime(2026, 6, 1, 10, 0, 0),
      maxDays: 7,
    );

    await service.deleteLegacyFiles();

    expect(await legacy.exists(), isFalse);
    expect(await current.exists(), isTrue);
  });

  test('clearAllLogs entfernt alle Dateien', () async {
    final service = HitobitoTrafficLogService(
      logsDirectoryProvider: () async => tempDir,
      nowProvider: () => DateTime(2026, 6, 3, 10, 0, 0),
      maxDays: 7,
    );
    await service.logResponse(
      source: 'people',
      method: 'GET',
      uri: Uri.parse('https://example.org/api/people'),
      statusCode: 200,
    );

    await service.clearAllLogs();

    expect(await service.listLogFiles(), isEmpty);
  });

  group('HitobitoTrafficLogEntry', () {
    test('liest geschriebene Zeilen wieder ein', () async {
      final service = HitobitoTrafficLogService(
        logsDirectoryProvider: () async => tempDir,
        nowProvider: () => DateTime(2026, 6, 3, 10, 0, 5),
        maxDays: 7,
      );
      await service.logResponse(
        source: 'people',
        method: 'GET',
        uri: Uri.parse(
          'https://example.org/api/people?filter[primary_group_id]=12&fields[people]=first_name&include=roles',
        ),
        statusCode: 200,
      );
      await service.logResponse(
        source: 'groups',
        method: 'GET',
        uri: Uri.parse('https://example.org/api/groups'),
        error: const FormatException('kaputt'),
      );

      final lines = (await service.readLogs()).split('\n');
      final ok = HitobitoTrafficLogEntry.tryParse(lines.first)!;
      expect(ok.timestamp, DateTime(2026, 6, 3, 10, 0, 5));
      expect(ok.method, 'GET');
      expect(ok.statusCode, 200);
      expect(ok.isError, isFalse);
      expect(ok.source, 'people');
      expect(ok.path, '/api/people');
      expect(ok.relevantQueryParameters, <String>[
        'filter[primary_group_id]=12',
      ]);
      expect(ok.hiddenQueryParameterCount, 2);

      final fehler = HitobitoTrafficLogEntry.tryParse(lines.last)!;
      expect(fehler.statusCode, isNull);
      expect(fehler.errorType, 'FormatException');
      expect(fehler.isError, isTrue);
      expect(fehler.queryParameters, isEmpty);
    });

    test('liefert null fuer fremde Zeilen', () {
      expect(HitobitoTrafficLogEntry.tryParse('===== datei ====='), isNull);
      expect(
        HitobitoTrafficLogEntry.tryParse(
          '[2026-06-03 10:00:00] GET abc people https://example.org/api',
        ),
        isNull,
      );
    });
  });
}
