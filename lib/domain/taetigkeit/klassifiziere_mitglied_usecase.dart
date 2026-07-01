import '../arbeitskontext/arbeitskontext_read_model.dart';
import 'roles.dart';

class KlassifiziereMitgliedUseCase {
  const KlassifiziereMitgliedUseCase();

  static const _stammGroupTypes = <String>{
    'Group::StammGruppeBiber',
    'Group::StammGruppeWoelflinge',
    'Group::StammGruppeJungpfadfinder',
    'Group::StammGruppePfadfinder',
    'Group::StammGruppeRover',
  };

  RoleCategory klassifiziere(
    String mitgliedsnummer,
    ArbeitskontextReadModel readModel,
  ) {
    final gruppenById = <int, ArbeitskontextGruppe>{
      for (final gruppe in readModel.gruppen) gruppe.id: gruppe,
    };
    final assignments = readModel.findeMitgliedsZuordnungen(mitgliedsnummer);

    if (assignments.any((a) => istLeitungsrolleInStammGruppe(a, gruppenById))) {
      return RoleCategory.leitung;
    }

    if (assignments.any(
      (a) => istMitgliedsrolleInStammGruppe(a, gruppenById),
    )) {
      return RoleCategory.mitglied;
    }

    return RoleCategory.sonstiges;
  }

  bool istLeitungsrolleInStammGruppe(
    ArbeitskontextMitgliedsZuordnung assignment,
    Map<int, ArbeitskontextGruppe> gruppenById,
  ) {
    if (!istInStammGruppe(assignment, gruppenById)) {
      return false;
    }

    return _isLeaderRoleText(assignment);
  }

  bool istMitgliedsrolleInStammGruppe(
    ArbeitskontextMitgliedsZuordnung assignment,
    Map<int, ArbeitskontextGruppe> gruppenById,
  ) {
    if (!istInStammGruppe(assignment, gruppenById)) {
      return false;
    }

    return !_isLeaderRoleText(assignment);
  }

  bool istInStammGruppe(
    ArbeitskontextMitgliedsZuordnung assignment,
    Map<int, ArbeitskontextGruppe> gruppenById,
  ) {
    final gruppe = gruppenById[assignment.gruppenId];
    if (gruppe == null) return false;
    return _stammGroupTypes.contains(gruppe.gruppenTyp);
  }

  bool _isLeaderRoleText(ArbeitskontextMitgliedsZuordnung assignment) {
    final roleText =
        '${assignment.rollenTyp ?? ''} ${assignment.rollenLabel ?? ''}'
            .trim()
            .toLowerCase();
    return roleText.contains('leitung') ||
        roleText.contains('hilfsleitung') ||
        roleText.contains('leiter') ||
        roleText.contains('hilfsleiter');
  }
}
