import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/arbeitskontext/hitobito_group_resource.dart';
import 'hitobito_auth_env.dart';

class HitobitoGroupsException implements Exception {
  const HitobitoGroupsException(this.message);

  final String message;

  @override
  String toString() => message;
}

class HitobitoGroupsService {
  HitobitoGroupsService({required this.config, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final HitobitoAuthConfig config;
  final http.Client _httpClient;

  Future<List<HitobitoGroupResource>> fetchAccessibleGroups(
    String accessToken,
  ) async {
    final requestUri = config.groupsUri;
    if (requestUri == null) {
      throw const HitobitoGroupsException(
        'Der Groups-Endpoint konnte nicht aus der OAuth-Konfiguration abgeleitet werden.',
      );
    }

    final resources = <HitobitoGroupResource>[];
    Uri? nextUri = requestUri;

    while (nextUri != null) {
      final decoded = await _fetchGroupsPage(
        requestUri: nextUri,
        accessToken: accessToken,
      );
      final data = decoded['data'];
      if (data is! List) {
        throw const HitobitoGroupsException(
          'Groups-Antwort enthaelt keine gueltige Datensammlung.',
        );
      }

      resources.addAll(data.whereType<Map<String, dynamic>>().map(_mapGroup));
      nextUri = _resolveNextUri(decoded, currentUri: nextUri);
    }

    return resources;
  }

  Future<Map<String, dynamic>> _fetchGroupsPage({
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
      throw HitobitoGroupsException(
        'Groups-Anfrage fehlgeschlagen (${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const HitobitoGroupsException(
        'Groups-Antwort hat ein ungueltiges Format.',
      );
    }

    return decoded;
  }

  HitobitoGroupResource _mapGroup(Map<String, dynamic> resource) {
    final attributes = resource['attributes'];
    final attributesMap = attributes is Map<String, dynamic>
        ? attributes
        : const <String, dynamic>{};

    final id = _toInt(resource['id']);
    final name = attributesMap['name']?.toString() ?? '';
    if (id <= 0 || name.isEmpty) {
      throw const HitobitoGroupsException(
        'Groups-Antwort enthaelt eine ungueltige Gruppe.',
      );
    }

    return HitobitoGroupResource(
      id: id,
      name: name,
      isLayer: attributesMap['layer'] == true,
      parentId: _toNullableInt(attributesMap['parent_id']),
      layerGroupId: _toNullableInt(attributesMap['layer_group_id']),
    );
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
}
