import 'package:flutter/material.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/member_filters/beitragsart.dart';
import 'package:nami/presentation/widgets/member_basis.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

import 'support/mitglied_edge_cases.dart';

Story memberDetailsStory() => Story(
  name: 'Mitglieder/Widgets/Basis/Gesamt',
  builder: (context) {
    final mitglied = context.knobs.options<Mitglied>(
      label: 'Mitglied',
      initial: MitgliedEdgeCases.mats,
      options: [
        for (final eintrag in MitgliedEdgeCases.alle.entries)
          Option(label: eintrag.key, value: eintrag.value),
      ],
    );

    return MemberDetails(
      key: ValueKey<String>(mitglied.mitgliedsnummer),
      mitglied: mitglied,
      heute: MitgliedEdgeCases.heute,
      beitragsart: Beitragsart.ordentlicheMitgliedschaft,
      stammNamen: const <String>[MitgliedEdgeCases.stamm],
      gruppenNamen: const <String>['Meute Seeonee'],
      haushalt: mitglied == MitgliedEdgeCases.mats
          ? MitgliedEdgeCases.matsHaushalt
          : const <Mitglied>[],
      onHaushaltTap: (andere) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Öffnet ${andere.fullName}'))),
    );
  },
);
