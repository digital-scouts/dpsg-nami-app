import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/model/member_edit_model.dart';
import 'package:nami/presentation/screens/member_edit_page.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story memberEditFormWithBankStory() => Story(
  name: 'Mitglieder/Screens/Bearbeiten/Formular/MitBankverbindung',
  builder: (context) => _MemberEditFormStoryShell(
    mitglied: _baseMember().copyWith(
      detailsLesbar: true,
      bankAccountOwner: 'Julia Keller',
      iban: 'DE02120300000000202051',
      bic: 'BYLADEM1001',
      bankName: 'Testbank',
      paymentMethod: 'debit',
    ),
  ),
);

Story memberEditFormWithoutDetailsStory() => Story(
  name: 'Mitglieder/Screens/Bearbeiten/Formular/OhneDetailrechte',
  builder: (context) => _MemberEditFormStoryShell(
    mitglied: _baseMember().copyWith(
      detailsLesbar: false,
      geburtsdatum: Mitglied.peoplePlaceholderDate,
      genderLoeschen: true,
    ),
  ),
);

class _MemberEditFormStoryShell extends StatelessWidget {
  const _MemberEditFormStoryShell({required this.mitglied});

  final Mitglied mitglied;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthSessionModel?>.value(value: null),
        Provider<MemberEditModel?>.value(value: null),
      ],
      child: MaterialApp(
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de'), Locale('en')],
        locale: const Locale('de'),
        home: MemberEditPage(mitglied: mitglied),
      ),
    );
  }
}

Mitglied _baseMember() {
  return Mitglied(
    personId: 23,
    mitgliedsnummer: '4711',
    vorname: 'Julia',
    nachname: 'Keller',
    fahrtenname: 'Jule',
    pronoun: 'sie/ihr',
    gender: 'w',
    geburtsdatum: DateTime(2012, 5, 4),
    eintrittsdatum: DateTime(2020, 1, 1),
    updatedAt: DateTime(2026, 4, 14, 12, 0),
    emailAdressen: const <MitgliedKontaktEmail>[
      MitgliedKontaktEmail(
        wert: 'julia@example.org',
        label: Mitglied.primaryEmailLabel,
        istPrimaer: true,
      ),
    ],
    telefonnummern: const <MitgliedKontaktTelefon>[
      MitgliedKontaktTelefon(
        phoneNumberId: 1,
        wert: '+491701234567',
        label: 'Mobil',
        istOeffentlich: true,
      ),
    ],
    adressen: const <MitgliedKontaktAdresse>[
      MitgliedKontaktAdresse(
        additionalAddressId: 0,
        street: 'Musterweg',
        housenumber: '5',
        zipCode: '50667',
        town: 'Köln',
        country: 'DE',
      ),
    ],
  );
}
