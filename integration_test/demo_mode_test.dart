// Geraete-Test fuer den Demo-Zugang: Start ohne Login, Demo betreten, Demo-
// Stamm sehen und Demo wieder beenden. Setzt eine frische Installation ohne
// Hitobito-Login voraus.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nami/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(finder, findsWidgets);
  }

  testWidgets('Demo-Zugang laesst sich betreten und beenden', (tester) async {
    final originalOnError = FlutterError.onError;
    app.main();

    await pumpUntilFound(tester, find.byKey(const Key('demo-start')));
    await tester.tap(find.byKey(const Key('demo-start')));

    // Mitgliederliste des erfundenen Stammes.
    await pumpUntilFound(tester, find.textContaining('Albrecht'));
    expect(find.text('DEMO'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings));
    await pumpUntilFound(tester, find.byKey(const Key('demo-exit')));
    await tester.tap(find.byKey(const Key('demo-exit')));

    await pumpUntilFound(tester, find.byKey(const Key('demo-start')));
    expect(find.text('DEMO'), findsNothing);
    FlutterError.onError = originalOnError;
  });
}
