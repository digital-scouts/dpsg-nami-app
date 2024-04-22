import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/stufe.dart';
import 'package:nami/utilities/hive/mitglied.dart';

///Filter bei Vor- und Name, Nummer, E-Mail
void filterByString(List<Mitglied> mitglieder, String filterString) {
  filterString = filterString.toLowerCase().trim();
  mitglieder.retainWhere((mitglied) =>
      mitglied.vorname.toLowerCase().contains(filterString) ||
      mitglied.nachname.toLowerCase().contains(filterString) ||
      (mitglied.email?.toLowerCase().contains(filterString) ?? false) ||
      (mitglied.emailVertretungsberechtigter
              ?.toLowerCase()
              .contains(filterString) ??
          false) ||
      mitglied.mitgliedsNummer.toString().contains(filterString) ||
      mitglied.id.toString().contains(filterString));
}

///Filter bei Stufe/Tätigkeit Leiter (woe, jufi, pfadi, rover, leiter)
void filterByStufe(List<Mitglied> mitglieder, List<Stufe> stufen) {
  if (stufen.isEmpty) return;
  List<String> s = stufen.map((e) => e.display).toList();
  mitglieder.removeWhere((m) =>
      !s.contains(m.stufe) &&
      !(s.contains('Leiter') &&
          (m.isMitgliedLeiter() || m.stufe == Stufe.KEINE_STUFE.display)) &&
      !(s.contains(Stufe.FAVOURITE.display) &&
          getFavouriteList().contains(m.mitgliedsNummer)));
}

///Nur aktive Mitglieder
void filterByStatus(List<Mitglied> mitglieder) {
  mitglieder.retainWhere((mitglied) => mitglied.status == 'Aktiv');
}

void sortByName(List<Mitglied> mitglieder) {
  mitglieder.sort((a, b) => a.compareByName(b));
}

void sortByLastName(List<Mitglied> mitglieder) {
  mitglieder.sort((a, b) => a.compareByLastName(b));
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

enum MemberSorting { name, lastname, age, group, memberTime }

const Map<MemberSorting, String> memberSortingValues = {
  MemberSorting.name: "Vorname",
  MemberSorting.lastname: "Nachname",
  MemberSorting.age: 'Alter',
  MemberSorting.group: "Gruppe",
  MemberSorting.memberTime: "Mitgliedsdauer",
};

enum MemberSubElement { id, birthday }

const Map<MemberSubElement, String> memberSubElementValues = {
  MemberSubElement.id: "Mitgliedsnummer",
  MemberSubElement.birthday: 'Geburtstag',
};

class FilterOptions {
  MemberSorting sorting;
  MemberSubElement subElement;
  bool disableInactive;
  String searchString;
  List<bool> filterGroup;

  FilterOptions(
      {this.sorting = MemberSorting.name,
      this.subElement = MemberSubElement.id,
      this.disableInactive = true,
      this.searchString = "",
      required this.filterGroup});

  FilterOptions copy() {
    return FilterOptions(
        sorting: sorting,
        subElement: subElement,
        disableInactive: disableInactive,
        searchString: searchString,
        filterGroup: List.from(filterGroup));
  }
}
