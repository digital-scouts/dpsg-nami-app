import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/presentation/theme/app_bewegung.dart';

double _maximum(Curve kurve) {
  var maximum = 0.0;
  for (var i = 0; i <= 200; i++) {
    final wert = kurve.transform(i / 200);
    if (wert > maximum) maximum = wert;
  }
  return maximum;
}

void main() {
  group('FederKurve', () {
    const dauer = Duration(milliseconds: 650);

    test('beginnt bei 0 und endet bei 1', () {
      final kurve = FederKurve(
        SpringDescription.withDurationAndBounce(
          duration: const Duration(milliseconds: 450),
          bounce: 0.25,
        ),
        dauer: dauer,
      );
      expect(kurve.transform(0), 0);
      expect(kurve.transform(1), 1);
    });

    test('schwingt mit Bounce einmal über 1', () {
      final kurve = FederKurve(
        SpringDescription.withDurationAndBounce(
          duration: const Duration(milliseconds: 450),
          bounce: 0.25,
        ),
        dauer: dauer,
      );
      expect(_maximum(kurve), greaterThan(1.02));
      // Kurz vor dem Ende ist die Feder eingeschwungen, ohne Sprung auf 1.
      expect(kurve.transform(0.99), closeTo(1, 0.02));
    });

    test('bleibt ohne Bounce unter 1', () {
      final kurve = FederKurve(AppBewegung.feder, dauer: dauer);
      expect(_maximum(kurve), lessThanOrEqualTo(1));
    });
  });

  group('reduzierte Bewegung', () {
    Future<(bool, Duration)> lies(WidgetTester tester, bool aus) async {
      late bool reduziert;
      late Duration lage;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: aus),
          child: Builder(
            builder: (context) {
              reduziert = AppBewegung.reduziert(context);
              lage = AppBewegung.lage(context, AppBewegung.standard);
              return const SizedBox();
            },
          ),
        ),
      );
      return (reduziert, lage);
    }

    testWidgets('Lagebewegung entfällt bei „Bewegung reduzieren“', (
      tester,
    ) async {
      expect(await lies(tester, true), (true, Duration.zero));
    });

    testWidgets('Lagebewegung läuft sonst mit voller Dauer', (tester) async {
      expect(await lies(tester, false), (false, AppBewegung.standard));
    });

    testWidgets('ohne MediaQuery gilt Bewegung als erlaubt', (tester) async {
      late bool reduziert;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            reduziert = AppBewegung.reduziert(context);
            return const SizedBox();
          },
        ),
      );
      expect(reduziert, isFalse);
    });
  });
}
