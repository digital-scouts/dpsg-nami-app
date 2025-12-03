import 'package:flutter/material.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/presentation/widgets/member_basis.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story memberDetailsStory() => Story(
  name: 'MemberDetails/Basis/CombinedDetails',
  builder: (context) {
    final m1 = MitgliedFactory.demo(index: 1);
    final m2 = MitgliedFactory.demo(index: 2);
    final m3 = MitgliedFactory.demo(
      index: 3,
    ).copyWith(austrittsdatum: DateTime(DateTime.now().year - 1, 1, 1));

    final mitglied = context.knobs.options<Mitglied>(
      label: 'Mitglied',
      initial: m1,
      options: [
        Option(label: 'Demo 1 (aktiv)', value: m1),
        Option(label: 'Demo 2 (aktiv)', value: m2),
        Option(label: 'Demo 3 (beendet)', value: m3),
      ],
    );

    return MemberDetails(
      mitglied: mitglied,
      onEndMembership: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('EndMembership Callback ausgelöst')),
        );
      },
    );
  },
);
