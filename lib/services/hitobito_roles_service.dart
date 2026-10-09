import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/arbeitskontext/hitobito_person_resource.dart';
import 'hitobito_api_exception.dart';
import 'hitobito_auth_env.dart';
import 'hitobito_http_client.dart';
import 'hitobito_pagination.dart';
import 'hitobito_traffic_log_service.dart';
import 'logger_service.dart';

class HitobitoRolesException extends HitobitoApiException {
  const HitobitoRolesException(super.message, {super.statusCode});
}

class HitobitoRolesService {
  HitobitoRolesService({
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

  /// [filter] wird als zusaetzliche Query-Parameter auf jede Seite gesetzt,
  /// z.B. `{'filter[group_id]': '11,12'}`.
  Future<List<HitobitoPersonRoleResource>> fetchRoleResources(
    String accessToken, {
    Map<String, String> filter = const <String, String>{},
    void Function(List<HitobitoPersonRoleResource> loadedSoFar)? onPageLoaded,
  }) async {
    final requestUri = config.rolesUri;
    if (requestUri == null) {
      throw const HitobitoRolesException(
        'Der Roles-Endpoint konnte nicht aus der OAuth-Konfiguration abgeleitet werden.',
      );
    }

    final resources = <HitobitoPersonRoleResource>[];
    Uri? nextUri = requestUri;
    var mitGruppen = true;

    while (nextUri != null) {
      var effectiveRequestUri = withHitobitoListFilter(
        _decorateRolesRequestUri(nextUri, mitGruppen: mitGruppen),
        filter,
      );
      Map<String, dynamic> decoded;
      try {
        decoded = await _fetchRolesPage(
          requestUri: effectiveRequestUri,
          accessToken: accessToken,
        );
      } on HitobitoRolesException catch (error) {
        // Lehnt die Instanz die Gruppen-Sideloads ab, laden wir die Rollen
        // ohne Gruppennamen statt den ganzen Abruf scheitern zu lassen.
        if (!mitGruppen || error.statusCode != 400) {
          rethrow;
        }
        mitGruppen = false;
        effectiveRequestUri = withHitobitoListFilter(
          _decorateRolesRequestUri(nextUri, mitGruppen: false),
          filter,
        );
        decoded = await _fetchRolesPage(
          requestUri: effectiveRequestUri,
          accessToken: accessToken,
        );
      }
      final data = decoded['data'];
      if (data is! List) {
        throw const HitobitoRolesException(
          'Roles-Antwort enthält keine gültige Datensammlung.',
        );
      }

      final gruppenNamen = _extractIncludedGroupNames(decoded['included']);
      resources.addAll(
        data.whereType<Map<String, dynamic>>().map(
          (resource) => _mapRoleResource(resource, gruppenNamen),
        ),
      );
      onPageLoaded?.call(List.unmodifiable(resources));
      nextUri = _resolveNextUri(decoded, currentUri: effectiveRequestUri);
    }

    return resources;
  }

  Uri _decorateRolesRequestUri(Uri uri, {required bool mitGruppen}) {
    final queryParameters = Map<String, String>.from(uri.queryParameters);
    queryParameters['fields[roles]'] =
        'created_at,updated_at,start_on,end_on,name,person_id,group_id,type,label';
    if (mitGruppen) {
      queryParameters['include'] = 'group,layer_group';
      queryParameters['fields[groups]'] = 'name';
    } else {
      queryParameters.remove('include');
      queryParameters.remove('fields[groups]');
    }

    // Hitobito erwartet fuer filter[active][eq] ein Datum als Stichtag.
    // Solange die API keinen verlaesslichen Modus fuer historische oder
    // inaktive Rollen anbietet, setzen wir hier bewusst keinen Active-Filter.
    return withHitobitoListPaging(
      uri.replace(queryParameters: queryParameters),
    );
  }

  Future<Map<String, dynamic>> _fetchRolesPage({
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
        source: 'hitobito_roles',
        method: 'GET',
        uri: requestUri,
        error: error,
      );
      await _trafficLogService?.logResponse(
        source: 'roles',
        method: 'GET',
        uri: requestUri,
        error: error,
      );
      rethrow;
    }

    await _logger?.logHttpRequest(
      source: 'hitobito_roles',
      method: 'GET',
      uri: requestUri,
      statusCode: response.statusCode,
    );
    await _trafficLogService?.logResponse(
      source: 'roles',
      method: 'GET',
      uri: requestUri,
      statusCode: response.statusCode,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HitobitoRolesException(
        'Roles-Anfrage fehlgeschlagen (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const HitobitoRolesException(
        'Roles-Antwort hat ein ungültiges Format.',
      );
    }
    return decoded;
  }

  /// Liest Gruppennamen aus `included` (Typ `groups`), damit Rollen auch
  /// ausserhalb des aktiven Layers mit Gruppe und Layer angezeigt werden.
  Map<int, String> _extractIncludedGroupNames(Object? included) {
    if (included is! List) {
      return const <int, String>{};
    }
    final names = <int, String>{};
    for (final entry in included.whereType<Map<String, dynamic>>()) {
      if (entry['type']?.toString() != 'groups') {
        continue;
      }
      final id = _toNullableInt(entry['id']);
      final attributes = entry['attributes'];
      final name = attributes is Map<String, dynamic>
          ? attributes['name']?.toString().trim()
          : null;
      if (id != null && name != null && name.isNotEmpty) {
        names[id] = name;
      }
    }
    return names;
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

  HitobitoPersonRoleResource _mapRoleResource(
    Map<String, dynamic> resource,
    Map<int, String> gruppenNamen,
  ) {
    final attributes = resource['attributes'];
    final attributesMap = attributes is Map<String, dynamic>
        ? attributes
        : const <String, dynamic>{};
    final id = _toInt(resource['id']);
    final groupId = _toNullableInt(attributesMap['group_id']);
    if (id <= 0 || groupId == null) {
      throw const HitobitoRolesException(
        'Roles-Antwort enthält einen ungültigen Role-Eintrag.',
      );
    }

    return HitobitoPersonRoleResource(
      id: id,
      groupId: groupId,
      personId: _toNullableInt(attributesMap['person_id']),
      createdAt: _toDateTime(attributesMap['created_at']),
      updatedAt: _toDateTime(attributesMap['updated_at']),
      startOn: _toDateTime(attributesMap['start_on']),
      endOn: _toDateTime(attributesMap['end_on']),
      roleType: attributesMap['type']?.toString(),
      roleName: attributesMap['name']?.toString(),
      roleLabel: attributesMap['label']?.toString(),
      groupName:
          gruppenNamen[_relationshipId(resource['relationships'], 'group') ??
              groupId],
      layerName:
          gruppenNamen[_relationshipId(
            resource['relationships'],
            'layer_group',
          )],
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
