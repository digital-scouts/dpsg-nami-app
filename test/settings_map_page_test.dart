import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:nami/domain/maps/diocese_boundary.dart';
import 'package:nami/domain/maps/diocese_boundary_repository.dart';
import 'package:nami/domain/maps/stamm_map_marker.dart';
import 'package:nami/domain/maps/stamm_map_marker_repository.dart';
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
        home: SettingsMapPage(
          repository: _FakeDioceseBoundaryRepository(),
          stammRepository: _FakeStammMapMarkerRepository(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Karte'), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(MarkerClusterLayerWidget), findsOneWidget);

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

  testWidgets(
    'zeigt den Namen und den Website-Link eines Stammes nach Marker-Klick',
    (tester) async {
      Uri? openedUri;

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
          home: SettingsMapPage(
            repository: _FakeDioceseBoundaryRepository(),
            stammRepository: _FakeStammMapMarkerRepository(),
            externalUrlOpener: (uri) async {
              openedUri = uri;
              return true;
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('stamm-1')).last);
      await tester.pumpAndSettle();

      expect(find.text('Nordlicht'), findsOneWidget);
      expect(find.text('nordlicht.example'), findsOneWidget);

      await tester.tap(find.text('nordlicht.example'));
      await tester.pumpAndSettle();

      expect(openedUri, isNotNull);
      expect(openedUri.toString(), 'https://nordlicht.example');
    },
  );

  testWidgets('zeigt den Website-Link für eine ausgewählte Diözese', (
    tester,
  ) async {
    Uri? openedUri;

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
        home: SettingsMapPage(
          repository: _FakeDioceseBoundaryRepository(),
          stammRepository: _FakeStammMapMarkerRepository(),
          initialSelectedBoundaryId: 'south',
          externalUrlOpener: (uri) async {
            openedUri = uri;
            return true;
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Sued'), findsOneWidget);
    expect(find.text('www.dpsg-sued.de'), findsOneWidget);

    await tester.tap(find.text('www.dpsg-sued.de'));
    await tester.pumpAndSettle();

    expect(openedUri, isNotNull);
    expect(openedUri.toString(), 'https://www.dpsg-sued.de');
  });

  testWidgets('versteckt Stammmarker unterhalb des Mindestzooms', (
    tester,
  ) async {
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
        home: SettingsMapPage(
          repository: _FakeDioceseBoundaryRepository(),
          stammRepository: _FakeStammMapMarkerRepository(),
          stammMinVisibleZoom: 7,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(MarkerClusterLayerWidget), findsNothing);
  });
}

class _FakeDioceseBoundaryRepository implements DioceseBoundaryRepository {
  @override
  Future<List<DioceseBoundary>> loadBoundaries() async {
    return const [
      DioceseBoundary(
        id: 'north',
        name: 'Nord',
        website: 'https://www.dpsg-nord.de',
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
        website: 'www.dpsg-sued.de',
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

class _FakeStammMapMarkerRepository implements StammMapMarkerRepository {
  @override
  Future<StammMapMarkerSnapshot> forceRefresh() async {
    return loadCachedOrFallback();
  }

  @override
  Future<StammMapMarkerSnapshot> loadCachedOrFallback() async {
    return StammMapMarkerSnapshot(
      markers: const [
        StammMapMarker(
          id: 'stamm-1',
          name: 'Nordlicht',
          latitude: 53.55,
          longitude: 10.01,
          city: 'Hamburg',
          postalCode: '20095',
          website: 'nordlicht.example',
        ),
      ],
      fetchedAt: DateTime(2026, 4, 8),
      source: StammMapMarkerSource.cache,
    );
  }

  @override
  Future<StammMapMarkerSnapshot?> refreshIfDue() async {
    return null;
  }
}
