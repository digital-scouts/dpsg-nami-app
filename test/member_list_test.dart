import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/member/member_list_preferences.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/widgets/member_list.dart';
import 'package:nami/presentation/widgets/member_list_tile.dart';

void main() {
  testWidgets(
    'sucht ueber Name, Fahrtenname, Mitgliedsnummer und strukturierte E-Mail-Adressen, aber nicht ueber Telefonnummern',
    (tester) async {
      final mitglieder = <Mitglied>[
        Mitglied(
          mitgliedsnummer: '1001',
          vorname: 'Anna',
          nachname: 'Beispiel',
          fahrtenname: 'Falke',
          geburtsdatum: DateTime(2010, 4, 3),
          eintrittsdatum: DateTime(2021, 9, 1),
          emailAdressen: const <MitgliedKontaktEmail>[
            MitgliedKontaktEmail(
              wert: 'familie@example.org',
              label: Mitglied.secondaryEmailLabel,
            ),
          ],
        ),
        Mitglied(
          mitgliedsnummer: '1002',
          vorname: 'Ben',
          nachname: 'Beispiel',
          geburtsdatum: DateTime(2011, 7, 12),
          eintrittsdatum: DateTime(2022, 9, 1),
          telefonnummern: const <MitgliedKontaktTelefon>[
            MitgliedKontaktTelefon(
              wert: '+49 170 1234567',
              label: Mitglied.phoneMobileLabel,
            ),
          ],
        ),
      ];

      Future<void> pumpList(String searchString) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              AppLocalizations.delegate,
            ],
            supportedLocales: const [Locale('de'), Locale('en')],
            locale: const Locale('de'),
            home: Scaffold(
              body: MemberList(
                mitglieder: mitglieder,
                searchString: searchString,
                subtitleMode: MemberSubtitleMode.mitgliedsnummer,
              ),
            ),
          ),
        );

        await tester.pump();
      }

      await pumpList('anna');

      expect(find.text('Anna Beispiel'), findsOneWidget);
      expect(find.text('Ben Beispiel'), findsNothing);

      await pumpList('falke');

      expect(find.text('Anna Beispiel'), findsOneWidget);
      expect(find.text('Ben Beispiel'), findsNothing);

      await pumpList('1002');

      expect(find.text('Anna Beispiel'), findsNothing);
      expect(find.text('Ben Beispiel'), findsOneWidget);

      await pumpList('familie@example.org');

      expect(find.text('Anna Beispiel'), findsOneWidget);
      expect(find.text('Ben Beispiel'), findsNothing);
      expect(find.text('Mitglieder: 1'), findsOneWidget);

      await pumpList('+49 170 1234567');

      expect(find.byType(MemberListTile), findsNothing);
      expect(find.text('Keine Mitglieder gefunden'), findsOneWidget);
    },
  );

  testWidgets(
    'zeigt bei aktiviertem Toggle das Trefferfeld mit hervorgehobenem Match im Subtitle',
    (tester) async {
      final mitglieder = <Mitglied>[
        Mitglied(
          mitgliedsnummer: '1001',
          vorname: 'Anna',
          nachname: 'Beispiel',
          geburtsdatum: DateTime(2010, 4, 3),
          eintrittsdatum: DateTime(2021, 9, 1),
          emailAdressen: const <MitgliedKontaktEmail>[
            MitgliedKontaktEmail(
              wert: 'test@google.de',
              label: Mitglied.primaryEmailLabel,
              istPrimaer: true,
            ),
          ],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            AppLocalizations.delegate,
          ],
          supportedLocales: const [Locale('de'), Locale('en')],
          locale: const Locale('de'),
          home: Scaffold(
            body: MemberList(
              mitglieder: mitglieder,
              searchString: 'tes',
              highlightSearchMatches: true,
              subtitleMode: MemberSubtitleMode.mitgliedsnummer,
            ),
          ),
        ),
      );

      await tester.pump();

      final richTextFinder = find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText() == 'test@google.de',
      );
      expect(richTextFinder, findsOneWidget);

      final richText = tester.widget<RichText>(richTextFinder);
      final text = richText.text as TextSpan;
      expect(text.toPlainText(), 'test@google.de');
      expect(text.children, hasLength(3));
      expect((text.children![1] as TextSpan).text, 'tes');
    },
  );

  testWidgets(
    'behaelt bei deaktiviertem Toggle das eingestellte Subtitle statt des Trefferfelds',
    (tester) async {
      final mitglieder = <Mitglied>[
        Mitglied(
          mitgliedsnummer: '1001',
          vorname: 'Anna',
          nachname: 'Beispiel',
          geburtsdatum: DateTime(2010, 4, 3),
          eintrittsdatum: DateTime(2021, 9, 1),
          emailAdressen: const <MitgliedKontaktEmail>[
            MitgliedKontaktEmail(
              wert: 'test@google.de',
              label: Mitglied.primaryEmailLabel,
              istPrimaer: true,
            ),
          ],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            AppLocalizations.delegate,
          ],
          supportedLocales: const [Locale('de'), Locale('en')],
          locale: const Locale('de'),
          home: Scaffold(
            body: MemberList(
              mitglieder: mitglieder,
              searchString: 'tes',
              highlightSearchMatches: false,
              subtitleMode: MemberSubtitleMode.mitgliedsnummer,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('1001'), findsOneWidget);
      final richTextFinder = find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText() == 'test@google.de',
      );
      expect(richTextFinder, findsNothing);
    },
  );
}
