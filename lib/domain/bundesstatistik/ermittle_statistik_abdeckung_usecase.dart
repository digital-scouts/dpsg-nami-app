import '../arbeitskontext/arbeitskontext.dart';
import '../arbeitskontext/arbeitskontext_read_model.dart';
import '../auth/auth_profile.dart';
import '../auth/hitobito_berechtigungen.dart';
import 'statistik_abdeckung.dart';

/// Bestimmt aus den Hitobito-Rechten, ob die Person den aktiven Layer ganz
/// oder nur einzelne Gruppen lesen darf.
///
/// - `layer_read`/`layer_full` auf dem aktiven Layer oder
///   `layer_and_below_*` auf ihm oder einem Layer darueber: ganzer Stamm.
/// - `group_*` bzw. `group_and_below_*` auf Gruppen des aktiven Layers:
///   nur diese Gruppen (mit Untergruppen).
///
/// Der Layer einer Rolle wird wie bei den Schreibrechten aufgeloest: ueber
/// die bekannten Layer oder die Gruppen des aktiven Layers.
class ErmittleStatistikAbdeckungUseCase {
  const ErmittleStatistikAbdeckungUseCase();

  StatistikAbdeckung call({
    required AuthProfile profile,
    required ArbeitskontextReadModel readModel,
  }) {
    final arbeitskontext = readModel.arbeitskontext;
    final gruppenIds = <int>{};

    for (final rolle in profile.roles) {
      final rechte = HitobitoBerechtigungen.normalisiere(rolle.permissions);
      final rollenGruppe = readModel.findeGruppe(rolle.groupId);
      final rollenLayerId = arbeitskontext.enthaeltLayer(rolle.groupId)
          ? rolle.groupId
          : rollenGruppe?.layerId;

      if (rechte.any(HitobitoBerechtigungen.layerLesen.contains) &&
          rollenLayerId == arbeitskontext.aktiverLayer.id) {
        return const StatistikAbdeckung.stamm();
      }
      if (rechte.any(HitobitoBerechtigungen.layerUndDarunterLesen.contains) &&
          (rollenLayerId == null ||
              _istGleichOderDarueber(rollenLayerId, arbeitskontext))) {
        // Eine Rolle ausserhalb des aktiven Layers (z. B. im Bezirk) macht ihn
        // nur ueber layer_and_below lesbar; ihr Layer ist hier oft unbekannt.
        return const StatistikAbdeckung.stamm();
      }

      if (rollenGruppe == null) {
        continue;
      }
      if (rechte.any(HitobitoBerechtigungen.gruppeUndDarunterLesen.contains)) {
        gruppenIds.addAll(_mitUntergruppen(rollenGruppe.id, readModel));
      } else if (rechte.any(HitobitoBerechtigungen.gruppeLesen.contains)) {
        gruppenIds.add(rollenGruppe.id);
      }
    }

    return StatistikAbdeckung.gruppen(gruppenIds);
  }

  bool _istGleichOderDarueber(int layerId, Arbeitskontext arbeitskontext) {
    var aktuell = arbeitskontext.aktiverLayer;
    final besucht = <int>{};
    while (besucht.add(aktuell.id)) {
      if (aktuell.id == layerId) {
        return true;
      }
      final parentId = aktuell.parentLayerId;
      final parent = parentId == null
          ? null
          : arbeitskontext.findeLayer(parentId);
      if (parentId == layerId) {
        return true;
      }
      if (parent == null) {
        return false;
      }
      aktuell = parent;
    }
    return false;
  }

  Set<int> _mitUntergruppen(int gruppenId, ArbeitskontextReadModel readModel) {
    final ergebnis = <int>{gruppenId};
    var gewachsen = true;
    while (gewachsen) {
      gewachsen = false;
      for (final gruppe in readModel.gruppen) {
        final parentId = gruppe.parentId;
        if (parentId != null &&
            ergebnis.contains(parentId) &&
            ergebnis.add(gruppe.id)) {
          gewachsen = true;
        }
      }
    }
    return ergebnis;
  }
}
