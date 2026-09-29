import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'geoapify_env.dart';
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
  GeoapifyAddressMapService({
    http.Client? httpClient,
    String? apiKeyOverride,
    LoggerService? logger,
    NetworkAccessPolicy? networkAccessPolicy,
    Duration requestTimeout = const Duration(seconds: 10),
    double? minimumConfidence,
    double? minimumStreetLevelConfidence,
    bool? detailedLogEnabled,
  }) : _httpClient = httpClient ?? http.Client(),
       _apiKeyOverride = apiKeyOverride,
       _logger = logger,
       _networkAccessPolicy = networkAccessPolicy,
       _requestTimeout = requestTimeout,
       _minimumConfidence = minimumConfidence ?? GeoapifyEnv.minConfidence,
       _minimumStreetLevelConfidence =
           minimumStreetLevelConfidence ?? GeoapifyEnv.minStreetLevelConfidence,
       _detailedLogEnabled =
           detailedLogEnabled ?? GeoapifyEnv.detailedLogEnabled;

  final http.Client _httpClient;
  final String? _apiKeyOverride;
  final LoggerService? _logger;
  final NetworkAccessPolicy? _networkAccessPolicy;
  final Duration _requestTimeout;
  final double _minimumConfidence;
  final double _minimumStreetLevelConfidence;
  final bool _detailedLogEnabled;

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
      await _logger?.logHttpRequest(
        source: 'geoapify_geocode',
        method: 'GET',
        uri: uri,
        statusCode: response.statusCode,
      );
      await _logger?.log(
        'maps',
        'Geoapify Geocoding Response: status=${response.statusCode}, bytes=${response.bodyBytes.length}',
      );
      if (response.statusCode != 200) {
        await _logger?.log(
          'maps',
          'Geoapify Geocoding fehlgeschlagen: status=${response.statusCode}',
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
        await _logDetailedResults(
          trimmedAddress: trimmedAddress,
          payload: decoded,
        );
        return const GeoapifyGeocodeResult.addressNotFound();
      }
      await _logDetailedResults(
        trimmedAddress: trimmedAddress,
        payload: decoded,
      );
      final first = results.first;
      if (first is! Map<String, dynamic>) {
        return const GeoapifyGeocodeResult.technicalError();
      }
      final precisionCheck = _checkPrecision(result: first, payload: decoded);
      if (!precisionCheck.isPreciseEnough) {
        await _logRejectedResult(
          trimmedAddress: trimmedAddress,
          payload: decoded,
          rejection: precisionCheck,
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
    } on TimeoutException catch (error) {
      await _logger?.logHttpRequest(
        source: 'geoapify_geocode',
        method: 'GET',
        uri: uri,
        error: error,
      );
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
      await _logger?.logHttpRequest(
        source: 'geoapify_geocode',
        method: 'GET',
        uri: uri,
        error: error,
      );
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

  _GeoapifyPrecisionCheck _checkPrecision({
    required Map<String, dynamic> result,
    required Map<String, dynamic> payload,
  }) {
    final rank = result['rank'];
    if (rank is! Map<String, dynamic>) {
      return const _GeoapifyPrecisionCheck(isPreciseEnough: true);
    }

    final confidence = _toDouble(rank['confidence']) ?? 0;
    final confidenceStreetLevel =
        _toDouble(rank['confidence_street_level']) ?? 0;
    final matchType = rank['match_type']?.toString().trim().toLowerCase();

    if (confidence < _minimumConfidence) {
      return _GeoapifyPrecisionCheck(
        isPreciseEnough: false,
        reason: 'confidence_below_minimum',
        confidence: confidence,
        confidenceStreetLevel: confidenceStreetLevel,
        matchType: matchType,
        resultType: result['result_type']?.toString(),
      );
    }
    if (matchType == 'inner_part') {
      return _GeoapifyPrecisionCheck(
        isPreciseEnough: false,
        reason: 'inner_part_match',
        confidence: confidence,
        confidenceStreetLevel: confidenceStreetLevel,
        matchType: matchType,
        resultType: result['result_type']?.toString(),
      );
    }

    final query = payload['query'];
    final parsed = query is Map<String, dynamic> ? query['parsed'] : null;
    final parsedMap = parsed is Map<String, dynamic> ? parsed : null;
    final expectedType = parsedMap?['expected_type']?.toString().trim();
    final hasHouseNumber =
        (parsedMap?['housenumber']?.toString().trim().isNotEmpty ?? false);

    if ((expectedType == 'building' || hasHouseNumber) &&
        confidenceStreetLevel < _minimumStreetLevelConfidence) {
      return _GeoapifyPrecisionCheck(
        isPreciseEnough: false,
        reason: 'street_level_confidence_below_minimum',
        confidence: confidence,
        confidenceStreetLevel: confidenceStreetLevel,
        matchType: matchType,
        resultType: result['result_type']?.toString(),
      );
    }

    return _GeoapifyPrecisionCheck(
      isPreciseEnough: true,
      confidence: confidence,
      confidenceStreetLevel: confidenceStreetLevel,
      matchType: matchType,
      resultType: result['result_type']?.toString(),
    );
  }

  Future<void> _logRejectedResult({
    required String trimmedAddress,
    required Map<String, dynamic> payload,
    required _GeoapifyPrecisionCheck rejection,
  }) async {
    final baseMessage =
        StringBuffer('Geoapify Geocoding verworfen: reason=${rejection.reason}')
          ..write(' confidence=${rejection.confidence}')
          ..write(' min_confidence=$_minimumConfidence')
          ..write(' confidence_street_level=${rejection.confidenceStreetLevel}')
          ..write(' min_street_level_confidence=$_minimumStreetLevelConfidence')
          ..write(' match_type=${rejection.matchType}')
          ..write(' result_type=${rejection.resultType}');

    if (!_detailedLogEnabled) {
      await _logger?.log('maps', baseMessage.toString());
      return;
    }

    baseMessage.write(' searched_address="$trimmedAddress"');
    baseMessage.write(' hits=${_describeHits(payload)}');
    await _logger?.log('maps', baseMessage.toString());
  }

  Future<void> _logDetailedResults({
    required String trimmedAddress,
    required Map<String, dynamic> payload,
  }) async {
    if (!_detailedLogEnabled) {
      return;
    }
    await _logger?.log(
      'maps',
      'Geoapify Geocoding Detail: searched_address="$trimmedAddress" hits=${_describeHits(payload)}',
    );
  }

  String _describeHits(Map<String, dynamic> payload) {
    final results = payload['results'];
    if (results is! List) {
      return '[]';
    }
    final hits = results.take(5).map((result) {
      if (result is! Map<String, dynamic>) {
        return '{invalid}';
      }
      final rank = result['rank'];
      final rankMap = rank is Map<String, dynamic> ? rank : null;
      return '{formatted=${result['formatted']}, result_type=${result['result_type']}, confidence=${rankMap?['confidence']}, confidence_street_level=${rankMap?['confidence_street_level']}, match_type=${rankMap?['match_type']}}';
    });
    return '[${hits.join(', ')}]';
  }
}

class _GeoapifyPrecisionCheck {
  const _GeoapifyPrecisionCheck({
    required this.isPreciseEnough,
    this.reason,
    this.confidence,
    this.confidenceStreetLevel,
    this.matchType,
    this.resultType,
  });

  final bool isPreciseEnough;
  final String? reason;
  final double? confidence;
  final double? confidenceStreetLevel;
  final String? matchType;
  final String? resultType;
}
