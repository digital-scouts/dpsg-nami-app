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
    expect(find.text('Kontakt', skipOffstage: false), findsOneWidget);
    expect(find.byKey(const Key('member-edit-save-button')), findsOneWidget);
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
