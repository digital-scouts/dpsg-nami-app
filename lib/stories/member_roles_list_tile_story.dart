import 'package:flutter/material.dart';
import 'package:nami/domain/taetigkeit/role_derivation.dart';
import 'package:nami/domain/taetigkeit/roles.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/presentation/widgets/member_roles_list_tile.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story memberRolesListTileStory() => Story(
  name: 'Mitglieder/Widgets/Rollen/ListTile',
  builder: (context) {
    final stufe = context.knobs.options<Stufe>(
      label: 'Stufe',
      initial: Stufe.pfadfinder,
      options: [
        for (final s in Stufe.values) Option(label: s.displayName, value: s),
      ],
    );
    final isLeitung = context.knobs.boolean(
      label: 'Ist Leitung',
      initial: false,
    );

    final startMonth = context.knobs
        .slider(label: 'Startmonat', initial: 6, min: 1, max: 12)
        .round();
    final hasEnd = context.knobs.boolean(label: 'Ende gesetzt', initial: false);
    final endMonth = context.knobs
        .slider(label: 'Endmonat', initial: 11, min: 1, max: 12)
        .round();
    final permission = context.knobs.text(
      label: 'Berechtigung (nur aktiv)',
      initial: isLeitung ? 'Berechtigung: Leitung' : '',
    );

    final t = roleFromLegacy(
      stufe: stufe,
      art: isLeitung ? RoleCategory.leitung : RoleCategory.mitglied,
      start: DateTime(2020, startMonth, 1),
      ende: hasEnd ? DateTime(2025, endMonth, 1) : null,
      permission: permission,
    );

    return MemberRolesListTile(
      taetigkeit: t,
      onDismissRequested: (tt) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Dismiss angefragt für ${tt.art.displayName} - ${tt.stufe.displayName}',
            ),
          ),
        );
      },
    );
  },
);
