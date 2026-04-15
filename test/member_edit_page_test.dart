import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/presentation/screens/member_edit_page.dart';

void main() {
  testWidgets('zeigt Formularinhalt auch auf schmalem Viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
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

    final vornameRect = tester.getRect(
      find.widgetWithText(TextFormField, 'Vorname'),
    );
    final fahrtennameRect = tester.getRect(
      find.widgetWithText(TextFormField, 'Fahrtenname'),
    );
    final genderRect = tester.getRect(
      find.byKey(const Key('member-edit-gender-field')),
    );
    final geburtsdatumRect = tester.getRect(
      find.byKey(const Key('member-edit-birthdate-field')),
    );

    expect((vornameRect.top - fahrtennameRect.top).abs(), lessThan(2));
    expect(geburtsdatumRect.left, greaterThan(genderRect.left + 20));
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
      _buildTestApp(
        MemberEditPage(
          mitglied: _buildMember(gender: '').copyWith(
            telefonnummern: const <MitgliedKontaktTelefon>[
              MitgliedKontaktTelefon(phoneNumberId: 1, wert: 'abc'),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('member-edit-save-button')));
    await tester.pump();

    expect(
      find.text('Bitte eine gültige Telefonnummer eingeben.'),
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
}

Widget _buildTestApp(Widget home) {
  return MaterialApp(home: home);
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
      MitgliedKontaktTelefon(phoneNumberId: 1, wert: '0123456789'),
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
