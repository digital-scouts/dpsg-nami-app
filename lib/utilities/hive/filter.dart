import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:nami/utilities/hive/custom_group.dart';
import 'package:nami/utilities/mitglied.filterAndSort.dart';
import 'package:nami/utilities/stufe.dart';

enum FilterValue { listSortBy, listSubtext, customGroups }

Box get filterBox => Hive.box('filterBox');

void saveCustomGroups(Map<String, CustomGroup> groups) {
  final box = filterBox;
  box.put(FilterValue.customGroups.toString(), groups);
}

Map<String, CustomGroup> getCustomGroups() {
  final Map<dynamic, dynamic>? rawGroups =
      filterBox.get(FilterValue.customGroups.toString());

  if (rawGroups == null) {
    return {
      'Biber': CustomGroup(stufeIndex: Stufe.BIBER.index, static: true),
      'Wö': CustomGroup(stufeIndex: Stufe.WOELFLING.index, static: true),
      'Jufi': CustomGroup(stufeIndex: Stufe.JUNGPADFINDER.index, static: true),
      'Pfadi': CustomGroup(stufeIndex: Stufe.PFADFINDER.index, static: true),
      'Rover': CustomGroup(stufeIndex: Stufe.ROVER.index, static: true),
      'Leitende': CustomGroup(
        taetigkeiten: ['LeiterIn'],
        iconCodePoint: Icons.group.codePoint,
      ),
    };
  }

  return rawGroups
      .map((key, value) => MapEntry(key as String, value as CustomGroup));
}

MemberSorting getListSort() {
  String? sortingString = filterBox.get(FilterValue.listSortBy.toString());
  return MemberSorting.values.firstWhere(
    (e) => e.toString() == sortingString,
    orElse: () => MemberSorting.name,
  );
}

void setListSort(MemberSorting value) {
  filterBox.put(FilterValue.listSortBy.toString(), value.toString());
}

void setListSubtext(MemberSubElement value) {
  filterBox.put(FilterValue.listSubtext.toString(), value.toString());
}

void deleteListSort() {
  filterBox.delete(FilterValue.listSortBy.toString());
}

void deleteListSubtext() {
  filterBox.delete(FilterValue.listSubtext.toString());
}

MemberSubElement getListSubtext() {
  String? subElementString = filterBox.get(FilterValue.listSubtext.toString());
  return MemberSubElement.values.firstWhere(
    (e) => e.toString() == subElementString,
    orElse: () => MemberSubElement.id,
  );
}
