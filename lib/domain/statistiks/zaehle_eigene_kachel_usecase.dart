import '../arbeitskontext/arbeitskontext_read_model.dart';
import '../member_filters/member_custom_filter.dart';
import '../member_filters/usecases/ermittle_member_filter_treffer_usecase.dart';
import '../stufe/usecases/ermittle_stufen_im_arbeitskontext_usecase.dart';
import '../taetigkeit/stufe.dart';

class EigeneKachelZaehlung {
  const EigeneKachelZaehlung({required this.anzahl, required this.jeStufe});

  final int anzahl;

  /// Treffer je Stufe (Biber bis Rover); Personen ohne Stufe fehlen hier,
  /// Personen in mehreren Stufen zählen in jeder.
  final Map<Stufe, int> jeStufe;
}

/// Zählt die Personen, auf die der Filter einer eigenen Kachel passt – mit
/// derselben Auswertung wie die Filter der Mitgliederliste.
class ZaehleEigeneKachelUseCase {
  const ZaehleEigeneKachelUseCase();

  static const ErmittleMemberFilterTrefferUseCase _treffer =
      ErmittleMemberFilterTrefferUseCase();
  static const ErmittleStufenImArbeitskontextUseCase _stufen =
      ErmittleStufenImArbeitskontextUseCase();

  EigeneKachelZaehlung call(
    ArbeitskontextReadModel readModel,
    MemberCustomFilterGroup filter,
  ) {
    final stufenJeMitglied = _stufen(readModel);
    final treffer = _treffer(
      readModel,
      customGroups: <MemberCustomFilterGroup>[filter],
      mitgliedsStufen: stufenJeMitglied,
    );
    final jeStufe = <Stufe, int>{};
    var anzahl = 0;
    for (final eintrag in treffer.entries) {
      if (!eintrag.value.contains(filter.filterKey)) continue;
      anzahl++;
      for (final stufe in stufenJeMitglied[eintrag.key] ?? const <Stufe>{}) {
        if (stufe == Stufe.leitung) continue;
        jeStufe[stufe] = (jeStufe[stufe] ?? 0) + 1;
      }
    }
    return EigeneKachelZaehlung(
      anzahl: anzahl,
      jeStufe: Map.unmodifiable(jeStufe),
    );
  }
}
