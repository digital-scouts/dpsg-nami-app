import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

import '../domain/taetigkeit/role_derivation.dart';
import '../domain/taetigkeit/roles.dart';
import '../domain/taetigkeit/stufe.dart';
import '../presentation/widgets/member_roles_statistik_pie.dart';

final DateTime _storybookNow = DateTime(2025, 10, 1);

Story memberRolesPieNurMitgliedStory() {
  return Story(
    name: 'MemberDetails/StatistikPie/NurMitglied',
    builder: (context) {
      final size = context.knobs
          .sliderInt(label: 'Größe', initial: 180, min: 120, max: 300)
          .toDouble();
      final roles = [
        roleFromLegacy(
          stufe: Stufe.woelfling,
          art: RoleCategory.mitglied,
          start: _storybookNow.subtract(const Duration(days: 900)),
          ende: _storybookNow.subtract(const Duration(days: 600)),
        ),
        roleFromLegacy(
          stufe: Stufe.jungpfadfinder,
          art: RoleCategory.mitglied,
          start: _storybookNow.subtract(const Duration(days: 500)),
          ende: _storybookNow.subtract(const Duration(days: 300)),
        ),
      ];
      return Center(
        child: MemberRolesStatistikPie(roles: roles, size: size),
      );
    },
  );
}

Story memberRolesPieNurLeitungStory() {
  return Story(
    name: 'MemberDetails/StatistikPie/NurLeitung',
    builder: (context) {
      final size = context.knobs
          .sliderInt(label: 'Größe', initial: 180, min: 120, max: 300)
          .toDouble();
      final roles = [
        roleFromLegacy(
          stufe: Stufe.rover,
          art: RoleCategory.leitung,
          start: _storybookNow.subtract(const Duration(days: 800)),
          ende: _storybookNow.subtract(const Duration(days: 400)),
        ),
        roleFromLegacy(
          stufe: Stufe.pfadfinder,
          art: RoleCategory.leitung,
          start: _storybookNow.subtract(const Duration(days: 350)),
          ende: _storybookNow.subtract(const Duration(days: 100)),
        ),
      ];
      return Center(
        child: MemberRolesStatistikPie(roles: roles, size: size),
      );
    },
  );
}

Story memberRolesPieMitgliedUndLeitungStory() {
  return Story(
    name: 'MemberDetails/StatistikPie/MitgliedUndLeitung',
    builder: (context) {
      final size = context.knobs
          .sliderInt(label: 'Größe', initial: 180, min: 120, max: 300)
          .toDouble();
      final roles = [
        roleFromLegacy(
          stufe: Stufe.pfadfinder,
          art: RoleCategory.mitglied,
          start: _storybookNow.subtract(const Duration(days: 900)),
          ende: _storybookNow.subtract(const Duration(days: 600)),
        ),
        roleFromLegacy(
          stufe: Stufe.rover,
          art: RoleCategory.leitung,
          start: _storybookNow.subtract(const Duration(days: 500)),
          ende: _storybookNow.subtract(const Duration(days: 200)),
        ),
      ];
      return Center(
        child: MemberRolesStatistikPie(roles: roles, size: size),
      );
    },
  );
}

Story memberRolesPieNurEineStufeStory() {
  return Story(
    name: 'MemberDetails/StatistikPie/NurEineStufe',
    description: 'Einfarbig -> leerer Container',
    builder: (context) {
      final size = context.knobs
          .sliderInt(label: 'Größe', initial: 180, min: 120, max: 300)
          .toDouble();
      final roles = [
        roleFromLegacy(
          stufe: Stufe.woelfling,
          art: RoleCategory.mitglied,
          start: _storybookNow.subtract(const Duration(days: 400)),
          ende: _storybookNow.subtract(const Duration(days: 200)),
        ),
        roleFromLegacy(
          stufe: Stufe.woelfling,
          art: RoleCategory.leitung,
          start: _storybookNow.subtract(const Duration(days: 180)),
          ende: _storybookNow.subtract(const Duration(days: 60)),
        ),
      ];
      return Center(
        child: MemberRolesStatistikPie(roles: roles, size: size),
      );
    },
  );
}

Story memberRolesPieMaxStory() {
  return Story(
    name: 'MemberDetails/StatistikPie/Maximal',
    builder: (context) {
      final size = context.knobs
          .sliderInt(label: 'Größe', initial: 180, min: 120, max: 300)
          .toDouble();
      final roles = <Role>[];
      final stufen = [
        Stufe.biber,
        Stufe.woelfling,
        Stufe.jungpfadfinder,
        Stufe.pfadfinder,
        Stufe.rover,
      ];
      int offset = 2000;
      for (final s in stufen) {
        roles.add(
          roleFromLegacy(
            stufe: s,
            art: RoleCategory.mitglied,
            start: _storybookNow.subtract(Duration(days: offset)),
            ende: _storybookNow.subtract(Duration(days: offset - 100)),
          ),
        );
        offset -= 150;
        roles.add(
          roleFromLegacy(
            stufe: s,
            art: RoleCategory.leitung,
            start: _storybookNow.subtract(Duration(days: offset)),
            ende: _storybookNow.subtract(Duration(days: offset - 100)),
          ),
        );
        offset -= 150;
      }
      roles.add(
        roleFromLegacy(
          stufe: Stufe.leitung,
          art: RoleCategory.sonstiges,
          start: _storybookNow.subtract(const Duration(days: 150)),
          ende: _storybookNow.subtract(const Duration(days: 100)),
        ),
      );
      return Center(
        child: MemberRolesStatistikPie(roles: roles, size: size),
      );
    },
  );
}

Story memberRolesPieUeberlappStory() {
  return Story(
    name: 'MemberDetails/StatistikPie/Ueberlapp',
    description: 'Überlappende Zeiten, neuere Tätigkeit zählt im Overlap',
    builder: (context) {
      final size = context.knobs
          .sliderInt(label: 'Größe', initial: 180, min: 120, max: 300)
          .toDouble();
      final roles = [
        roleFromLegacy(
          stufe: Stufe.pfadfinder,
          art: RoleCategory.mitglied,
          start: DateTime(2022, 1, 1),
          ende: DateTime(2023, 12, 31),
        ),
        roleFromLegacy(
          stufe: Stufe.rover,
          art: RoleCategory.leitung,
          start: DateTime(2023, 6, 1),
          ende: DateTime(2024, 6, 1),
        ),
      ];
      return Center(
        child: MemberRolesStatistikPie(roles: roles, size: size),
      );
    },
  );
}
