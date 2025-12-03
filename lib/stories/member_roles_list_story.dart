import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

import '../domain/taetigkeit/stufe.dart';
import '../domain/taetigkeit/taetigkeit.dart';
import '../presentation/widgets/member_roles_list.dart';

Story memberRolesListStory() {
  return Story(
    name: 'MemberDetails/Role/MemberRolesList',
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

      List<Taetigkeit> genRoles(
        int count, {
        required Stufe stufe,
        required TaetigkeitsArt art,
        required DateTime start,
        DateTime? ende,
      }) {
        return List.generate(
          count,
          (i) => Taetigkeit(
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
        art: TaetigkeitsArt.mitglied,
        start: now.add(const Duration(days: 30)),
        ende: now.add(const Duration(days: 365)),
      );
      final activeRoles = genRoles(
        activeCount,
        stufe: Stufe.jungpfadfinder,
        art: TaetigkeitsArt.mitglied,
        start: now.subtract(const Duration(days: 200)),
        ende: null,
      );
      final pastRoles = genRoles(
        pastCount,
        stufe: Stufe.woelfling,
        art: TaetigkeitsArt.mitglied,
        start: now.subtract(const Duration(days: 600)),
        ende: now.subtract(const Duration(days: 100)),
      );

      // Empfehlung: basierend auf erster zukünftiger Tätigkeit oder Default.
      final recommendation = Taetigkeit(
        stufe: Stufe.rover,
        art: TaetigkeitsArt.mitglied,
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
