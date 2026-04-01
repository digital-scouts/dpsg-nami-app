import 'package:flutter/material.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/presentation/widgets/member_basis_info_card.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story memberGeneralInfoCardStory() => Story(
  name: 'MemberDetails/Basis/Allgemeine Info',
  builder: (context) {
    final now = DateTime.now();
    final mitglieder = [
      Option(
        label: 'Wenig Infos',
        value: Mitglied(
          vorname: 'Max',
          nachname: 'Mustermann',
          geburtsdatum: DateTime(now.year - 8, 5, 15),
          eintrittsdatum: DateTime(now.year - 2, 5, 15),
          mitgliedsnummer: '12345',
          telefonnummern: const <MitgliedKontaktTelefon>[
            MitgliedKontaktTelefon(
              wert: '01234 567890',
              label: Mitglied.phoneLandlineLabel,
            ),
          ],
          emailAdressen: const <MitgliedKontaktEmail>[
            MitgliedKontaktEmail(
              wert: 'max@example.com',
              label: Mitglied.primaryEmailLabel,
              istPrimaer: true,
            ),
          ],
        ),
      ),
      Option(
        label: 'Viele Infos',
        value: Mitglied(
          vorname: 'Max',
          nachname: 'Mustermann',
          fahrtenname: 'Maxi',
          geburtsdatum: DateTime(now.year - 20, 5, 15),
          eintrittsdatum: DateTime(now.year - 10, 5, 15),
          mitgliedsnummer: '12345',
          telefonnummern: const <MitgliedKontaktTelefon>[
            MitgliedKontaktTelefon(
              wert: '01234 567890',
              label: Mitglied.phoneLandlineLabel,
            ),
            MitgliedKontaktTelefon(
              wert: '09876 543210',
              label: Mitglied.phoneMobileLabel,
            ),
            MitgliedKontaktTelefon(
              wert: '01111 222333',
              label: Mitglied.phoneBusinessLabel,
            ),
          ],
          emailAdressen: const <MitgliedKontaktEmail>[
            MitgliedKontaktEmail(
              wert: 'max.mustermann@example.com',
              label: Mitglied.primaryEmailLabel,
              istPrimaer: true,
            ),
            MitgliedKontaktEmail(
              wert: 'max2.mustermann@example.com',
              label: Mitglied.secondaryEmailLabel,
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

    return MemberGeneralInfoCard(mitglied: mitglied);
  },
);

Story memberMembershipInfoCardStory() => Story(
  name: 'MemberDetails/Basis/Mitgliedschaft Info',
  builder: (context) {
    final now = DateTime.now();
    final options = [
      Option(
        label: 'Aktiv',
        value: Mitglied(
          vorname: 'Max',
          nachname: 'Mustermann',
          geburtsdatum: DateTime(now.year - 20, 5, 15),
          eintrittsdatum: DateTime(now.year - 5, 3, 10),
          mitgliedsnummer: 'M-001',
          emailAdressen: const <MitgliedKontaktEmail>[
            MitgliedKontaktEmail(
              wert: 'max@example.com',
              label: Mitglied.primaryEmailLabel,
              istPrimaer: true,
            ),
          ],
        ),
      ),
      Option(
        label: 'Beendet',
        value: Mitglied(
          vorname: 'Max',
          nachname: 'Mustermann',
          geburtsdatum: DateTime(now.year - 20, 5, 15),
          eintrittsdatum: DateTime(now.year - 5, 3, 10),
          mitgliedsnummer: 'M-002',
        ).copyWith(austrittsdatum: DateTime(now.year - 1, 1, 1)),
      ),
    ];

    final mitglied = context.knobs.options<Mitglied>(
      label: 'Mitglied',
      initial: options[0].value,
      options: options,
    );

    return MemberMembershipInfoCard(
      mitglied: mitglied,
      onEndMembership: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mitgliedschaft beenden ausgelöst')),
        );
      },
    );
  },
);
