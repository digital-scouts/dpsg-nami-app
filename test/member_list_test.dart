import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/appearance/appearance_catalog.dart';
import 'package:nami/domain/member/member_list_preferences.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/taetigkeit/roles.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/widgets/member_list.dart';
import 'package:nami/presentation/widgets/member_list_group_filter_bar.dart';
import 'package:nami/presentation/widgets/member_list_tile.dart';
import 'package:nami/presentation/widgets/supporter_badge.dart';
import 'package:nami/presentation/widgets/member_list_directory.dart';

import 'support/page_header_height.dart';

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
    final jetzt = DateTime(2026, 6, 15, 12);
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
              nowProvider: () => jetzt,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pumpList(jetzt);
    expect(find.text('Letztes Update: Jetzt'), findsOneWidget);

    await pumpList(jetzt.subtract(const Duration(seconds: 10)));
    expect(find.text('Letztes Update: vor 10 Sekunden'), findsOneWidget);

    await pumpList(jetzt.subtract(const Duration(minutes: 30)));
    expect(find.text('Letztes Update: vor 30 Minuten'), findsOneWidget);

    await pumpList(jetzt.subtract(const Duration(minutes: 1, seconds: 20)));
    expect(find.text('Letztes Update: vor 1 Minute'), findsOneWidget);

    await pumpList(jetzt.subtract(const Duration(hours: 1, minutes: 5)));
    expect(find.text('Letztes Update: vor 1 Stunde'), findsOneWidget);

    await pumpList(jetzt.subtract(const Duration(days: 1, hours: 2)));
    expect(find.text('Letztes Update: vor 1 Tag'), findsOneWidget);

    await pumpList(jetzt.subtract(const Duration(days: 3)));
    expect(find.text('Letztes Update: vor 3 Tagen'), findsOneWidget);
  });

  testWidgets('Mitglieder-Header folgt dem Header-Raster', (tester) async {
    await expectPageHeaderMatchesRaster(
      tester,
      () => MaterialApp(
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de'), Locale('en')],
        locale: const Locale('de'),
        home: Scaffold(
          body: MemberDirectory(
            mitglieder: [MitgliedFactory.demo(index: 1)],
            fixedFilterGroups: [
              for (var i = 0; i < 12; i++)
                MemberFixedFilterGroup(
                  keyName: 'gruppe_$i',
                  label: 'Sehr lange Gruppe $i',
                  groupType: 'sonstige',
                ),
            ],
          ),
        ),
      ),
    );
  });

  testWidgets('Gruppenfilter zeigt viele Chips in einer scrollbaren Zeile', (
    tester,
  ) async {
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

    final bar = find.byType(GroupFilterBar);
    final height = tester.getSize(bar).height;
    expect(find.text('Mehr anzeigen'), findsNothing);
    expect(find.text('Gruppe 0').hitTestable(), findsOneWidget);
    expect(find.text('Gruppe 7').hitTestable(), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Gruppe 7'),
      100,
      scrollable: find.descendant(of: bar, matching: find.byType(Scrollable)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gruppe 7').hitTestable(), findsOneWidget);
    // Eine Zeile: die Hoehe bleibt unabhaengig von der Chip-Anzahl.
    expect(tester.getSize(bar).height, height);
  });

  testWidgets('zeigt das Supporter-Badge nur beim gewuenschten Mitglied', (
    tester,
  ) async {
    final mitglieder = <Mitglied>[
      Mitglied(
        mitgliedsnummer: '2001',
        personId: 42,
        vorname: 'Eigene',
        nachname: 'Person',
        geburtsdatum: DateTime(1990, 1, 1),
        eintrittsdatum: DateTime(2020, 1, 1),
      ),
      Mitglied(
        mitgliedsnummer: '2002',
        personId: 43,
        vorname: 'Andere',
        nachname: 'Person',
        geburtsdatum: DateTime(1991, 1, 1),
        eintrittsdatum: DateTime(2020, 1, 1),
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
            searchString: '',
            sortKey: MemberSortKey.name,
            subtitleMode: MemberSubtitleMode.mitgliedsnummer,
            favourites: const {},
            selectedFilterKeys: const {},
            mitgliedsFilterKeys: const {},
            supporterBadgeBuilder: (m) => m.personId == 42
                ? SupporterBadgeId.kompassJungpfadfinder
                : null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SupporterBadge), findsOneWidget);
    expect(
      find.byKey(const ValueKey('supporter-badge-kompass-jufi')),
      findsOneWidget,
    );
    final ownTile = find.ancestor(
      of: find.byType(SupporterBadge),
      matching: find.byType(MemberListTile),
    );
    expect(
      tester.widget<MemberListTile>(ownTile).mitglied.mitgliedsnummer,
      '2001',
    );
  });
}
