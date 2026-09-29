import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nami/domain/achievements/achievement_definition.dart';
import 'package:nami/domain/achievements/achievement_progress.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/screens/achievements_page.dart';

Widget _app(List<AchievementProgress> achievements) => MaterialApp(
  localizationsDelegates: [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [Locale('de'), Locale('en')],
  locale: const Locale('de'),
  home: AchievementsPage(achievements: achievements),
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
}
