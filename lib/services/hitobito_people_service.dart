import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/arbeitskontext/hitobito_person_resource.dart';
import '../domain/member/mitglied.dart';
import 'hitobito_auth_env.dart';

class HitobitoPeopleException implements Exception {
  const HitobitoPeopleException(this.message);

  final String message;

  @override
  String toString() => message;
}

class HitobitoPeopleService {
  HitobitoPeopleService({required this.config, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final HitobitoAuthConfig config;
  final http.Client _httpClient;

  Future<List<Mitglied>> fetchPeople(String accessToken) async {
    final resources = await fetchPeopleResources(accessToken);
    return resources
        .map((resource) => resource.toMitglied())
        .toList(growable: false);
  }

  Future<List<HitobitoPersonResource>> fetchPeopleResources(
    String accessToken,
  ) async {
    final requestUri = config.peopleUri;
    if (requestUri == null) {
      throw const HitobitoPeopleException(
        'Der People-Endpoint konnte nicht aus der OAuth-Konfiguration abgeleitet werden.',
      );
    }

    final resources = <HitobitoPersonResource>[];
    Uri? nextUri = requestUri;

    while (nextUri != null) {
      final decoded = await _fetchPeoplePage(
        requestUri: nextUri,
        accessToken: accessToken,
      );
      final data = decoded['data'];
      if (data is! List) {
        throw const HitobitoPeopleException(
          'People-Antwort enthaelt keine gueltige Datensammlung.',
        );
      }

      resources.addAll(
        data.whereType<Map<String, dynamic>>().map(_mapPersonResource),
      );
      nextUri = _resolveNextUri(decoded, currentUri: nextUri);
    }

    return resources;
  }

  Future<Map<String, dynamic>> _fetchPeoplePage({
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
      throw HitobitoPeopleException(
        'People-Anfrage fehlgeschlagen (${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const HitobitoPeopleException(
        'People-Antwort hat ein ungueltiges Format.',
      );
    }
    return decoded;
  }

  HitobitoPersonResource _mapPersonResource(Map<String, dynamic> resource) {
    final attributes = resource['attributes'];
    final attributesMap = attributes is Map<String, dynamic>
        ? attributes
        : const <String, dynamic>{};

    final id = _toInt(resource['id']);
    if (id <= 0) {
      throw const HitobitoPeopleException(
        'People-Antwort enthaelt eine ungueltige Person.',
      );
    }

    return HitobitoPersonResource(
      id: id,
      firstName: attributesMap['first_name']?.toString() ?? '',
      lastName: attributesMap['last_name']?.toString() ?? '',
      nickname: attributesMap['nickname']?.toString(),
      primaryGroupId: _toNullableInt(attributesMap['primary_group_id']),
      membershipNumber: _toNullableInt(attributesMap['membership_number']),
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
