import 'arbeitskontext.dart';

enum RelevanterLayerScope { exactLayer, layerUndUnterlayer }

class RollenRelevanzZuLayer {
  const RollenRelevanzZuLayer({required this.layerId, required this.scope})
    : assert(layerId > 0);

  final int layerId;
  final RelevanterLayerScope scope;

  @override
  bool operator ==(Object other) {
    return other is RollenRelevanzZuLayer &&
        other.layerId == layerId &&
        other.scope == scope;
  }

  @override
  int get hashCode => Object.hash(layerId, scope);
}

class RelevanteLayerInput {
  RelevanteLayerInput({
    Iterable<ArbeitskontextLayer> sichtbareLayer =
        const <ArbeitskontextLayer>[],
    Iterable<RollenRelevanzZuLayer> rollenRelevanzen =
        const <RollenRelevanzZuLayer>[],
  }) : sichtbareLayer = List.unmodifiable(sichtbareLayer),
       rollenRelevanzen = List.unmodifiable(rollenRelevanzen);

  final List<ArbeitskontextLayer> sichtbareLayer;
  final List<RollenRelevanzZuLayer> rollenRelevanzen;
}
