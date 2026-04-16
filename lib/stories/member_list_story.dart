import 'package:nami/domain/member/member_list_preferences.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/presentation/widgets/member_list.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story memberListStory() => Story(
  name: 'Mitglieder/Widgets/Liste/Uebersicht',
  builder: (context) {
    final count = context.knobs
        .slider(label: 'Anzahl Mitglieder', initial: 8, min: 0, max: 40)
        .round();
    final search = context.knobs.text(label: 'Suchstring', initial: '');
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
    final favCount = context.knobs
        .slider(label: 'Favoriten Anzahl', initial: 2, min: 0, max: 20)
        .round();
    final favourites = members
        .take(favCount)
        .map((m) => m.mitgliedsnummer)
        .toSet();

    final selectedFilterKeys = <String>{};
    for (final s in Stufe.values) {
      final active = context.knobs.boolean(
        label: 'Filter ${s.displayName}',
        initial: false,
      );
      if (active) selectedFilterKeys.add(s.name);
    }
    return MemberList(
      mitglieder: members,
      searchString: search,
      sortKey: sort,
      subtitleMode: subtitle,
      favourites: favourites,
      selectedFilterKeys: selectedFilterKeys,
    );
  },
);
