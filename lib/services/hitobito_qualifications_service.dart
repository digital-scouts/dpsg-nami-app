import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/qualifikation/qualifikation.dart';
import 'hitobito_api_exception.dart';
import 'hitobito_auth_env.dart';
import 'hitobito_traffic_log_service.dart';
import 'logger_service.dart';

class HitobitoQualificationsException extends HitobitoApiException {
  const HitobitoQualificationsException(super.message, {super.statusCode});
}

/// Laedt Qualifikationen aus `/api/qualifications` samt Art
/// (`include=qualification_kind`), paginiert ueber `links.next`.
class HitobitoQualificationsService {
  HitobitoQualificationsService({
    required this.config,
    http.Client? httpClient,
    HitobitoTrafficLogService? trafficLogService,
    LoggerService? logger,
  }) : _httpClient = httpClient ?? http.Client(),
       _trafficLogService = trafficLogService,
       _logger = logger;

  HitobitoAuthConfig config;
  final http.Client _httpClient;
  final HitobitoTrafficLogService? _trafficLogService;
  final LoggerService? _logger;

  void updateConfig(HitobitoAuthConfig nextConfig) {
    config = nextConfig;
  }

  /// Alle fuer den Token sichtbaren Qualifikationen. Die API kennt nur
  /// Filter auf `person_id` und `qualification_kind_id`, daher wird die
  /// Gesamtliste geladen und erst im Arbeitskontext eingeschraenkt.
  Future<List<Qualifikation>> fetchAlleQualifikationen(
    String accessToken,
  ) async {
    final requestUri = config.qualificationsUri;
    if (requestUri == null) {
      throw const HitobitoQualificationsException(
        'Der Qualifications-Endpoint konnte nicht aus der OAuth-Konfiguration abgeleitet werden.',
      );
    }

    final qualifikationen = <Qualifikation>[];
    Uri? nextUri = _decorateRequestUri(requestUri);

    while (nextUri != null) {
      final decoded = await _fetchPage(
        requestUri: nextUri,
        accessToken: accessToken,
      );
      final data = decoded['data'];
      if (data is! List) {
        throw const HitobitoQualificationsException(
          'Qualifications-Antwort enthaelt keine gueltige Datensammlung.',
        );
      }

      final arten = _extractIncludedKinds(decoded['included']);
      for (final resource in data.whereType<Map<String, dynamic>>()) {
        final qualifikation = _mapResource(resource, arten);
        if (qualifikation != null) {
          qualifikationen.add(qualifikation);
        }
      }
      nextUri = _resolveNextUri(decoded, currentUri: nextUri);
    }

    return qualifikationen;
  }

  Uri _decorateRequestUri(Uri uri) {
    final queryParameters = Map<String, String>.from(uri.queryParameters);
    queryParameters['include'] = 'qualification_kind';
    queryParameters['fields[qualifications]'] =
        'person_id,qualification_kind_id,start_at,finish_at,qualified_at,origin';
    queryParameters['fields[qualification_kinds]'] =
        'label,validity,reactivateable';
    return uri.replace(queryParameters: queryParameters);
  }

  Future<Map<String, dynamic>> _fetchPage({
    required Uri requestUri,
    required String accessToken,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/vnd.api+json, application/json',
      'Authorization': 'Bearer $accessToken',
    };

    http.Response response;
    try {
      response = await _httpClient.get(requestUri, headers: headers);
    } catch (error) {
      await _logger?.logHttpRequest(
        source: 'hitobito_qualifications',
        method: 'GET',
        uri: requestUri,
        error: error,
      );
      await _trafficLogService?.logResponse(
        source: 'qualifications',
        method: 'GET',
        uri: requestUri,
        error: error,
      );
      rethrow;
    }

    await _logger?.logHttpRequest(
      source: 'hitobito_qualifications',
      method: 'GET',
      uri: requestUri,
      statusCode: response.statusCode,
    );
    await _trafficLogService?.logResponse(
      source: 'qualifications',
      method: 'GET',
      uri: requestUri,
      statusCode: response.statusCode,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HitobitoQualificationsException(
        'Qualifications-Anfrage fehlgeschlagen (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const HitobitoQualificationsException(
        'Qualifications-Antwort hat ein ungueltiges Format.',
      );
    }
    return decoded;
  }

  Map<int, _QualifikationsArt> _extractIncludedKinds(Object? included) {
    if (included is! List) {
      return const <int, _QualifikationsArt>{};
    }
    final arten = <int, _QualifikationsArt>{};
    for (final entry in included.whereType<Map<String, dynamic>>()) {
      if (entry['type']?.toString() != 'qualification_kinds') {
        continue;
      }
      final id = _toNullableInt(entry['id']);
      final attributes = entry['attributes'];
      if (id == null || attributes is! Map<String, dynamic>) {
        continue;
      }
      final label = attributes['label']?.toString().trim();
      if (label == null || label.isEmpty) {
        continue;
      }
      final reaktivierbarJahre = _toNullableInt(attributes['reactivateable']);
      final gueltigkeitJahre = _toNullableInt(attributes['validity']);
      arten[id] = _QualifikationsArt(
        label: label,
        reaktivierbar: reaktivierbarJahre != null && reaktivierbarJahre > 0,
        gueltigkeitJahre: gueltigkeitJahre != null && gueltigkeitJahre > 0
            ? gueltigkeitJahre
            : null,
      );
    }
    return arten;
  }

  /// Liefert `null` fuer Eintraege ohne Person oder ohne bekannte Art, statt
  /// den ganzen Abruf scheitern zu lassen.
  Qualifikation? _mapResource(
    Map<String, dynamic> resource,
    Map<int, _QualifikationsArt> arten,
  ) {
    final attributes = resource['attributes'];
    final attributesMap = attributes is Map<String, dynamic>
        ? attributes
        : const <String, dynamic>{};
    final id = _toNullableInt(resource['id']);
    final personId = _toNullableInt(attributesMap['person_id']);
    final artId =
        _toNullableInt(attributesMap['qualification_kind_id']) ??
        _relationshipId(resource['relationships'], 'qualification_kind');
    final art = artId == null ? null : arten[artId];
    if (id == null || id <= 0 || personId == null || personId <= 0) {
      return null;
    }
    if (art == null) {
      return null;
    }

    return Qualifikation(
      id: id,
      personId: personId,
      artId: artId,
      label: art.label,
      qualifiedAt: _toDateTime(attributesMap['qualified_at']),
      startAt: _toDateTime(attributesMap['start_at']),
      finishAt: _toDateTime(attributesMap['finish_at']),
      origin: attributesMap['origin']?.toString(),
      reaktivierbar: art.reaktivierbar,
      gueltigkeitJahre: art.gueltigkeitJahre,
    );
  }

  int? _relationshipId(Object? relationships, String key) {
    if (relationships is! Map<String, dynamic>) {
      return null;
    }
    final relationship = relationships[key];
    if (relationship is! Map<String, dynamic>) {
      return null;
    }
    final data = relationship['data'];
    return data is Map<String, dynamic> ? _toNullableInt(data['id']) : null;
  }

  Uri? _resolveNextUri(
    Map<String, dynamic> decoded, {
    required Uri currentUri,
  }) {
    final links = decoded['links'];
    if (links is! Map<String, dynamic>) {
      return null;
    }

    final next = links['next'];
    final nextValue = next is String
        ? next
        : next is Map<String, dynamic>
        ? next['href']?.toString()
        : null;
    if (nextValue == null || nextValue.isEmpty) {
      return null;
    }

    return currentUri.resolve(nextValue);
  }

  DateTime? _toDateTime(Object? value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  int? _toNullableInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
  }
}

class _QualifikationsArt {
  const _QualifikationsArt({
    required this.label,
    required this.reaktivierbar,
    this.gueltigkeitJahre,
  });

  final String label;
  final bool reaktivierbar;
  final int? gueltigkeitJahre;
}
