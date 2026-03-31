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
  }) : assert(id > 0),
       assert(name != '');

  final int id;
  final String name;
  final bool isLayer;
  final int? parentId;
  final int? layerGroupId;

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

    return ArbeitskontextGruppe(id: id, name: name, layerId: aktiverLayerId);
  }
}
