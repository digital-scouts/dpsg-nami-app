import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/member/member_list_preferences.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/taetigkeit/roles.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/widgets/member_list.dart';
import 'package:nami/presentation/widgets/member_list_group_filter_bar.dart';
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

  testWidgets('zeigt im Geburtstag-Subtitle keinen Placeholder-Wert', (
    tester,
  ) async {
    final mitglieder = <Mitglied>[
      Mitglied.peopleListItem(
        mitgliedsnummer: '1001',
        vorname: 'Sven',
        nachname: 'Stamm',
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
            subtitleMode: MemberSubtitleMode.geburtstag,
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Sven Stamm'), findsOneWidget);
    expect(find.text('1. Januar 1900'), findsNothing);
  });

  testWidgets(
    'sortiert Mitglieder ohne bekanntes Geburtsdatum bei Alterssortierung ans Ende nach Name',
    (tester) async {
      final mitglieder = <Mitglied>[
        Mitglied.peopleListItem(
          mitgliedsnummer: '1003',
          vorname: 'Zara',
          nachname: 'Unbekannt',
        ),
        Mitglied(
          mitgliedsnummer: '1002',
          vorname: 'Cem',
          nachname: 'Jung',
          geburtsdatum: DateTime(2015, 5, 1),
          eintrittsdatum: DateTime(2022, 9, 1),
        ),
        Mitglied.peopleListItem(
          mitgliedsnummer: '1004',
          vorname: 'Aaron',
          nachname: 'Unbekannt',
        ),
        Mitglied(
          mitgliedsnummer: '1001',
          vorname: 'Berta',
          nachname: 'Alt',
          geburtsdatum: DateTime(2010, 5, 1),
          eintrittsdatum: DateTime(2022, 9, 1),
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
              sortKey: MemberSortKey.age,
            ),
          ),
        ),
      );

      await tester.pump();

      final visibleNames = tester
          .widgetList<Text>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Text &&
                  <String>{
                    'Berta Alt',
                    'Cem Jung',
                    'Aaron Unbekannt',
                    'Zara Unbekannt',
                  }.contains(widget.data),
            ),
          )
          .map((text) => text.data)
          .toList(growable: false);

      expect(visibleNames, [
        'Berta Alt',
        'Cem Jung',
        'Aaron Unbekannt',
        'Zara Unbekannt',
      ]);
    },
  );

  testWidgets('faerbt den Listenstreifen fuer Sonstige grau', (tester) async {
    final mitglieder = <Mitglied>[
      Mitglied.peopleListItem(
        mitgliedsnummer: '1001',
        vorname: 'Sven',
        nachname: 'Stamm',
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
            roleCategoryBuilder: (_) => RoleCategory.sonstiges,
          ),
        ),
      ),
    );

    await tester.pump();

    final stripeFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).color != null,
    );
    final stripe = tester.widget<Container>(stripeFinder.first);
    final decoration = stripe.decoration! as BoxDecoration;

    final colorScheme = Theme.of(tester.element(find.byType(MemberListTile)));

    expect(decoration.color, colorScheme.colorScheme.outline);
    expect(decoration.gradient, isNull);
  });

  testWidgets('zeigt letztes Update als relative Zeit an', (tester) async {
    final mitglieder = <Mitglied>[
      Mitglied.peopleListItem(
        mitgliedsnummer: '1001',
        vorname: 'Sven',
        nachname: 'Stamm',
      ),
    ];

    Future<void> pumpList(DateTime lastUpdateAt) async {
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
              lastUpdateAt: lastUpdateAt,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pumpList(DateTime.now());
    expect(find.text('Letztes Update: Jetzt'), findsOneWidget);

    await pumpList(DateTime.now().subtract(const Duration(seconds: 10)));
    expect(find.text('Letztes Update: vor 10 Sekunden'), findsOneWidget);

    await pumpList(DateTime.now().subtract(const Duration(minutes: 30)));
    expect(find.text('Letztes Update: vor 30 Minuten'), findsOneWidget);
  });

  testWidgets(
    'Gruppenfilter klappt viele Chips ohne horizontales Scrollen auf',
    (tester) async {
      final selectedKeys = <String>{};

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
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 180,
                child: GroupFilterBar(
                  items: List<GroupFilterItem>.generate(
                    8,
                    (index) => GroupFilterItem(
                      keyName: 'filter_$index',
                      label: 'Gruppe $index',
                    ),
                  ),
                  selectedKeys: selectedKeys,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(find.text('Mehr anzeigen'), findsOneWidget);
      expect(find.text('Gruppe 7').hitTestable(), findsNothing);

      await tester.tap(find.text('Mehr anzeigen'));
      await tester.pumpAndSettle();

      expect(find.text('Weniger anzeigen'), findsOneWidget);
      expect(find.text('Gruppe 7').hitTestable(), findsOneWidget);
    },
  );
}
