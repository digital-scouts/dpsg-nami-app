import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nami/services/geoapify_address_map_service.dart';

void main() {
  test('geocodiert eine Adresse ueber Geoapify', () async {
    final service = GeoapifyAddressMapService(
      apiKeyOverride: 'test-key',
      httpClient: MockClient((request) async {
        expect(request.url.host, 'api.geoapify.com');
        return http.Response(
          '{"results":[{"lat":53.5511,"lon":9.9937}]}',
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

  test('laedt eine statische Karten-Vorschau und speichert sie lokal', () async {
    final tempDir = await Directory.systemTemp.createTemp('geoapify_preview_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final service = GeoapifyAddressMapService(
      apiKeyOverride: 'test-key',
      directoryProvider: () async => tempDir,
      httpClient: MockClient((request) async {
        expect(request.url.host, 'maps.geoapify.com');
        return http.Response.bytes(
          Uint8List.fromList(<int>[1, 2, 3, 4]),
          200,
          headers: <String, String>{'content-type': 'image/png'},
        );
      }),
    );

    final path = await service.downloadStaticMapPreview(
      cacheKey: '23:0',
      addressFingerprint: 'abcdef1234567890',
      latitude: 53.5511,
      longitude: 9.9937,
    );

    expect(path, isNotNull);
    expect(await File(path!).exists(), isTrue);
    expect(await File(path).readAsBytes(), <int>[1, 2, 3, 4]);
  });

  test('faellt bei fehlerhaftem Marker auf Preview ohne Marker zurueck', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'geoapify_preview_fallback_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final requestedMarkerValues = <String?>[];
    final service = GeoapifyAddressMapService(
      apiKeyOverride: 'test-key',
      directoryProvider: () async => tempDir,
      httpClient: MockClient((request) async {
        requestedMarkerValues.add(request.url.queryParameters['marker']);
        final markerValue = request.url.queryParameters['marker'];
        if (markerValue != null) {
          return http.Response(
            '{"statusCode":400,"error":"Bad Request","message":"marker invalid"}',
            400,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        return http.Response.bytes(
          Uint8List.fromList(<int>[7, 8, 9]),
          200,
          headers: <String, String>{'content-type': 'image/png'},
        );
      }),
    );

    final path = await service.downloadStaticMapPreview(
      cacheKey: '80:0',
      addressFingerprint: 'abcdef1234567890',
      latitude: 53.5511,
      longitude: 9.9937,
    );

    expect(path, isNotNull);
    expect(requestedMarkerValues, hasLength(2));
    expect(requestedMarkerValues.first, isNotNull);
    expect(requestedMarkerValues.last, isNull);
    expect(await File(path!).readAsBytes(), <int>[7, 8, 9]);
  });
}