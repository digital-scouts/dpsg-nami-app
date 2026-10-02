import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/arbeitskontext/teildaten_stand.dart';
import 'package:nami/domain/member/efz_einsichtnahme.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/qualifikation/qualifikation.dart';
import 'package:nami/domain/taetigkeit/roles.dart';

/// Gemeinsame Testdaten der Qualifikationen-Uebersicht; Stichtag fest.
final qualiHeute = DateTime(2026, 10, 2);

const praeventionId = 14;
const ersteHilfeId = 9;
const woodbadgeId = 3;

Mitglied qualiMitglied(
  String nummer,
  int personId,
  List<Role> rollen, {
  DateTime? geburtsdatum,
  String? fahrtenname,
}) {
  return Mitglied(
    vorname: 'Person$nummer',
    nachname: 'Test',
    fahrtenname: fahrtenname,
    mitgliedsnummer: nummer,
    geburtsdatum: geburtsdatum ?? DateTime(2000, 1, 1),
    eintrittsdatum: DateTime(2010, 1, 1),
    personId: personId,
    roles: rollen,
  );
}

Role leitung(String stufe) => Role(type: 'Group::StammGruppe$stufe::Leiter');
Role mitgliedRolle(String stufe) =>
    Role(type: 'Group::StammGruppe$stufe::Mitglied');
Role amt(String label) => Role(type: 'Group::Stamm::$label', label: label);

Qualifikation quali(
  int id,
  int personId,
  int artId,
  String label, {
  DateTime? finishAt,
  int? gueltigkeitJahre,
  bool reaktivierbar = false,
}) => Qualifikation(
  id: id,
  personId: personId,
  artId: artId,
  label: label,
  finishAt: finishAt,
  gueltigkeitJahre: gueltigkeitJahre,
  reaktivierbar: reaktivierbar,
);

ArbeitskontextReadModel qualiReadModel({
  required List<Mitglied> mitglieder,
  List<EfzEinsichtnahme> efz = const <EfzEinsichtnahme>[],
  List<Qualifikation> qualifikationen = const <Qualifikation>[],
  TeildatenStand efzStand = TeildatenStand.geladen,
}) {
  return ArbeitskontextReadModel(
    arbeitskontext: Arbeitskontext(
      aktiverLayer: const ArbeitskontextLayer(id: 11, name: 'Stamm Test'),
      verfuegbareLayer: const <ArbeitskontextLayer>[],
    ),
    mitglieder: mitglieder,
    efzStand: efzStand,
    efzEinsichtnahmen: efz,
    qualifikationenStand: TeildatenStand.geladen,
    qualifikationen: qualifikationen,
  );
}
