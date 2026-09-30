import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/presentation/widgets/app_page_header.dart';

/// Breiten (iPhone SE, iPhone 15, iPad) und Textskalierungen, bei denen die
/// Header aller Hauptseiten gleich hoch sein muessen.
const pageHeaderWidths = <double>[320, 390, 820];
const pageHeaderTextScales = <double>[1.0, 1.3, 2.0];

/// Prueft fuer jede Kombination aus [pageHeaderWidths] und
/// [pageHeaderTextScales], dass der [AppPageHeader] der von [buildPage]
/// erzeugten Seite genau so hoch ist wie ein leerer Header und im Header
/// nichts ueberlaeuft. Overflows im Seiteninhalt darunter sind hier nicht
/// Gegenstand und werden ignoriert; andere Fehler schlagen weiter durch.
Future<void> expectPageHeaderMatchesRaster(
  WidgetTester tester,
  Widget Function() buildPage, {
  Future<void> Function(WidgetTester tester)? settle,
}) async {
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  for (final width in pageHeaderWidths) {
    for (final textScale in pageHeaderTextScales) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AppPageHeader(
                  primary: SizedBox.shrink(),
                  secondary: SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      );
      final expected = tester.getSize(find.byType(AppPageHeader)).height;

      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (!details.exceptionAsString().contains('overflowed')) {
          originalOnError?.call(details);
        }
      };
      try {
        await tester.pumpWidget(buildPage());
        if (settle != null) {
          await settle(tester);
        } else {
          await tester.pump();
          await tester.pump();
        }
      } finally {
        FlutterError.onError = originalOnError;
      }

      final flexes = find.descendant(
        of: find.byType(AppPageHeader),
        matching: find.byWidgetPredicate((widget) => widget is Flex),
      );
      for (final element in flexes.evaluate()) {
        expect(
          element.renderObject!.toStringShort(),
          isNot(contains('OVERFLOWING')),
          reason:
              'Overflow im Header bei Breite $width, '
              'Textskalierung $textScale: ${element.widget}',
        );
      }

      expect(
        tester.getSize(find.byType(AppPageHeader)).height,
        expected,
        reason: 'Breite $width, Textskalierung $textScale',
      );
    }
  }
}
