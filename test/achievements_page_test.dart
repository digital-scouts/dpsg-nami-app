import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nami/data/achievements/in_memory_achievement_repository.dart';
import 'package:nami/domain/achievements/achievement_definition.dart';
import 'package:nami/domain/achievements/achievement_progress.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/screens/achievements_page.dart';
import 'package:nami/services/achievement_service.dart';

Widget _app(
  List<AchievementProgress> achievements, {
  VoidCallback? onRateApp,
  VoidCallback? onGiveFeedback,
}) => MaterialApp(
  localizationsDelegates: [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [Locale('de'), Locale('en')],
  locale: const Locale('de'),
  home: AchievementsPage(
    achievements: achievements,
    onRateApp: onRateApp,
    onGiveFeedback: onGiveFeedback,
  ),
);

AchievementProgress _progress(String id, int count, {DateTime? at}) {
  final definition = achievementCatalog.firstWhere((d) => d.id == id);
  final levels = AchievementProgress(
    definition: definition,
    count: count,
  ).reachedLevels;
  return AchievementProgress(
    definition: definition,
    count: count,
    unlockedAt: {
      for (var i = 0; i < levels; i++) i: at ?? DateTime(2026, 9, 1),
    },
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('de'));

  testWidgets('zeigt Zusammenfassung, Fortschritt und besondere Abzeichen', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app([
        _progress(AchievementIds.appDays, 12),
        _progress(AchievementIds.memberEdited, 0),
        _progress(AchievementIds.storeRating, 1),
        _progress(AchievementIds.feedbackSent, 0),
      ]),
    );

    // Bronze + Silber bei app_days, einmalige Bewertung: 3 von 12 Stufen.
    expect(find.text('3 von 12 Stufen erreicht'), findsOneWidget);
    expect(find.text('Immer dabei'), findsOneWidget);
    expect(find.text('Silber'), findsOneWidget);
    expect(find.text('12 / 25 bis Gold'), findsOneWidget);
    expect(find.text('0 / 1 bis Bronze'), findsOneWidget);
    expect(find.text('App bewertet'), findsOneWidget);
    expect(find.text('Mitgestalten'), findsOneWidget);
  });

  testWidgets('Detail zeigt alle Stufen mit Datum und Restmenge', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app([_progress(AchievementIds.appDays, 12, at: DateTime(2026, 9, 5))]),
    );

    await tester.tap(find.byKey(const Key('achievement-tile-app_days')));
    await tester.pumpAndSettle();

    expect(find.byType(AchievementDetailSheet), findsOneWidget);
    expect(find.text('Erreicht am 5.9.2026'), findsNWidgets(2));
    expect(find.text('Noch 13'), findsOneWidget);
    expect(find.text('Noch 488'), findsOneWidget);
  });

  testWidgets('offene Abzeichen mit Aktion rufen beim Tippen den Callback', (
    tester,
  ) async {
    var rated = 0;
    var feedback = 0;
    await tester.pumpWidget(
      _app(
        [
          _progress(AchievementIds.storeRating, 0),
          _progress(AchievementIds.feedbackSent, 0),
        ],
        onRateApp: () => rated++,
        onGiveFeedback: () => feedback++,
      ),
    );

    expect(find.text('Jetzt bewerten'), findsOneWidget);
    expect(find.text('Feedback geben'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new), findsNWidgets(2));

    await tester.tap(find.byKey(const Key('achievement-special-store_rating')));
    await tester.pumpAndSettle();
    expect(rated, 1);
    expect(find.byType(AchievementDetailSheet), findsNothing);

    await tester.tap(
      find.byKey(const Key('achievement-special-feedback_sent')),
    );
    await tester.pumpAndSettle();
    expect(feedback, 1);
    expect(find.byType(AchievementDetailSheet), findsNothing);
  });

  testWidgets('erreichte Abzeichen öffnen weiter das Detail', (tester) async {
    var rated = 0;
    await tester.pumpWidget(
      _app([
        _progress(AchievementIds.storeRating, 1),
      ], onRateApp: () => rated++),
    );

    expect(find.text('Jetzt bewerten'), findsNothing);

    await tester.tap(find.byKey(const Key('achievement-special-store_rating')));
    await tester.pumpAndSettle();
    expect(rated, 0);
    expect(find.byType(AchievementDetailSheet), findsOneWidget);
  });

  testWidgets(
    'Android zeigt kein App-bewertet-Abzeichen, Mitgestalten bleibt',
    (tester) async {
      // Plattform kommt wie in der App aus defaultTargetPlatform.
      final service = AchievementService(
        repository: InMemoryAchievementRepository(),
      );
      final achievements = await service.loadAll();
      var feedback = 0;

      await tester.pumpWidget(
        _app(achievements, onGiveFeedback: () => feedback++),
      );

      expect(find.text('App bewertet'), findsNothing);
      expect(
        find.byKey(const Key('achievement-special-store_rating')),
        findsNothing,
      );
      expect(find.text('Mitgestalten'), findsOneWidget);
      expect(find.text('Feedback geben'), findsOneWidget);

      final cell = find.byKey(const Key('achievement-special-feedback_sent'));
      await tester.ensureVisible(cell);
      await tester.pumpAndSettle();
      await tester.tap(cell);
      await tester.pumpAndSettle();
      expect(feedback, 1);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'iOS zeigt App bewertet mit Hinweis Jetzt bewerten',
    (tester) async {
      final service = AchievementService(
        repository: InMemoryAchievementRepository(),
      );
      final achievements = await service.loadAll();

      await tester.pumpWidget(
        _app(achievements, onRateApp: () {}, onGiveFeedback: () {}),
      );

      expect(find.text('App bewertet'), findsOneWidget);
      expect(find.text('Jetzt bewerten'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
