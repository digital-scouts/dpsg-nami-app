import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import 'logger_service.dart';

typedef MapPreviewDirectoryProvider = Future<Directory> Function();

class GeoapifyAddressMapService {
  GeoapifyAddressMapService({
    http.Client? httpClient,
    MapPreviewDirectoryProvider? directoryProvider,
    String? apiKeyOverride,
    LoggerService? logger,
    Duration requestTimeout = const Duration(seconds: 10),
  }) : _httpClient = httpClient ?? http.Client(),
       _directoryProvider =
           directoryProvider ?? getApplicationDocumentsDirectory,
       _apiKeyOverride = apiKeyOverride,
       _logger = logger,
       _requestTimeout = requestTimeout;

  final http.Client _httpClient;
  final MapPreviewDirectoryProvider _directoryProvider;
  final String? _apiKeyOverride;
  final LoggerService? _logger;
  final Duration _requestTimeout;

  bool get hasApiKey {
    final key = _apiKey;
    return key != null && key.isNotEmpty;
  }

  Future<LatLng?> geocodeAddress(String addressText) async {
    final key = _apiKey;
    if (key == null || key.isEmpty) {
      await _logger?.log(
        'maps',
        'Geoapify Geocoding uebersprungen: API-Key fehlt',
      );
      return null;
    }

    final trimmedAddress = addressText.trim();
    if (trimmedAddress.isEmpty) {
      await _logger?.log(
        'maps',
        'Geoapify Geocoding uebersprungen: leere Adresse',
      );
      return null;
    }

    final uri = Uri.https('api.geoapify.com', '/v1/geocode/search', {
      'text': trimmedAddress,
      'lang': 'de',
      'limit': '1',
      'format': 'json',
      'apiKey': key,
    });

    try {
      await _logger?.log(
        'maps',
        'Geoapify Geocoding Request: host=${uri.host}, path=${uri.path}, textLength=${trimmedAddress.length}',
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
        return null;
      }
      if (response.body.isEmpty) {
        await _logger?.log('maps', 'Geoapify Geocoding lieferte leeren Body');
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final results = decoded['results'];
      if (results is! List || results.isEmpty) {
        return null;
      }
      final first = results.first;
      if (first is! Map<String, dynamic>) {
        return null;
      }
      final latitude = _toDouble(first['lat']);
      final longitude = _toDouble(first['lon']);
      if (latitude == null || longitude == null) {
        await _logger?.log(
          'maps',
          'Geoapify Geocoding ohne gueltige Koordinaten',
        );
        return null;
      }
      await _logger?.log('maps', 'Geoapify Geocoding erfolgreich');
      return LatLng(latitude, longitude);
    } on TimeoutException {
      await _logger?.log(
        'maps',
        'Geoapify Geocoding Timeout nach $_requestTimeout',
      );
      return null;
    } catch (error, stackTrace) {
      await _logger?.log(
        'maps',
        'Geoapify Geocoding Exception: $error\n$stackTrace',
      );
      return null;
    }
  }

  Future<String?> downloadStaticMapPreview({
    required String cacheKey,
    required String addressFingerprint,
    required double latitude,
    required double longitude,
    int width = 800,
    int height = 400,
    int zoom = 15,
  }) async {
    final key = _apiKey;
    if (key == null || key.isEmpty) {
      await _logger?.log(
        'maps',
        'Geoapify Karten-Preview uebersprungen: API-Key fehlt',
      );
      return null;
    }

    try {
      var response = await _requestStaticMapPreview(
        cacheKey: cacheKey,
        latitude: latitude,
        longitude: longitude,
        width: width,
        height: height,
        zoom: zoom,
        includeMarker: true,
      );

      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        await _logger?.log(
          'maps',
          'Geoapify Karten-Preview mit Marker fehlgeschlagen, versuche Fallback ohne Marker: status=${response.statusCode}',
        );
        response = await _requestStaticMapPreview(
          cacheKey: cacheKey,
          latitude: latitude,
          longitude: longitude,
          width: width,
          height: height,
          zoom: zoom,
          includeMarker: false,
        );
      }

      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        await _logger?.log(
          'maps',
          'Geoapify Karten-Preview fehlgeschlagen: status=${response.statusCode}, body=${_truncate(response.body)}',
        );
        return null;
      }

      final rootDirectory = await _directoryProvider();
      final previewDirectory = Directory(
        '${rootDirectory.path}/address_map_previews',
      );
      if (!await previewDirectory.exists()) {
        await previewDirectory.create(recursive: true);
      }

      final sanitizedKey = cacheKey.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
      final shortenedFingerprint = addressFingerprint.substring(
        0,
        addressFingerprint.length < 12 ? addressFingerprint.length : 12,
      );
      final file = File(
        '${previewDirectory.path}/$sanitizedKey-$shortenedFingerprint.png',
      );
      await file.writeAsBytes(response.bodyBytes, flush: true);
      await _logger?.log(
        'maps',
        'Geoapify Karten-Preview gespeichert: ${file.path}',
      );
      return file.path;
    } on TimeoutException {
      await _logger?.log(
        'maps',
        'Geoapify Karten-Preview Timeout nach $_requestTimeout',
      );
      return null;
    } catch (error, stackTrace) {
      await _logger?.log(
        'maps',
        'Geoapify Karten-Preview Exception: $error\n$stackTrace',
      );
      return null;
    }
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

  String _truncate(String value, {int maxLength = 280}) {
    if (value.length <= maxLength) {
      return value;
    }
    return '${value.substring(0, maxLength)}...';
  }

  Future<http.Response> _requestStaticMapPreview({
    required String cacheKey,
    required double latitude,
    required double longitude,
    required int width,
    required int height,
    required int zoom,
    required bool includeMarker,
  }) async {
    final key = _apiKey!;
    final queryParameters = <String, String>{
      'style': 'osm-bright',
      'width': '$width',
      'height': '$height',
      'center': 'lonlat:$longitude,$latitude',
      'zoom': '$zoom',
      'apiKey': key,
    };
    if (includeMarker) {
      queryParameters['marker'] =
          'lonlat:$longitude,$latitude;color:#c62828;size:medium';
    }

    final uri = Uri.https(
      'maps.geoapify.com',
      '/v1/staticmap',
      queryParameters,
    );
    final loggedUri = uri.replace(
      queryParameters: <String, String>{...queryParameters, 'apiKey': '***'},
    );

    await _logger?.log(
      'maps',
      'Geoapify Karten-Preview Request: host=${uri.host}, path=${uri.path}, cacheKey=$cacheKey, zoom=$zoom, includeMarker=$includeMarker, url=$loggedUri',
    );
    final response = await _httpClient.get(uri).timeout(_requestTimeout);
    await _logger?.log(
      'maps',
      'Geoapify Karten-Preview Response: status=${response.statusCode}, bytes=${response.bodyBytes.length}, includeMarker=$includeMarker',
    );
    return response;
  }
}
