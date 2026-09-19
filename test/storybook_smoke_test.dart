import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nami/main_storybook.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('de');
  });

  testWidgets('alle registrierten Storybook-Stories bauen ohne Laufzeitfehler', (
    tester,
  ) async {
    addTearDown(tester.view.reset);

    final stories = buildStorybookStories();
    final viewports = <Size>[const Size(1280, 1600), const Size(430, 932)];

    for (final viewport in viewports) {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = viewport;

      for (final story in stories) {
        final failures = await _pumpStoryAndCollectFailures(tester, story);
        expect(
          failures,
          isEmpty,
          reason:
              'Story ${story.name} hat bei ${viewport.width.toInt()}x${viewport.height.toInt()} Laufzeitfehler: ${failures.join('\n')}',
        );
      }
    }
  });
}

Future<List<String>> _pumpStoryAndCollectFailures(
  WidgetTester tester,
  Story story,
) async {
  final flutterErrors = <FlutterErrorDetails>[];
  final oldOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    flutterErrors.add(details);
  };

  try {
    await tester.pumpWidget(StorybookEntry(stories: <Story>[story]));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    final failures = <String>[];
    Object? exception;
    while ((exception = tester.takeException()) != null) {
      failures.add(exception.toString());
    }

    for (final error in flutterErrors) {
      final message = error.exceptionAsString();
      if (_isIgnorableFlutterError(message)) {
        continue;
      }
      failures.add(message);
    }
    return failures;
  } finally {
    FlutterError.onError = oldOnError;
  }
}

bool _isIgnorableFlutterError(String message) {
  return message.contains('GoldenFileComparator') ||
      message.contains('A Timer is still pending');
}
