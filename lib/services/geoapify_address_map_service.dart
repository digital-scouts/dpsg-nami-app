import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'logger_service.dart';
import 'network_access_policy.dart';

class GeoapifyGeocodeResult {
  const GeoapifyGeocodeResult._({
    this.location,
    this.addressNotFound = false,
    this.technicalError = false,
    this.networkBlocked = false,
    this.deviceOffline = false,
    this.mobileDataBlocked = false,
  });

  const GeoapifyGeocodeResult.success(LatLng location)
    : this._(location: location);

  const GeoapifyGeocodeResult.addressNotFound() : this._(addressNotFound: true);

  const GeoapifyGeocodeResult.technicalError() : this._(technicalError: true);

  const GeoapifyGeocodeResult.networkBlocked({
    required bool deviceOffline,
    required bool mobileDataBlocked,
  }) : this._(
         networkBlocked: true,
         deviceOffline: deviceOffline,
         mobileDataBlocked: mobileDataBlocked,
       );

  final LatLng? location;
  final bool addressNotFound;
  final bool technicalError;
  final bool networkBlocked;
  final bool deviceOffline;
  final bool mobileDataBlocked;
}

class GeoapifyAddressMapService {
  static const double minimumConfidence = 0.8;
  static const double minimumStreetLevelConfidence = 0.8;

  GeoapifyAddressMapService({
    http.Client? httpClient,
    String? apiKeyOverride,
    LoggerService? logger,
    NetworkAccessPolicy? networkAccessPolicy,
    Duration requestTimeout = const Duration(seconds: 10),
  }) : _httpClient = httpClient ?? http.Client(),
       _apiKeyOverride = apiKeyOverride,
       _logger = logger,
       _networkAccessPolicy = networkAccessPolicy,
       _requestTimeout = requestTimeout;

  final http.Client _httpClient;
  final String? _apiKeyOverride;
  final LoggerService? _logger;
  final NetworkAccessPolicy? _networkAccessPolicy;
  final Duration _requestTimeout;

  bool get hasApiKey {
    final key = _apiKey;
    return key != null && key.isNotEmpty;
  }

  Future<GeoapifyGeocodeResult> resolveAddress(String addressText) async {
    final key = _apiKey;
    if (key == null || key.isEmpty) {
      await _logger?.log(
        'maps',
        'Geoapify Geocoding uebersprungen: API-Key fehlt',
      );
      return const GeoapifyGeocodeResult.technicalError();
    }

    final trimmedAddress = addressText.trim();
    if (trimmedAddress.isEmpty) {
      await _logger?.log(
        'maps',
        'Geoapify Geocoding uebersprungen: leere Adresse',
      );
      return const GeoapifyGeocodeResult.addressNotFound();
    }

    final uri = Uri.https('api.geoapify.com', '/v1/geocode/search', {
      'text': trimmedAddress,
      'lang': 'de',
      'limit': '1',
      'format': 'json',
      'apiKey': key,
    });

    try {
      await _networkAccessPolicy?.ensureNetworkAllowed(
        trigger: 'geoapify_geocode',
        feature: 'Adresssuche',
      );
      final response = await _httpClient.get(uri).timeout(_requestTimeout);
      await _logger?.log(
        'maps',
        'Geoapify Geocoding Response: status=${response.statusCode}, bytes=${response.bodyBytes.length}',
      );
      if (response.statusCode != 200) {
        await _logger?.log(
          'maps',
          'Geoapify Geocoding fehlgeschlagen: status=${response.statusCode}, body=${_truncate(response.body)}',
        );
        return const GeoapifyGeocodeResult.technicalError();
      }
      if (response.body.isEmpty) {
        await _logger?.log('maps', 'Geoapify Geocoding lieferte leeren Body');
        return const GeoapifyGeocodeResult.technicalError();
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const GeoapifyGeocodeResult.technicalError();
      }
      final results = decoded['results'];
      if (results is! List || results.isEmpty) {
        return const GeoapifyGeocodeResult.addressNotFound();
      }
      final first = results.first;
      if (first is! Map<String, dynamic>) {
        return const GeoapifyGeocodeResult.technicalError();
      }
      if (!_isPreciseEnough(result: first, payload: decoded)) {
        await _logger?.log(
          'maps',
          'Geoapify Geocoding verworfen: Treffer nicht praezise genug',
        );
        return const GeoapifyGeocodeResult.addressNotFound();
      }
      final latitude = _toDouble(first['lat']);
      final longitude = _toDouble(first['lon']);
      if (latitude == null || longitude == null) {
        await _logger?.log(
          'maps',
          'Geoapify Geocoding ohne gueltige Koordinaten',
        );
        return const GeoapifyGeocodeResult.technicalError();
      }
      await _logger?.log('maps', 'Geoapify Geocoding erfolgreich');
      return GeoapifyGeocodeResult.success(LatLng(latitude, longitude));
    } on TimeoutException {
      await _logger?.log(
        'maps',
        'Geoapify Geocoding Timeout nach $_requestTimeout',
      );
      return const GeoapifyGeocodeResult.technicalError();
    } on NetworkAccessBlockedException catch (error) {
      await _logger?.log(
        'maps',
        'Geoapify Geocoding blockiert: ${error.message}',
      );
      return GeoapifyGeocodeResult.networkBlocked(
        deviceOffline: error.isOffline,
        mobileDataBlocked: error.isBlockedByNoMobileData,
      );
    } catch (error, stackTrace) {
      await _logger?.log(
        'maps',
        'Geoapify Geocoding Exception: $error\n$stackTrace',
      );
      return const GeoapifyGeocodeResult.technicalError();
    }
  }

  Future<LatLng?> geocodeAddress(String addressText) async {
    final result = await resolveAddress(addressText);
    return result.location;
  }

  String? get _apiKey {
    final override = _apiKeyOverride?.trim();
    if (override != null && override.isNotEmpty) {
      return override;
    }
    try {
      return dotenv.env['GEOAPIFY_KEY'];
    } catch (_) {
      return null;
    }
  }

  double? _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }

  bool _isPreciseEnough({
    required Map<String, dynamic> result,
    required Map<String, dynamic> payload,
  }) {
    final rank = result['rank'];
    if (rank is! Map<String, dynamic>) {
      return true;
    }

    final confidence = _toDouble(rank['confidence']) ?? 0;
    final confidenceStreetLevel =
        _toDouble(rank['confidence_street_level']) ?? 0;
    final matchType = rank['match_type']?.toString().trim().toLowerCase();

    if (confidence < minimumConfidence) {
      return false;
    }
    if (matchType == 'inner_part') {
      return false;
    }

    final query = payload['query'];
    final parsed = query is Map<String, dynamic> ? query['parsed'] : null;
    final parsedMap = parsed is Map<String, dynamic> ? parsed : null;
    final expectedType = parsedMap?['expected_type']?.toString().trim();
    final hasHouseNumber =
        (parsedMap?['housenumber']?.toString().trim().isNotEmpty ?? false);

    if ((expectedType == 'building' || hasHouseNumber) &&
        confidenceStreetLevel < minimumStreetLevelConfidence) {
      return false;
    }

    return true;
  }

  String _truncate(String value, {int maxLength = 280}) {
    if (value.length <= maxLength) {
      return value;
    }
    return '${value.substring(0, maxLength)}...';
  }
}
