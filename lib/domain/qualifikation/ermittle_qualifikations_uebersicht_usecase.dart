import '../arbeitskontext/arbeitskontext_read_model.dart';
import '../member/efz_einsichtnahme.dart';
import '../member/mitglied.dart';
import 'berechne_efz_gueltigkeit_usecase.dart';
import 'ist_fuehrungszeugnispflichtig_usecase.dart';
import 'qualifikations_status.dart';
import 'qualifikationsart.dart';

/// Ein Eintrag der Qualifikationen-Uebersicht: eine Person mit ihrem Status
/// fuer eine bestimmte [Qualifikationsart].
class QualifikationsUebersichtEintrag {
  const QualifikationsUebersichtEintrag({
    required this.mitglied,
    required this.qualifikationsart,
    required this.status,
    this.issuedOn,
    this.gueltigBis,
  });

  final Mitglied mitglied;
  final Qualifikationsart qualifikationsart;
  final QualifikationsStatus status;
  final DateTime? issuedOn;
  final DateTime? gueltigBis;
}

class ErmittleQualifikationsUebersichtUseCase {
  const ErmittleQualifikationsUebersichtUseCase({
    this.istFuehrungszeugnispflichtigUseCase =
        const IstFuehrungszeugnispflichtigUseCase(),
    this.berechneEfzGueltigkeitUseCase = const BerechneEfzGueltigkeitUseCase(),
  });

  final IstFuehrungszeugnispflichtigUseCase istFuehrungszeugnispflichtigUseCase;
  final BerechneEfzGueltigkeitUseCase berechneEfzGueltigkeitUseCase;

  /// Ermittelt die Uebersichtsliste fuer [qualifikationsart] (aktuell nur
  /// EFZ) im uebergebenen Arbeitskontext.
  ///
  /// Bei einer Pflicht-Qualifikationsart werden alle Personen ausgegeben, die
  /// laut [IstFuehrungszeugnispflichtigUseCase] mindestens eine aktive Rolle
  /// jenseits reiner Mitgliedschaft haben (Leitung, Vorstand, Kurat,
  /// Zuschussbeauftragte*r, ...), auch ohne vorhandenen Eintrag (Status
  /// `fehlt`). Bei einer optionalen Qualifikationsart werden nur Personen mit
  /// einem vorhandenen Eintrag ausgegeben.
  ///
  /// Sortierung: Personen ohne gueltigen Nachweis zuerst (kein `gueltigBis`
  /// sortiert vor jedem vorhandenen Datum), danach aufsteigend nach
  /// `gueltigBis` (am dringendsten zuerst).
  List<QualifikationsUebersichtEintrag> call({
    required ArbeitskontextReadModel readModel,
    required List<EfzEinsichtnahme> einsichtnahmen,
    Qualifikationsart qualifikationsart = efzQualifikationsart,
    DateTime? heute,
  }) {
    final referenceDate = heute ?? DateTime.now();
    final einsichtnahmenByPersonId = <int, List<EfzEinsichtnahme>>{};
    for (final eintrag in einsichtnahmen) {
      einsichtnahmenByPersonId
          .putIfAbsent(eintrag.personId, () => <EfzEinsichtnahme>[])
          .add(eintrag);
    }

    final relevanteMitglieder = readModel.mitglieder.where((mitglied) {
      if (mitglied.personId == null) {
        return false;
      }
      if (qualifikationsart.istPflicht) {
        return istFuehrungszeugnispflichtigUseCase(mitglied);
      }
      return einsichtnahmenByPersonId.containsKey(mitglied.personId);
    });

    final eintraege = relevanteMitglieder
        .map((mitglied) {
          final personEinsichtnahmen =
              einsichtnahmenByPersonId[mitglied.personId] ??
              const <EfzEinsichtnahme>[];
          final gueltigkeit = berechneEfzGueltigkeitUseCase(
            personEinsichtnahmen,
            qualifikationsart: qualifikationsart,
          );
          final status = berechneStatus(
            gueltigBis: gueltigkeit.gueltigBis,
            heute: referenceDate,
          );

          return QualifikationsUebersichtEintrag(
            mitglied: mitglied,
            qualifikationsart: qualifikationsart,
            status: status,
            issuedOn: gueltigkeit.issuedOn,
            gueltigBis: gueltigkeit.gueltigBis,
          );
        })
        .toList(growable: false);

    eintraege.sort((a, b) {
      final aSortDate = a.gueltigBis ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bSortDate = b.gueltigBis ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aSortDate.compareTo(bSortDate);
    });

    return eintraege;
  }
}
