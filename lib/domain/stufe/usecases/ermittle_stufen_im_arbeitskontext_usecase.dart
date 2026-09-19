import '../../arbeitskontext/arbeitskontext_read_model.dart';
import '../../taetigkeit/stufe.dart';
import '../arbeitskontext_stufen_mapping.dart';

class ErmittleStufenImArbeitskontextUseCase {
  const ErmittleStufenImArbeitskontextUseCase();

  Map<String, Set<Stufe>> call(ArbeitskontextReadModel readModel) {
    final result = <String, Set<Stufe>>{};

    for (final zuordnung in readModel.mitgliedsZuordnungen) {
      final gruppe = readModel.findeGruppe(zuordnung.gruppenId);
      if (gruppe == null) {
        continue;
      }

      for (final regel in ArbeitskontextStufenMapping.regeln) {
        if (!regel.passtZu(gruppenTyp: gruppe.gruppenTyp)) {
          continue;
        }

        result
            .putIfAbsent(zuordnung.mitgliedsnummer, () => <Stufe>{})
            .add(regel.stufe);
      }
    }

    return Map<String, Set<Stufe>>.unmodifiable(
      result.map(
        (mitgliedsnummer, stufen) =>
            MapEntry(mitgliedsnummer, Set<Stufe>.unmodifiable(stufen)),
      ),
    );
  }
}
