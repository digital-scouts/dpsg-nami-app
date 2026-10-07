import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/presentation/widgets/karten_quellenangabe.dart';

void main() {
  test('OSM-Rückfall nennt nur OpenStreetMap', () {
    dotenv.loadFromString(envString: 'MAP_TILE_URL=\nMAPTILER_KEY=\n');
    expect(
      KartenQuellenangabe.fuerKonfiguration(),
      '© OpenStreetMap-Mitwirkende',
    );
  });

  test('MapTiler nennt MapTiler und OpenStreetMap', () {
    dotenv.loadFromString(
      envString:
          'MAP_TILE_URL=https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key={key}\n'
          'MAPTILER_KEY=abc\n',
    );
    expect(
      KartenQuellenangabe.fuerKonfiguration(),
      '© MapTiler © OpenStreetMap-Mitwirkende',
    );
  });

  testWidgets('steht unten links und ist sichtbar', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              KartenQuellenangabe(text: '© OpenStreetMap-Mitwirkende'),
            ],
          ),
        ),
      ),
    );

    final finder = find.text('© OpenStreetMap-Mitwirkende');
    expect(finder, findsOneWidget);
    final position = tester.getBottomLeft(finder);
    final screen = tester.getSize(find.byType(Scaffold));
    expect(position.dx, lessThan(40));
    expect(position.dy, greaterThan(screen.height - 40));
  });
}
