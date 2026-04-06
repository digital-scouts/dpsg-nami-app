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

  test(
    'liefert null bei Gebaeude-Suche ohne ausreichende street confidence',
    () async {
      final service = GeoapifyAddressMapService(
        apiKeyOverride: 'test-key',
        httpClient: MockClient((request) async {
          expect(request.url.host, 'api.geoapify.com');
          return http.Response(
            '{"results":[{"lat":53.5511,"lon":9.9937,"rank":{"confidence":0.92,"confidence_street_level":0.4,"match_type":"full_match"}}],"query":{"parsed":{"expected_type":"building","housenumber":"4"}}}',
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }),
      );

      final location = await service.geocodeAddress('Musterweg 4, 50667 Koeln');

      expect(location, isNull);
    },
  );

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
