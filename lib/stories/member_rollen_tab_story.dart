import 'package:flutter/material.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/presentation/widgets/member_detail/member_rollen_tab.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

import 'support/mitglied_edge_cases.dart';

/// Rollen-Tab mit Pfadfinder-Verlauf und Zeitstrahl fuer alle Edge Cases.
Story memberRollenTabStory() => Story(
  name: 'Mitglieder/Widgets/Rollen/Tab',
  builder: (context) {
    final mitglied = context.knobs.options<Mitglied>(
      label: 'Mitglied',
      initial: MitgliedEdgeCases.funke,
      options: [
        for (final eintrag in MitgliedEdgeCases.alle.entries)
          Option(label: eintrag.key, value: eintrag.value),
      ],
    );
    final nurAktuell = context.knobs.boolean(
      label: 'Wie heute: nur aktuelle Rollen',
      initial: false,
    );
    final mitLayer = context.knobs.boolean(
      label: 'Aktiver Layer Stamm Silberfels',
      initial: true,
    );
    final nichtLesbar = context.knobs.boolean(
      label: 'Nur Leserecht: Hitobito liefert keine Rollen',
      initial: false,
    );
    final anzeige = nichtLesbar
        ? mitglied.copyWith(roles: const [])
        : nurAktuell
        ? mitglied.copyWith(
            roles: mitglied.roles
                .where(
                  (r) =>
                      r.endOn == null ||
                      r.endOn!.isAfter(MitgliedEdgeCases.heute),
                )
                .toList(),
          )
        : mitglied;

    return MemberRollenTab(
      key: ValueKey<Object>(
        Object.hash(mitglied, nurAktuell, mitLayer, nichtLesbar),
      ),
      rollenNichtLesbar: nichtLesbar,
      mitglied: anzeige,
      heute: MitgliedEdgeCases.heute,
      aktiverLayerName: mitLayer ? MitgliedEdgeCases.stamm : null,
    );
  },
);
