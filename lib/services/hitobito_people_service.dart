import 'dart:convert';

import 'package:http/http.dart' as http;

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
    final requestUri = config.peopleUri;
    if (requestUri == null) {
      throw const HitobitoPeopleException(
        'Der People-Endpoint konnte nicht aus der OAuth-Konfiguration abgeleitet werden.',
      );
    }

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

    final data = decoded['data'];
    if (data is! List) {
      throw const HitobitoPeopleException(
        'People-Antwort enthaelt keine gueltige Datensammlung.',
      );
    }

    return data.whereType<Map<String, dynamic>>().map(_mapPerson).toList();
  }

  Mitglied _mapPerson(Map<String, dynamic> resource) {
    final attributes = resource['attributes'];
    final attributesMap = attributes is Map<String, dynamic>
        ? attributes
        : const <String, dynamic>{};

    final fallbackId = resource['id']?.toString() ?? '';
    final membershipNumber = attributesMap['membership_number']?.toString();
    final memberId = membershipNumber != null && membershipNumber.isNotEmpty
        ? membershipNumber
        : fallbackId;

    return Mitglied.peopleListItem(
      mitgliedsnummer: memberId,
      vorname: attributesMap['first_name']?.toString() ?? '',
      nachname: attributesMap['last_name']?.toString() ?? '',
      fahrtenname: attributesMap['nickname']?.toString(),
    );
  }
}
