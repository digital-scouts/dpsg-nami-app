import 'package:flutter/material.dart';
import 'package:nami/utilities/hive/custom_group.dart';
import 'package:nami/utilities/hive/filter.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/stufe.dart';

enum MemberSorting { name, lastname, age, group, memberTime }

const Map<MemberSorting, String> memberSortingValues = {
  MemberSorting.name: "Vorname",
  MemberSorting.lastname: "Nachname",
  MemberSorting.age: 'Alter',
  MemberSorting.group: "Gruppe",
  MemberSorting.memberTime: "Mitgliedsdauer",
};

enum MemberSubElement { id, birthday, spitzname }

const Map<MemberSubElement, String> memberSubElementValues = {
  MemberSubElement.id: "Mitgliedsnummer",
  MemberSubElement.birthday: 'Geburtstag',
  MemberSubElement.spitzname: 'Spitzname',
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

    // filter by Gruppe
    if (!filterOptions.filterGroup.values.toList().every(
      (gruppe) => !gruppe.active,
    )) {
      for (var gruppe in filterOptions.filterGroup.values) {
        if (!gruppe.active) continue;
        if (gruppe.orFilter) {
          filteredMitglieder.addAll(orFilterMitglieder(mitglieder, gruppe));
        } else {
          filteredMitglieder.addAll(andFilterMitglieder(mitglieder, gruppe));
        }
      }
    } else {
      // wenn keine Gruppen ausgewählt sind, dann alle Mitglieder anzeigen
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

  /// Mitglied muss mindestens einem Kriterium entsprechen
  List<Mitglied> orFilterMitglieder(
    List<Mitglied> mitglieder,
    CustomGroup gruppe,
  ) {
    List<Mitglied> filteredMitglieder = [];
    filteredMitglieder.addAll(
      filterGruppeByTaetigkeit(mitglieder, gruppe.taetigkeiten),
    );

    filteredMitglieder.addAll(filterGruppeByStufe(mitglieder, gruppe.stufe));

    if (gruppe.showInactive) {
      filteredMitglieder.addAll(filterInactive(mitglieder));
    }

    if (gruppe.showNonMembers) {
      filteredMitglieder.addAll(filterNonMembers(mitglieder));
    }
    return filteredMitglieder;
  }

  /// Mitglied muss allen kriterien entsprechen
  List<Mitglied> andFilterMitglieder(
    List<Mitglied> mitglieder,
    CustomGroup gruppe,
  ) {
    List<Mitglied> filteredMitglieder = [];

    for (var mitglied in mitglieder) {
      bool matchesAllCriteria = true;

      // Überprüfen, ob das Mitglied die Tätigkeiten erfüllt
      if (gruppe.taetigkeiten != null && gruppe.taetigkeiten!.isNotEmpty) {
        bool matchesTaetigkeit = gruppe.taetigkeiten!.every(
          (taetigkeit) => mitglied.getActiveTaetigkeiten().any(
            (activeTaetigkeit) => activeTaetigkeit.taetigkeit == taetigkeit,
          ),
        );
        if (!matchesTaetigkeit) {
          matchesAllCriteria = false;
        }
      }

      // Überprüfen, ob das Mitglied die Stufe erfüllt
      if (gruppe.stufe != null) {
        bool matchesStufe = mitglied.currentStufeWithoutLeiter == gruppe.stufe;
        if (!matchesStufe) {
          matchesAllCriteria = false;
        }
      }

      // Überprüfen, ob das Mitglied inaktiv ist
      if (gruppe.showInactive) {
        bool matchesInactive = mitglied.status == 'Inaktiv';
        if (!matchesInactive) {
          matchesAllCriteria = false;
        }
      }

      // Überprüfen, ob das Mitglied ein Nicht-Mitglied ist
      if (gruppe.showNonMembers) {
        bool matchesNonMember = mitglied.mglTypeId == 'NICHT_MITGLIED';
        if (!matchesNonMember) {
          matchesAllCriteria = false;
        }
      }

      // Wenn das Mitglied alle Kriterien erfüllt, zur Liste hinzufügen
      if (matchesAllCriteria) {
        filteredMitglieder.add(mitglied);
      }
    }

    return filteredMitglieder;
  }

  void updateSearchString(String searchString) {
    _filterOptions.searchString = searchString;
    notifyListeners();
  }

  void updateFilterGroupActive(String name, bool value) {
    _filterOptions.filterGroup[name]!.active = value;
    saveCustomGroups(_filterOptions.filterGroup);
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
    mitglieder.retainWhere(
      (mitglied) =>
          mitglied.vorname.toLowerCase().contains(filterString) ||
          mitglied.nachname.toLowerCase().contains(filterString) ||
          (mitglied.email?.toLowerCase().contains(filterString) ?? false) ||
          (mitglied.emailVertretungsberechtigter?.toLowerCase().contains(
                filterString,
              ) ??
              false) ||
          mitglied.mitgliedsNummer.toString().contains(filterString) ||
          mitglied.id.toString().contains(filterString),
    );
  }

  List<Mitglied> filterInactive(List<Mitglied> mitglieder) {
    // return List with only mitglied.status == 'Inaktiv'
    return mitglieder
        .where((mitglied) => mitglied.status == 'Inaktiv')
        .toList();
  }

  List<Mitglied> filterNonMembers(List<Mitglied> mitglieder) {
    // return List with only mitglied.mglTypeId == 'NICHT_MITGLIED'
    return mitglieder
        .where((mitglied) => mitglied.mglTypeId == 'NICHT_MITGLIED')
        .toList();
  }

  List<Mitglied> filterGruppeByStufe(
    final List<Mitglied> mitglieder,
    final Stufe? stufe,
  ) {
    if (stufe == null) {
      return List.empty();
    }
    return mitglieder
        .where((mitglied) => mitglied.currentStufeWithoutLeiter == stufe)
        .toList();
  }

  List<Mitglied> filterGruppeByTaetigkeit(
    final List<Mitglied> mitglieder,
    final List<String>? taetigkeiten,
  ) {
    if (taetigkeiten == null) {
      return List.empty();
    }

    return mitglieder
        .where(
          (mitglied) => mitglied.getActiveTaetigkeiten().any(
            (taetigkeit) => taetigkeiten.contains(taetigkeit.taetigkeit),
          ),
        )
        .toList();
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
