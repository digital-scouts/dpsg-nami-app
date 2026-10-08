import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../domain/member/efz_einsichtnahme.dart';
import 'hitobito_api_exception.dart';
import 'hitobito_auth_env.dart';
import 'hitobito_http_client.dart';
import 'hitobito_pagination.dart';
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
  }) : _httpClient = httpClient ?? HitobitoHttpClient(),
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

  /// EFZ-Einsichtnahmen, eingeschraenkt ueber [filter] (z.B.
  /// `{'filter[person_id]': '1,2,3'}`). Der Filter wird auf jede Seite
  /// gesetzt.
  Future<List<EfzEinsichtnahme>> fetchEfzEinsichtnahmen(
    String accessToken, {
    Map<String, String> filter = const <String, String>{},
  }) {
    return _fetchAll(accessToken, extraQueryParameters: filter);
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
    Uri? nextUri = requestUri;

    while (nextUri != null) {
      final effectiveRequestUri = withHitobitoListFilter(
        withHitobitoListPaging(nextUri),
        extraQueryParameters,
      );
      final decoded = await _fetchPage(
        requestUri: effectiveRequestUri,
        accessToken: accessToken,
      );
      final data = decoded['data'];
      if (data is! List) {
        throw const HitobitoEfzException(
          'Efz-Einsichtnahmen-Antwort enthaelt keine gueltige Datensammlung.',
        );
      }

      resources.addAll(
        data
            .whereType<Map<String, dynamic>>()
            .map(_mapResource)
            .whereType<EfzEinsichtnahme>(),
      );
      nextUri = _resolveNextUri(decoded, currentUri: effectiveRequestUri);
    }

    return resources;
  }

  Future<Map<String, dynamic>> _fetchPage({
    required Uri requestUri,
    required String accessToken,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    http.Response response;
    try {
      response = await _httpClient.get(requestUri, headers: headers);
    } catch (error) {
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

  /// Liefert `null` fuer unvollstaendige Eintraege, damit ein einzelner
  /// Datensatz nicht den ganzen Abruf scheitern laesst.
  EfzEinsichtnahme? _mapResource(Map<String, dynamic> resource) {
    final attributes = resource['attributes'];
    final attributesMap = attributes is Map<String, dynamic>
        ? attributes
        : const <String, dynamic>{};
    final id = _toInt(resource['id']);
    final personId =
        _toNullableInt(attributesMap['person_id']) ??
        _personIdAusRelationships(resource['relationships']);
    if (id <= 0 || personId == null || personId <= 0) {
      return null;
    }

    return EfzEinsichtnahme(
      id: id,
      personId: personId,
      einsichtnehmerId: _toNullableInt(attributesMap['einsichtnehmer_id']),
      einsichtOn: _toDateTime(attributesMap['einsicht_on']),
      issuedOn: _toDateTime(attributesMap['issued_on']),
    );
  }

  int? _personIdAusRelationships(Object? relationships) {
    if (relationships is! Map<String, dynamic>) {
      return null;
    }
    final person = relationships['person'];
    final data = person is Map<String, dynamic> ? person['data'] : null;
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

    http.Response response;
    try {
      response = await _httpClient.get(requestUri, headers: headers);
    } catch (error) {
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
    );

    if (response.statusCode == 401) {
      // Abgelaufenes oder widerrufenes Token: Das klaert der Sitzungspfad
      // (Refresh oder Neuanmeldung), nicht der Browser.
      throw const HitobitoEfzException(
        'Efz-Antrag-Anfrage nicht autorisiert (401).',
        statusCode: 401,
      );
    }

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
