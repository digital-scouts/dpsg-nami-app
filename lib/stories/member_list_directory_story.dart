import 'package:nami/domain/member/member_list_preferences.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/presentation/widgets/member_list_directory.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story memberDirectoryStory() => Story(
  name: 'MemberList/View',
  description: 'Komplette Liste mit Suchleiste und Filterleiste.',
  builder: (context) {
    final count = context.knobs
        .slider(label: 'Anzahl Mitglieder', initial: 10, min: 0, max: 40)
        .round();
    final members = List.generate(
      count,
      (i) => MitgliedFactory.demo(index: i + 1),
    );
    final sort = context.knobs.options<MemberSortKey>(
      label: 'Sortierung',
      initial: MemberSortKey.name,
      options: [
        Option(label: 'Name', value: MemberSortKey.name),
        Option(label: 'Vorname', value: MemberSortKey.vorname),
        Option(label: 'Alter', value: MemberSortKey.age),
        Option(label: 'Stufe', value: MemberSortKey.group),
        Option(label: 'Mitgliedsdauer', value: MemberSortKey.memberTime),
      ],
    );
    final subtitle = context.knobs.options<MemberSubtitleMode>(
      label: 'Subtitle',
      initial: MemberSubtitleMode.mitgliedsnummer,
      options: [
        Option(
          label: 'Mitgliedsnummer',
          value: MemberSubtitleMode.mitgliedsnummer,
        ),
        Option(label: 'Geburtstag', value: MemberSubtitleMode.geburtstag),
        Option(label: 'Fahrtenname', value: MemberSubtitleMode.spitzname),
        Option(
          label: 'Eintrittsdatum',
          value: MemberSubtitleMode.eintrittsdatum,
        ),
      ],
    );
    final highlightSearchMatches = context.knobs.boolean(
      label: 'Suchtreffer hervorheben',
      initial: true,
    );

    return MemberDirectory(
      mitglieder: members,
      sortKey: sort,
      subtitleMode: subtitle,
      highlightSearchMatches: highlightSearchMatches,
    );
  },
);
