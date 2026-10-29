import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/achievements/achievement_definition.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/notifications/achievement_unlocked.dart';
import 'package:nami/presentation/theme/app_haptik.dart';
import 'package:nami/presentation/widgets/achievement_badge.dart';
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

  Future<void> zeige(WidgetTester tester, AchievementTier tier) async {
    await tester.pumpWidget(
      _nestedApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showAchievementUnlocked(
              context,
              definition: definition,
              tier: tier,
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump(const Duration(milliseconds: 300));
  }

  final konfettiBild = find.descendant(
    of: find.byType(ConfettiOverlay),
    matching: find.byType(CustomPaint),
  );

  group('Haptik', () {
    late List<String> haptik;
    setUp(() {
      haptik = [];
      AppHaptik.beobachter = haptik.add;
    });
    tearDown(() => AppHaptik.beobachter = null);

    testWidgets('ab Gold ist der Erfolg spürbar, sobald das Badge aufspringt', (
      tester,
    ) async {
      await zeige(tester, AchievementTier.gold);
      // Der Dialog blendet noch ein; Badge und Haptik warten.
      expect(haptik, isEmpty);
      await tester.pump(const Duration(milliseconds: 200));
      expect(haptik, ['erfolg']);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('Bronze und Silber bleiben ohne Haptik', (tester) async {
      await zeige(tester, AchievementTier.silver);
      expect(haptik, isEmpty);
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('Bewegung reduzieren', () {
    testWidgets('ohne Einstellung fliegt Konfetti', (tester) async {
      await zeige(tester, AchievementTier.gold);
      expect(konfettiBild, findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('kein Konfetti und das Badge steht sofort', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      final haptik = <String>[];
      AppHaptik.beobachter = haptik.add;
      addTearDown(() => AppHaptik.beobachter = null);

      await zeige(tester, AchievementTier.gold);
      expect(tester.takeException(), isNull);
      expect(find.byType(AchievementUnlockedDialog), findsOneWidget);
      expect(konfettiBild, findsNothing);
      // Ohne Aufspringen kommt die Haptik mit dem ersten Bild des Dialogs.
      expect(haptik, ['erfolg']);
      final badge = tester.widget<Transform>(
        find
            .ancestor(
              of: find.byType(AchievementBadge),
              matching: find.byType(Transform),
            )
            .first,
      );
      expect(badge.transform.getMaxScaleOnAxis(), 1);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('auch der Snackbar-Weg bleibt ohne Konfetti', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await zeige(tester, AchievementTier.bronze);
      expect(find.byType(AchievementUnlockedSnackbarContent), findsOneWidget);
      expect(konfettiBild, findsNothing);
      await tester.pump(const Duration(seconds: 6));
    });
  });
}
