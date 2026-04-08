import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:nami/domain/maps/diocese_boundary.dart';
import 'package:nami/domain/maps/diocese_boundary_repository.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/screens/settings_map_page.dart';

void main() {
  testWidgets('rendert die Karten-Seite mit Boundary-Daten', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de'), Locale('en')],
        locale: const Locale('de'),
        home: SettingsMapPage(repository: _FakeDioceseBoundaryRepository()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Karte'), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);

    final polygonLayer = tester.widget<PolygonLayer<String>>(
      find.byType(PolygonLayer<String>),
    );
    expect(polygonLayer.polygonLabels, isFalse);
    expect(polygonLayer.hitNotifier, isNotNull);
    expect(polygonLayer.polygons, hasLength(3));

    final southPolygons = polygonLayer.polygons
        .where((polygon) => polygon.hitValue == 'south')
        .toList(growable: false);
    expect(southPolygons, hasLength(2));
    expect(southPolygons[0].color, southPolygons[1].color);
    expect(southPolygons[0].borderColor, southPolygons[1].borderColor);
    expect(find.text('Nord'), findsNothing);
    expect(find.text('Sued'), findsNothing);
  });
}

class _FakeDioceseBoundaryRepository implements DioceseBoundaryRepository {
  @override
  Future<List<DioceseBoundary>> loadBoundaries() async {
    return const [
      DioceseBoundary(
        id: 'north',
        name: 'Nord',
        polygons: [
          DioceseBoundaryPolygon(
            points: [
              LatLng(53.8, 9.4),
              LatLng(53.8, 10.0),
              LatLng(53.3, 10.0),
              LatLng(53.3, 9.4),
            ],
          ),
        ],
      ),
      DioceseBoundary(
        id: 'south',
        name: 'Sued',
        polygons: [
          DioceseBoundaryPolygon(
            points: [
              LatLng(48.4, 10.6),
              LatLng(48.4, 11.2),
              LatLng(47.9, 11.2),
              LatLng(47.9, 10.6),
            ],
          ),
          DioceseBoundaryPolygon(
            points: [
              LatLng(49.0, 8.0),
              LatLng(49.0, 8.4),
              LatLng(48.7, 8.4),
              LatLng(48.7, 8.0),
            ],
          ),
        ],
      ),
    ];
  }
}
