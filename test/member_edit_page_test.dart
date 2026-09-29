import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/auth/auth_profile.dart';
import 'package:nami/domain/auth/auth_profile_repository.dart';
import 'package:nami/domain/auth/auth_session.dart';
import 'package:nami/domain/auth/auth_session_repository.dart';
import 'package:nami/domain/member/member_resolution.dart';
import 'package:nami/domain/member/member_write_repository.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/member/pending_person_update.dart';
import 'package:nami/domain/member/pending_person_update_repository.dart';
import 'package:nami/domain/settings/app_settings.dart';
import 'package:nami/domain/settings/app_settings_repository.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/model/member_edit_model.dart';
import 'package:nami/presentation/model/member_phone_input.dart';
import 'package:nami/presentation/screens/member_edit_page.dart';
import 'package:nami/services/biometric_lock_service.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_data_retention_policy.dart';
import 'package:nami/services/hitobito_oauth_service.dart';
import 'package:nami/services/logger_service.dart';
import 'package:nami/services/network_access_policy.dart';
import 'package:nami/services/sensitive_storage_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

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

  testWidgets('normalisiert unbekannte Werte auf Unbekannt', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(MemberEditPage(mitglied: _buildMember(gender: 'x'))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unbekannt', skipOffstage: false), findsOneWidget);
    expect(find.text('Keine Angabe', skipOffstage: false), findsNothing);
  });

  testWidgets('zeigt Geschlecht d als Divers', (tester) async {
    for (final gender in const <String>['d', 'divers']) {
      await tester.pumpWidget(
        _buildTestApp(
          MemberEditPage(
            key: ValueKey<String>(gender),
            mitglied: _buildMember(gender: gender),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final field = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(const Key('member-edit-gender-field')),
      );
      expect(field.initialValue, 'd');
      expect(find.text('Divers', skipOffstage: false), findsOneWidget);
    }
  });

  testWidgets('speichert unbekanntes Geschlecht als null', (tester) async {
    final model = _RecordingMemberEditModel();

    _useLargeViewport(tester);
    await tester.pumpWidget(
      _buildTestApp(
        MemberEditPage(mitglied: _buildMember(gender: '')),
        providers: _buildEditProviders(model),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('member-edit-save-button')));
    await tester.pumpAndSettle();

    expect(model.submitCalls.single.zielMitglied.gender, isNull);
  });

  testWidgets('behaelt Geschlecht d beim Speichern', (tester) async {
    final model = _RecordingMemberEditModel();

    _useLargeViewport(tester);
    await tester.pumpWidget(
      _buildTestApp(
        MemberEditPage(mitglied: _buildMember(gender: 'd')),
        providers: _buildEditProviders(model),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('member-edit-save-button')));
    await tester.pumpAndSettle();

    expect(model.submitCalls.single.zielMitglied.gender, 'd');
  });

  testWidgets('zeigt keine Bezeichnung fuer die Hauptadresse', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(
      _buildTestApp(
        MemberEditPage(
          mitglied: _buildMember(
            gender: 'w',
          ).copyWith(telefonnummern: const <MitgliedKontaktTelefon>[]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Musterweg'), findsOneWidget);
    expect(find.text('Bezeichnung', skipOffstage: false), findsNothing);
    expect(find.text('c/o', skipOffstage: false), findsOneWidget);
  });

  group('Speichern', () {
    Future<void> pumpEditor(
      WidgetTester tester, {
      required Mitglied mitglied,
      MemberEditModel? model,
      bool withSession = true,
    }) async {
      _useLargeViewport(tester);
      final providers = model == null
          ? const <SingleChildWidget>[]
          : withSession
          ? _buildEditProviders(model)
          : <SingleChildWidget>[
              ChangeNotifierProvider<MemberEditModel>.value(value: model),
            ];
      await tester.pumpWidget(
        _buildTestApp(MemberEditPage(mitglied: mitglied), providers: providers),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tapSave(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('member-edit-save-button')));
      await tester.pumpAndSettle();
    }

    testWidgets('schliesst die Seite bei Erfolg mit dem Ergebnis', (
      tester,
    ) async {
      final model = _RecordingMemberEditModel(
        result: const MemberEditSubmitResult(success: true, wasQueued: false),
      );
      MemberEditSubmitResult? received;

      _useLargeViewport(tester);
      await tester.pumpWidget(
        _buildTestApp(
          _EditPageLauncher(
            pageBuilder: () =>
                MemberEditPage(mitglied: _buildMember(gender: 'w')),
            onResult: (result) => received = result,
          ),
          providers: _buildEditProviders(model),
        ),
      );
      await tester.tap(find.text('Editor oeffnen'));
      await tester.pumpAndSettle();
      await tapSave(tester);

      expect(received?.success, isTrue);
      expect(find.byType(MemberEditPage), findsNothing);
    });

    testWidgets(
      'zeigt Ladezustand und sperrt den Button waehrend des Sendens',
      (tester) async {
        final gate = Completer<void>();
        final model = _RecordingMemberEditModel(
          result: const MemberEditSubmitResult(success: true, wasQueued: false),
          gate: gate.future,
        );
        await pumpEditor(
          tester,
          mitglied: _buildMember(gender: 'w'),
          model: model,
        );

        await tester.tap(find.byKey(const Key('member-edit-save-button')));
        await tester.pump();

        expect(find.text('Speichert...'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('member-edit-save-button')),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );
        final button = tester.widget<ButtonStyleButton>(
          find.byKey(const Key('member-edit-save-button')),
        );
        expect(button.onPressed, isNull);

        await tester.tap(
          find.byKey(const Key('member-edit-save-button')),
          warnIfMissed: false,
        );
        await tester.pump();
        expect(model.submitCalls, hasLength(1));

        gate.complete();
        await tester.pumpAndSettle();
      },
    );

    testWidgets('zeigt Fehlermeldung, wenn Speichern scheitert', (
      tester,
    ) async {
      final model = _RecordingMemberEditModel(
        result: const MemberEditSubmitResult(success: false, wasQueued: false),
      );
      await pumpEditor(
        tester,
        mitglied: _buildMember(gender: 'w'),
        model: model,
      );

      await tapSave(tester);

      expect(find.text('Speichern fehlgeschlagen.'), findsOneWidget);
      expect(find.byType(MemberEditPage), findsOneWidget);
      final button = tester.widget<ButtonStyleButton>(
        find.byKey(const Key('member-edit-save-button')),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('warnt ohne Sitzung und sendet nichts', (tester) async {
      final model = _RecordingMemberEditModel();
      await pumpEditor(
        tester,
        mitglied: _buildMember(gender: 'w'),
        model: model,
        withSession: false,
      );

      await tapSave(tester);

      expect(
        find.text('Aktuell ist keine gültige Sitzung zum Speichern verfügbar.'),
        findsOneWidget,
      );
      expect(model.submitCalls, isEmpty);
    });

    testWidgets('zeigt Server-Validierung einer Telefonnummer am Feld', (
      tester,
    ) async {
      final model = _RecordingMemberEditModel(
        result: const MemberEditSubmitResult(
          success: false,
          wasQueued: false,
          message: 'Validierung fehlgeschlagen',
          validationErrors: <MemberWriteFieldValidationError>[
            MemberWriteFieldValidationError(
              message: 'Nummer ist ungültig',
              relationshipName: 'phone_numbers',
              relationshipAttribute: 'number',
              relationshipId: 1,
            ),
          ],
        ),
      );
      await pumpEditor(
        tester,
        mitglied: _buildMember(gender: 'w'),
        model: model,
      );

      await tapSave(tester);

      expect(find.text('Nummer ist ungültig'), findsOneWidget);
      expect(find.text('Validierung fehlgeschlagen'), findsNothing);
    });

    testWidgets('blockiert Geburtsdatum in der Zukunft', (tester) async {
      final model = _RecordingMemberEditModel();
      final zukunft = DateTime.now().add(const Duration(days: 30));
      await pumpEditor(
        tester,
        mitglied: _buildMember(gender: 'w').copyWith(
          geburtsdatum: DateTime(zukunft.year, zukunft.month, zukunft.day),
        ),
        model: model,
      );

      await tapSave(tester);

      expect(
        find.text('Geburtsdatum darf nicht in der Zukunft liegen.'),
        findsOneWidget,
      );
      expect(model.submitCalls, isEmpty);
    });

    testWidgets('uebernimmt jedes Formularfeld in das Zielmitglied', (
      tester,
    ) async {
      final model = _RecordingMemberEditModel();
      await pumpEditor(
        tester,
        mitglied: _buildMember(gender: 'w'),
        model: model,
      );

      Future<void> enter(String key, String value) async {
        final field = find.byKey(Key(key));
        await tester.ensureVisible(field);
        await tester.enterText(field, value);
      }

      await enter('member-edit-first-name-field', ' Juliane ');
      await enter('member-edit-last-name-field', 'Kellermann');
      await enter('member-edit-nickname-field', '');
      await enter('member-edit-primary-email-field', 'neu@example.org');
      await enter('member-edit-phone-number-0', '0170 1234567');
      await tester.pumpAndSettle();
      await tapSave(tester);

      final ziel = model.submitCalls.single.zielMitglied;
      expect(ziel.vorname, 'Juliane');
      expect(ziel.nachname, 'Kellermann');
      expect(ziel.fahrtenname, isNull);
      expect(ziel.gender, 'w');
      expect(ziel.geburtsdatum, DateTime(2012, 5, 4));
      expect(
        ziel.emailAdressen.where((email) => email.istPrimaer).single.wert,
        'neu@example.org',
      );
      expect(ziel.telefonnummern.single.phoneNumberId, 1);
      expect(ziel.telefonnummern.single.wert, '+491701234567');
      expect(ziel.primaryAddress?.street, 'Musterweg');
      expect(ziel.primaryAddress?.label, isNull);
    });
  });

  group('Pronomen, Bankverbindung und Berechtigung', () {
    Mitglied mitBank() => _buildMember(gender: 'w').copyWith(
      detailsLesbar: true,
      bankAccountOwner: 'Julia Keller',
      iban: 'DE02120300000000202051',
      bic: 'BYLADEM1001',
      bankName: 'Testbank',
      paymentMethod: 'invoice',
    );

    Future<void> pumpEditor(
      WidgetTester tester,
      Mitglied mitglied, {
      MemberEditModel? model,
    }) async {
      _useLargeViewport(tester);
      await tester.pumpWidget(
        _buildTestApp(
          MemberEditPage(mitglied: mitglied),
          providers: model == null
              ? const <SingleChildWidget>[]
              : _buildEditProviders(model),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> enter(WidgetTester tester, String key, String value) async {
      final field = find.byKey(Key(key));
      await tester.ensureVisible(field);
      await tester.enterText(field, value);
      await tester.pumpAndSettle();
    }

    Future<void> tapSave(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('member-edit-save-button')));
      await tester.pumpAndSettle();
    }

    testWidgets('speichert Pronomen', (tester) async {
      final model = _RecordingMemberEditModel();
      await pumpEditor(tester, _buildMember(gender: 'w'), model: model);

      await enter(tester, 'member-edit-pronoun-field', ' sie/ihr ');
      await tapSave(tester);

      expect(model.submitCalls.single.zielMitglied.pronoun, 'sie/ihr');
    });

    testWidgets('speichert Sichtbarkeit einer Telefonnummer', (tester) async {
      final model = _RecordingMemberEditModel();
      await pumpEditor(tester, _buildMember(gender: 'w'), model: model);

      final toggle = find.byKey(const Key('member-edit-phone-public-0'));
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await tapSave(tester);

      final phone = model.submitCalls.single.zielMitglied.telefonnummern.single;
      expect(phone.phoneNumberId, 1);
      expect(phone.istOeffentlich, isTrue);
    });

    testWidgets('zeigt keine Bankverbindung ohne lesbare Bankdaten', (
      tester,
    ) async {
      await pumpEditor(tester, _buildMember(gender: 'w'));

      expect(find.text('Bankverbindung', skipOffstage: false), findsNothing);
      expect(
        find.byKey(const Key('member-edit-iban-field'), skipOffstage: false),
        findsNothing,
      );
    });

    testWidgets('bearbeitet Bankverbindung und normalisiert die IBAN', (
      tester,
    ) async {
      final model = _RecordingMemberEditModel();
      await pumpEditor(tester, mitBank(), model: model);

      expect(find.text('Bankverbindung'), findsOneWidget);
      await enter(
        tester,
        'member-edit-iban-field',
        'de89 3704 0044 0532 0130 00',
      );
      await enter(tester, 'member-edit-bic-field', '');
      final paymentField = find.byKey(
        const Key('member-edit-payment-method-field'),
      );
      await tester.ensureVisible(paymentField);
      await tester.tap(paymentField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lastschrift').last);
      await tester.pumpAndSettle();
      await tapSave(tester);

      final ziel = model.submitCalls.single.zielMitglied;
      expect(ziel.iban, 'DE89370400440532013000');
      expect(ziel.bic, isNull);
      expect(ziel.paymentMethod, 'debit');
      expect(ziel.bankAccountOwner, 'Julia Keller');
    });

    testWidgets('bietet bei der Zahlart keine leere Auswahl an', (
      tester,
    ) async {
      await pumpEditor(tester, mitBank());

      final paymentField = find.byKey(
        const Key('member-edit-payment-method-field'),
      );
      await tester.ensureVisible(paymentField);
      await tester.tap(paymentField);
      await tester.pumpAndSettle();

      final values = tester
          .widgetList<DropdownMenuItem<String>>(
            find.byType(DropdownMenuItem<String>),
          )
          .map((item) => item.value)
          .toSet();
      expect(values, containsAll(<String>['invoice', 'debit']));
      expect(values.contains(null), isFalse);
      expect(values.contains(''), isFalse);
    });

    testWidgets('blockiert ungueltige IBAN und BIC', (tester) async {
      final model = _RecordingMemberEditModel();
      await pumpEditor(tester, mitBank(), model: model);

      await enter(tester, 'member-edit-iban-field', 'DE00123456789012345678');
      await enter(tester, 'member-edit-bic-field', 'ABC');
      await tapSave(tester);

      expect(find.text('Bitte eine gültige IBAN eingeben.'), findsOneWidget);
      expect(find.text('Bitte eine gültige BIC eingeben.'), findsOneWidget);
      expect(model.submitCalls, isEmpty);
    });

    testWidgets('zeigt Serverfehler zur IBAN direkt am Feld', (tester) async {
      final model = _RecordingMemberEditModel(
        result: const MemberEditSubmitResult(
          success: false,
          wasQueued: false,
          message: 'Validierung fehlgeschlagen',
          validationErrors: <MemberWriteFieldValidationError>[
            MemberWriteFieldValidationError(
              message: 'IBAN ist nicht gültig',
              attribute: 'iban',
            ),
          ],
        ),
      );
      await pumpEditor(tester, mitBank(), model: model);

      await tapSave(tester);

      expect(find.text('IBAN ist nicht gültig'), findsOneWidget);
      expect(find.text('Validierung fehlgeschlagen'), findsNothing);

      await enter(tester, 'member-edit-iban-field', 'DE89370400440532013000');
      await tapSave(tester);
      expect(model.submitCalls, hasLength(2));
      expect(
        model.submitCalls.last.zielMitglied.iban,
        'DE89370400440532013000',
      );
    });

    testWidgets(
      'sperrt Geschlecht und Geburtsdatum ohne Berechtigung und behaelt sie',
      (tester) async {
        final model = _RecordingMemberEditModel();
        final mitglied = _buildMember(gender: '').copyWith(
          detailsLesbar: false,
          geburtsdatum: Mitglied.peoplePlaceholderDate,
          genderLoeschen: true,
        );
        await pumpEditor(tester, mitglied, model: model);

        expect(
          find.byKey(const Key('member-edit-details-locked')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('member-edit-gender-field')), findsNothing);
        expect(
          find.byKey(const Key('member-edit-birthdate-field')),
          findsNothing,
        );

        await tapSave(tester);

        final ziel = model.submitCalls.single.zielMitglied;
        expect(ziel.gender, isNull);
        expect(ziel.geburtsdatum, Mitglied.peoplePlaceholderDate);
      },
    );
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
    'zeigt im Problemlösungsfall neuen Titel, Intro und eingeklappten Bearbeiten-Bereich',
    (tester) async {
      final member = _buildMember(gender: '');
      final pendingEntry = _buildResolutionEntry(
        basisMitglied: member,
        zielMitglied: member.copyWith(vorname: 'Juliane'),
        remoteMitglied: member.copyWith(vorname: 'Jule'),
        items: const <MemberResolutionItem>[
          MemberResolutionItem(
            problemType: MemberResolutionProblemType.conflict,
            cause: MemberResolutionCause.overlappingChange,
            target: MemberResolutionTarget(
              type: MemberResolutionTargetType.firstName,
            ),
            message:
                'Vorname wurde lokal und auf dem Server unterschiedlich geändert.',
          ),
        ],
      );

      await tester.pumpWidget(
        _buildTestApp(
          MemberEditPage(
            mitglied: pendingEntry.zielMitglied,
            pendingEntry: pendingEntry,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Speicherprobleme bei Juliane Keller'), findsOneWidget);
      expect(
        find.text(
          'Behebe die folgenden Probleme, um das Mitglied zu speichern.',
        ),
        findsOneWidget,
      );
      expect(find.text('Mitglied bearbeiten'), findsOneWidget);
      expect(find.text('Allgemein', skipOffstage: false), findsNothing);

      await tester.tap(
        find.byKey(const Key('member-edit-resolution-edit-section-toggle')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Allgemein', skipOffstage: false), findsOneWidget);
    },
  );

  testWidgets(
    'zeigt im Problemlösungsfall Telefon und Zusatz-E-Mail im Vergleich nebeneinander',
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

      expect(find.text('Lokal'), findsNWidgets(2));
      expect(find.text('Server'), findsNWidgets(2));
      expect(find.text('Mobil'), findsOneWidget);
      expect(find.text('Schule'), findsOneWidget);
      expect(find.text('Privat'), findsNWidgets(2));
      expect(find.text('+49123456789'), findsNWidgets(2));
      expect(find.text('jule@example.org'), findsNWidgets(2));
    },
  );

  testWidgets(
    'Leeren der Hauptadresse speichert Mitglied ohne Hauptadresse und '
    'laesst Zusatzadresse unveraendert',
    (tester) async {
      const zusatzadresse = MitgliedKontaktAdresse(
        additionalAddressId: 8,
        label: 'Lager',
        street: 'Zeltplatz',
        housenumber: '7',
        zipCode: '50667',
        town: 'Bonn',
      );
      final member = _buildMember(gender: '').copyWith(
        adressen: const <MitgliedKontaktAdresse>[
          MitgliedKontaktAdresse(
            additionalAddressId: 0,
            street: 'Musterweg',
            housenumber: '5',
            zipCode: '12345',
            town: 'Köln',
          ),
          zusatzadresse,
        ],
      );
      final model = _RecordingMemberEditModel();

      _useLargeViewport(tester);
      await tester.pumpWidget(
        _buildTestApp(
          MemberEditPage(mitglied: member),
          providers: _buildEditProviders(model),
        ),
      );
      await tester.pumpAndSettle();

      // Hauptadresse und Zusatzadresse erscheinen jeweils genau einmal.
      expect(find.widgetWithText(TextField, 'Musterweg'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Zeltplatz'), findsOneWidget);

      for (final value in <String>['Musterweg', '5', '12345', 'Köln']) {
        final field = find.widgetWithText(TextField, value);
        await tester.ensureVisible(field);
        await tester.enterText(field, '');
      }
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('member-edit-save-button')));
      await tester.pumpAndSettle();

      expect(model.submitCalls, hasLength(1));
      final ziel = model.submitCalls.single.zielMitglied;
      expect(ziel.primaryAddress, isNull);
      expect(ziel.additionalAddresses, [zusatzadresse]);
      expect(ziel.adressen, [zusatzadresse]);
    },
  );

  testWidgets(
    'zeigt Zusatzadresse ohne Hauptadresse nicht zusaetzlich als Hauptadresse',
    (tester) async {
      const zusatzadresse = MitgliedKontaktAdresse(
        additionalAddressId: 8,
        label: 'Lager',
        street: 'Zeltplatz',
        housenumber: '7',
        zipCode: '50667',
        town: 'Bonn',
      );
      final member = _buildMember(
        gender: '',
      ).copyWith(adressen: const <MitgliedKontaktAdresse>[zusatzadresse]);
      final model = _RecordingMemberEditModel();

      _useLargeViewport(tester);
      await tester.pumpWidget(
        _buildTestApp(
          MemberEditPage(mitglied: member),
          providers: _buildEditProviders(model),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Zeltplatz'), findsOneWidget);

      await tester.tap(find.byKey(const Key('member-edit-save-button')));
      await tester.pumpAndSettle();

      expect(model.submitCalls, hasLength(1));
      expect(model.submitCalls.single.zielMitglied.adressen, [zusatzadresse]);
    },
  );

  testWidgets(
    'zeigt im Problemlösungsfall Zusatzadresse mit einzelnen Adressfeldern im Vergleich',
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

      expect(find.text('Bezeichnung'), findsAtLeastNWidgets(2));
      expect(find.text('Straße'), findsAtLeastNWidgets(2));
      expect(find.text('Hausnr.'), findsAtLeastNWidgets(2));
      expect(find.text('PLZ'), findsAtLeastNWidgets(2));
      expect(find.text('Ort'), findsAtLeastNWidgets(2));
      expect(find.text('Lager'), findsOneWidget);
      expect(find.text('Zeltplatz'), findsNWidgets(2));
      expect(find.text('7'), findsNWidgets(2));
      expect(find.text('50667'), findsNWidgets(2));
      expect(find.text('Koeln'), findsNWidgets(2));
      expect(find.text('Nicht gesetzt'), findsAtLeastNWidgets(1));
    },
  );

  testWidgets(
    'Bearbeiten öffnet den Bearbeiten-Bereich und fokussiert das passende Feld',
    (tester) async {
      final basisMitglied = _buildMember(gender: '').copyWith(
        telefonnummern: const <MitgliedKontaktTelefon>[
          MitgliedKontaktTelefon(
            phoneNumberId: 1,
            wert: '+49123456789',
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
                'Telefonnummer wurde lokal und auf dem Server unterschiedlich geändert.',
          ),
        ],
      );

      await tester.pumpWidget(
        _buildTestApp(
          MemberEditPage(mitglied: zielMitglied, pendingEntry: pendingEntry),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('member-edit-phone-number-0')), findsNothing);

      await tester.tap(
        find.byKey(const Key('member-edit-resolution-edit-conflict:phone:1')),
      );
      await tester.pumpAndSettle();

      final editableText = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('member-edit-phone-number-0')),
          matching: find.byType(EditableText),
        ),
      );

      expect(
        find.byKey(const Key('member-edit-phone-number-0')),
        findsOneWidget,
      );
      expect(editableText.focusNode.hasFocus, isTrue);
    },
  );

  group('Problemloesungsmodus', () {
    const firstNameConflict = MemberResolutionItem(
      problemType: MemberResolutionProblemType.conflict,
      cause: MemberResolutionCause.overlappingChange,
      target: MemberResolutionTarget(
        type: MemberResolutionTargetType.firstName,
      ),
      message:
          'Vorname wurde lokal und auf dem Server unterschiedlich geändert.',
    );
    const phoneConflict = MemberResolutionItem(
      problemType: MemberResolutionProblemType.conflict,
      cause: MemberResolutionCause.overlappingChange,
      target: MemberResolutionTarget(
        type: MemberResolutionTargetType.phone,
        relationshipId: 1,
      ),
      message: 'Telefonnummer wurde lokal und auf dem Server geändert.',
    );
    const primaryEmailValidation = MemberResolutionItem(
      problemType: MemberResolutionProblemType.validation,
      cause: MemberResolutionCause.serverValidation,
      target: MemberResolutionTarget(
        type: MemberResolutionTargetType.primaryEmail,
      ),
      message: 'E-Mail wurde vom Server abgelehnt.',
    );

    const emptyStateText =
        'Alle aktuell sichtbaren Problemfälle wurden für diesen Durchgang bearbeitet.';

    Future<void> pumpResolutionPage(
      WidgetTester tester, {
      required PendingPersonUpdate pendingEntry,
      required _RecordingMemberEditModel model,
    }) async {
      _useLargeViewport(tester);
      await tester.pumpWidget(
        _buildTestApp(
          MemberEditPage(
            mitglied: pendingEntry.zielMitglied,
            pendingEntry: pendingEntry,
          ),
          providers: _buildEditProviders(model),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> expandEditSection(WidgetTester tester) async {
      await tester.tap(
        find.byKey(const Key('member-edit-resolution-edit-section-toggle')),
      );
      await tester.pumpAndSettle();
    }

    String fieldText(WidgetTester tester, Key key) {
      return tester.widget<TextFormField>(find.byKey(key)).controller!.text;
    }

    testWidgets(
      'Lokal behalten blendet Konflikt aus und behaelt lokalen Wert',
      (tester) async {
        final member = _buildMember(gender: '');
        final pendingEntry = _buildResolutionEntry(
          basisMitglied: member,
          zielMitglied: member.copyWith(vorname: 'Juliane'),
          remoteMitglied: member.copyWith(vorname: 'Jule'),
          items: const <MemberResolutionItem>[firstNameConflict],
        );
        final model = _RecordingMemberEditModel();

        await pumpResolutionPage(
          tester,
          pendingEntry: pendingEntry,
          model: model,
        );

        expect(find.text(firstNameConflict.message), findsOneWidget);
        expect(find.text('Lokal'), findsOneWidget);
        expect(find.text('Server'), findsOneWidget);
        expect(find.text(emptyStateText), findsNothing);

        await tester.tap(find.text('Lokal behalten'));
        await tester.pumpAndSettle();

        expect(find.text(firstNameConflict.message), findsNothing);
        expect(find.text('Lokal behalten'), findsNothing);
        expect(find.text('Serverstand verwenden'), findsNothing);
        expect(model.choices, <String>['keep_local']);

        await expandEditSection(tester);

        expect(
          fieldText(tester, const Key('member-edit-first-name-field')),
          'Juliane',
        );
      },
    );

    testWidgets(
      'Serverstand verwenden blendet Konflikt aus und uebernimmt Server-Vorname',
      (tester) async {
        final member = _buildMember(gender: '');
        final pendingEntry = _buildResolutionEntry(
          basisMitglied: member,
          zielMitglied: member.copyWith(vorname: 'Juliane'),
          remoteMitglied: member.copyWith(vorname: 'Jule'),
          items: const <MemberResolutionItem>[firstNameConflict],
        );
        final model = _RecordingMemberEditModel();

        await pumpResolutionPage(
          tester,
          pendingEntry: pendingEntry,
          model: model,
        );

        await tester.tap(find.text('Serverstand verwenden'));
        await tester.pumpAndSettle();

        expect(find.text(firstNameConflict.message), findsNothing);
        expect(find.text('Serverstand verwenden'), findsNothing);
        expect(model.choices, <String>['use_server']);

        await expandEditSection(tester);

        expect(
          fieldText(tester, const Key('member-edit-first-name-field')),
          'Jule',
        );
      },
    );

    testWidgets(
      'Serverstand verwenden ersetzt Telefonnummer inklusive Vorwahl und Bezeichnung',
      (tester) async {
        final member = _buildMember(gender: '').copyWith(
          telefonnummern: const <MitgliedKontaktTelefon>[
            MitgliedKontaktTelefon(
              phoneNumberId: 1,
              wert: '+49123456789',
              label: 'Privat',
            ),
          ],
        );
        final pendingEntry = _buildResolutionEntry(
          basisMitglied: member,
          zielMitglied: member.copyWith(
            telefonnummern: const <MitgliedKontaktTelefon>[
              MitgliedKontaktTelefon(
                phoneNumberId: 1,
                wert: '+49987654321',
                label: 'Privat',
              ),
            ],
          ),
          remoteMitglied: member.copyWith(
            telefonnummern: const <MitgliedKontaktTelefon>[
              MitgliedKontaktTelefon(
                phoneNumberId: 1,
                wert: '+352621123456',
                label: 'Mobil',
              ),
            ],
          ),
          items: const <MemberResolutionItem>[phoneConflict],
        );
        final model = _RecordingMemberEditModel();

        await pumpResolutionPage(
          tester,
          pendingEntry: pendingEntry,
          model: model,
        );
        // Bearbeiten-Bereich vorher oeffnen, damit die bereits gebauten
        // Felder nach dem Ersetzen des Entwurfs aktualisiert werden muessen.
        await expandEditSection(tester);
        expect(
          fieldText(tester, const Key('member-edit-phone-number-0')),
          '987654321',
        );

        await tester.ensureVisible(find.text('Serverstand verwenden'));
        await tester.tap(find.text('Serverstand verwenden'));
        await tester.pumpAndSettle();

        expect(find.text(phoneConflict.message), findsNothing);
        expect(model.choices, <String>['use_server']);
        expect(
          fieldText(tester, const Key('member-edit-phone-number-0')),
          '621123456',
        );
        final countryDropdown = tester.widget<DropdownButton<String>>(
          find.descendant(
            of: find.byKey(const Key('member-edit-phone-country-0')),
            matching: find.byType(DropdownButton<String>),
          ),
        );
        expect(countryDropdown.value, 'lu');

        await tester.tap(find.byKey(const Key('member-edit-save-button')));
        await tester.pumpAndSettle();

        expect(model.submitCalls, hasLength(1));
        expect(
          model.submitCalls.single.zielMitglied.telefonnummern,
          const <MitgliedKontaktTelefon>[
            MitgliedKontaktTelefon(
              phoneNumberId: 1,
              wert: '+352621123456',
              label: 'Mobil',
            ),
          ],
        );
      },
    );

    testWidgets(
      'Lokale Aenderung verwerfen uebernimmt Basiswert und blendet Validierungsfall aus',
      (tester) async {
        final member = _buildMember(gender: '');
        final pendingEntry = _buildResolutionEntry(
          basisMitglied: member,
          zielMitglied: member.copyWith(
            emailAdressen: const <MitgliedKontaktEmail>[
              MitgliedKontaktEmail(
                additionalEmailId: 1,
                wert: 'juliane@example.org',
                label: Mitglied.primaryEmailLabel,
                istPrimaer: true,
              ),
            ],
          ),
          remoteMitglied: member.copyWith(
            emailAdressen: const <MitgliedKontaktEmail>[
              MitgliedKontaktEmail(
                additionalEmailId: 1,
                wert: 'remote@example.org',
                label: Mitglied.primaryEmailLabel,
                istPrimaer: true,
              ),
            ],
          ),
          items: const <MemberResolutionItem>[primaryEmailValidation],
        );
        final model = _RecordingMemberEditModel();

        await pumpResolutionPage(
          tester,
          pendingEntry: pendingEntry,
          model: model,
        );

        expect(find.text('Aktuell'), findsOneWidget);
        expect(find.text('Vorheriger Stand'), findsOneWidget);
        expect(find.text('juliane@example.org'), findsOneWidget);
        expect(find.text('julia@example.org'), findsOneWidget);
        expect(find.text('Lokal behalten'), findsNothing);

        await tester.tap(find.text('Lokale Änderung verwerfen'));
        await tester.pumpAndSettle();

        expect(find.text(primaryEmailValidation.message), findsNothing);
        expect(find.text('Lokale Änderung verwerfen'), findsNothing);
        expect(model.choices, <String>['discard_local']);

        await expandEditSection(tester);

        expect(
          fieldText(tester, const Key('member-edit-primary-email-field')),
          'julia@example.org',
        );
      },
    );

    testWidgets('zeigt Leerzustand nachdem alle Problemfaelle erledigt sind', (
      tester,
    ) async {
      final member = _buildMember(gender: '');
      final pendingEntry = _buildResolutionEntry(
        basisMitglied: member,
        zielMitglied: member.copyWith(vorname: 'Juliane'),
        remoteMitglied: member.copyWith(vorname: 'Jule'),
        items: const <MemberResolutionItem>[
          firstNameConflict,
          primaryEmailValidation,
        ],
      );
      final model = _RecordingMemberEditModel();

      await pumpResolutionPage(
        tester,
        pendingEntry: pendingEntry,
        model: model,
      );

      expect(find.text(firstNameConflict.message), findsOneWidget);
      expect(find.text(primaryEmailValidation.message), findsOneWidget);
      expect(find.text(emptyStateText), findsNothing);

      await tester.tap(find.text('Lokal behalten'));
      await tester.pumpAndSettle();

      expect(find.text(firstNameConflict.message), findsNothing);
      expect(find.text(primaryEmailValidation.message), findsOneWidget);
      expect(find.text(emptyStateText), findsNothing);

      await tester.tap(find.text('Lokale Änderung verwerfen'));
      await tester.pumpAndSettle();

      expect(find.text(primaryEmailValidation.message), findsNothing);
      expect(find.text(emptyStateText), findsOneWidget);
      expect(find.text('Speicherprobleme'), findsOneWidget);
      expect(model.choices, <String>['keep_local', 'discard_local']);
    });

    testWidgets(
      'Speichern sendet mit Serverstand als Basis und bestehendem Problemfall',
      (tester) async {
        final member = _buildMember(gender: '');
        final pendingEntry = _buildResolutionEntry(
          basisMitglied: member,
          zielMitglied: member.copyWith(vorname: 'Juliane'),
          remoteMitglied: member.copyWith(vorname: 'Jule', nachname: 'Remote'),
          items: const <MemberResolutionItem>[firstNameConflict],
        );
        final model = _RecordingMemberEditModel();

        await pumpResolutionPage(
          tester,
          pendingEntry: pendingEntry,
          model: model,
        );

        await tester.tap(find.text('Lokal behalten'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('member-edit-save-button')));
        await tester.pumpAndSettle();

        expect(model.submitCalls, hasLength(1));
        final call = model.submitCalls.single;
        expect(call.accessToken, 'token-123');
        expect(
          call.basisMitglied,
          same(pendingEntry.resolutionCase!.remoteMitglied),
        );
        expect(call.trigger, 'manual_resolution');
        expect(call.existingResolutionCase, same(pendingEntry.resolutionCase));
        expect(call.zielMitglied.vorname, 'Juliane');
        expect(call.zielMitglied.nachname, 'Keller');
      },
    );

    testWidgets(
      'validiert beim Speichern auch mit eingeklapptem Bearbeiten-Bereich',
      (tester) async {
        final member = _buildMember(gender: '');
        final pendingEntry = _buildResolutionEntry(
          basisMitglied: member,
          zielMitglied: member.copyWith(
            emailAdressen: const <MitgliedKontaktEmail>[
              MitgliedKontaktEmail(
                additionalEmailId: 1,
                wert: 'ungueltig',
                label: Mitglied.primaryEmailLabel,
                istPrimaer: true,
              ),
            ],
          ),
          remoteMitglied: member,
          items: const <MemberResolutionItem>[primaryEmailValidation],
        );
        final model = _RecordingMemberEditModel();

        await pumpResolutionPage(
          tester,
          pendingEntry: pendingEntry,
          model: model,
        );

        await tester.tap(find.byKey(const Key('member-edit-save-button')));
        await tester.pumpAndSettle();

        expect(model.submitCalls, isEmpty);
        expect(
          find.text('Bitte eine gültige E-Mail-Adresse eingeben.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'ersetzt die Seite bei erneutem Problemfall durch neue Problemloesung',
      (tester) async {
        final member = _buildMember(gender: '');
        final pendingEntry = _buildResolutionEntry(
          basisMitglied: member,
          zielMitglied: member.copyWith(vorname: 'Juliane'),
          remoteMitglied: member.copyWith(vorname: 'Jule'),
          items: const <MemberResolutionItem>[firstNameConflict],
        );
        final nextZiel = member.copyWith(vorname: 'Julchen');
        final nextEntry = _buildResolutionEntry(
          basisMitglied: member,
          zielMitglied: nextZiel,
          remoteMitglied: member.copyWith(nachname: 'Schmidt'),
          items: const <MemberResolutionItem>[
            MemberResolutionItem(
              problemType: MemberResolutionProblemType.conflict,
              cause: MemberResolutionCause.overlappingChange,
              target: MemberResolutionTarget(
                type: MemberResolutionTargetType.lastName,
              ),
              message: 'Nachname wurde parallel geändert.',
            ),
          ],
        );
        final model = _RecordingMemberEditModel(
          result: MemberEditSubmitResult(
            success: false,
            wasQueued: false,
            requiresResolution: true,
            message: 'Neue Konflikte gefunden.',
            pendingEntry: nextEntry,
          ),
        );

        await pumpResolutionPage(
          tester,
          pendingEntry: pendingEntry,
          model: model,
        );
        await tester.tap(find.byKey(const Key('member-edit-save-button')));
        await tester.pumpAndSettle();

        expect(model.submitCalls, hasLength(1));
        expect(find.byType(MemberEditPage), findsOneWidget);
        expect(find.text('Speicherprobleme bei Juliane Keller'), findsNothing);
        expect(
          find.text('Speicherprobleme bei Julchen Keller'),
          findsOneWidget,
        );
        expect(find.text('Neue Konflikte gefunden.'), findsOneWidget);
        expect(find.text('Nachname wurde parallel geändert.'), findsOneWidget);
        expect(find.text(firstNameConflict.message), findsNothing);
        expect(model.openedEntryPoints, <String>['unknown', 'submit_result']);
      },
    );

    testWidgets('schliesst die Seite bei eingereihter Aenderung mit Ergebnis', (
      tester,
    ) async {
      final member = _buildMember(gender: '');
      final pendingEntry = _buildResolutionEntry(
        basisMitglied: member,
        zielMitglied: member.copyWith(vorname: 'Juliane'),
        remoteMitglied: member.copyWith(vorname: 'Jule'),
        items: const <MemberResolutionItem>[firstNameConflict],
      );
      const queuedResult = MemberEditSubmitResult(
        success: false,
        wasQueued: true,
        message: 'Änderung wird später gesendet.',
      );
      final model = _RecordingMemberEditModel(result: queuedResult);
      final results = <MemberEditSubmitResult?>[];

      _useLargeViewport(tester);
      await tester.pumpWidget(
        _buildTestApp(
          _EditPageLauncher(
            pageBuilder: () => MemberEditPage(
              mitglied: pendingEntry.zielMitglied,
              pendingEntry: pendingEntry,
            ),
            onResult: results.add,
          ),
          providers: _buildEditProviders(model),
        ),
      );
      await tester.tap(find.text('Editor oeffnen'));
      await tester.pumpAndSettle();

      expect(find.byType(MemberEditPage), findsOneWidget);

      await tester.tap(find.byKey(const Key('member-edit-save-button')));
      await tester.pumpAndSettle();

      expect(model.submitCalls, hasLength(1));
      expect(find.byType(MemberEditPage), findsNothing);
      expect(find.text('Editor oeffnen'), findsOneWidget);
      expect(results, hasLength(1));
      expect(results.single, same(queuedResult));
    });

    testWidgets(
      'reicht das Ergebnis einer Folge-Problemloesung an den Aufrufer weiter',
      (tester) async {
        final member = _buildMember(gender: '');
        final pendingEntry = _buildResolutionEntry(
          basisMitglied: member,
          zielMitglied: member.copyWith(vorname: 'Juliane'),
          remoteMitglied: member.copyWith(vorname: 'Jule'),
          items: const <MemberResolutionItem>[firstNameConflict],
        );
        final nextEntry = _buildResolutionEntry(
          basisMitglied: member,
          zielMitglied: member.copyWith(vorname: 'Julchen'),
          remoteMitglied: member.copyWith(vorname: 'Jule'),
          items: const <MemberResolutionItem>[firstNameConflict],
        );
        const queuedResult = MemberEditSubmitResult(
          success: false,
          wasQueued: true,
        );
        final model = _RecordingMemberEditModel(
          results: <MemberEditSubmitResult>[
            MemberEditSubmitResult(
              success: false,
              wasQueued: false,
              requiresResolution: true,
              pendingEntry: nextEntry,
            ),
            queuedResult,
          ],
        );
        final results = <MemberEditSubmitResult?>[];

        _useLargeViewport(tester);
        await tester.pumpWidget(
          _buildTestApp(
            _EditPageLauncher(
              pageBuilder: () => MemberEditPage(
                mitglied: pendingEntry.zielMitglied,
                pendingEntry: pendingEntry,
              ),
              onResult: results.add,
            ),
            providers: _buildEditProviders(model),
          ),
        );
        await tester.tap(find.text('Editor oeffnen'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('member-edit-save-button')));
        await tester.pumpAndSettle();

        expect(
          find.text('Speicherprobleme bei Julchen Keller'),
          findsOneWidget,
        );
        expect(results, isEmpty);

        await tester.tap(find.byKey(const Key('member-edit-save-button')));
        await tester.pumpAndSettle();

        expect(model.submitCalls, hasLength(2));
        expect(find.byType(MemberEditPage), findsNothing);
        expect(results, <MemberEditSubmitResult?>[queuedResult]);
      },
    );
  });
}

Widget _buildTestApp(
  Widget home, {
  List<SingleChildWidget> providers = const <SingleChildWidget>[],
}) {
  final app = MaterialApp(
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

  if (providers.isEmpty) {
    return app;
  }

  return MultiProvider(providers: providers, child: app);
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

void _useLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

List<SingleChildWidget> _buildEditProviders(MemberEditModel model) {
  return <SingleChildWidget>[
    ChangeNotifierProvider<AuthSessionModel>.value(
      value: _StubAuthSessionModel(
        session: AuthSession(
          accessToken: 'token-123',
          receivedAt: DateTime(2026, 4, 14),
        ),
      ),
    ),
    ChangeNotifierProvider<MemberEditModel>.value(value: model),
  ];
}

class _EditPageLauncher extends StatelessWidget {
  const _EditPageLauncher({required this.pageBuilder, required this.onResult});

  final Widget Function() pageBuilder;
  final void Function(MemberEditSubmitResult? result) onResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () async {
            final result = await Navigator.of(context)
                .push<MemberEditSubmitResult>(
                  MaterialPageRoute<MemberEditSubmitResult>(
                    builder: (_) => pageBuilder(),
                  ),
                );
            onResult(result);
          },
          child: const Text('Editor oeffnen'),
        ),
      ),
    );
  }
}

class _SubmitCall {
  const _SubmitCall({
    required this.accessToken,
    required this.basisMitglied,
    required this.zielMitglied,
    required this.trigger,
    required this.existingResolutionCase,
  });

  final String accessToken;
  final Mitglied basisMitglied;
  final Mitglied zielMitglied;
  final String trigger;
  final MemberResolutionCase? existingResolutionCase;
}

class _RecordingMemberEditModel extends MemberEditModel {
  _RecordingMemberEditModel({
    MemberEditSubmitResult result = const MemberEditSubmitResult(
      success: false,
      wasQueued: true,
    ),
    List<MemberEditSubmitResult>? results,
    this.gate,
  }) : _results = results ?? <MemberEditSubmitResult>[result],
       super(
         memberWriteRepository: _NoopMemberWriteRepository(),
         pendingRepository: _NoopPendingPersonUpdateRepository(),
         logger: _FakeLoggerService(),
         onMemberUpdated: (_) async {},
       );

  final List<MemberEditSubmitResult> _results;
  final Future<void>? gate;
  final List<_SubmitCall> submitCalls = <_SubmitCall>[];
  final List<String> choices = <String>[];
  final List<String> openedEntryPoints = <String>[];

  @override
  Future<MemberEditSubmitResult> submitUpdate({
    required String accessToken,
    required Mitglied basisMitglied,
    required Mitglied zielMitglied,
    String trigger = 'manual_edit',
    MemberResolutionCase? existingResolutionCase,
  }) async {
    submitCalls.add(
      _SubmitCall(
        accessToken: accessToken,
        basisMitglied: basisMitglied,
        zielMitglied: zielMitglied,
        trigger: trigger,
        existingResolutionCase: existingResolutionCase,
      ),
    );
    final pendingGate = gate;
    if (pendingGate != null) {
      await pendingGate;
    }
    final index = submitCalls.length - 1;
    return index < _results.length ? _results[index] : _results.last;
  }

  @override
  Future<void> logResolutionChoice({
    required PendingPersonUpdate entry,
    required MemberResolutionItem item,
    required String choice,
  }) async {
    choices.add(choice);
  }

  @override
  Future<void> logResolutionOpened({
    required PendingPersonUpdate entry,
    required String entryPoint,
  }) async {
    openedEntryPoints.add(entryPoint);
  }
}

class _StubAuthSessionModel extends AuthSessionModel {
  _StubAuthSessionModel({required AuthSession session})
    : _sessionOverride = session,
      super(
        repository: _InMemoryAuthSessionRepository(initial: session),
        profileRepository: _InMemoryAuthProfileRepository(),
        oauthService: _FakeOauthService(),
        biometricLockService: _FakeBiometricLockService(),
        sensitiveStorageService: _FakeSensitiveStorageService(),
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 30),
          refreshInterval: const Duration(days: 1),
        ),
        logger: _FakeLoggerService(),
      );

  final AuthSession _sessionOverride;

  @override
  AuthSession? get session => _sessionOverride;

  @override
  NetworkAccessBlockedReason? get remoteAccessBlockedReason => null;

  @override
  bool get requiresInteractiveLogin => false;
}

class _NoopMemberWriteRepository implements MemberWriteRepository {
  @override
  Future<Mitglied> fetchRemoteMember({
    required String accessToken,
    required int personId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Mitglied> updateMember({
    required String accessToken,
    required Mitglied basisMitglied,
    required Mitglied zielMitglied,
  }) async {
    return zielMitglied;
  }
}

class _NoopPendingPersonUpdateRepository
    implements PendingPersonUpdateRepository {
  @override
  Future<void> clear() async {}

  @override
  Future<List<PendingPersonUpdate>> loadAll() async {
    return const <PendingPersonUpdate>[];
  }

  @override
  Future<void> remove(String entryId) async {}

  @override
  Future<void> save(PendingPersonUpdate entry) async {}
}

class _InMemoryAuthSessionRepository implements AuthSessionRepository {
  _InMemoryAuthSessionRepository({this.initial});

  final AuthSession? initial;

  @override
  Future<void> clear() async {}

  @override
  Future<AuthSession?> load() async => initial;

  @override
  Future<void> save(AuthSession session) async {}
}

class _InMemoryAuthProfileRepository implements AuthProfileRepository {
  @override
  Future<void> clear() async {}

  @override
  Future<AuthProfile?> loadCached() async => null;

  @override
  Future<DateTime?> loadLastSyncAt() async => null;

  @override
  Future<void> save(AuthProfile profile) async {}

  @override
  Future<void> saveLastSyncAt(DateTime timestamp) async {}
}

class _FakeOauthService extends HitobitoOauthService {
  _FakeOauthService()
    : super(
        config: const HitobitoAuthConfig(
          clientId: 'client',
          clientSecret: 'secret',
          authorizationUrl: 'https://demo.hitobito.com/oauth/authorize',
          tokenUrl: 'https://demo.hitobito.com/oauth/token',
          redirectUri: 'de.jlange.nami.app:/oauth/callback',
          scopeString: 'openid email',
          discoveryUrl: '',
          profileUrl: 'https://demo.hitobito.com/oauth/profile',
        ),
      );
}

class _FakeBiometricLockService extends BiometricLockService {
  _FakeBiometricLockService();

  @override
  Future<bool> authenticate() async => true;

  @override
  Future<bool> isAvailable() async => false;
}

class _FakeSensitiveStorageService extends SensitiveStorageService {
  @override
  Future<DateTime?> loadLastBackgroundedAt() async => null;

  @override
  Future<DateTime?> loadLastSensitiveSyncAt() async => null;

  @override
  Future<DateTime?> loadLastSensitiveSyncAttemptAt() async => null;

  @override
  Future<void> purgeSensitiveData() async {}
}

class _FakeLoggerService extends LoggerService {
  _FakeLoggerService()
    : super(
        settingsRepository: _FakeAppSettingsRepository(),
        navigatorKey: GlobalKey<NavigatorState>(),
      );

  @override
  Future<void> log(String service, String message) async {}

  @override
  Future<void> logInfo(String service, String message) async {}

  @override
  Future<void> logWarn(String service, String message) async {}

  @override
  Future<void> logError(
    String service,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) async {}
}

class _FakeAppSettingsRepository extends AppSettingsRepository {
  @override
  Future<AppSettings> load() async => const AppSettings(
    themeMode: ThemeMode.system,
    languageCode: 'de',
    analyticsEnabled: false,
  );

  @override
  Future<void> saveAnalyticsEnabled(bool enabled) async {}

  @override
  Future<void> saveBiometricLockEnabled(bool enabled) async {}

  @override
  Future<void> saveMemberListSearchResultHighlightEnabled(bool enabled) async {}

  @override
  Future<void> saveGeburstagsbenachrichtigungStufen(Set<Stufe> stufen) async {}

  @override
  Future<void> saveLanguageCode(String code) async {}

  @override
  Future<void> saveNotificationsEnabled(bool enabled) async {}

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {}
}
