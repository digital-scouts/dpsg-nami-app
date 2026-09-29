import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/achievements/achievement_definition.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/notifications/achievement_unlocked.dart';
import 'package:nami/presentation/widgets/confetti_overlay.dart';

Widget _nestedApp(Widget child) => MaterialApp(
  // Äußere App ohne AppLocalizations, wie im Storybook.
  home: MaterialApp(
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('de')],
    locale: const Locale('de'),
    home: Scaffold(body: child),
  ),
);

void main() {
  final definition = achievementCatalog.firstWhere(
    (d) => d.id == AchievementIds.memberEdited,
  );

  testWidgets('ab Gold erscheint ein Dialog im Kontext des Aufrufers', (
    tester,
  ) async {
    await tester.pumpWidget(
      _nestedApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showAchievementUnlocked(
              context,
              definition: definition,
              tier: AchievementTier.gold,
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.byType(AchievementUnlockedDialog), findsOneWidget);
    expect(find.text('Datenpflege'), findsOneWidget);
    expect(find.byType(ConfettiOverlay), findsOneWidget);

    await tester.tap(find.text('Weiter'));
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(AchievementUnlockedDialog), findsNothing);
  });

  testWidgets('Bronze und Silber erscheinen als Snackbar', (tester) async {
    await tester.pumpWidget(
      _nestedApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showAchievementUnlocked(
              context,
              definition: definition,
              tier: AchievementTier.silver,
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AchievementUnlockedSnackbarContent), findsOneWidget);
    expect(find.byType(AchievementUnlockedDialog), findsNothing);
    expect(find.byType(ConfettiOverlay), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(ConfettiOverlay), findsNothing);
  });
}
