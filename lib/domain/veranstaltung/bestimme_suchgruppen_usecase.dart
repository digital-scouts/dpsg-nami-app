import '../arbeitskontext/arbeitskontext_read_model.dart';
import 'veranstaltungs_filter.dart';

/// Gruppen-IDs fuer `filter[group_id]` je Ebenen-Filter. Die API kennt
/// keinen rekursiven Filter; deshalb stehen hier alle Gruppen der gewaehlten
/// Ebenen. `null` bedeutet: ohne Gruppenfilter, also alles Sichtbare.
class BestimmeSuchgruppenUseCase {
  const BestimmeSuchgruppenUseCase();

  Set<int>? call(ArbeitskontextReadModel? readModel, EbenenFilter ebene) {
    if (ebene == EbenenFilter.alle || readModel == null) {
      return null;
    }
    final arbeitskontext = readModel.arbeitskontext;
    final aktiverLayer = arbeitskontext.aktiverLayer;
    final ids = <int>{
      aktiverLayer.id,
      for (final gruppe in readModel.gruppen) gruppe.id,
    };
    if (ebene == EbenenFilter.meinStammUndDarueber) {
      ids.addAll(readModel.uebergeordneteGruppenIds);
      // Die Layer-Gruppen darueber selbst, auch wenn ihre Untergruppen nicht
      // lesbar sind: Kurse haengen meist direkt am Bezirk oder an der
      // Dioezese.
      final layerById = {
        for (final layer in arbeitskontext.verfuegbareLayer) layer.id: layer,
      };
      final besucht = <int>{aktiverLayer.id};
      var parentId =
          layerById[aktiverLayer.id]?.parentLayerId ??
          aktiverLayer.parentLayerId;
      while (parentId != null && besucht.add(parentId)) {
        ids.add(parentId);
        parentId = layerById[parentId]?.parentLayerId;
      }
    }
    return ids;
  }
}
