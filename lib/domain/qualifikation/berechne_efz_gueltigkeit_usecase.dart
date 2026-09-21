import '../member/efz_einsichtnahme.dart';
import 'qualifikationsart.dart';

/// Ergebnis der Gueltigkeitsberechnung fuer eine Person: das massgebliche
/// (neueste) [EfzEinsichtnahme]-Datum und das daraus abgeleitete
/// Gueltig-bis-Datum, oder beides `null`, wenn keine Einsichtnahme vorliegt.
class EfzGueltigkeit {
  const EfzGueltigkeit({this.issuedOn, this.gueltigBis});

  final DateTime? issuedOn;
  final DateTime? gueltigBis;
}

class BerechneEfzGueltigkeitUseCase {
  const BerechneEfzGueltigkeitUseCase();

  /// Waehlt aus [einsichtnahmen] den Eintrag mit dem neuesten `issuedOn` und
  /// berechnet daraus das Gueltig-bis-Datum (`issuedOn` + Gueltigkeitsjahre
  /// der [qualifikationsart], standardmaessig EFZ mit 5 Jahren).
  EfzGueltigkeit call(
    List<EfzEinsichtnahme> einsichtnahmen, {
    Qualifikationsart qualifikationsart = efzQualifikationsart,
  }) {
    final mitAusstellungsdatum =
        einsichtnahmen
            .where((eintrag) => eintrag.issuedOn != null)
            .toList(growable: false)
          ..sort((a, b) => b.issuedOn!.compareTo(a.issuedOn!));

    if (mitAusstellungsdatum.isEmpty) {
      return const EfzGueltigkeit();
    }

    final issuedOn = mitAusstellungsdatum.first.issuedOn!;
    final gueltigBis = DateTime(
      issuedOn.year + qualifikationsart.gueltigkeitsjahre,
      issuedOn.month,
      issuedOn.day,
    );

    return EfzGueltigkeit(issuedOn: issuedOn, gueltigBis: gueltigBis);
  }
}
