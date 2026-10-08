import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/appearance/appearance_catalog.dart';
import 'package:nami/presentation/widgets/supporter_background.dart';

void main() {
  Widget build(
    AppearanceBackgroundId id, {
    required bool dark,
    required bool disableAnimations,
  }) {
    return MaterialApp(
      theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Center(
          child: SizedBox(
            width: 390,
            height: 160,
            child: SupporterBackground(background: id),
          ),
        ),
      ),
    );
  }

  testWidgets('zeichnet alle Szenen bei Tag und Nacht', (tester) async {
    for (final id in AppearanceBackgroundId.values) {
      for (final dark in [false, true]) {
        await tester.pumpWidget(
          build(id, dark: dark, disableAnimations: false),
        );
        await tester.pump(const Duration(seconds: 3));
        await tester.pump(const Duration(seconds: 9));
        expect(tester.takeException(), isNull, reason: '${id.name} $dark');
      }
    }
  });

  testWidgets('verlaengert den Himmel auf hohen Flaechen', (tester) async {
    for (final id in AppearanceBackgroundId.values) {
      for (final dark in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            home: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 390,
                height: 700,
                child: SupporterBackground(background: id),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 5));
        expect(tester.takeException(), isNull, reason: '${id.name} $dark');
      }
    }
  });

  testWidgets('bleibt bei reduzierter Bewegung stehen', (tester) async {
    await tester.pumpWidget(
      build(
        AppearanceBackgroundId.waldsee,
        dark: true,
        disableAnimations: true,
      ),
    );

    // Ohne laufende Animation gibt es keine weiteren Frames.
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('animiert ohne reduzierte Bewegung', (tester) async {
    await tester.pumpWidget(
      build(
        AppearanceBackgroundId.nachthimmel,
        dark: false,
        disableAnimations: false,
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));

    expect(tester.binding.hasScheduledFrame, isTrue);
  });
}
