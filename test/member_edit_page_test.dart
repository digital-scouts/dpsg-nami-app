import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/member/member_resolution.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/member/pending_person_update.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/member_phone_input.dart';
import 'package:nami/presentation/screens/member_edit_page.dart';

void main() {
  testWidgets('zeigt Formularinhalt auch auf schmalem Viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _buildTestApp(MemberEditPage(mitglied: _buildMember(gender: 'd'))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Allgemein', skipOffstage: false), findsOneWidget);
    expect(find.text('Vorname', skipOffstage: false), findsOneWidget);
    expect(find.text('Nachname', skipOffstage: false), findsOneWidget);
    expect(find.text('Kontakt', skipOffstage: false), findsNothing);
    expect(find.text('E-Mail', skipOffstage: false), findsWidgets);
    expect(find.text('Telefon', skipOffstage: false), findsWidgets);
    expect(find.text('Adresse', skipOffstage: false), findsWidgets);
    expect(find.byKey(const Key('member-edit-save-button')), findsOneWidget);

    final genderRect = tester.getRect(
      find.byKey(const Key('member-edit-gender-field')),
    );
    final geburtsdatumRect = tester.getRect(
      find.byKey(const Key('member-edit-birthdate-field')),
    );
    final phoneRowFinder = find.byKey(const Key('member-edit-phone-row-0'));

    await tester.ensureVisible(
      find.byKey(const Key('member-edit-phone-number-0')),
    );
    await tester.pumpAndSettle();

    final phoneCountryRect = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('member-edit-phone-country-0')),
        matching: find.byType(InputDecorator),
      ),
    );
    final phoneNumberRect = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('member-edit-phone-number-0')),
        matching: find.byType(InputDecorator),
      ),
    );
    expect(geburtsdatumRect.top, greaterThanOrEqualTo(genderRect.top));
    expect(phoneRowFinder, findsOneWidget);
    expect(
      find.descendant(
        of: phoneRowFinder,
        matching: find.byKey(const Key('member-edit-phone-country-0')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: phoneRowFinder,
        matching: find.byKey(const Key('member-edit-phone-number-0')),
      ),
      findsOneWidget,
    );
    expect(phoneCountryRect.right, lessThan(phoneNumberRect.left));
    expect(
      (phoneCountryRect.height - phoneNumberRect.height).abs(),
      lessThan(2),
    );
  });

  testWidgets(
    'zeigt fixierten Speichern-Button und konsistente Hinzufuegen-Buttons',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _buildTestApp(MemberEditPage(mitglied: _buildMember(gender: 'd'))),
      );
      await tester.pumpAndSettle();

      final saveFinder = find.byKey(const Key('member-edit-save-button'));
      expect(saveFinder, findsOneWidget);
      expect(find.text('Speichern'), findsOneWidget);
      expect(
        find.text('E-Mail hinzufügen', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('Telefon hinzufügen', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('Adresse hinzufügen', skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('Primär', skipOffstage: false), findsNothing);
      expect(
        find.textContaining('Standard', skipOffstage: false),
        findsNothing,
      );
      expect(
        find.textContaining('Weitere E-Mail', skipOffstage: false),
        findsNothing,
      );
      expect(
        find.textContaining('Weitere Adresse', skipOffstage: false),
        findsNothing,
      );
      expect(find.textContaining('Eintrag', skipOffstage: false), findsNothing);

      final initialRect = tester.getRect(saveFinder);
      expect(initialRect.bottom, lessThanOrEqualTo(700));

      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -700),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      final scrolledRect = tester.getRect(saveFinder);
      expect(scrolledRect.bottom, lessThanOrEqualTo(700));
    },
  );

  testWidgets('normalisiert alte Werte auf Unbekannt', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(MemberEditPage(mitglied: _buildMember(gender: 'divers'))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unbekannt', skipOffstage: false), findsOneWidget);
    expect(find.text('Divers', skipOffstage: false), findsNothing);
    expect(find.text('Keine Angabe', skipOffstage: false), findsNothing);
  });

  testWidgets('blockiert Speichern ohne Namen oder Fahrtenname', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        MemberEditPage(
          mitglied: _buildMember(gender: '').copyWith(
            vorname: '',
            nachname: '',
            fahrtenname: '',
            fahrtennameLoeschen: true,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('member-edit-save-button')));
    await tester.pump();

    expect(
      find.text('Mindestens Vorname, Nachname oder Fahrtenname angeben.'),
      findsOneWidget,
    );
  });

  testWidgets('blockiert zu altes Geburtsdatum', (tester) async {
    final oldDate = DateTime(DateTime.now().year - 121, 1, 1);
    await tester.pumpWidget(
      _buildTestApp(
        MemberEditPage(
          mitglied: _buildMember(gender: '').copyWith(geburtsdatum: oldDate),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('member-edit-save-button')));
    await tester.pump();

    expect(
      find.text('Geburtsdatum ist zu weit in der Vergangenheit.'),
      findsOneWidget,
    );
  });

  testWidgets('blockiert ungueltige E-Mail-Adressen', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        MemberEditPage(
          mitglied: _buildMember(gender: '').copyWith(
            emailAdressen: const <MitgliedKontaktEmail>[
              MitgliedKontaktEmail(
                additionalEmailId: 1,
                wert: 'ungueltig',
                label: Mitglied.primaryEmailLabel,
                istPrimaer: true,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('member-edit-save-button')));
    await tester.pump();

    expect(
      find.text('Bitte eine gültige E-Mail-Adresse eingeben.'),
      findsOneWidget,
    );
  });

  testWidgets('blockiert ungueltige Telefonnummern', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(MemberEditPage(mitglied: _buildMember(gender: ''))),
    );

    await tester.enterText(
      find.byKey(const Key('member-edit-phone-number-0')),
      'abc',
    );

    await tester.tap(find.byKey(const Key('member-edit-save-button')));
    await tester.pump();

    expect(
      find.text('Bitte eine gültige Telefonnummer eingeben.'),
      findsOneWidget,
    );
  });

  testWidgets('neue Telefonnummer nutzt Deutschland als Default-Vorwahl', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _buildTestApp(MemberEditPage(mitglied: _buildMember(gender: ''))),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Telefon hinzufügen'));
    await tester.tap(find.text('Telefon hinzufügen'));
    await tester.pumpAndSettle();

    final dropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const Key('member-edit-phone-country-1')),
    );
    expect(dropdown.initialValue, MemberPhoneInput.defaultCountryId);
  });

  testWidgets('zerlegt bekannte europaeische Vorwahl beim Laden', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        MemberEditPage(
          mitglied: _buildMember(gender: '').copyWith(
            telefonnummern: const <MitgliedKontaktTelefon>[
              MitgliedKontaktTelefon(phoneNumberId: 1, wert: '+352621123456'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const Key('member-edit-phone-country-0')),
    );
    final numberField = tester.widget<TextFormField>(
      find.byKey(const Key('member-edit-phone-number-0')),
    );

    expect(dropdown.initialValue, 'lu');
    expect(numberField.controller?.text, '621123456');
  });

  testWidgets('ordnet unbekannte Vorwahl Sonstige zu', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        MemberEditPage(
          mitglied: _buildMember(gender: '').copyWith(
            telefonnummern: const <MitgliedKontaktTelefon>[
              MitgliedKontaktTelefon(phoneNumberId: 1, wert: '+12125550123'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const Key('member-edit-phone-country-0')),
    );
    final numberField = tester.widget<TextFormField>(
      find.byKey(const Key('member-edit-phone-number-0')),
    );

    expect(dropdown.initialValue, MemberPhoneInput.otherCountryId);
    expect(numberField.controller?.text, '+12125550123');
  });

  testWidgets('Sonstige verlangt volle Nummer mit Plus', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _buildTestApp(MemberEditPage(mitglied: _buildMember(gender: ''))),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('member-edit-phone-country-0')),
    );
    await tester.tap(find.byKey(const Key('member-edit-phone-country-0')));
    await tester.pumpAndSettle();

    expect(find.text('🇩🇪 +49').last, findsOneWidget);
    expect(find.text('🌍 Sonstige').last, findsOneWidget);
    expect(find.text('Deutschland (+49)'), findsNothing);

    await tester.tap(find.text('🌍 Sonstige').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('member-edit-phone-number-0')),
      '2125550123',
    );
    await tester.tap(find.byKey(const Key('member-edit-save-button')));
    await tester.pump();

    expect(
      find.text(
        'Bitte bei Sonstige die vollständige Telefonnummer mit +XX angeben.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('blockiert leere Zusatz-E-Mails', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(MemberEditPage(mitglied: _buildMember(gender: ''))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('E-Mail hinzufügen'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('member-edit-save-button')));
    await tester.pump();

    expect(find.text('E-Mail darf nicht leer sein.'), findsOneWidget);
  });

  testWidgets('zeigt leeres Geburtsdatum statt 01.01.1900', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        MemberEditPage(
          mitglied: _buildMember(
            gender: '',
          ).copyWith(geburtsdatum: Mitglied.peoplePlaceholderDate),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nicht gesetzt'), findsOneWidget);
    expect(find.text('01.01.1900'), findsNothing);
  });

  testWidgets(
    'zeigt im Problemlosungsfall bei Telefon und Zusatz-E-Mail immer Bezeichnung plus Wert',
    (tester) async {
      final basisMitglied = _buildMember(gender: '').copyWith(
        telefonnummern: const <MitgliedKontaktTelefon>[
          MitgliedKontaktTelefon(
            phoneNumberId: 1,
            wert: '+49123456789',
            label: 'Privat',
          ),
        ],
        emailAdressen: const <MitgliedKontaktEmail>[
          MitgliedKontaktEmail(
            additionalEmailId: 1,
            wert: 'julia@example.org',
            label: Mitglied.primaryEmailLabel,
            istPrimaer: true,
          ),
          MitgliedKontaktEmail(
            additionalEmailId: 2,
            wert: 'jule@example.org',
            label: 'Privat',
          ),
        ],
      );
      final zielMitglied = basisMitglied.copyWith(
        telefonnummern: const <MitgliedKontaktTelefon>[
          MitgliedKontaktTelefon(
            phoneNumberId: 1,
            wert: '+49123456789',
            label: 'Mobil',
          ),
        ],
        emailAdressen: const <MitgliedKontaktEmail>[
          MitgliedKontaktEmail(
            additionalEmailId: 1,
            wert: 'julia@example.org',
            label: Mitglied.primaryEmailLabel,
            istPrimaer: true,
          ),
          MitgliedKontaktEmail(
            additionalEmailId: 2,
            wert: 'jule@example.org',
            label: 'Schule',
          ),
        ],
      );
      final pendingEntry = _buildResolutionEntry(
        basisMitglied: basisMitglied,
        zielMitglied: zielMitglied,
        remoteMitglied: basisMitglied,
        items: const <MemberResolutionItem>[
          MemberResolutionItem(
            problemType: MemberResolutionProblemType.conflict,
            cause: MemberResolutionCause.overlappingChange,
            target: MemberResolutionTarget(
              type: MemberResolutionTargetType.phone,
              relationshipId: 1,
            ),
            message:
                'Telefonnummer wurde lokal und in Hitobito unterschiedlich geändert.',
          ),
          MemberResolutionItem(
            problemType: MemberResolutionProblemType.conflict,
            cause: MemberResolutionCause.overlappingChange,
            target: MemberResolutionTarget(
              type: MemberResolutionTargetType.additionalEmail,
              relationshipId: 2,
            ),
            message:
                'Zusätzliche E-Mail wurde lokal und in Hitobito unterschiedlich geändert.',
          ),
        ],
      );

      await tester.pumpWidget(
        _buildTestApp(
          MemberEditPage(mitglied: zielMitglied, pendingEntry: pendingEntry),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lokal: Mobil: +49123456789'), findsOneWidget);
      expect(find.text('Hitobito: Privat: +49123456789'), findsOneWidget);
      expect(find.text('Lokal: Schule: jule@example.org'), findsOneWidget);
      expect(find.text('Hitobito: Privat: jule@example.org'), findsOneWidget);
    },
  );

  testWidgets(
    'zeigt im Problemlösungsfall Zusatzadresse mit Bezeichnung und Adressblock ohne leere Labelanteile',
    (tester) async {
      final basisMitglied = _buildMember(gender: '').copyWith(
        adressen: const <MitgliedKontaktAdresse>[
          MitgliedKontaktAdresse(
            additionalAddressId: 0,
            street: 'Musterweg',
            housenumber: '5',
            zipCode: '12345',
            town: 'Koeln',
          ),
          MitgliedKontaktAdresse(
            additionalAddressId: 8,
            street: 'Zeltplatz',
            housenumber: '7',
            zipCode: '50667',
            town: 'Koeln',
          ),
        ],
      );
      final zielMitglied = basisMitglied.copyWith(
        adressen: const <MitgliedKontaktAdresse>[
          MitgliedKontaktAdresse(
            additionalAddressId: 0,
            street: 'Musterweg',
            housenumber: '5',
            zipCode: '12345',
            town: 'Koeln',
          ),
          MitgliedKontaktAdresse(
            additionalAddressId: 8,
            label: 'Lager',
            street: 'Zeltplatz',
            housenumber: '7',
            zipCode: '50667',
            town: 'Koeln',
          ),
        ],
      );
      final pendingEntry = _buildResolutionEntry(
        basisMitglied: basisMitglied,
        zielMitglied: zielMitglied,
        remoteMitglied: basisMitglied,
        items: const <MemberResolutionItem>[
          MemberResolutionItem(
            problemType: MemberResolutionProblemType.conflict,
            cause: MemberResolutionCause.overlappingChange,
            target: MemberResolutionTarget(
              type: MemberResolutionTargetType.additionalAddress,
              relationshipId: 8,
            ),
            message:
                'Zusatzadresse wurde lokal und in Hitobito unterschiedlich geändert.',
          ),
        ],
      );

      await tester.pumpWidget(
        _buildTestApp(
          MemberEditPage(mitglied: zielMitglied, pendingEntry: pendingEntry),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Lokal: Lager: Zeltplatz 7, 50667 Koeln'),
        findsOneWidget,
      );
      expect(find.text('Hitobito: Zeltplatz 7, 50667 Koeln'), findsOneWidget);
      expect(find.textContaining('Hitobito: :'), findsNothing);
    },
  );
}

Widget _buildTestApp(Widget home) {
  return MaterialApp(
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('de'), Locale('en')],
    locale: const Locale('de'),
    home: home,
  );
}

PendingPersonUpdate _buildResolutionEntry({
  required Mitglied basisMitglied,
  required Mitglied zielMitglied,
  required Mitglied remoteMitglied,
  required List<MemberResolutionItem> items,
}) {
  return PendingPersonUpdate(
    entryId: 'person-${zielMitglied.personId ?? 0}',
    personId: zielMitglied.personId ?? 23,
    mitgliedsnummer: zielMitglied.mitgliedsnummer,
    displayName: zielMitglied.fullName,
    basisMitglied: basisMitglied,
    zielMitglied: zielMitglied,
    queuedAt: DateTime(2026, 4, 14, 12, 0),
    status: PendingPersonUpdateStatus.needsResolution,
    resolutionCase: MemberResolutionCase(
      remoteMitglied: remoteMitglied,
      items: items,
      source: MemberResolutionSource.manualSave,
    ),
  );
}

Mitglied _buildMember({required String gender}) {
  return Mitglied(
    vorname: 'Julia',
    nachname: 'Keller',
    fahrtenname: 'Jule',
    geburtsdatum: DateTime(2012, 5, 4),
    eintrittsdatum: DateTime(2020, 1, 1),
    mitgliedsnummer: '4711',
    personId: 23,
    primaryGroupId: 111,
    gender: gender,
    emailAdressen: const <MitgliedKontaktEmail>[
      MitgliedKontaktEmail(
        additionalEmailId: 1,
        wert: 'julia@example.org',
        label: Mitglied.primaryEmailLabel,
        istPrimaer: true,
      ),
    ],
    telefonnummern: const <MitgliedKontaktTelefon>[
      MitgliedKontaktTelefon(phoneNumberId: 1, wert: '+49123456789'),
    ],
    adressen: const <MitgliedKontaktAdresse>[
      MitgliedKontaktAdresse(
        additionalAddressId: 0,
        street: 'Musterweg',
        housenumber: '5',
        zipCode: '12345',
        town: 'Köln',
      ),
    ],
  );
}
