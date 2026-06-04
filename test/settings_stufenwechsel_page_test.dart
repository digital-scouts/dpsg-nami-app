import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/screens/member_detail_page.dart';
import 'package:nami/presentation/screens/settings_stufenwechsel_page.dart';

void main() {
  Widget buildTestApp(Widget child) {
    return MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de'), Locale('en')],
      locale: const Locale('de'),
      home: child,
    );
  }

  Future<void> scrollUntilFound(
    WidgetTester tester,
    Finder finder, {
    int maxSwipes = 12,
  }) async {
    for (var i = 0; i < maxSwipes && finder.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -260));
      await tester.pumpAndSettle();
    }
    expect(finder, findsOneWidget);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('Button ist initial deaktiviert und wird durch Checkbox aktiv', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(const SettingsStufenwechselPage()));

    final buttonFinder = find.byKey(
      const Key('stufenwechsel-transfer-button-woelfling'),
    );
    await tester.pumpAndSettle();
    expect(buttonFinder, findsOneWidget);

    var button = tester.widget<FilledButton>(buttonFinder);
    expect(button.onPressed, isNull);

    final firstCheckbox = find.byKey(const Key('stufenwechsel-checkbox-w1'));
    await scrollUntilFound(tester, firstCheckbox);
    await tester.tap(firstCheckbox);
    await tester.pumpAndSettle();

    button = tester.widget<FilledButton>(buttonFinder);
    expect(button.onPressed, isNotNull);
    expect(find.text('1 ausgewählt'), findsOneWidget);
  });

  testWidgets(
    'Klick auf Stufe wechseln liefert Anzahl ausgewaehlter Elemente',
    (tester) async {
      int? capturedCount;

      await tester.pumpWidget(
        buildTestApp(
          SettingsStufenwechselPage(
            onTransferTap: (count) => capturedCount = count,
          ),
        ),
      );

      final firstCheckbox = find.byKey(const Key('stufenwechsel-checkbox-w1'));
      final secondCheckbox = find.byKey(const Key('stufenwechsel-checkbox-w2'));

      await scrollUntilFound(tester, firstCheckbox);
      await tester.ensureVisible(firstCheckbox);
      await tester.tap(firstCheckbox);

      await scrollUntilFound(tester, secondCheckbox);
      await tester.ensureVisible(secondCheckbox);
      await tester.tap(secondCheckbox);
      await tester.pumpAndSettle();

      final buttonFinder = find.byKey(
        const Key('stufenwechsel-transfer-button-woelfling'),
      );
      await scrollUntilFound(tester, buttonFinder);
      await tester.pumpAndSettle();

      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(capturedCount, 2);
    },
  );

  testWidgets('Tap auf Mitglied oeffnet Mitgliedsdetails', (tester) async {
    await tester.pumpWidget(buildTestApp(const SettingsStufenwechselPage()));

    final memberRow = find.byKey(const Key('stufenwechsel-member-row-w1'));
    await scrollUntilFound(tester, memberRow);
    await tester.tap(memberRow);
    await tester.pumpAndSettle();

    expect(find.byType(MemberDetailPage), findsOneWidget);
    expect(find.text('Emma Mueller'), findsWidgets);
  });

  testWidgets('Empty-State und Rover-Block werden gerendert', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        const SettingsStufenwechselPage(mode: StufenwechselDummyMode.empty),
      ),
    );

    expect(find.byKey(const Key('stufenwechsel-empty-state')), findsOneWidget);
    expect(
      find.byKey(const Key('stufenwechsel-rover-section')),
      findsOneWidget,
    );
  });

  testWidgets('Es gibt Übernehmen-Buttons nur für Stufen mit Mitgliedern', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(const SettingsStufenwechselPage()));

    final biberFinder = find.byKey(
      const Key('stufenwechsel-transfer-button-biber'),
    );
    final woelflingFinder = find.byKey(
      const Key('stufenwechsel-transfer-button-woelfling'),
    );
    final jufiFinder = find.byKey(
      const Key('stufenwechsel-transfer-button-jungpfadfinder'),
    );
    final pfadiFinder = find.byKey(
      const Key('stufenwechsel-transfer-button-pfadfinder'),
    );

    await scrollUntilFound(tester, woelflingFinder);
    expect(woelflingFinder, findsOneWidget);

    await scrollUntilFound(tester, pfadiFinder);
    expect(pfadiFinder, findsOneWidget);

    expect(biberFinder, findsNothing);
    expect(jufiFinder, findsNothing);

    expect(
      find.byKey(const Key('stufenwechsel-transfer-button')),
      findsNothing,
    );
  });

  testWidgets('Leere Stufen werden ohne Auswahlzeile und Button angezeigt', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(const SettingsStufenwechselPage()));

    final biberButtonFinder = find.byKey(
      const Key('stufenwechsel-transfer-button-biber'),
    );
    final biberTransferRowFinder = find.byKey(
      const Key('stufenwechsel-transfer-row-biber'),
    );
    expect(
      find.text('Keine passenden Mitglieder für diese Stufe.'),
      findsAtLeastNWidgets(1),
    );
    expect(biberTransferRowFinder, findsNothing);
    expect(biberButtonFinder, findsNothing);
  });
}
