import 'package:flutter/widgets.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/presentation/screens/member_detail_page.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

import 'support/mitglied_edge_cases.dart';

Story memberDetailPageStory() => Story(
  name: 'Mitglieder/Screens/Detail/Uebersicht',
  builder: (context) {
    final optionen = <Option<Mitglied>>[
      for (final eintrag in MitgliedEdgeCases.alle.entries)
        Option(label: eintrag.key, value: eintrag.value),
      Option(label: 'Demo 1 (Factory)', value: MitgliedFactory.demo(index: 1)),
    ];
    final mitglied = context.knobs.options<Mitglied>(
      label: 'Mitglied',
      initial: MitgliedEdgeCases.funke,
      options: optionen,
    );

    return MemberDetailPage(
      key: ValueKey<String>(mitglied.mitgliedsnummer),
      mitglied: mitglied,
      heuteProvider: () => MitgliedEdgeCases.heute,
    );
  },
);
