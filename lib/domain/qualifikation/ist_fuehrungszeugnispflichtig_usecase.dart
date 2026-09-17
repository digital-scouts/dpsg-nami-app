import '../member/mitglied.dart';
import '../taetigkeit/role_derivation.dart';
import '../taetigkeit/roles.dart';

/// Ermittelt, ob eine Person aufgrund ihrer aktiven Rollen grundsätzlich
/// EFZ-pflichtig ist: jede aktive Rolle, die nicht nur eine reine
/// Mitgliedschaft ist (`RoleCategory.mitglied`), zählt — also Leitung
/// (Stufenleitung, Vorstand, Kurat, Stammes-/Bezirks-/Diözesanführung, ...)
/// ebenso wie sonstige Funktionen (z.B. Zuschussbeauftragte*r), die keinem
/// der bekannten Leitungs-Schlüsselwörter entsprechen, aber ebenfalls keine
/// reine Mitgliedschaft sind (siehe `classifyRole` in `role_derivation.dart`).
///
/// Eine Person mit mehreren Rollen (z.B. Wölflings-Leitung UND
/// Rover-Mitglied) gilt bereits als pflichtig, wenn mindestens eine aktive
/// Rolle nicht `RoleCategory.mitglied` ist — eine reine "X Mitglied"-Rolle
/// allein macht dagegen nicht pflichtig.
class IstFuehrungszeugnispflichtigUseCase {
  const IstFuehrungszeugnispflichtigUseCase();

  bool call(Mitglied mitglied) {
    return mitglied.roles.any(
      (role) => role.istAktiv && role.art != RoleCategory.mitglied,
    );
  }
}
