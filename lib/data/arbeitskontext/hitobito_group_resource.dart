import '../../domain/arbeitskontext/arbeitskontext.dart';
import '../../domain/arbeitskontext/arbeitskontext_read_model.dart';
import '../../domain/arbeitskontext/startkontext_input.dart';

class HitobitoGroupResource {
  const HitobitoGroupResource({
    required this.id,
    required this.name,
    required this.isLayer,
    this.parentId,
    this.layerGroupId,
    this.displayName,
    this.shortName,
    this.description,
    this.groupType,
    this.selfRegistrationUrl,
    this.selfRegistrationRequireAdultConsent = false,
    this.archivedAt,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  }) : assert(id > 0),
       assert(name != '');

  final int id;
  final String name;
  final bool isLayer;
  final int? parentId;
  final int? layerGroupId;
  final String? displayName;
  final String? shortName;
  final String? description;
  final String? groupType;
  final String? selfRegistrationUrl;
  final bool selfRegistrationRequireAdultConsent;
  final DateTime? archivedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  ArbeitskontextLayer toArbeitskontextLayer() =>
      ArbeitskontextLayer(id: id, name: name, parentLayerId: parentId);

  PrimaryGroupLayerZuordnung? toPrimaryGroupLayerZuordnung(
    int? resolvedLayerId,
  ) {
    if (resolvedLayerId == null ||
        resolvedLayerId <= 0 ||
        resolvedLayerId == id) {
      return null;
    }

    return PrimaryGroupLayerZuordnung(groupId: id, layerId: resolvedLayerId);
  }

  ArbeitskontextGruppe? toArbeitskontextGruppe({required int aktiverLayerId}) {
    if (isLayer) {
      return null;
    }

    return ArbeitskontextGruppe(
      id: id,
      name: name,
      layerId: aktiverLayerId,
      parentId: parentId,
      displayName: displayName,
      shortName: shortName,
      description: description,
      gruppenTyp: groupType,
      selfRegistrationUrl: selfRegistrationUrl,
      selfRegistrationRequireAdultConsent: selfRegistrationRequireAdultConsent,
      archivedAt: archivedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    );
  }
}
