import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../domain/member/efz_einsichtnahme.dart';
import 'hitobito_api_exception.dart';
import 'hitobito_auth_env.dart';
import 'hitobito_traffic_log_service.dart';
import 'logger_service.dart';

class HitobitoEfzException extends HitobitoApiException {
  const HitobitoEfzException(super.message, {super.statusCode});
}

/// Wird geworfen, wenn der (nicht dokumentierte) `efz_antrag`-Web-Endpoint
/// kein PDF liefert (z.B. weil der Bearer-Token dort nicht akzeptiert wird).
/// Aufrufer sollten in diesem Fall auf einen Browser-Fallback ausweichen.
class HitobitoEfzAntragUnavailableException extends HitobitoEfzException {
  const HitobitoEfzAntragUnavailableException(
    super.message, {
    super.statusCode,
  });
}

class HitobitoEfzService {
  HitobitoEfzService({
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

  Future<List<EfzEinsichtnahme>> fetchEfzEinsichtnahmenFuerPerson(
    String accessToken, {
    required int personId,
  }) {
    return _fetchAll(
      accessToken,
      extraQueryParameters: <String, String>{
        'filter[person_id][eq]': '$personId',
      },
    );
  }

  /// Laedt die komplette, fuer den Token sichtbare `efz_einsichtnahmen`-Liste
  /// (paginiert). Wird von der Qualifikationen-Uebersichtsseite verwendet, da
  /// die API keinen Batch-/"in"-Filter fuer `person_id` anbietet.
  Future<List<EfzEinsichtnahme>> fetchAlleEfzEinsichtnahmen(
    String accessToken,
  ) {
    return _fetchAll(accessToken);
  }

  Future<List<EfzEinsichtnahme>> _fetchAll(
    String accessToken, {
    Map<String, String> extraQueryParameters = const <String, String>{},
  }) async {
    final requestUri = config.efzEinsichtnahmenUri;
    if (requestUri == null) {
      throw const HitobitoEfzException(
        'Der Efz-Einsichtnahmen-Endpoint konnte nicht aus der OAuth-Konfiguration abgeleitet werden.',
      );
    }

    final resources = <EfzEinsichtnahme>[];
    Uri? nextUri = _decorateRequestUri(requestUri, extraQueryParameters);

    while (nextUri != null) {
      final decoded = await _fetchPage(
        requestUri: nextUri,
        accessToken: accessToken,
      );
      final data = decoded['data'];
      if (data is! List) {
        throw const HitobitoEfzException(
          'Efz-Einsichtnahmen-Antwort enthaelt keine gueltige Datensammlung.',
        );
      }

      resources.addAll(
        data.whereType<Map<String, dynamic>>().map(_mapResource),
      );
      nextUri = _resolveNextUri(decoded, currentUri: nextUri);
    }

    return resources;
  }

  Uri _decorateRequestUri(Uri uri, Map<String, String> extraQueryParameters) {
    final queryParameters = Map<String, String>.from(uri.queryParameters);
    queryParameters['sort'] = '-issued_on';
    queryParameters.addAll(extraQueryParameters);
    return uri.replace(queryParameters: queryParameters);
  }

  Future<Map<String, dynamic>> _fetchPage({
    required Uri requestUri,
    required String accessToken,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
    await _trafficLogService?.logRequest(
      source: 'efz_einsichtnahmen',
      method: 'GET',
      uri: requestUri,
      headers: headers,
    );

    http.Response response;
    try {
      response = await _httpClient.get(requestUri, headers: headers);
    } catch (error, stackTrace) {
      await _logger?.logHttpRequest(
        source: 'hitobito_efz',
        method: 'GET',
        uri: requestUri,
        error: error,
      );
      await _trafficLogService?.logResponse(
        source: 'efz_einsichtnahmen',
        method: 'GET',
        uri: requestUri,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }

    await _logger?.logHttpRequest(
      source: 'hitobito_efz',
      method: 'GET',
      uri: requestUri,
      statusCode: response.statusCode,
    );
    await _trafficLogService?.logResponse(
      source: 'efz_einsichtnahmen',
      method: 'GET',
      uri: requestUri,
      statusCode: response.statusCode,
      headers: response.headers,
      body: response.body,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HitobitoEfzException(
        'Efz-Einsichtnahmen-Anfrage fehlgeschlagen (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const HitobitoEfzException(
        'Efz-Einsichtnahmen-Antwort hat ein ungueltiges Format.',
      );
    }
    return decoded;
  }

  EfzEinsichtnahme _mapResource(Map<String, dynamic> resource) {
    final attributes = resource['attributes'];
    final attributesMap = attributes is Map<String, dynamic>
        ? attributes
        : const <String, dynamic>{};
    final id = _toInt(resource['id']);
    final personId = _toNullableInt(attributesMap['person_id']);
    if (id <= 0 || personId == null) {
      throw const HitobitoEfzException(
        'Efz-Einsichtnahmen-Antwort enthaelt einen ungueltigen Eintrag.',
      );
    }

    return EfzEinsichtnahme(
      id: id,
      personId: personId,
      einsichtnehmerId: _toNullableInt(attributesMap['einsichtnehmer_id']),
      einsichtOn: _toDateTime(attributesMap['einsicht_on']),
      issuedOn: _toDateTime(attributesMap['issued_on']),
    );
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

  /// Laedt das persoenliche EFZ-Antragsformular (PDF) ueber den
  /// Web-Endpoint `/groups/{groupId}/people/{personId}/efz_antrag`.
  ///
  /// Dieser Endpoint ist nicht Teil der dokumentierten JSON:API, sondern
  /// derselbe, ueber den auch die NAMI-Weboberflaeche das PDF ausliefert.
  /// Wenn der Server keinen Bearer-Token akzeptiert und stattdessen ein Login
  /// erwartet, wird [HitobitoEfzAntragUnavailableException] geworfen; Aufrufer
  /// sollten dann auf einen Browser-Fallback ausweichen.
  Future<Uint8List> downloadEfzAntrag(
    String accessToken, {
    required int groupId,
    required int personId,
  }) async {
    final requestUri = config.efzAntragUri(
      groupId: groupId,
      personId: personId,
    );
    if (requestUri == null) {
      throw const HitobitoEfzAntragUnavailableException(
        'Der Efz-Antrag-Endpoint konnte nicht aus der OAuth-Konfiguration abgeleitet werden.',
      );
    }

    final headers = <String, String>{
      'Accept': 'application/pdf',
      'Authorization': 'Bearer $accessToken',
    };
    await _trafficLogService?.logRequest(
      source: 'efz_antrag',
      method: 'GET',
      uri: requestUri,
      headers: headers,
    );

    http.Response response;
    try {
      response = await _httpClient.get(requestUri, headers: headers);
    } catch (error, stackTrace) {
      await _logger?.logHttpRequest(
        source: 'hitobito_efz_antrag',
        method: 'GET',
        uri: requestUri,
        error: error,
      );
      await _trafficLogService?.logResponse(
        source: 'efz_antrag',
        method: 'GET',
        uri: requestUri,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }

    await _logger?.logHttpRequest(
      source: 'hitobito_efz_antrag',
      method: 'GET',
      uri: requestUri,
      statusCode: response.statusCode,
    );
    await _trafficLogService?.logResponse(
      source: 'efz_antrag',
      method: 'GET',
      uri: requestUri,
      statusCode: response.statusCode,
      headers: response.headers,
    );

    final contentType = response.headers['content-type'] ?? '';
    if (response.statusCode != 200 ||
        !contentType.contains('application/pdf')) {
      throw HitobitoEfzAntragUnavailableException(
        'Efz-Antrag-Anfrage lieferte kein PDF (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    return response.bodyBytes;
  }

  DateTime? _toDateTime(Object? value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  int _toInt(Object? value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int? _toNullableInt(Object? value) {
    final parsed = _toInt(value);
    if (parsed <= 0) {
      return null;
    }
    return parsed;
  }
}
