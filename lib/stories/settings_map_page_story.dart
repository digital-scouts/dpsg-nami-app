import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:latlong2/latlong.dart';
import 'package:nami/domain/maps/diocese_boundary.dart';
import 'package:nami/domain/maps/diocese_boundary_repository.dart';
import 'package:nami/domain/maps/stamm_map_marker.dart';
import 'package:nami/domain/maps/stamm_map_marker_repository.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/screens/settings_map_page.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story settingsMapPageStory() => Story(
  name: 'Screens/SettingsMapPage',
  builder: (context) {
    return MaterialApp(
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        AppLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de'), Locale('en')],
      home: SettingsMapPage(
        repository: _StoryDioceseBoundaryRepository(),
        stammRepository: _StoryStammRepository(),
      ),
    );
  },
);

class _StoryDioceseBoundaryRepository implements DioceseBoundaryRepository {
  @override
  Future<List<DioceseBoundary>> loadBoundaries() async {
    return const [
      DioceseBoundary(
        id: 'hh',
        name: 'Hamburg',
        website: 'www.dpsg-hamburg.de',
        polygons: [
          DioceseBoundaryPolygon(
            points: [
              LatLng(53.72, 9.72),
              LatLng(53.72, 10.35),
              LatLng(53.35, 10.35),
              LatLng(53.35, 9.72),
            ],
          ),
        ],
      ),
      DioceseBoundary(
        id: 'os',
        name: 'Osnabrück',
        website: 'https://example.org/dv-os',
        polygons: [
          DioceseBoundaryPolygon(
            points: [
              LatLng(52.72, 8.02),
              LatLng(52.72, 8.82),
              LatLng(52.12, 8.82),
              LatLng(52.12, 8.02),
            ],
          ),
        ],
      ),
    ];
  }
}

class _StoryStammRepository implements StammMapMarkerRepository {
  @override
  Future<StammMapMarkerSnapshot> forceRefresh() async {
    return loadCachedOrFallback();
  }

  @override
  Future<StammMapMarkerSnapshot> loadCachedOrFallback() async {
    return StammMapMarkerSnapshot(
      markers: const [
        StammMapMarker(
          id: '1',
          name: 'Hamburg, Schwalben',
          latitude: 53.55,
          longitude: 10.0,
          city: 'Hamburg',
          postalCode: '20095',
          website: 'www.schwalben-hamburg.de',
        ),
        StammMapMarker(
          id: '2',
          name: 'Osnabrueck, Kompass',
          latitude: 52.27,
          longitude: 8.04,
          city: 'Osnabrueck',
          postalCode: '49074',
          website: 'https://example.org/kompass',
        ),
      ],
      fetchedAt: DateTime(2026, 4, 8),
      source: StammMapMarkerSource.asset,
    );
  }

  @override
  Future<StammMapMarkerSnapshot?> refreshIfDue() async {
    return null;
  }
}
