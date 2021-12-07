import 'package:flutter/material.dart';
import 'package:nami/utilities/constants.dart';
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
void filterByStufe(List<Mitglied> mitglieder, List<Stufe> stufen) {
  if (stufen.isEmpty) return;
  List<String> s = stufen.map((e) => e.string()).toList();
  mitglieder.removeWhere((m) => !s.contains(m.stufe));
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

enum MemberSorting { name, age, group, memberTime }
const memberSortingNameString = "Name";
const memberSortingAgeString = 'Alter';
const memberSortingGroupString = "Gruppe";
const memberSortingMemberTimeString = "Mitgliedsdauer";

extension MemberSortingExtension on MemberSorting {
  String string() {
    switch (this) {
      case MemberSorting.name:
        return memberSortingNameString;
      case MemberSorting.group:
        return memberSortingGroupString;
      case MemberSorting.memberTime:
        return memberSortingMemberTimeString;
      case MemberSorting.age:
      default:
        return memberSortingAgeString;
    }
  }

  static MemberSorting getValue(String? value) {
    switch (value) {
      case memberSortingAgeString:
        return MemberSorting.age;
      case memberSortingGroupString:
        return MemberSorting.group;
      case memberSortingMemberTimeString:
        return MemberSorting.memberTime;
      case memberSortingNameString:
      default:
        return MemberSorting.name;
    }
  }
}
