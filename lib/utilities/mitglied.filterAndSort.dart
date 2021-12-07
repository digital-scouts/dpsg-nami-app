import 'package:nami/utilities/hive/mitglied.dart';

///Filter bei Vor- und Name, Nummer, E-Mail
void filterByString(List<Mitglied> mitglieder, String filterString) {
  filterString = filterString.toLowerCase().trim();
  mitglieder.retainWhere((mitglied) =>
      mitglied.vorname.toLowerCase().contains(filterString) ||
      mitglied.nachname.toLowerCase().contains(filterString) ||
      mitglied.email!.toLowerCase().contains(filterString) ||
      mitglied.emailVertretungsberechtigter!
          .toLowerCase()
          .contains(filterString) ||
      mitglied.mitgliedsNummer.toString().contains(filterString) ||
      mitglied.id.toString().contains(filterString));
}

///Filter bei Stufe (woe, jufi, pfadi, rover, leiter)
void filterByStufe(List<Mitglied> mitglieder, List<String> stufen) {
  mitglieder.retainWhere((mitglied) => stufen.contains(mitglied.stufe));
}

///Nur aktive Mitglieder
void filterByStatus(List<Mitglied> mitglieder) {
  mitglieder.retainWhere((mitglied) => mitglied.status == 'Aktiv');
}

void sortByName(List<Mitglied> mitglieder) {
  mitglieder.sort((a, b) => a.compareByName(b));
}

void sortByStufe(List<Mitglied> mitglieder) {
  mitglieder.sort((a, b) => a.compareByStufe(b));
}

void sortByAge(List<Mitglied> mitglieder) {
  mitglieder.sort((a, b) => a.compareByAge(b));
}

void sortByMitgliedsalter(List<Mitglied> mitglieder) {
  mitglieder.sort((a, b) => a.compareByMitgliedsalter(b));
}
