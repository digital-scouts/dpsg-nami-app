import 'arbeitskontext.dart';

/// Abstrakter Domain-Input fuer die Bestimmung eines Startkontexts.
///
/// Der Input kennt weder HTTP noch JSON noch konkrete Hitobito-Responses.
class StartkontextInput {
  StartkontextInput({
    this.primaryGroupId,
    Iterable<ArbeitskontextLayer> verfuegbareLayer =
        const <ArbeitskontextLayer>[],
    Iterable<PrimaryGroupLayerZuordnung> groupLayerZuordnungen =
        const <PrimaryGroupLayerZuordnung>[],
  }) : verfuegbareLayer = List.unmodifiable(verfuegbareLayer),
       groupLayerZuordnungen = List.unmodifiable(groupLayerZuordnungen);

  final int? primaryGroupId;
  final List<ArbeitskontextLayer> verfuegbareLayer;
  final List<PrimaryGroupLayerZuordnung> groupLayerZuordnungen;
}

/// Beschreibt die abstrakte Aufloesung einer Gruppen-ID zu einem Layer.
class PrimaryGroupLayerZuordnung {
  const PrimaryGroupLayerZuordnung({
    required this.groupId,
    required this.layerId,
  }) : assert(groupId > 0),
       assert(layerId > 0);

  final int groupId;
  final int layerId;

  @override
  bool operator ==(Object other) {
    return other is PrimaryGroupLayerZuordnung &&
        other.groupId == groupId &&
        other.layerId == layerId;
  }

  @override
  int get hashCode => Object.hash(groupId, layerId);

  @override
  String toString() {
    return 'PrimaryGroupLayerZuordnung(groupId: $groupId, layerId: $layerId)';
  }
}
