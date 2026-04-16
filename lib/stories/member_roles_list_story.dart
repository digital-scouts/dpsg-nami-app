import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

import '../domain/taetigkeit/role_derivation.dart';
import '../domain/taetigkeit/roles.dart';
import '../domain/taetigkeit/stufe.dart';
import '../presentation/widgets/member_roles_list.dart';

Story memberRolesListStory() {
  return Story(
    name: 'Mitglieder/Widgets/Rollen/Liste',
    builder: (context) {
      final knobs = context.knobs;
      final futureCount = knobs.sliderInt(
        label: 'Zukünftig',
        initial: 1,
        max: 5,
        min: 0,
      );
      final activeCount = knobs.sliderInt(
        label: 'Aktiv',
        initial: 1,
        max: 5,
        min: 0,
      );
      final pastCount = knobs.sliderInt(
        label: 'Abgeschlossen',
        initial: 1,
        max: 5,
        min: 0,
      );

      List<Role> genRoles(
        int count, {
        required Stufe stufe,
        required RoleCategory art,
        required DateTime start,
        DateTime? ende,
      }) {
        return List.generate(
          count,
          (i) => roleFromLegacy(
            stufe: stufe,
            art: art,
            start: start.add(Duration(days: i * 30)),
            ende: ende != null ? ende.add(Duration(days: i * 30)) : ende,
          ),
        );
      }

      final now = DateTime.now();
      final futureRoles = genRoles(
        futureCount,
        stufe: Stufe.pfadfinder,
        art: RoleCategory.mitglied,
        start: now.add(const Duration(days: 30)),
        ende: now.add(const Duration(days: 365)),
      );
      final activeRoles = genRoles(
        activeCount,
        stufe: Stufe.jungpfadfinder,
        art: RoleCategory.mitglied,
        start: now.subtract(const Duration(days: 200)),
        ende: null,
      );
      final pastRoles = genRoles(
        pastCount,
        stufe: Stufe.woelfling,
        art: RoleCategory.mitglied,
        start: now.subtract(const Duration(days: 600)),
        ende: now.subtract(const Duration(days: 100)),
      );

      // Empfehlung: basierend auf erster zukünftiger Tätigkeit oder Default.
      final recommendation = roleFromLegacy(
        stufe: Stufe.rover,
        art: RoleCategory.mitglied,
        start: now.add(const Duration(days: 230)),
      );

      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: MemberRolesList(
          roles: [...futureRoles, ...activeRoles, ...pastRoles],
          recommendation:
              knobs.boolean(label: 'Empfehlung anzeigen', initial: true)
              ? recommendation
              : null,
          onRecommendationRequested: (t) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Empfehlung ausgeführt: ${t.stufe.displayName}'),
              ),
            );
          },
          onDismissRequested: (t) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Dismiss: ${t.art.displayName} - ${t.stufe.displayName}',
                ),
              ),
            );
          },
        ),
      );
    },
  );
}
