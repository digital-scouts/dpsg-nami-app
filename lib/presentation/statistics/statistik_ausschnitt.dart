import '../../domain/arbeitskontext/arbeitskontext_read_model.dart';

extension StatistikAusschnitt on ArbeitskontextReadModel {
  /// Nur die Gruppen, für die [enthalten] gilt, samt ihren Mitgliedern; z. B.
  /// für die Detailseite einer Gruppe oder die Teilsicht einer Leitung.
  ArbeitskontextReadModel nurGruppen(bool Function(int gruppenId) enthalten) {
    final gruppenIds = {
      for (final g in gruppen)
        if (enthalten(g.id)) g.id,
    };
    final mitgliedsnummern = {
      for (final z in mitgliedsZuordnungen)
        if (gruppenIds.contains(z.gruppenId)) z.mitgliedsnummer,
    };
    return copyWith(
      gruppen: gruppen.where((g) => gruppenIds.contains(g.id)),
      mitglieder: mitglieder.where(
        (m) => mitgliedsnummern.contains(m.mitgliedsnummer),
      ),
    );
  }
}
