class ArbeitskontextLayer {
  const ArbeitskontextLayer({
    required this.id,
    required this.name,
    this.parentLayerId,
  }) : assert(id > 0),
       assert(name != '');

  final int id;
  final String name;
  final int? parentLayerId;

  bool get hatParentLayer => parentLayerId != null;

  ArbeitskontextLayer copyWith({
    int? id,
    String? name,
    int? parentLayerId,
    bool parentLayerLoeschen = false,
  }) => ArbeitskontextLayer(
    id: id ?? this.id,
    name: name ?? this.name,
    parentLayerId: parentLayerLoeschen
        ? null
        : parentLayerId ?? this.parentLayerId,
  );

  @override
  bool operator ==(Object other) {
    return other is ArbeitskontextLayer &&
        other.id == id &&
        other.name == name &&
        other.parentLayerId == parentLayerId;
  }

  @override
  int get hashCode => Object.hash(id, name, parentLayerId);

  @override
  String toString() {
    return 'ArbeitskontextLayer(id: $id, name: $name, parentLayerId: $parentLayerId)';
  }
}

/// Reiner Domain-Schnitt fuer genau einen aktiven Layer der App.
///
/// Rechte veraendern nicht den Arbeitskontext selbst, sondern spaeter nur den
/// lesbaren Bestand innerhalb dieses Layers.
class Arbeitskontext {
  Arbeitskontext({
    required this.aktiverLayer,
    Iterable<ArbeitskontextLayer> verfuegbareLayer =
        const <ArbeitskontextLayer>[],
  }) : verfuegbareLayer = List.unmodifiable(
         _normalizeVerfuegbareLayer(
           aktiverLayer: aktiverLayer,
           verfuegbareLayer: verfuegbareLayer,
         ),
       );

  static const String sichtbarkeitsRegel =
      'Rechte verkleinern nur die sichtbare Teilmenge innerhalb des Layers.';

  static const String unterlayerRegel =
      'Unterlayer gehoeren nicht automatisch zum Arbeitskontext.';

  final ArbeitskontextLayer aktiverLayer;
  final List<ArbeitskontextLayer> verfuegbareLayer;

  bool get hatVerfuegbareLayer => verfuegbareLayer.isNotEmpty;

  bool enthaeltLayer(int layerId) {
    if (aktiverLayer.id == layerId) {
      return true;
    }

    return verfuegbareLayer.any((layer) => layer.id == layerId);
  }

  ArbeitskontextLayer? findeLayer(int layerId) {
    if (aktiverLayer.id == layerId) {
      return aktiverLayer;
    }

    for (final layer in verfuegbareLayer) {
      if (layer.id == layerId) {
        return layer;
      }
    }

    return null;
  }

  Arbeitskontext copyWith({
    ArbeitskontextLayer? aktiverLayer,
    Iterable<ArbeitskontextLayer>? verfuegbareLayer,
  }) => Arbeitskontext(
    aktiverLayer: aktiverLayer ?? this.aktiverLayer,
    verfuegbareLayer: verfuegbareLayer ?? this.verfuegbareLayer,
  );

  @override
  bool operator ==(Object other) {
    return other is Arbeitskontext &&
        other.aktiverLayer == aktiverLayer &&
        _listEquals(other.verfuegbareLayer, verfuegbareLayer);
  }

  @override
  int get hashCode =>
      Object.hash(aktiverLayer, Object.hashAll(verfuegbareLayer));

  @override
  String toString() {
    return 'Arbeitskontext(aktiverLayer: $aktiverLayer, verfuegbareLayer: $verfuegbareLayer)';
  }

  static List<ArbeitskontextLayer> _normalizeVerfuegbareLayer({
    required ArbeitskontextLayer aktiverLayer,
    required Iterable<ArbeitskontextLayer> verfuegbareLayer,
  }) {
    final ids = <int>{aktiverLayer.id};
    final result = <ArbeitskontextLayer>[];

    for (final layer in verfuegbareLayer) {
      if (!ids.add(layer.id)) {
        continue;
      }
      result.add(layer);
    }

    return result;
  }

  static bool _listEquals(
    List<ArbeitskontextLayer> a,
    List<ArbeitskontextLayer> b,
  ) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) {
        return false;
      }
    }
    return true;
  }
}
