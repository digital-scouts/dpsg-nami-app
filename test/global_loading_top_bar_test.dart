import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/presentation/theme/app_bewegung.dart';
import 'package:nami/presentation/widgets/global_loading_top_bar.dart';

Widget _buildHarness({required bool active, required bool immediate}) {
  return MaterialApp(
    home: Scaffold(
      body: GlobalLoadingTopBar(active: active, immediate: immediate),
    ),
  );
}

/// Lässt das Ausblenden ablaufen: Der Ticker beginnt einen Frame nach dem
/// Auslösen und meldet das Ende erst im Frame nach Ablauf der Dauer.
Future<void> _blendeAus(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(AppBewegung.klein);
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  testWidgets('zeigt bei delayed mode erst nach Show-Delay', (tester) async {
    await tester.pumpWidget(_buildHarness(active: true, immediate: false));

    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('haelt bei immediate mode die Mindest-Sichtdauer ein', (
    tester,
  ) async {
    await tester.pumpWidget(_buildHarness(active: true, immediate: true));

    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.pumpWidget(_buildHarness(active: false, immediate: true));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    // Nach der Mindest-Sichtdauer blendet die Leiste noch aus.
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await _blendeAus(tester);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  double deckkraft(WidgetTester tester) => tester
      .widget<FadeTransition>(
        find.descendant(
          of: find.byType(GlobalLoadingTopBar),
          matching: find.byType(FadeTransition),
        ),
      )
      .opacity
      .value;

  testWidgets('blendet aus, statt schlagartig zu verschwinden', (tester) async {
    await tester.pumpWidget(_buildHarness(active: true, immediate: false));
    await tester.pump(const Duration(milliseconds: 200));
    // Der Ticker beginnt im Frame nach dem Auslösen.
    await tester.pump();
    await tester.pump(AppBewegung.klein);
    expect(deckkraft(tester), 1);

    // Delayed-Modus: nach der Mindest-Sichtdauer von 420 ms ausblenden.
    await tester.pumpWidget(_buildHarness(active: false, immediate: false));
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(deckkraft(tester), inExclusiveRange(0, 1));

    await _blendeAus(tester);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('verschwindet bei „Bewegung reduzieren“ sofort', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(_buildHarness(active: true, immediate: true));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.pumpWidget(_buildHarness(active: false, immediate: true));
    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
