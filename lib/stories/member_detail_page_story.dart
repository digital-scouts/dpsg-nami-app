import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/presentation/screens/member_detail_page.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story memberDetailPageStory() => Story(
  name: 'Mitglieder/Screens/Detail/Uebersicht',
  builder: (context) {
    final activeMember = MitgliedFactory.demo(index: 1);
    final endedMember = MitgliedFactory.demo(
      index: 3,
    ).copyWith(austrittsdatum: DateTime(DateTime.now().year - 1, 1, 1));

    final mitglied = context.knobs.options<Mitglied>(
      label: 'Mitglied',
      initial: activeMember,
      options: [
        Option(label: 'Demo 1 (aktiv)', value: activeMember),
        Option(label: 'Demo 3 (beendet)', value: endedMember),
      ],
    );

    return MemberDetailPage(mitglied: mitglied);
  },
);
