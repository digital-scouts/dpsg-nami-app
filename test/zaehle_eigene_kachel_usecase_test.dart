import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/statistiks/zaehle_eigene_kachel_usecase.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/stories/statistik/statistik_beispiel_staemme.dart';

void main() {
  const usecase = ZaehleEigeneKachelUseCase();
  final heute = DateTime(2026, 9, 30);

  test('zählt mit derselben Auswertung wie die Mitgliederfilter', () {
    final readModel = StatistikBeispielStaemme.weitblick(heute: heute);
    final einstellungen = StatistikBeispielStaemme.einstellungenWeitblick();

    final vorstand = usecase(
      readModel,
      einstellungen.eigeneKachel('kachel-vorstand')!.filter,
    );
    expect(vorstand.anzahl, 3);

    final foerder = usecase(
      readModel,
      einstellungen.eigeneKachel('kachel-foerder')!.filter,
    );
    expect(foerder.anzahl, 6);
    expect(foerder.jeStufe, {
      Stufe.woelfling: 2,
      Stufe.jungpfadfinder: 1,
      Stufe.pfadfinder: 1,
      Stufe.rover: 2,
    });
  });

  test('Filter ohne Treffer ergibt 0 und eine leere Aufteilung', () {
    final readModel = StatistikBeispielStaemme.querfeld(heute: heute);
    final einstellungen = StatistikBeispielStaemme.einstellungenQuerfeld();

    final ohne = usecase(
      readModel,
      einstellungen.eigeneKachel('kachel-ohne')!.filter,
    );
    expect(ohne.anzahl, 0);
    expect(ohne.jeStufe, isEmpty);
  });
}
