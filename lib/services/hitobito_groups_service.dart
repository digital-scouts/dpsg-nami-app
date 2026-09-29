import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/arbeitskontext/hitobito_group_resource.dart';
import 'hitobito_api_exception.dart';
import 'hitobito_auth_env.dart';
import 'hitobito_traffic_log_service.dart';
import 'logger_service.dart';

class HitobitoGroupsException extends HitobitoApiException {
  const HitobitoGroupsException(super.message, {super.statusCode});
}

class HitobitoBrokenGroupInfo {
  const HitobitoBrokenGroupInfo({required this.groupId, this.groupName});

  final int groupId;
  final String? groupName;
}

class HitobitoGroupsDiagnosisResult {
  const HitobitoGroupsDiagnosisResult({
    this.brokenGroups = const <HitobitoBrokenGroupInfo>[],
    this.probedGroupCount = 0,
  });

  final List<HitobitoBrokenGroupInfo> brokenGroups;
  final int probedGroupCount;

  bool get found => brokenGroups.isNotEmpty;
}

class HitobitoGroupsService {
  HitobitoGroupsService({
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

  /// Übergangs-Diagnosewerkzeug: grenzt per Teile-und-herrsche über
  /// Gruppen-ID-Bereiche ALLE Gruppen ein, deren Hitobito-Datensatz die
  /// Serialisierung von `/api/groups` zum Absturz bringt (z.B. ein
  /// nicht-numerisches `zip_code`). Wird ausschliesslich vom Debug & Tools-
  /// Screen aufgerufen.
  Future<HitobitoGroupsDiagnosisResult> diagnoseBrokenGroup(
    String accessToken,
  ) async {
    final ids = await _fetchAllGroupIds(accessToken);
    if (ids.isEmpty) {
      return const HitobitoGroupsDiagnosisResult();
    }

    final brokenIds = <int>[];
    await _collectBrokenIds(
      ids: ids,
      lo: 0,
      hi: ids.length - 1,
      accessToken: accessToken,
      brokenIds: brokenIds,
    );

    final brokenGroups = <HitobitoBrokenGroupInfo>[];
    for (final id in brokenIds) {
      final name = await _fetchGroupNameSafely(id, accessToken);
      brokenGroups.add(HitobitoBrokenGroupInfo(groupId: id, groupName: name));
    }

    return HitobitoGroupsDiagnosisResult(
      brokenGroups: brokenGroups,
      probedGroupCount: ids.length,
    );
  }

  /// Testet den ID-Teilbereich `ids[lo..hi]` als Ganzes; schlaegt er fehl,
  /// wird er rekursiv halbiert, bis einzelne defekte IDs uebrig bleiben.
  /// Findet so ALLE defekten Gruppen in einem Bereich, nicht nur die erste.
  Future<void> _collectBrokenIds({
    required List<int> ids,
    required int lo,
    required int hi,
    required String accessToken,
    required List<int> brokenIds,
  }) async {
    final rangeOk = await _probeRangeSucceeds(
      loId: ids[lo],
      hiId: ids[hi],
      accessToken: accessToken,
    );
    if (rangeOk) {
      return;
    }

    if (lo == hi) {
      brokenIds.add(ids[lo]);
      return;
    }

    final mid = lo + (hi - lo) ~/ 2;
    await _collectBrokenIds(
      ids: ids,
      lo: lo,
      hi: mid,
      accessToken: accessToken,
      brokenIds: brokenIds,
    );
    await _collectBrokenIds(
      ids: ids,
      lo: mid + 1,
      hi: hi,
      accessToken: accessToken,
      brokenIds: brokenIds,
    );
  }

  Future<List<int>> _fetchAllGroupIds(String accessToken) async {
    final base = config.groupsUri;
    if (base == null) {
      return const <int>[];
    }

    final ids = <int>[];
    Uri? nextUri = base.replace(
      queryParameters: {'fields[groups]': 'id', 'sort': 'id'},
    );

    while (nextUri != null) {
      final decoded = await _fetchGroupsPage(
        requestUri: nextUri,
        accessToken: accessToken,
      );
      final data = decoded['data'];
      if (data is List) {
        ids.addAll(
          data
              .whereType<Map<String, dynamic>>()
              .map((resource) => _toInt(resource['id']))
              .where((id) => id > 0),
        );
      }
      nextUri = _resolveNextUri(decoded, currentUri: nextUri);
    }

    ids.sort();
    return ids;
  }

  Future<bool> _probeRangeSucceeds({
    required int loId,
    required int hiId,
    required String accessToken,
  }) async {
    final base = config.groupsUri;
    if (base == null) {
      return false;
    }

    Uri? nextUri = base.replace(
      queryParameters: {'filter[id][gte]': '$loId', 'filter[id][lte]': '$hiId'},
    );

    while (nextUri != null) {
      try {
        final decoded = await _fetchGroupsPage(
          requestUri: nextUri,
          accessToken: accessToken,
        );
        nextUri = _resolveNextUri(decoded, currentUri: nextUri);
      } on HitobitoGroupsException {
        return false;
      }
    }

    return true;
  }

  Future<String?> _fetchGroupNameSafely(int id, String accessToken) async {
    final base = config.groupsUri;
    if (base == null) {
      return null;
    }

    final requestUri = base.replace(
      queryParameters: {
        'filter[id][eq]': '$id',
        'fields[groups]': 'id,name,short_name',
      },
    );

    try {
      final decoded = await _fetchGroupsPage(
        requestUri: requestUri,
        accessToken: accessToken,
      );
      final data = decoded['data'];
      if (data is List && data.isNotEmpty) {
        final first = data.first;
        if (first is Map<String, dynamic>) {
          final attributes = first['attributes'];
          if (attributes is Map<String, dynamic>) {
            return attributes['name']?.toString();
          }
        }
      }
    } on HitobitoGroupsException {
      return null;
    }

    return null;
  }

  String? _extractFailureDetail(String body) {
    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(trimmedBody);
      if (decoded is Map<String, dynamic>) {
        final errors = decoded['errors'];
        if (errors is List) {
          final details = errors
              .whereType<Map<String, dynamic>>()
              .map((error) => error['detail'] ?? error['title'])
              .whereType<String>()
              .map((detail) => detail.trim())
              .where((detail) => detail.isNotEmpty)
              .toList(growable: false);
          if (details.isNotEmpty) {
            return details.join(' | ');
          }
        }

        final detail = decoded['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail.trim();
        }
      }
    } catch (_) {
      // Fallback auf kompakten Klartext weiter unten.
    }

    if (trimmedBody.contains('<html') ||
        trimmedBody.contains('<!DOCTYPE html')) {
      return null;
    }

    return trimmedBody.replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<Map<String, dynamic>> _fetchGroupsPage({
    required Uri requestUri,
    required String accessToken,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
    await _trafficLogService?.logRequest(
      source: 'groups',
      method: 'GET',
      uri: requestUri,
      headers: headers,
    );

    http.Response response;
    try {
      response = await _httpClient.get(requestUri, headers: headers);
    } catch (error, stackTrace) {
      await _logger?.logHttpRequest(
        source: 'hitobito_groups',
        method: 'GET',
        uri: requestUri,
        error: error,
      );
      await _trafficLogService?.logResponse(
        source: 'groups',
        method: 'GET',
        uri: requestUri,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }

    await _logger?.logHttpRequest(
      source: 'hitobito_groups',
      method: 'GET',
      uri: requestUri,
      statusCode: response.statusCode,
    );
    await _trafficLogService?.logResponse(
      source: 'groups',
      method: 'GET',
      uri: requestUri,
      statusCode: response.statusCode,
      headers: response.headers,
      body: response.body,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = _extractFailureDetail(response.body);
      final message = detail == null
          ? 'Groups-Anfrage fehlgeschlagen (${response.statusCode}).'
          : 'Groups-Anfrage fehlgeschlagen (${response.statusCode}). Grund: $detail';
      throw HitobitoGroupsException(message, statusCode: response.statusCode);
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
      displayName: _trimToNull(attributesMap['display_name']?.toString()),
      shortName: _trimToNull(attributesMap['short_name']?.toString()),
      description: _trimToNull(attributesMap['description']?.toString()),
      groupType: _trimToNull(attributesMap['type']?.toString()),
      selfRegistrationUrl: _trimToNull(
        attributesMap['self_registration_url']?.toString(),
      ),
      selfRegistrationRequireAdultConsent:
          attributesMap['self_registration_require_adult_consent'] == true,
      archivedAt: _toDateTime(attributesMap['archived_at']),
      createdAt: _toDateTime(attributesMap['created_at']),
      updatedAt: _toDateTime(attributesMap['updated_at']),
      deletedAt: _toDateTime(attributesMap['deleted_at']),
    );
  }

  DateTime? _toDateTime(Object? value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return DateTime.tryParse(raw);
  }

  String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
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
