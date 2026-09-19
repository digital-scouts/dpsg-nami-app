import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/presentation/widgets/global_loading_top_bar.dart';

Widget _buildHarness({required bool active, required bool immediate}) {
  return MaterialApp(
    home: Scaffold(
      body: GlobalLoadingTopBar(active: active, immediate: immediate),
    ),
  );
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

    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
