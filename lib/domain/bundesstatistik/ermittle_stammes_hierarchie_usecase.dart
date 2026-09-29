import '../arbeitskontext/arbeitskontext.dart';
import '../arbeitskontext/arbeitskontext_read_model.dart';

class StammesHierarchie {
  const StammesHierarchie({required this.stammId, this.bezirkId, this.dvId});

  final String stammId;
  final String? bezirkId;
  final String? dvId;
}

/// Prueft, ob der aktive Layer ein Stamm ist, und ermittelt Bezirk und
/// Dioezese, soweit deren Layer mit Gruppentyp im Arbeitskontext bekannt sind.
/// Unbekannte Ebenen bleiben `null` statt geraten zu werden.
class ErmittleStammesHierarchieUseCase {
  const ErmittleStammesHierarchieUseCase();

  static const String _stammSuffix = '::stamm';
  static const String _bezirkSuffix = '::bezirk';
  static const String _dioezeseSuffix = '::dioezese';
  static const String _stammGruppenPrefix = 'group::stammgruppe';

  StammesHierarchie? call(ArbeitskontextReadModel readModel) {
    final arbeitskontext = readModel.arbeitskontext;
    final aktiverLayer = arbeitskontext.aktiverLayer;
    if (!_istStamm(aktiverLayer, readModel)) {
      return null;
    }

    String? bezirkId;
    String? dvId;
    final besucht = <int>{aktiverLayer.id};
    var parentId = aktiverLayer.parentLayerId;

    while (parentId != null && besucht.add(parentId)) {
      final parent = arbeitskontext.findeLayer(parentId);
      if (parent == null) {
        break;
      }
      final typ = _normalisiere(parent.layerTyp);
      if (bezirkId == null && typ.endsWith(_bezirkSuffix)) {
        bezirkId = parent.id.toString();
      } else if (typ.endsWith(_dioezeseSuffix)) {
        dvId = parent.id.toString();
        break;
      }
      parentId = parent.parentLayerId;
    }

    return StammesHierarchie(
      stammId: aktiverLayer.id.toString(),
      bezirkId: bezirkId,
      dvId: dvId,
    );
  }

  bool _istStamm(ArbeitskontextLayer layer, ArbeitskontextReadModel readModel) {
    final typ = _normalisiere(layer.layerTyp);
    if (typ.isNotEmpty) {
      return typ.endsWith(_stammSuffix);
    }
    // Zwischengespeicherte Daten ohne Layer-Typ: Stufengruppen gibt es nur in Staemmen.
    return readModel.gruppen.any(
      (gruppe) =>
          _normalisiere(gruppe.gruppenTyp).startsWith(_stammGruppenPrefix),
    );
  }

  String _normalisiere(String? value) => (value ?? '').trim().toLowerCase();
}
