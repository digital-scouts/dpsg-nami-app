import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nami/domain/member/member_resolution.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/member/pending_person_update.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/model/member_edit_model.dart';
import 'package:nami/presentation/screens/member_edit_page.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story memberEditResolutionServerConflictStory() => Story(
  name: 'Mitglieder/Screens/Bearbeiten/Problemlosung/Serverkonflikt',
  builder: (context) =>
      _MemberResolutionStoryShell(pendingEntry: _buildServerConflictEntry()),
);

Story memberEditResolutionServerValidationStory() => Story(
  name: 'Mitglieder/Screens/Bearbeiten/Problemlosung/Servervalidierung',
  builder: (context) =>
      _MemberResolutionStoryShell(pendingEntry: _buildServerValidationEntry()),
);

Story memberEditResolutionMixedFieldsStory() => Story(
  name: 'Mitglieder/Screens/Bearbeiten/Problemlosung/GemischteFelder',
  builder: (context) =>
      _MemberResolutionStoryShell(pendingEntry: _buildMixedFieldsEntry()),
);

class _MemberResolutionStoryShell extends StatelessWidget {
  const _MemberResolutionStoryShell({required this.pendingEntry});

  final PendingPersonUpdate pendingEntry;

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
        home: MemberEditPage(
          mitglied: pendingEntry.zielMitglied,
          pendingEntry: pendingEntry,
        ),
      ),
    );
  }
}

PendingPersonUpdate _buildServerConflictEntry() {
  final basisMitglied = _buildBaseMember();
  final zielMitglied = basisMitglied.copyWith(
    vorname: 'Juliane',
    telefonnummern: const <MitgliedKontaktTelefon>[
      MitgliedKontaktTelefon(
        phoneNumberId: 1,
        wert: '+49 171 9999991',
        label: Mitglied.phoneMobileLabel,
      ),
      MitgliedKontaktTelefon(
        phoneNumberId: 2,
        wert: '+49 221 555123',
        label: Mitglied.phoneBusinessLabel,
      ),
    ],
  );
  final remoteMitglied = basisMitglied.copyWith(
    vorname: 'Jule',
    telefonnummern: const <MitgliedKontaktTelefon>[
      MitgliedKontaktTelefon(
        phoneNumberId: 1,
        wert: '+49 171 1111111',
        label: Mitglied.phoneLandlineLabel,
      ),
      MitgliedKontaktTelefon(
        phoneNumberId: 2,
        wert: '+49 221 555123',
        label: Mitglied.phoneBusinessLabel,
      ),
    ],
    updatedAt: DateTime(2026, 4, 16, 9, 30),
  );

  return _buildPendingEntry(
    basisMitglied: basisMitglied,
    zielMitglied: zielMitglied,
    remoteMitglied: remoteMitglied,
    items: const <MemberResolutionItem>[
      MemberResolutionItem(
        problemType: MemberResolutionProblemType.conflict,
        cause: MemberResolutionCause.overlappingChange,
        target: MemberResolutionTarget(
          type: MemberResolutionTargetType.firstName,
        ),
        message:
            'Vorname wurde lokal und auf dem Server unterschiedlich geaendert.',
      ),
      MemberResolutionItem(
        problemType: MemberResolutionProblemType.conflict,
        cause: MemberResolutionCause.overlappingChange,
        target: MemberResolutionTarget(
          type: MemberResolutionTargetType.phone,
          relationshipId: 1,
        ),
        message:
            'Telefonnummer wurde lokal und auf dem Server unterschiedlich geaendert.',
      ),
    ],
  );
}

PendingPersonUpdate _buildServerValidationEntry() {
  final basisMitglied = _buildBaseMember();
  final zielMitglied = basisMitglied.copyWith(
    emailAdressen: const <MitgliedKontaktEmail>[
      MitgliedKontaktEmail(
        wert: 'julia.keller@',
        label: Mitglied.primaryEmailLabel,
        istPrimaer: true,
      ),
      MitgliedKontaktEmail(
        additionalEmailId: 2,
        wert: 'lager@example.org',
        label: 'Lager',
      ),
    ],
    adressen: const <MitgliedKontaktAdresse>[
      MitgliedKontaktAdresse(
        additionalAddressId: 0,
        street: 'Musterweg',
        housenumber: '5',
        zipCode: '50667',
        town: 'Koeln',
        country: 'Deutschland',
      ),
      MitgliedKontaktAdresse(
        additionalAddressId: 8,
        label: 'Lager',
        street: 'Ohneweg',
        housenumber: '99',
        zipCode: '99999',
        town: 'Unbekannt',
        country: 'Deutschland',
      ),
    ],
  );

  return _buildPendingEntry(
    basisMitglied: basisMitglied,
    zielMitglied: zielMitglied,
    remoteMitglied: basisMitglied,
    items: const <MemberResolutionItem>[
      MemberResolutionItem(
        problemType: MemberResolutionProblemType.validation,
        cause: MemberResolutionCause.serverValidation,
        target: MemberResolutionTarget(
          type: MemberResolutionTargetType.primaryEmail,
        ),
        message: 'Die primaere E-Mail-Adresse wurde vom Server abgelehnt.',
      ),
      MemberResolutionItem(
        problemType: MemberResolutionProblemType.validation,
        cause: MemberResolutionCause.serverValidation,
        target: MemberResolutionTarget(
          type: MemberResolutionTargetType.additionalAddress,
          relationshipId: 8,
        ),
        message:
            'Die Zusatzadresse konnte serverseitig nicht validiert werden.',
      ),
    ],
  );
}

PendingPersonUpdate _buildMixedFieldsEntry() {
  final basisMitglied = _buildBaseMember();
  final zielMitglied = basisMitglied.copyWith(
    telefonnummern: const <MitgliedKontaktTelefon>[
      MitgliedKontaktTelefon(
        phoneNumberId: 1,
        wert: '+49 171 12',
        label: Mitglied.phoneMobileLabel,
      ),
      MitgliedKontaktTelefon(
        phoneNumberId: 2,
        wert: '+49 221 555123',
        label: Mitglied.phoneBusinessLabel,
      ),
    ],
    emailAdressen: const <MitgliedKontaktEmail>[
      MitgliedKontaktEmail(
        wert: 'julia.keller@example.org',
        label: Mitglied.primaryEmailLabel,
        istPrimaer: true,
      ),
      MitgliedKontaktEmail(
        additionalEmailId: 2,
        wert: 'fahrt@example.org',
        label: 'Fahrt',
      ),
    ],
    adressen: const <MitgliedKontaktAdresse>[
      MitgliedKontaktAdresse(
        additionalAddressId: 0,
        addressCareOf: 'Stammheim',
        street: 'Musterweg',
        housenumber: '7',
        zipCode: '50667',
        town: 'Koeln',
        country: 'Deutschland',
      ),
      MitgliedKontaktAdresse(
        additionalAddressId: 8,
        label: 'Lager',
        street: 'Waldpfad',
        housenumber: '3',
        zipCode: '50999',
        town: 'Koeln',
        country: 'Deutschland',
      ),
    ],
  );
  final remoteMitglied = basisMitglied.copyWith(
    emailAdressen: const <MitgliedKontaktEmail>[
      MitgliedKontaktEmail(
        wert: 'julia.keller@example.org',
        label: Mitglied.primaryEmailLabel,
        istPrimaer: true,
      ),
      MitgliedKontaktEmail(
        additionalEmailId: 2,
        wert: 'stamm@example.org',
        label: 'Stamm',
      ),
    ],
    updatedAt: DateTime(2026, 4, 16, 10, 15),
  );

  return _buildPendingEntry(
    basisMitglied: basisMitglied,
    zielMitglied: zielMitglied,
    remoteMitglied: remoteMitglied,
    items: const <MemberResolutionItem>[
      MemberResolutionItem(
        problemType: MemberResolutionProblemType.conflict,
        cause: MemberResolutionCause.overlappingChange,
        target: MemberResolutionTarget(
          type: MemberResolutionTargetType.additionalEmail,
          relationshipId: 2,
        ),
        message:
            'Zusatz-E-Mail wurde lokal und auf dem Server unterschiedlich geaendert.',
      ),
      MemberResolutionItem(
        problemType: MemberResolutionProblemType.validation,
        cause: MemberResolutionCause.serverValidation,
        target: MemberResolutionTarget(
          type: MemberResolutionTargetType.phone,
          relationshipId: 1,
        ),
        message: 'Die Telefonnummer ist im Serverformat ungueltig.',
      ),
      MemberResolutionItem(
        problemType: MemberResolutionProblemType.validation,
        cause: MemberResolutionCause.addressValidation,
        target: MemberResolutionTarget(
          type: MemberResolutionTargetType.primaryAddress,
        ),
        message: 'Die Hauptadresse ist fachlich nicht plausibel.',
      ),
    ],
  );
}

PendingPersonUpdate _buildPendingEntry({
  required Mitglied basisMitglied,
  required Mitglied zielMitglied,
  required Mitglied remoteMitglied,
  required List<MemberResolutionItem> items,
}) {
  return PendingPersonUpdate(
    entryId: 'story-${zielMitglied.personId}',
    personId: zielMitglied.personId!,
    mitgliedsnummer: zielMitglied.mitgliedsnummer,
    displayName: zielMitglied.fullName,
    basisMitglied: basisMitglied,
    zielMitglied: zielMitglied,
    queuedAt: DateTime(2026, 4, 16, 11, 0),
    status: PendingPersonUpdateStatus.needsResolution,
    resolutionCase: MemberResolutionCase(
      remoteMitglied: remoteMitglied,
      items: items,
      source: MemberResolutionSource.pendingRetry,
    ),
  );
}

Mitglied _buildBaseMember() {
  return MitgliedFactory.demo(index: 7).copyWith(
    personId: 23,
    primaryGroupId: 111,
    mitgliedsnummer: '4711',
    vorname: 'Julia',
    nachname: 'Keller',
    gender: 'w',
    updatedAt: DateTime(2026, 4, 15, 18, 0),
    telefonnummern: const <MitgliedKontaktTelefon>[
      MitgliedKontaktTelefon(
        phoneNumberId: 1,
        wert: '+49 171 5551111',
        label: Mitglied.phoneMobileLabel,
      ),
      MitgliedKontaktTelefon(
        phoneNumberId: 2,
        wert: '+49 221 555123',
        label: Mitglied.phoneBusinessLabel,
      ),
    ],
    emailAdressen: const <MitgliedKontaktEmail>[
      MitgliedKontaktEmail(
        wert: 'julia.keller@example.org',
        label: Mitglied.primaryEmailLabel,
        istPrimaer: true,
      ),
      MitgliedKontaktEmail(
        additionalEmailId: 2,
        wert: 'stamm@example.org',
        label: 'Stamm',
      ),
    ],
    adressen: const <MitgliedKontaktAdresse>[
      MitgliedKontaktAdresse(
        additionalAddressId: 0,
        street: 'Musterweg',
        housenumber: '5',
        zipCode: '50667',
        town: 'Koeln',
        country: 'Deutschland',
      ),
      MitgliedKontaktAdresse(
        additionalAddressId: 8,
        label: 'Lager',
        street: 'Waldpfad',
        housenumber: '3',
        zipCode: '50999',
        town: 'Koeln',
        country: 'Deutschland',
      ),
    ],
  );
}
