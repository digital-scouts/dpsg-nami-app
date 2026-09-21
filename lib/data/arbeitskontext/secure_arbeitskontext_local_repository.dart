import 'dart:convert';

import '../../domain/arbeitskontext/arbeitskontext.dart';
import '../../domain/arbeitskontext/arbeitskontext_local_repository.dart';
import '../../domain/arbeitskontext/arbeitskontext_read_model.dart';
import '../../domain/member/mitglied.dart';
import '../../services/sensitive_storage_service.dart';

class SecureArbeitskontextLocalRepository
    implements ArbeitskontextLocalRepository {
  SecureArbeitskontextLocalRepository({
    required SensitiveStorageService sensitiveStorageService,
  }) : _sensitiveStorageService = sensitiveStorageService;

  static const String _boxName = 'hitobito_arbeitskontext_box';
  static const String _cacheKey = 'arbeitskontext_read_model_v1';

  final SensitiveStorageService _sensitiveStorageService;

  @override
  Future<void> clearCached() async {
    final box = await _sensitiveStorageService.openEncryptedStringBox(_boxName);
    await box.delete(_cacheKey);
  }

  @override
  Future<ArbeitskontextReadModel?> loadLastCached() async {
    final box = await _sensitiveStorageService.openEncryptedStringBox(_boxName);
    final raw = box.get(_cacheKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    return _readModelFromJson(decoded);
  }

  @override
  Future<void> saveCached(ArbeitskontextReadModel readModel) async {
    final box = await _sensitiveStorageService.openEncryptedStringBox(_boxName);
    await box.put(_cacheKey, jsonEncode(_readModelToJson(readModel)));
  }

  Map<String, dynamic> _readModelToJson(ArbeitskontextReadModel readModel) {
    return <String, dynamic>{
      'arbeitskontext': <String, dynamic>{
        'aktiver_layer': _layerToJson(readModel.arbeitskontext.aktiverLayer),
        'verfuegbare_layer': readModel.arbeitskontext.verfuegbareLayer
            .map(_layerToJson)
            .toList(growable: false),
      },
      'roles_sind_geladen': readModel.rolesSindGeladen,
      'mitglieder': readModel.mitglieder
          .map((mitglied) => mitglied.toPeopleListJson())
          .toList(growable: false),
      'gruppen': readModel.gruppen.map(_gruppeToJson).toList(growable: false),
      'mitglieds_zuordnungen': readModel.mitgliedsZuordnungen
          .map(_mitgliedsZuordnungToJson)
          .toList(growable: false),
    };
  }

  ArbeitskontextReadModel? _readModelFromJson(Map<String, dynamic> json) {
    final arbeitskontextJson = json['arbeitskontext'];
    if (arbeitskontextJson is! Map<String, dynamic>) {
      return null;
    }

    final aktiverLayerJson = arbeitskontextJson['aktiver_layer'];
    if (aktiverLayerJson is! Map<String, dynamic>) {
      return null;
    }

    final aktiverLayer = _layerFromJson(aktiverLayerJson);
    if (aktiverLayer == null) {
      return null;
    }

    final verfuegbareLayerJson = arbeitskontextJson['verfuegbare_layer'];
    final verfuegbareLayer = verfuegbareLayerJson is List
        ? verfuegbareLayerJson
              .whereType<Map<String, dynamic>>()
              .map(_layerFromJson)
              .whereType<ArbeitskontextLayer>()
              .toList(growable: false)
        : const <ArbeitskontextLayer>[];

    final mitgliederJson = json['mitglieder'];
    final mitglieder = mitgliederJson is List
        ? mitgliederJson
              .whereType<Map<String, dynamic>>()
              .map(Mitglied.fromPeopleListJson)
              .toList(growable: false)
        : const <Mitglied>[];

    final gruppenJson = json['gruppen'];
    final gruppen = gruppenJson is List
        ? gruppenJson
              .whereType<Map<String, dynamic>>()
              .map(_gruppeFromJson)
              .whereType<ArbeitskontextGruppe>()
              .toList(growable: false)
        : const <ArbeitskontextGruppe>[];

    final mitgliedsZuordnungenJson = json['mitglieds_zuordnungen'];
    final mitgliedsZuordnungen = mitgliedsZuordnungenJson is List
        ? mitgliedsZuordnungenJson
              .whereType<Map<String, dynamic>>()
              .map(_mitgliedsZuordnungFromJson)
              .whereType<ArbeitskontextMitgliedsZuordnung>()
              .toList(growable: false)
        : const <ArbeitskontextMitgliedsZuordnung>[];

    return ArbeitskontextReadModel(
      arbeitskontext: Arbeitskontext(
        aktiverLayer: aktiverLayer,
        verfuegbareLayer: verfuegbareLayer,
      ),
      rolesSindGeladen: json['roles_sind_geladen'] == true,
      mitglieder: mitglieder,
      gruppen: gruppen,
      mitgliedsZuordnungen: mitgliedsZuordnungen,
    );
  }

  Map<String, dynamic> _layerToJson(ArbeitskontextLayer layer) {
    return <String, dynamic>{
      'id': layer.id,
      'name': layer.name,
      'parent_layer_id': layer.parentLayerId,
    };
  }

  ArbeitskontextLayer? _layerFromJson(Map<String, dynamic> json) {
    final id = _toInt(json['id']);
    final name = json['name']?.toString() ?? '';
    if (id <= 0 || name.isEmpty) {
      return null;
    }

    return ArbeitskontextLayer(
      id: id,
      name: name,
      parentLayerId: _toNullableInt(json['parent_layer_id']),
    );
  }

  Map<String, dynamic> _gruppeToJson(ArbeitskontextGruppe gruppe) {
    return <String, dynamic>{
      'id': gruppe.id,
      'name': gruppe.name,
      'layer_id': gruppe.layerId,
      'parent_id': gruppe.parentId,
      'display_name': gruppe.displayName,
      'short_name': gruppe.shortName,
      'description': gruppe.description,
      'gruppen_typ': gruppe.gruppenTyp,
      'self_registration_url': gruppe.selfRegistrationUrl,
      'self_registration_require_adult_consent':
          gruppe.selfRegistrationRequireAdultConsent,
      'archived_at': gruppe.archivedAt?.toIso8601String(),
      'created_at': gruppe.createdAt?.toIso8601String(),
      'updated_at': gruppe.updatedAt?.toIso8601String(),
      'deleted_at': gruppe.deletedAt?.toIso8601String(),
    };
  }

  ArbeitskontextGruppe? _gruppeFromJson(Map<String, dynamic> json) {
    final id = _toInt(json['id']);
    final name = json['name']?.toString() ?? '';
    final layerId = _toInt(json['layer_id']);
    if (id <= 0 || layerId <= 0 || name.isEmpty) {
      return null;
    }

    return ArbeitskontextGruppe(
      id: id,
      name: name,
      layerId: layerId,
      parentId: _toNullableInt(json['parent_id']),
      displayName: _trimToNull(json['display_name']?.toString()),
      shortName: _trimToNull(json['short_name']?.toString()),
      description: _trimToNull(json['description']?.toString()),
      gruppenTyp: _trimToNull(json['gruppen_typ']?.toString()),
      selfRegistrationUrl: _trimToNull(
        json['self_registration_url']?.toString(),
      ),
      selfRegistrationRequireAdultConsent:
          json['self_registration_require_adult_consent'] == true,
      archivedAt: _toDateTime(json['archived_at']),
      createdAt: _toDateTime(json['created_at']),
      updatedAt: _toDateTime(json['updated_at']),
      deletedAt: _toDateTime(json['deleted_at']),
    );
  }

  Map<String, dynamic> _mitgliedsZuordnungToJson(
    ArbeitskontextMitgliedsZuordnung zuordnung,
  ) {
    return <String, dynamic>{
      'mitgliedsnummer': zuordnung.mitgliedsnummer,
      'gruppen_id': zuordnung.gruppenId,
      'rollen_typ': zuordnung.rollenTyp,
      'rollen_label': zuordnung.rollenLabel,
    };
  }

  ArbeitskontextMitgliedsZuordnung? _mitgliedsZuordnungFromJson(
    Map<String, dynamic> json,
  ) {
    final mitgliedsnummer = json['mitgliedsnummer']?.toString() ?? '';
    final gruppenId = _toInt(json['gruppen_id']);
    if (mitgliedsnummer.isEmpty || gruppenId <= 0) {
      return null;
    }

    return ArbeitskontextMitgliedsZuordnung(
      mitgliedsnummer: mitgliedsnummer,
      gruppenId: gruppenId,
      rollenTyp: json['rollen_typ']?.toString(),
      rollenLabel: json['rollen_label']?.toString(),
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
}
