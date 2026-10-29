import 'dart:async';

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
  testWidgets('zeigt den Zurück-Button auch während des Ladens', (
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
          repository: _DelayedDioceseBoundaryRepository(),
          stammRepository: _FakeStammMapMarkerRepository(),
        ),
      ),
    );

    await tester.pump();

    expect(
      find.byKey(const ValueKey('settings-map-back-button')),
      findsOneWidget,
    );
    expect(find.text('Kartendaten werden geladen'), findsOneWidget);
  });

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

    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byKey(const Key('karten-quellenangabe')), findsOneWidget);
    expect(find.byType(MarkerClusterLayerWidget), findsOneWidget);
    expect(
      find.byKey(const ValueKey('settings-map-back-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-map-search-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-map-recenter-button')),
      findsOneWidget,
    );

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('settings-map-back-button')),
        matching: find.byIcon(Icons.arrow_back),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('settings-map-back-button')),
        matching: find.text('Zurück'),
      ),
      findsOneWidget,
    );

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

  testWidgets('blendet Zentrieren erst für Suchergebnisse aus', (tester) async {
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

    expect(
      find.byKey(const ValueKey('settings-map-recenter-button')),
      findsOneWidget,
    );

    final zentrieren = find.byKey(
      const ValueKey('settings-map-recenter-button'),
    );
    double deckkraft() => tester
        .widget<FadeTransition>(
          find
              .ancestor(of: zentrieren, matching: find.byType(FadeTransition))
              .first,
        )
        .opacity
        .value;

    // Nur die Suche zu öffnen, lässt den Knopf stehen.
    await tester.tap(find.byKey(const ValueKey('settings-map-search-button')));
    await tester.pumpAndSettle();
    expect(zentrieren, findsOneWidget);
    expect(deckkraft(), 1);

    // Erst Ergebnisse verdrängen ihn, und zwar mit einer Blende.
    await tester.enterText(
      find.byKey(const ValueKey('settings-map-search-field')),
      'sud',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(zentrieren, findsOneWidget);
    expect(deckkraft(), inExclusiveRange(0, 1));

    await tester.pumpAndSettle();
    expect(zentrieren, findsNothing);
    expect(
      find.byKey(const ValueKey('settings-map-search-results')),
      findsOneWidget,
    );

    // Ohne Ergebnisse kommt er zurück.
    await tester.enterText(
      find.byKey(const ValueKey('settings-map-search-field')),
      '',
    );
    await tester.pumpAndSettle();
    expect(zentrieren, findsOneWidget);
    expect(deckkraft(), 1);
  });

  testWidgets('schließt die Suche in einer Bewegung in den Such-Button', (
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
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-map-search-button')));
    await tester.pumpAndSettle();

    // Eingabe und Hinweis in Fließtextgröße statt der größeren
    // Standardeingabe.
    final feld = tester.widget<TextField>(
      find.byKey(const ValueKey('settings-map-search-field')),
    );
    final fliesstext = Theme.of(
      tester.element(find.byType(TextField)),
    ).textTheme.bodyMedium!.fontSize;
    expect(feld.style?.fontSize, fliesstext);
    expect(feld.decoration?.hintStyle?.fontSize, fliesstext);

    await tester.tap(
      find.byKey(const ValueKey('settings-map-search-close-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    // Ohne Überlagerung: Zu Beginn geht nur der Inhalt des Feldes, der
    // Knopf-Inhalt kommt erst später dazu.
    double deckkraft(String key) => tester
        .widget<FadeTransition>(
          find
              .ancestor(
                of: find.byKey(ValueKey(key)),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;
    expect(deckkraft('settings-map-search-open'), lessThan(1));
    expect(deckkraft('settings-map-search-button'), 0);

    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('settings-map-search-field')),
      findsNothing,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('settings-map-search-button')))
          .height,
      44,
    );
  });

  testWidgets('die offene Suche lässt den Zurück-Knopf frei', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
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

    await tester.tap(find.byKey(const ValueKey('settings-map-search-button')));
    await tester.pumpAndSettle();

    final zurueck = tester.getRect(
      find.byKey(const ValueKey('settings-map-back-button')),
    );
    final suche = tester.getRect(
      find.byKey(const ValueKey('settings-map-search-open')),
    );
    expect(suche.left, greaterThan(zurueck.right));
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

      expect(find.text('Stamm Nordlicht'), findsOneWidget);
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

    expect(find.text('Süd'), findsOneWidget);
    expect(find.text('www.dpsg-sued.de'), findsOneWidget);

    await tester.tap(find.text('www.dpsg-sued.de'));
    await tester.pumpAndSettle();

    expect(openedUri, isNotNull);
    expect(openedUri.toString(), 'https://www.dpsg-sued.de');
  });

  testWidgets('durchsucht Karte per ASCII-Näherung und setzt die Auswahl', (
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
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-map-search-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('settings-map-search-field')),
      'sud',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('settings-map-search-results')),
      findsOneWidget,
    );
    expect(find.text('Süd'), findsOneWidget);
    expect(find.text('Diözese'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('settings-map-search-result-south')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('settings-map-search-field')),
      findsNothing,
    );
    expect(find.text('Süd'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings-map-search-button')));
    await tester.pumpAndSettle();

    final searchField = tester.widget<TextField>(
      find.byKey(const ValueKey('settings-map-search-field')),
    );
    expect(searchField.controller?.text, isEmpty);
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

  testWidgets(
    'zeigt ab dem maximalen DV-Zoom nur noch Polygon-Grenzen ohne Hit-Info',
    (tester) async {
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
            dvMaxVisibleZoom: 0,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final polygonLayer = tester.widget<PolygonLayer<String>>(
        find.byType(PolygonLayer<String>),
      );
      expect(polygonLayer.polygons, hasLength(3));
      expect(
        polygonLayer.polygons.every((polygon) => polygon.color == null),
        isTrue,
      );
      expect(
        polygonLayer.polygons.every((polygon) => polygon.hitValue == null),
        isTrue,
      );
    },
  );

  testWidgets(
    'blendet bestehende Diözesen-Auswahl ab dem maximalen DV-Zoom aus',
    (tester) async {
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
            dvMaxVisibleZoom: 0,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Süd'), findsNothing);
    },
  );

  testWidgets('die Suche ist eine Fläche, die wächst und schrumpft', (
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
        ),
      ),
    );
    await tester.pumpAndSettle();

    final flaeche = find.byKey(const ValueKey('settings-map-search-flaeche'));
    Element naechsteFlaeche(String key) => tester.element(
      find
          .ancestor(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(Material),
          )
          .first,
    );
    List<double> breiten() => [tester.getSize(flaeche).width];

    final zu = tester.getSize(flaeche).width;
    await tester.tap(find.byKey(const ValueKey('settings-map-search-button')));
    await tester.pump();

    // Während des Öffnens hängen beide Inhalte an derselben Fläche, und
    // ihre Ecken bleiben rund.
    final verlauf = <double>[];
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      verlauf.addAll(breiten());
      expect(
        naechsteFlaeche('settings-map-search-open'),
        same(naechsteFlaeche('settings-map-search-button')),
      );
      final form = tester.widget<Material>(flaeche).shape;
      expect(
        (form! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(14),
      );
    }
    await tester.pumpAndSettle();
    final auf = tester.getSize(flaeche).width;

    expect(auf, greaterThan(zu));
    for (var i = 1; i < verlauf.length; i++) {
      expect(verlauf[i], greaterThanOrEqualTo(verlauf[i - 1]));
    }
    expect(verlauf.first, greaterThan(zu));
    expect(verlauf.last, lessThanOrEqualTo(auf));

    // Und rückwärts: Die Fläche schrumpft wieder in den Knopf.
    await tester.tap(
      find.byKey(const ValueKey('settings-map-search-close-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final mitte = tester.getSize(flaeche).width;
    expect(mitte, lessThan(auf));
    expect(mitte, greaterThan(zu));
    await tester.pumpAndSettle();
    expect(tester.getSize(flaeche).width, zu);
  });
}

class _DelayedDioceseBoundaryRepository implements DioceseBoundaryRepository {
  @override
  Future<List<DioceseBoundary>> loadBoundaries() {
    return Completer<List<DioceseBoundary>>().future;
  }
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
        name: 'Süd',
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
        StammMapMarker(
          id: 'district-1',
          name: 'Bezirk Alster',
          latitude: 48.14,
          longitude: 11.58,
          city: 'München',
          postalCode: '80331',
        ),
        StammMapMarker(
          id: 'dv-1',
          name: 'Diözesanleitung Hamburg',
          latitude: 50.11,
          longitude: 8.68,
          city: 'Frankfurt am Main',
          postalCode: '60311',
        ),
      ],
      fetchedAt: DateTime(2026, 4, 8),
      source: StammMapMarkerSource.cache,
    );
  }

  @override
  Future<StammMapMarkerSnapshot?> refreshIfDue({
    bool allowMobileDataOverride = false,
  }) async {
    return null;
  }
}
