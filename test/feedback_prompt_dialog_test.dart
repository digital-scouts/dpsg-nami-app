import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/data/achievements/in_memory_achievement_repository.dart';
import 'package:nami/domain/achievements/achievement_definition.dart';
import 'package:nami/domain/settings/app_settings.dart';
import 'package:nami/domain/settings/app_settings_repository.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/notifications/feedback_prompt_dialog.dart';
import 'package:nami/services/achievement_service.dart';
import 'package:nami/services/logger_service.dart';

void main() {
  Future<FeedbackPromptChoice?> openAndTap(
    WidgetTester tester,
    String? label,
  ) async {
    FeedbackPromptChoice? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de'), Locale('en')],
        locale: const Locale('de'),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showFeedbackPromptDialog(context);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Wie gefällt dir die App?'), findsOneWidget);

    if (label == null) {
      await tester.tapAt(const Offset(5, 5));
    } else {
      await tester.tap(find.text(label));
    }
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('Feedback geben liefert feedback', (tester) async {
    expect(
      await openAndTap(tester, 'Feedback geben'),
      FeedbackPromptChoice.feedback,
    );
  });

  testWidgets('App bewerten liefert rate', (tester) async {
    expect(await openAndTap(tester, 'App bewerten'), FeedbackPromptChoice.rate);
  });

  testWidgets('Später liefert later', (tester) async {
    expect(await openAndTap(tester, 'Später'), FeedbackPromptChoice.later);
  });

  testWidgets('Schließen über Barrier zählt als later', (tester) async {
    expect(await openAndTap(tester, null), FeedbackPromptChoice.later);
  });

  group('runFeedbackPromptFlow Erfolge', () {
    Future<AchievementService> runFlow(
      WidgetTester tester,
      String label,
    ) async {
      final achievements = AchievementService(
        repository: InMemoryAchievementRepository(),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('de'), Locale('en')],
          locale: const Locale('de'),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => runFeedbackPromptFlow(
                context,
                logger: _FakeLoggerService(),
                trigger: 'test',
                achievements: achievements,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      return achievements;
    }

    Future<int> countOf(AchievementService service, String id) async =>
        (await service.loadAll()).firstWhere((p) => p.id == id).count;

    testWidgets('App bewerten schaltet den Bewertungs-Erfolg frei', (
      tester,
    ) async {
      final achievements = await runFlow(tester, 'App bewerten');

      expect(await countOf(achievements, AchievementIds.storeRating), 1);
      expect(await countOf(achievements, AchievementIds.feedbackSent), 0);
    });

    testWidgets('Später schaltet nichts frei', (tester) async {
      final achievements = await runFlow(tester, 'Später');

      expect(await countOf(achievements, AchievementIds.storeRating), 0);
      expect(await countOf(achievements, AchievementIds.feedbackSent), 0);
    });
  });
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
  Future<void> trackAndLog(
    String service,
    String name,
    Map<String, Object?> properties,
  ) async {}
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
