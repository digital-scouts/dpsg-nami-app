import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/presentation/widgets/app_page_header.dart';

void main() {
  Future<double> headerHeight(
    WidgetTester tester, {
    required double textScale,
    Widget primary = const SizedBox.shrink(),
    Widget secondary = const SizedBox.shrink(),
    AppPageHeaderCard? card,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Column(
              children: [
                AppPageHeader(
                  primary: primary,
                  secondary: secondary,
                  card: card,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return tester.getSize(find.byType(AppPageHeader)).height;
  }

  testWidgets('Hoehe haengt nicht von Inhalt oder Karte ab', (tester) async {
    final empty = await headerHeight(tester, textScale: 1);

    expect(
      await headerHeight(
        tester,
        textScale: 1,
        primary: const Text('Kurz'),
        secondary: Text('Ganz lang ' * 20, maxLines: 1),
      ),
      empty,
    );
    expect(
      await headerHeight(
        tester,
        textScale: 1,
        primary: const Text('Karte'),
        card: const AppPageHeaderCard(divider: true, insetSecondary: false),
      ),
      empty,
    );
  });

  testWidgets('waechst mit der Textskalierung bis zur Obergrenze', (
    tester,
  ) async {
    final normal = await headerHeight(tester, textScale: 1);
    final large = await headerHeight(tester, textScale: 1.3);
    final clamped = await headerHeight(
      tester,
      textScale: AppPageHeader.maxTextScaleFactor,
    );
    final huge = await headerHeight(tester, textScale: 3);

    expect(large, greaterThan(normal));
    expect(clamped, greaterThan(large));
    expect(huge, clamped);
  });
}
