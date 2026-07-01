import '../arbeitskontext.dart';
import '../relevante_layer_input.dart';

class BestimmeRelevanteLayerUseCase {
  const BestimmeRelevanteLayerUseCase();

  List<ArbeitskontextLayer> call(RelevanteLayerInput input) {
    final sichtbareLayer = _sortiereUndNormalisiereLayer(input.sichtbareLayer);
    if (sichtbareLayer.isEmpty || input.rollenRelevanzen.isEmpty) {
      return const <ArbeitskontextLayer>[];
    }

    final layerById = <int, ArbeitskontextLayer>{
      for (final layer in sichtbareLayer) layer.id: layer,
    };
    final relevanteIds = <int>{};

    for (final relevanz in input.rollenRelevanzen) {
      final basisLayer = layerById[relevanz.layerId];
      if (basisLayer == null) {
        continue;
      }

      relevanteIds.add(basisLayer.id);
      if (relevanz.scope != RelevanterLayerScope.layerUndUnterlayer) {
        continue;
      }

      for (final layer in sichtbareLayer) {
        if (_istUnterlayerVon(
          layer,
          ancestorId: basisLayer.id,
          layerById: layerById,
        )) {
          relevanteIds.add(layer.id);
        }
      }
    }

    return sichtbareLayer
        .where((layer) => relevanteIds.contains(layer.id))
        .toList(growable: false);
  }

  List<ArbeitskontextLayer> _sortiereUndNormalisiereLayer(
    List<ArbeitskontextLayer> sichtbareLayer,
  ) {
    final sortierteLayer = List<ArbeitskontextLayer>.from(sichtbareLayer)
      ..sort(_compareLayer);
    final ids = <int>{};
    final normalisierteLayer = <ArbeitskontextLayer>[];

    for (final layer in sortierteLayer) {
      if (!ids.add(layer.id)) {
        continue;
      }
      normalisierteLayer.add(layer);
    }

    return normalisierteLayer;
  }

  bool _istUnterlayerVon(
    ArbeitskontextLayer layer, {
    required int ancestorId,
    required Map<int, ArbeitskontextLayer> layerById,
  }) {
    final besuchteLayer = <int>{layer.id};
    var currentParentId = layer.parentLayerId;

    while (currentParentId != null) {
      if (currentParentId == ancestorId) {
        return true;
      }
      if (!besuchteLayer.add(currentParentId)) {
        return false;
      }
      currentParentId = layerById[currentParentId]?.parentLayerId;
    }

    return false;
  }

  static int _compareLayer(
    ArbeitskontextLayer left,
    ArbeitskontextLayer right,
  ) {
    final byName = left.name.toLowerCase().compareTo(right.name.toLowerCase());
    if (byName != 0) {
      return byName;
    }
    return left.id.compareTo(right.id);
  }
}
