import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/notifications/feedback_prompt_dialog.dart';

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
}
