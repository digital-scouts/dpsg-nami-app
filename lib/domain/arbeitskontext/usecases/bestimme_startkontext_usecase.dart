import '../arbeitskontext.dart';
import '../startkontext_input.dart';

class StartkontextNichtBestimmbarError implements Exception {
  const StartkontextNichtBestimmbarError(this.message);

  final String message;

  @override
  String toString() => message;
}

class BestimmeStartkontextUseCase {
  const BestimmeStartkontextUseCase();

  Arbeitskontext call(StartkontextInput input) {
    final verfuegbareLayer = _sortiereUndNormalisiereLayer(
      input.verfuegbareLayer,
    );

    if (verfuegbareLayer.isEmpty) {
      throw const StartkontextNichtBestimmbarError(
        'Es ist kein erreichbarer Layer fuer den Startkontext verfuegbar.',
      );
    }

    final bevorzugterLayer = _bestimmeBevorzugtenLayer(
      primaryGroupId: input.primaryGroupId,
      verfuegbareLayer: verfuegbareLayer,
      groupLayerZuordnungen: input.groupLayerZuordnungen,
    );

    final aktiverLayer = bevorzugterLayer ?? verfuegbareLayer.first;

    return Arbeitskontext(
      aktiverLayer: aktiverLayer,
      verfuegbareLayer: verfuegbareLayer,
    );
  }

  ArbeitskontextLayer? _bestimmeBevorzugtenLayer({
    required int? primaryGroupId,
    required List<ArbeitskontextLayer> verfuegbareLayer,
    required List<PrimaryGroupLayerZuordnung> groupLayerZuordnungen,
  }) {
    if (primaryGroupId == null) {
      return null;
    }

    for (final layer in verfuegbareLayer) {
      if (layer.id == primaryGroupId) {
        return layer;
      }
    }

    for (final zuordnung in groupLayerZuordnungen) {
      if (zuordnung.groupId != primaryGroupId) {
        continue;
      }

      for (final layer in verfuegbareLayer) {
        if (layer.id == zuordnung.layerId) {
          return layer;
        }
      }
    }

    return null;
  }

  List<ArbeitskontextLayer> _sortiereUndNormalisiereLayer(
    List<ArbeitskontextLayer> verfuegbareLayer,
  ) {
    final sortierteLayer = List<ArbeitskontextLayer>.from(verfuegbareLayer)
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
