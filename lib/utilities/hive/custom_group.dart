import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:nami/utilities/stufe.dart';

// flutter packages pub run build_runner build
part 'custom_group.g.dart';

@HiveType(typeId: 0)
class CustomGroup {
  @HiveField(0)
  bool active;

  @HiveField(1)
  List<String>? taetigkeiten;

  @HiveField(3)
  bool showNonMembers; // Zeige auch  Mitglieder vom Typ Nichtmitglied

  @HiveField(4)
  bool showInactive; // Zeige auch Mitglieder mit Status inaktiv

  @HiveField(5)
  bool static; // default groups, that can't be deleted

  @HiveField(6)
  int? stufeIndex;

  @HiveField(7)
  bool orFilter; // true or | false and

  @HiveField(8)
  int? iconIndex;

  CustomGroup({
    this.active = false,
    this.static = false,
    this.taetigkeiten,
    this.iconIndex,
    this.showNonMembers = false,
    this.showInactive = false,
    this.orFilter = true,
    this.stufeIndex,
  });

  Stufe? get stufe => stufeIndex != null ? Stufe.values[stufeIndex!] : null;

  set stufe(Stufe? value) => stufeIndex = value?.index;

  IconData get icon => icons[iconIndex ?? 0];

  set icon(IconData value) => iconIndex = icons.indexOf(value);

  static const List<IconData> icons = [
    Icons.groups,
    Icons.diversity_1,
    Icons.group,
    Icons.person,
    Icons.manage_accounts,
    Icons.star,
    Icons.handyman,
    Icons.sos,
    Icons.school,
    Icons.home,
  ];
}
