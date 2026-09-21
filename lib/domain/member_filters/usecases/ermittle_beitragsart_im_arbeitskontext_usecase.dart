import '../../arbeitskontext/arbeitskontext_read_model.dart';
import '../beitragsart.dart';

class ErmittleBeitragsartImArbeitskontextUseCase {
  const ErmittleBeitragsartImArbeitskontextUseCase();

  static const _ordentlicheRoleType =
      'group::mitglieder::ordentlichemitgliedschaft';
  static const _foerderRoleType = 'group::mitglieder::foerdermitgliedschaft';
  static const _zweitRoleType = 'group::mitglieder::zweitmitgliedschaft';

  Map<String, Beitragsart> call(ArbeitskontextReadModel readModel) {
    final result = <String, Beitragsart>{};

    for (final zuordnung in readModel.mitgliedsZuordnungen) {
      if (result.containsKey(zuordnung.mitgliedsnummer)) {
        continue;
      }

      final beitragsart = _parseBeitragsart(zuordnung.rollenTyp);
      if (beitragsart == null) {
        continue;
      }

      // Die Beitragsart ist aktuell reine Anzeige und folgt deshalb der ersten
      // im Read-Model sichtbaren Mitgliedschaftsrolle.
      result[zuordnung.mitgliedsnummer] = beitragsart;
    }

    return Map<String, Beitragsart>.unmodifiable(result);
  }

  Beitragsart? _parseBeitragsart(String? rollenTyp) {
    final normalisiert = _normalisiere(rollenTyp);
    return switch (normalisiert) {
      _ordentlicheRoleType => Beitragsart.ordentlicheMitgliedschaft,
      _foerderRoleType => Beitragsart.foerdermitgliedschaft,
      _zweitRoleType => Beitragsart.zweitmitgliedschaft,
      _ => null,
    };
  }

  String _normalisiere(String? value) {
    if (value == null) {
      return '';
    }
    return value.trim().toLowerCase();
  }
}
