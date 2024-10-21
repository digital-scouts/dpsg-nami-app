import 'package:flutter/material.dart';
import 'package:nami/utilities/hive/custom_group.dart';
import 'package:nami/utilities/hive/filter.dart';
import 'package:nami/utilities/hive/mitglied.dart';

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
  MemberSorting sorting = getListSort();
  MemberSubElement subElement = getListSubtext();
  String searchString = '';
  Map<String, CustomGroup> filterGroup = getCustomGroups();

  FilterOptions();
}

class MemberListSettingsHandler extends ChangeNotifier {
  static final MemberListSettingsHandler _instance =
      MemberListSettingsHandler._internal();
  final FilterOptions _filterOptions = FilterOptions();
  FilterOptions get filterOptions => _filterOptions;

  factory MemberListSettingsHandler() {
    return _instance;
  }

  MemberListSettingsHandler._internal();

  List<Mitglied> applyFilterAndSort(List<Mitglied> mitglieder) {
    List<Mitglied> filteredMitglieder = List.empty(growable: true);

// filter stufe & Tätigkeit
    if (!filterOptions.filterGroup.values
        .toList()
        .every((gruppe) => !gruppe.active)) {
      for (var gruppe in filterOptions.filterGroup.values) {
        if (!gruppe.active) continue;
        filteredMitglieder.addAll(
            filterGruppeByStufeAndTaetigkeit(List.from(mitglieder), gruppe));
      }
    } else {
      filteredMitglieder.addAll(mitglieder);
    }

    //filter suche
    if (filterOptions.searchString.isNotEmpty) {
      filterByString(filteredMitglieder, filterOptions.searchString);
    }

    //sort
    switch (filterOptions.sorting) {
      case MemberSorting.age:
        sortByAge(filteredMitglieder);
        break;
      case MemberSorting.group:
        sortByStufe(filteredMitglieder);
        break;
      case MemberSorting.name:
        sortByName(filteredMitglieder);
        break;
      case MemberSorting.lastname:
        sortByLastName(filteredMitglieder);
        break;
      case MemberSorting.memberTime:
        sortByMitgliedsalter(filteredMitglieder);
        break;
    }

    return filteredMitglieder;
  }

  void updateSearchString(String searchString) {
    _filterOptions.searchString = searchString;
    notifyListeners();
  }

  void updateFilterGroupActive(String name, bool value) {
    _filterOptions.filterGroup[name]!.active = value;
    notifyListeners();
  }

  void updateFilterGroup(String name, CustomGroup group) {
    _filterOptions.filterGroup[name] = group;
    saveCustomGroups(_filterOptions.filterGroup);
    notifyListeners();
  }

  void removeFilterGroup(String name) {
    _filterOptions.filterGroup.remove(name);
    notifyListeners();
  }

  void updateSorting(MemberSorting sorting) {
    _filterOptions.sorting = sorting;
    setListSort(sorting);
    notifyListeners();
  }

  void updateSubElement(MemberSubElement subElement) {
    _filterOptions.subElement = subElement;
    setListSubtext(subElement);
    notifyListeners();
  }

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

  void filterInactive(List<Mitglied> mitglieder) {
    mitglieder.removeWhere((mitglied) => mitglied.status == 'Inaktiv');
  }

  void filterNonMembers(List<Mitglied> mitglieder) {
    mitglieder
        .removeWhere((mitglied) => mitglied.mglTypeId == 'NICHT_MITGLIED');
  }

  List<Mitglied> filterGruppeByStufeAndTaetigkeit(
      final List<Mitglied> mitglieder, final CustomGroup gruppe) {
    List<Mitglied> filteredMitglieder = List.empty(growable: true);

    if (gruppe.stufe != null) {
      filteredMitglieder.addAll(mitglieder.where(
          (mitglied) => mitglied.currentStufeWithoutLeiter == gruppe.stufe));
    }

    if (gruppe.taetigkeiten != null) {
      filteredMitglieder.addAll(mitglieder.where((mitglied) => mitglied
          .getActiveTaetigkeiten()
          .any((taetigkeit) =>
              gruppe.taetigkeiten!.contains(taetigkeit.taetigkeit))));
    }

    if (gruppe.stufe == null && gruppe.taetigkeiten == null) {
      filteredMitglieder.addAll(mitglieder);
    }

    if (!gruppe.showInactive) {
      filterInactive(filteredMitglieder);
    }

    if (!gruppe.showNonMembers) {
      filterNonMembers(filteredMitglieder);
    }

    return filteredMitglieder;
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
}
