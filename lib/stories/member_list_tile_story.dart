import 'package:flutter/material.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/domain/taetigkeit/taetigkeit.dart';
import 'package:storybook_flutter/storybook_flutter.dart';

import '../presentation/widgets/member_list_tile.dart';

Story memberListTileStory() => Story(
  name: 'MemberList/ListTile',
  builder: (context) {
    final now = DateTime.now();
    final isFavourite = context.knobs.boolean(
      label: 'Als Favorit markiert',
      initial: false,
    );
    final subtitleMode = context.knobs.options<MemberSubtitleMode>(
      label: 'Subtitle Mode',
      initial: MemberSubtitleMode.mitgliedsnummer,
      options: const [
        Option(
          label: 'Mitgliedsnummer',
          value: MemberSubtitleMode.mitgliedsnummer,
        ),
        Option(label: 'Geburtstag', value: MemberSubtitleMode.geburtstag),
        Option(label: 'Spitzname', value: MemberSubtitleMode.spitzname),
      ],
    );
    final mitglieder = [
      Option(
        label: 'Wölflingskind',
        value: Mitglied(
          vorname: 'Max',
          nachname: 'Mustermann',
          geburtsdatum: DateTime(now.year - 8, 5, 15),
          eintrittsdatum: DateTime(now.year - 2, 5, 15),
          mitgliedsnummer: '12345',
          taetigkeiten: [
            Taetigkeit(
              stufe: Stufe.woelfling,
              art: TaetigkeitsArt.mitglied,
              start: DateTime(now.year - 2, 5, 15),
            ),
          ],
        ),
      ),
      Option(
        label: 'Wölflingsleitung',
        value: Mitglied(
          vorname: 'Max',
          nachname: 'Mustermann',
          fahrtenname: 'Maxi',
          geburtsdatum: DateTime(now.year - 20, 5, 15),
          eintrittsdatum: DateTime(now.year - 10, 5, 15),
          mitgliedsnummer: '12345',
          taetigkeiten: [
            Taetigkeit(
              stufe: Stufe.woelfling,
              art: TaetigkeitsArt.leitung,
              start: DateTime(now.year - 1, 5, 15),
            ),
            Taetigkeit(
              stufe: Stufe.jungpfadfinder,
              art: TaetigkeitsArt.mitglied,
              start: DateTime(now.year - 8, 5, 15),
              ende: DateTime(now.year - 6, 5, 14),
            ),
            Taetigkeit(
              stufe: Stufe.woelfling,
              art: TaetigkeitsArt.mitglied,
              start: DateTime(now.year - 10, 5, 15),
              ende: DateTime(now.year - 8, 5, 14),
            ),
          ],
        ),
      ),
    ];
    final mitglied = context.knobs.options<Mitglied>(
      label: 'Mitglied',
      initial: mitglieder[0].value,
      options: mitglieder,
    );

    return MemberListTile(
      mitglied: mitglied,
      isFavourite: isFavourite,
      subtitleMode: subtitleMode,
      toggleFavorites: () async {
        debugPrint(
          'Toggled favorite for ${mitglied.vorname} ${mitglied.nachname}',
        );
      },
      onTap: () => debugPrint('NamiListTile tapped'),
    );
  },
);
