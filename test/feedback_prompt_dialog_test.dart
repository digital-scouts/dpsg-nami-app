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
import 'package:nami/services/store_review_client.dart';

void main() {
  final ios = TargetPlatformVariant.only(TargetPlatform.iOS);
  final android = TargetPlatformVariant.only(TargetPlatform.android);

  Widget app(Widget Function(BuildContext context) builder) => MaterialApp(
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('de'), Locale('en')],
    locale: const Locale('de'),
    home: Builder(builder: builder),
  );

  Future<FeedbackPromptChoice?> openAndTap(
    WidgetTester tester,
    String? label,
  ) async {
    FeedbackPromptChoice? result;
    await tester.pumpWidget(
      app(
        (context) => TextButton(
          onPressed: () async {
            result = await showFeedbackPromptDialog(context);
          },
          child: const Text('open'),
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

  group('iOS', () {
    testWidgets('bietet kein App bewerten an', (tester) async {
      await tester.pumpWidget(
        app(
          (context) => TextButton(
            onPressed: () => showFeedbackPromptDialog(context),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Später'), findsOneWidget);
      expect(find.text('Feedback geben'), findsOneWidget);
      expect(find.text('App bewerten'), findsNothing);
      expect(find.textContaining('Store'), findsNothing);
    }, variant: ios);

    testWidgets('Feedback geben liefert feedback', (tester) async {
      expect(
        await openAndTap(tester, 'Feedback geben'),
        FeedbackPromptChoice.feedback,
      );
    }, variant: ios);

    testWidgets('Später liefert later', (tester) async {
      expect(await openAndTap(tester, 'Später'), FeedbackPromptChoice.later);
    }, variant: ios);

    testWidgets('Schließen über Barrier zählt als later', (tester) async {
      expect(await openAndTap(tester, null), FeedbackPromptChoice.later);
    }, variant: ios);
  });

  group('Android', () {
    testWidgets('zeigt drei gestapelte Knöpfe in voller Breite', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          (context) => TextButton(
            onPressed: () => showFeedbackPromptDialog(context),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final rate = find.byKey(const Key('feedback-prompt-rate'));
      final feedback = find.byKey(const Key('feedback-prompt-feedback'));
      final later = find.byKey(const Key('feedback-prompt-later'));

      expect(tester.widget(rate), isA<FilledButton>());
      expect(
        find.descendant(of: rate, matching: find.text('App bewerten')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: feedback, matching: find.text('Feedback geben')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: later, matching: find.text('Später')),
        findsOneWidget,
      );

      // Untereinander in dieser Reihenfolge und gleich breit.
      expect(
        tester.getTopLeft(rate).dy,
        lessThan(tester.getTopLeft(feedback).dy),
      );
      expect(
        tester.getTopLeft(feedback).dy,
        lessThan(tester.getTopLeft(later).dy),
      );
      final width = tester.getSize(rate).width;
      expect(tester.getSize(feedback).width, width);
      expect(tester.getSize(later).width, width);
      expect(tester.getTopLeft(feedback).dx, tester.getTopLeft(rate).dx);
    }, variant: android);

    testWidgets('App bewerten liefert rate', (tester) async {
      expect(
        await openAndTap(tester, 'App bewerten'),
        FeedbackPromptChoice.rate,
      );
    }, variant: android);

    testWidgets('Feedback geben liefert feedback', (tester) async {
      expect(
        await openAndTap(tester, 'Feedback geben'),
        FeedbackPromptChoice.feedback,
      );
    }, variant: android);

    testWidgets('Später liefert later', (tester) async {
      expect(await openAndTap(tester, 'Später'), FeedbackPromptChoice.later);
    }, variant: android);
  });

  group('runFeedbackPromptFlow', () {
    late _FakeStoreReviewClient reviewClient;
    late AchievementService achievements;

    setUp(() => reviewClient = _FakeStoreReviewClient());

    Future<void> runFlow(WidgetTester tester, String label) async {
      // Im Test angelegt, damit alle Futures in der Fake-Zeit laufen. Erfolge
      // wie auf iOS, damit ein vergebenes "App bewertet" auffiele.
      achievements = AchievementService(
        repository: InMemoryAchievementRepository(),
        platformProvider: () => TargetPlatform.iOS,
      );
      await tester.pumpWidget(
        app(
          (context) => TextButton(
            onPressed: () => runFeedbackPromptFlow(
              context,
              logger: _FakeLoggerService(),
              trigger: 'test',
              achievements: achievements,
              reviewClient: reviewClient,
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    Future<int> countOf(String id) async =>
        (await achievements.loadAll()).firstWhere((p) => p.id == id).count;

    testWidgets(
      'App bewerten startet das Play-In-App-Review ohne Abzeichen',
      (tester) async {
        await runFlow(tester, 'App bewerten');

        expect(reviewClient.requestReviewCalls, 1);
        expect(reviewClient.openStoreListingCalls, 0);
        expect(await countOf(AchievementIds.storeRating), 0);
        expect(await countOf(AchievementIds.feedbackSent), 0);
      },
      variant: android,
    );

    testWidgets(
      'ohne In-App-Review faellt App bewerten auf den Store-Eintrag zurueck',
      (tester) async {
        reviewClient.available = false;

        await runFlow(tester, 'App bewerten');

        expect(reviewClient.requestReviewCalls, 0);
        expect(reviewClient.openStoreListingCalls, 1);
        expect(await countOf(AchievementIds.storeRating), 0);
      },
      variant: android,
    );

    testWidgets('Später schaltet nichts frei', (tester) async {
      await runFlow(tester, 'Später');

      expect(await countOf(AchievementIds.storeRating), 0);
      expect(await countOf(AchievementIds.feedbackSent), 0);
      expect(reviewClient.requestReviewCalls, 0);
      expect(reviewClient.openStoreListingCalls, 0);
    }, variant: TargetPlatformVariant.mobile());
  });

  group('openAppStoreReviewPage', () {
    test(
      'oeffnet die Bewertungsseite und vergibt danach das Abzeichen',
      () async {
        final reviewClient = _FakeStoreReviewClient();
        final achievements = AchievementService(
          repository: InMemoryAchievementRepository(),
          platformProvider: () => TargetPlatform.iOS,
        );

        await openAppStoreReviewPage(
          logger: _FakeLoggerService(),
          achievements: achievements,
          reviewClient: reviewClient,
        );

        expect(reviewClient.openStoreListingCalls, 1);
        expect(reviewClient.requestReviewCalls, 0);
        final progress = (await achievements.loadAll()).firstWhere(
          (p) => p.id == AchievementIds.storeRating,
        );
        expect(progress.count, 1);
      },
    );

    test('vergibt kein Abzeichen, wenn der Link scheitert', () async {
      final reviewClient = _FakeStoreReviewClient()..failOpen = true;
      final achievements = AchievementService(
        repository: InMemoryAchievementRepository(),
        platformProvider: () => TargetPlatform.iOS,
      );

      await openAppStoreReviewPage(
        logger: _FakeLoggerService(),
        achievements: achievements,
        reviewClient: reviewClient,
      );

      final progress = (await achievements.loadAll()).firstWhere(
        (p) => p.id == AchievementIds.storeRating,
      );
      expect(progress.count, 0);
    });
  });
}

class _FakeStoreReviewClient implements StoreReviewClient {
  bool available = true;
  bool failOpen = false;
  int requestReviewCalls = 0;
  int openStoreListingCalls = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async => requestReviewCalls++;

  @override
  Future<void> openStoreListing() async {
    openStoreListingCalls++;
    if (failOpen) {
      throw StateError('kein Store');
    }
  }
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
