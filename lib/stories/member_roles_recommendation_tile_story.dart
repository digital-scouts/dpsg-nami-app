import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

import '../domain/taetigkeit/role_derivation.dart';
import '../domain/taetigkeit/roles.dart';
import '../domain/taetigkeit/stufe.dart';
import '../presentation/widgets/member_roles_list_tile.dart';

Story memberRolesRecommendationTileStory() {
  return Story(
    name: 'MemberDetails/Role/MemberRolesListTileRecommendation',
    builder: (context) {
      final knobs = context.knobs;
      final stufe = knobs.options(
        label: 'Stufe',
        initial: Stufe.pfadfinder,
        options: [
          Option(label: 'Wölfling', value: Stufe.woelfling),
          Option(label: 'Jungpfadfinder', value: Stufe.jungpfadfinder),
          Option(label: 'Pfadfinder', value: Stufe.pfadfinder),
          Option(label: 'Rover', value: Stufe.rover),
        ],
      );
      final monthsAhead = knobs.sliderInt(
        label: 'Monate bis Wechsel',
        initial: 1,
        min: 0,
        max: 12,
      );

      final now = DateTime.now();
      final taetigkeit = roleFromLegacy(
        stufe: stufe,
        art: RoleCategory.mitglied,
        start: now.add(Duration(days: 30 * monthsAhead)),
      );

      return MemberRolesRecommendationListTile(
        taetigkeit: taetigkeit,
        onActionRequested: (t) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Wechsel ausgelöst: ${t.stufe.displayName}'),
            ),
          );
        },
      );
    },
  );
}
