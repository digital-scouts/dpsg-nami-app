import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nami/domain/settings/app_settings.dart';
import 'package:nami/domain/settings/app_settings_repository.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/services/geoapify_address_map_service.dart';
import 'package:nami/services/logger_service.dart';

void main() {
  test('geocodiert eine Adresse ueber Geoapify', () async {
    final service = GeoapifyAddressMapService(
      apiKeyOverride: 'test-key',
      httpClient: MockClient((request) async {
        expect(request.url.host, 'api.geoapify.com');
        return http.Response(
          '{"results":[{"lat":53.5511,"lon":9.9937,"rank":{"confidence":1,"confidence_street_level":1,"match_type":"full_match"}}],"query":{"parsed":{"expected_type":"building","housenumber":"4"}}}',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final location = await service.geocodeAddress('Musterweg 4, 50667 Koeln');

    expect(location, isNotNull);
    expect(location?.latitude, 53.5511);
    expect(location?.longitude, 9.9937);
  });

  test(
    'resolveAddress markiert leere Trefferliste als Adresse nicht gefunden',
    () async {
      final service = GeoapifyAddressMapService(
        apiKeyOverride: 'test-key',
        httpClient: MockClient((request) async {
          expect(request.url.host, 'api.geoapify.com');
          return http.Response(
            '{"results":[]}',
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }),
      );

      final result = await service.resolveAddress(
        'Unbekannt 1, 99999 Nirgendwo',
      );

      expect(result.location, isNull);
      expect(result.addressNotFound, isTrue);
      expect(result.technicalError, isFalse);
    },
  );

  test('liefert null bei Geoapify-Fehlerstatus', () async {
    final service = GeoapifyAddressMapService(
      apiKeyOverride: 'test-key',
      httpClient: MockClient((request) async {
        expect(request.url.host, 'api.geoapify.com');
        return http.Response(
          '{"error":"bad request"}',
          400,
          headers: <String, String>{'content-type': 'image/png'},
        );
      }),
    );

    final location = await service.geocodeAddress('Musterweg 4, 50667 Koeln');

    expect(location, isNull);
  });

  test(
    'liefert null bei unpraezisem Naeherungstreffer mit confidence 0',
    () async {
      final service = GeoapifyAddressMapService(
        apiKeyOverride: 'test-key',
        httpClient: MockClient((request) async {
          expect(request.url.host, 'api.geoapify.com');
          return http.Response(
            '{"results":[{"lat":46.0781228,"lon":8.9590668,"result_type":"amenity","rank":{"confidence":0,"confidence_city_level":1,"confidence_street_level":0,"match_type":"inner_part"}}],"query":{"parsed":{"expected_type":"building","housenumber":"63a","street":"drosselweg","city":"calvin"}}}',
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }),
      );

      final location = await service.geocodeAddress(
        'Drosselweg 63a, 9959 Neu Calvin, CH',
      );

      expect(location, isNull);
    },
  );

  test('akzeptiert Gebaeude-Suche mit neuem Street-Level-Default 0.5', () async {
    final service = GeoapifyAddressMapService(
      apiKeyOverride: 'test-key',
      httpClient: MockClient((request) async {
        expect(request.url.host, 'api.geoapify.com');
        return http.Response(
          '{"results":[{"lat":53.5511,"lon":9.9937,"rank":{"confidence":0.5,"confidence_street_level":0.5,"match_type":"full_match"}}],"query":{"parsed":{"expected_type":"building","housenumber":"4"}}}',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final location = await service.geocodeAddress('Musterweg 4, 50667 Koeln');

    expect(location, isNotNull);
    expect(location?.latitude, 53.5511);
    expect(location?.longitude, 9.9937);
  });

  test(
    'liefert null unterhalb der konfigurierten allgemeinen confidence',
    () async {
      final service = GeoapifyAddressMapService(
        apiKeyOverride: 'test-key',
        httpClient: MockClient((request) async {
          expect(request.url.host, 'api.geoapify.com');
          return http.Response(
            '{"results":[{"lat":53.5511,"lon":9.9937,"rank":{"confidence":0.49,"confidence_street_level":1,"match_type":"full_match"}}],"query":{"parsed":{"expected_type":"street"}}}',
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }),
      );

      final location = await service.geocodeAddress('Musterweg, 50667 Koeln');

      expect(location, isNull);
    },
  );

  test(
    'liefert null bei Hausnummer unterhalb der street-level-confidence',
    () async {
      final service = GeoapifyAddressMapService(
        apiKeyOverride: 'test-key',
        httpClient: MockClient((request) async {
          expect(request.url.host, 'api.geoapify.com');
          return http.Response(
            '{"results":[{"lat":53.5511,"lon":9.9937,"rank":{"confidence":0.92,"confidence_street_level":0.49,"match_type":"full_match"}}],"query":{"parsed":{"expected_type":"building","housenumber":"4"}}}',
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }),
      );

      final location = await service.geocodeAddress('Musterweg 4, 50667 Koeln');

      expect(location, isNull);
    },
  );

  test('loggt ohne Detailed-Log keine gesuchte Adresse', () async {
    final logger = _RecordingLoggerService();
    final service = GeoapifyAddressMapService(
      apiKeyOverride: 'test-key',
      logger: logger,
      detailedLogEnabled: false,
      httpClient: MockClient((request) async {
        return http.Response(
          '{"results":[{"formatted":"Musterweg 4, 50667 Koeln","lat":53.5511,"lon":9.9937,"result_type":"building","rank":{"confidence":0.49,"confidence_street_level":0.9,"match_type":"full_match"}}],"query":{"parsed":{"expected_type":"building","housenumber":"4"}}}',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    await service.resolveAddress('Geheime Adresse 1, 12345 Ort');

    final messages = logger.messages.join('\n');
    expect(messages, contains('confidence=0.49'));
    expect(messages, isNot(contains('Geheime Adresse')));
    expect(messages, isNot(contains('Musterweg 4')));
  });

  test('loggt mit Detailed-Log gesuchte Adresse und Trefferliste', () async {
    final logger = _RecordingLoggerService();
    final service = GeoapifyAddressMapService(
      apiKeyOverride: 'test-key',
      logger: logger,
      detailedLogEnabled: true,
      httpClient: MockClient((request) async {
        return http.Response(
          '{"results":[{"formatted":"Musterweg 4, 50667 Koeln","lat":53.5511,"lon":9.9937,"result_type":"building","rank":{"confidence":0.49,"confidence_street_level":0.9,"match_type":"full_match"}}],"query":{"parsed":{"expected_type":"building","housenumber":"4"}}}',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    await service.resolveAddress('Geheime Adresse 1, 12345 Ort');

    final messages = logger.messages.join('\n');
    expect(messages, contains('searched_address="Geheime Adresse'));
    expect(messages, contains('Musterweg 4, 50667 Koeln'));
    expect(messages, contains('confidence=0.49'));
    expect(messages, contains('confidence_street_level=0.9'));
  });

  test('resolveAddress markiert HTTP-Fehler als technischen Fehler', () async {
    final service = GeoapifyAddressMapService(
      apiKeyOverride: 'test-key',
      httpClient: MockClient((request) async {
        expect(request.url.host, 'api.geoapify.com');
        return http.Response(
          '{"error":"bad request"}',
          400,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final result = await service.resolveAddress('Musterweg 4, 50667 Koeln');

    expect(result.location, isNull);
    expect(result.addressNotFound, isFalse);
    expect(result.technicalError, isTrue);
  });
}

class _RecordingLoggerService extends LoggerService {
  _RecordingLoggerService()
    : super(
        settingsRepository: _FakeAppSettingsRepository(),
        navigatorKey: GlobalKey<NavigatorState>(),
      );

  final List<String> messages = <String>[];

  @override
  Future<void> log(String service, String message) async {
    messages.add('[$service] $message');
  }

  @override
  Future<void> logInfo(String service, String message) async {
    messages.add('[$service] $message');
  }

  @override
  Future<void> logWarn(String service, String message) async {
    messages.add('[$service] $message');
  }

  @override
  Future<void> logError(
    String service,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) async {
    messages.add('[$service] $message');
  }
}

class _FakeAppSettingsRepository extends AppSettingsRepository {
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
  Future<void> saveGeburstagsbenachrichtigungStufen(Set<Stufe> stufen) async {}

  @override
  Future<void> saveLanguageCode(String code) async {}

  @override
  Future<void> saveMemberListSearchResultHighlightEnabled(bool enabled) async {}

  @override
  Future<void> saveNotificationsEnabled(bool enabled) async {}

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {}
}
