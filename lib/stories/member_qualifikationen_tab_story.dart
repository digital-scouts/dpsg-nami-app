import 'package:flutter/material.dart';
import 'package:nami/domain/arbeitskontext/teildaten_stand.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/presentation/widgets/member_detail/member_qualifikationen_tab.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

import 'support/mitglied_edge_cases.dart';

/// Qualifikationen-Tab mit EFZ-Zeile in allen Ladezustaenden.
Story memberQualifikationenTabStory() => Story(
  name: 'Mitglieder/Widgets/Qualifikationen/Tab',
  builder: (context) {
    final mitglied = context.knobs.options<Mitglied>(
      label: 'Mitglied',
      initial: MitgliedEdgeCases.funke,
      options: [
        for (final eintrag in MitgliedEdgeCases.alle.entries)
          Option(label: eintrag.key, value: eintrag.value),
      ],
    );
    final efzStand = context.knobs.options<TeildatenStand>(
      label: 'EFZ-Stand',
      initial: TeildatenStand.geladen,
      options: [
        for (final stand in TeildatenStand.values)
          Option(label: stand.name, value: stand),
      ],
    );
    final qualiStand = context.knobs.options<TeildatenStand>(
      label: 'Qualifikationen-Stand',
      initial: TeildatenStand.geladen,
      options: [
        for (final stand in TeildatenStand.values)
          Option(label: stand.name, value: stand),
      ],
    );
    final vollLesbar = !context.knobs.boolean(
      label: 'Nur Leserecht (group_read, fremde Person)',
      initial: false,
    );

    return MemberQualifikationenTab(
      key: ValueKey<Object>(
        Object.hash(mitglied, efzStand, qualiStand, vollLesbar),
      ),
      vollLesbar: vollLesbar,
      mitglied: mitglied,
      heute: MitgliedEdgeCases.heute,
      efzStand: efzStand,
      efzEinsichtnahmen: MitgliedEdgeCases.efzEinsichtnahmen
          .where((e) => e.personId == mitglied.personId)
          .toList(),
      qualifikationenStand: qualiStand,
      qualifikationen: MitgliedEdgeCases.qualifikationen
          .where((q) => q.personId == mitglied.personId)
          .toList(),
    );
  },
);
