import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/arbeitskontext/hitobito_person_resource.dart';
import 'hitobito_auth_env.dart';

class HitobitoRolesException implements Exception {
  const HitobitoRolesException(this.message);

  final String message;

  @override
  String toString() => message;
}

class HitobitoRolesService {
  HitobitoRolesService({required this.config, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  HitobitoAuthConfig config;
  final http.Client _httpClient;

  void updateConfig(HitobitoAuthConfig nextConfig) {
    config = nextConfig;
  }

  Future<List<HitobitoPersonRoleResource>> fetchRoleResources(
    String accessToken, {
    bool? active,
  }) async {
    final requestUri = config.rolesUri;
    if (requestUri == null) {
      throw const HitobitoRolesException(
        'Der Roles-Endpoint konnte nicht aus der OAuth-Konfiguration abgeleitet werden.',
      );
    }

    final resources = <HitobitoPersonRoleResource>[];
    Uri? nextUri = _decorateRolesRequestUri(requestUri, active: active);

    while (nextUri != null) {
      final decoded = await _fetchRolesPage(
        requestUri: nextUri,
        accessToken: accessToken,
      );
      final data = decoded['data'];
      if (data is! List) {
        throw const HitobitoRolesException(
          'Roles-Antwort enthaelt keine gueltige Datensammlung.',
        );
      }

      resources.addAll(
        data.whereType<Map<String, dynamic>>().map(_mapRoleResource),
      );
      nextUri = _resolveNextUri(decoded, currentUri: nextUri);
    }

    return resources;
  }

  Uri _decorateRolesRequestUri(Uri uri, {bool? active}) {
    final queryParameters = Map<String, String>.from(uri.queryParameters);
    queryParameters['fields[roles]'] =
        'created_at,updated_at,start_on,end_on,name,person_id,group_id,type,label';
    if (active != null) {
      queryParameters['filter[active][eq]'] = active.toString();
    }
    return uri.replace(queryParameters: queryParameters);
  }

  Future<Map<String, dynamic>> _fetchRolesPage({
    required Uri requestUri,
    required String accessToken,
  }) async {
    final response = await _httpClient.get(
      requestUri,
      headers: <String, String>{
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HitobitoRolesException(
        'Roles-Anfrage fehlgeschlagen (${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const HitobitoRolesException(
        'Roles-Antwort hat ein ungueltiges Format.',
      );
    }
    return decoded;
  }

  HitobitoPersonRoleResource _mapRoleResource(Map<String, dynamic> resource) {
    final attributes = resource['attributes'];
    final attributesMap = attributes is Map<String, dynamic>
        ? attributes
        : const <String, dynamic>{};
    final id = _toInt(resource['id']);
    final groupId = _toNullableInt(attributesMap['group_id']);
    if (id <= 0 || groupId == null) {
      throw const HitobitoRolesException(
        'Roles-Antwort enthaelt einen ungueltigen Role-Eintrag.',
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
