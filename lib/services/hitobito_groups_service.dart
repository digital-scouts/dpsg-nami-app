import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/arbeitskontext/hitobito_group_resource.dart';
import 'hitobito_api_exception.dart';
import 'hitobito_auth_env.dart';
import 'hitobito_pagination.dart';
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

/// Die von `_mapGroup` gelesenen Gruppenattribute. Hitobito serialisiert nur
/// angefragte Felder; ungenutzte Attribute (Adresse, Bankdaten ...) koennen so
/// weder die Antwort aufblaehen noch an fehlerhaften Datensaetzen die ganze
/// Seite scheitern lassen (z.B. eine nicht numerische `zip_code`).
const String hitobitoGroupFields =
    'name,short_name,display_name,description,layer,parent_id,'
    'layer_group_id,type,self_registration_url,'
    'self_registration_require_adult_consent,archived_at,created_at,'
    'updated_at,deleted_at';

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

    try {
      return await _fetchGroupList(
        requestUri,
        accessToken,
        query: const <String, String>{'fields[groups]': hitobitoGroupFields},
      );
    } on HitobitoGroupsException catch (error) {
      // 500 heisst hier praktisch immer: ein einzelner Datensatz der Seite
      // ist nicht serialisierbar. Statt alle Nutzer am selben Datensatz
      // scheitern zu lassen, wird um ihn herum geladen.
      if (error.statusCode != 500) {
        rethrow;
      }
      await _logger?.logWarn(
        'hitobito_groups',
        'Gruppenseite mit 500 abgelehnt, lade Gruppen in ID-Bloecken',
      );
      return _fetchGroupsInIdBlocks(requestUri, accessToken);
    }
  }

  Future<List<HitobitoGroupResource>> _fetchGroupList(
    Uri requestUri,
    String accessToken, {
    required Map<String, String> query,
  }) async {
    final resources = <HitobitoGroupResource>[];
    Uri? nextUri = requestUri;

    while (nextUri != null) {
      final effectiveRequestUri = withHitobitoListFilter(
        withHitobitoListPaging(nextUri),
        query,
      );
      final decoded = await _fetchGroupsPage(
        requestUri: effectiveRequestUri,
        accessToken: accessToken,
      );
      resources.addAll(await _mapGroups(decoded));
      nextUri = _resolveNextUri(decoded, currentUri: effectiveRequestUri);
    }

    return resources;
  }

  static const int _groupIdsPerRequest = 200;

  /// Felder, die fuer Layer-Zuordnung und Kontext mindestens noetig sind.
  static const String _minimalGroupFields =
      'name,layer,parent_id,layer_group_id,type';

  /// Rueckfall bei einer defekten Gruppenseite: alle IDs holen, in Bloecken
  /// laden und scheiternde Bloecke halbieren, bis die defekten Gruppen
  /// einzeln feststehen.
  Future<List<HitobitoGroupResource>> _fetchGroupsInIdBlocks(
    Uri requestUri,
    String accessToken,
  ) async {
    final ids = await _fetchAllGroupIds(accessToken);
    final groups = <HitobitoGroupResource>[];
    for (var start = 0; start < ids.length; start += _groupIdsPerRequest) {
      final end = start + _groupIdsPerRequest > ids.length
          ? ids.length
          : start + _groupIdsPerRequest;
      groups.addAll(
        await _fetchGroupIdBlock(
          requestUri,
          accessToken,
          ids: ids.sublist(start, end),
        ),
      );
    }
    return groups;
  }

  Future<List<HitobitoGroupResource>> _fetchGroupIdBlock(
    Uri requestUri,
    String accessToken, {
    required List<int> ids,
  }) async {
    try {
      return await _fetchGroupList(
        requestUri,
        accessToken,
        query: <String, String>{
          'filter[id]': ids.join(','),
          'fields[groups]': hitobitoGroupFields,
        },
      );
    } on HitobitoGroupsException catch (error) {
      if (error.statusCode != 500) {
        rethrow;
      }
    }

    if (ids.length == 1) {
      return _fetchGroupMinimal(requestUri, accessToken, id: ids.single);
    }
    final middle = ids.length ~/ 2;
    return <HitobitoGroupResource>[
      ...await _fetchGroupIdBlock(
        requestUri,
        accessToken,
        ids: ids.sublist(0, middle),
      ),
      ...await _fetchGroupIdBlock(
        requestUri,
        accessToken,
        ids: ids.sublist(middle),
      ),
    ];
  }

  /// Laedt eine defekte Gruppe nur mit den noetigsten Feldern. Scheitert
  /// auch das, wird sie ausgelassen.
  Future<List<HitobitoGroupResource>> _fetchGroupMinimal(
    Uri requestUri,
    String accessToken, {
    required int id,
  }) async {
    try {
      final groups = await _fetchGroupList(
        requestUri,
        accessToken,
        query: <String, String>{
          'filter[id]': '$id',
          'fields[groups]': _minimalGroupFields,
        },
      );
      await _logger?.logWarn(
        'hitobito_groups',
        'Gruppe nur mit Minimalfeldern geladen id=$id',
      );
      return groups;
    } on HitobitoGroupsException catch (error) {
      if (error.statusCode != 500) {
        rethrow;
      }
      await _logger?.logWarn(
        'hitobito_groups',
        'Gruppe nicht ladbar und ausgelassen id=$id',
      );
      return const <HitobitoGroupResource>[];
    }
  }

  /// Ungueltige Einzelgruppen werden uebersprungen, statt den ganzen Abruf
  /// scheitern zu lassen.
  Future<List<HitobitoGroupResource>> _mapGroups(
    Map<String, dynamic> decoded,
  ) async {
    final data = decoded['data'];
    if (data is! List) {
      throw const HitobitoGroupsException(
        'Groups-Antwort enthaelt keine gueltige Datensammlung.',
      );
    }

    final groups = <HitobitoGroupResource>[];
    for (final resource in data.whereType<Map<String, dynamic>>()) {
      final group = _mapGroup(resource);
      if (group == null) {
        await _logger?.logWarn(
          'hitobito_groups',
          'Ungueltige Gruppe uebersprungen id=${resource['id']}',
        );
        continue;
      }
      groups.add(group);
    }
    return groups;
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
    Uri? nextUri = base;

    while (nextUri != null) {
      final effectiveRequestUri = withHitobitoListFilter(
        withHitobitoListPaging(nextUri),
        const <String, String>{'fields[groups]': 'id'},
      );
      final decoded = await _fetchGroupsPage(
        requestUri: effectiveRequestUri,
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
      nextUri = _resolveNextUri(decoded, currentUri: effectiveRequestUri);
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

    http.Response response;
    try {
      response = await _httpClient.get(requestUri, headers: headers);
    } catch (error) {
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

  HitobitoGroupResource? _mapGroup(Map<String, dynamic> resource) {
    final attributes = resource['attributes'];
    final attributesMap = attributes is Map<String, dynamic>
        ? attributes
        : const <String, dynamic>{};

    final id = _toInt(resource['id']);
    final name = attributesMap['name']?.toString() ?? '';
    if (id <= 0 || name.isEmpty) {
      return null;
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
