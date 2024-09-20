import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:collection/collection.dart';

class MapWidget extends StatefulWidget {
  final List<Mitglied> members;
  final Map<int, Color>? elementColors;
  const MapWidget({required this.members, this.elementColors, super.key});

  @override
  MapWidgetState createState() => MapWidgetState();
}

class MapWidgetState extends State<MapWidget> {
  bool _isExpanded = false;
  MapController mapController = MapController();
  late Future<({LatLng? stammheim, Map<int, LatLng> members})> _addressLocation;

  @override
  void initState() {
    super.initState();
    _addressLocation = _getAddressLocation();
  }

  @override
  void didUpdateWidget(MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!const DeepCollectionEquality()
        .equals(widget.members, oldWidget.members)) {
      // Create new map controller, because new [MapWidget] gets created in [build]
      mapController = MapController();
      _addressLocation = _getAddressLocation();
    }
  }

  Future<({LatLng? stammheim, Map<int, LatLng> members})>
      _getAddressLocation() async {
    final stammheim = getStammheim();
    LatLng? stammheimLocation;
    if (stammheim != null) {
      try {
        final res = await locationFromAddress(stammheim);
        stammheimLocation = LatLng(res.first.latitude, res.first.longitude);
      } on NoResultFoundException catch (_, __) {}
    }
    Map<int, LatLng> members = {};
    for (Mitglied member in widget.members) {
      LatLng? coordinates = await member.getCoordinates();
      if (coordinates != null) {
        members[member.mitgliedsNummer] = coordinates;
      }
    }

    return (stammheim: stammheimLocation, members: members);
  }

  LatLngBounds _getMapBounds(List<LatLng> markers) {
    double minLat = markers
        .reduce((val, marker) => val.latitude < marker.latitude ? val : marker)
        .latitude;
    double maxLat = markers
        .reduce((val, marker) => val.latitude > marker.latitude ? val : marker)
        .latitude;
    double minLng = markers
        .reduce(
            (val, marker) => val.longitude < marker.longitude ? val : marker)
        .longitude;
    double maxLng = markers
        .reduce(
            (val, marker) => val.longitude > marker.longitude ? val : marker)
        .longitude;

    LatLngBounds bounds = LatLngBounds(
      LatLng(maxLat, maxLng),
      LatLng(minLat, minLng),
    );
    return bounds;
  }

  Widget _buildMap(Map<int, LatLng> addressLocations, LatLng? homeLocation) {
    List<LatLng> markers = [...addressLocations.values];
    if (homeLocation != null) {
      markers.add(homeLocation);
    }

    if (homeLocation == null && addressLocations.isEmpty) {
      return const Center(
        child: Text('Keine Adresse gefunden'),
      );
    }
    final bounds = _getMapBounds(markers);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: double.infinity,
              height: _isExpanded
                  ? (MediaQuery.of(context).size.height - 300)
                  : 200.0,
              child: FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  maxZoom: 17,
                  minZoom: 3,
                  initialCameraFit: CameraFit.bounds(
                    bounds: bounds,
                    padding: const EdgeInsets.all(32),
                  ),
                  interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag),
                ),
                children: [
                  TileLayer(
                    // TODO: Recommended: Do not hardcode any URL to tile.openstreetmap.org as doing so will limit your ability to react if the service is disrupted or blocked. In particular, switching should be possible without requiring a software update.
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'de.jlange.nami.app',
                    tileProvider: isMapTileCachingEnabled()
                        ? const FMTCStore('mapStore').getTileProvider()
                        : null,
                  ),
                  MarkerLayer(
                    markers: [
                      if (homeLocation != null)
                        Marker(
                          width: 20.0,
                          height: 20.0,
                          point: homeLocation, // Position für den Marker
                          child: const Icon(
                            Icons.home,
                            color: Colors.black,
                          ),
                        ),
                      ...addressLocations.entries.map((entry) {
                        Mitglied member = widget.members.firstWhere(
                            (element) => element.mitgliedsNummer == entry.key);
                        return Marker(
                          width: 25.0,
                          height: 25.0,
                          point: entry.value,
                          child: Tooltip(
                            triggerMode: TooltipTriggerMode.tap,
                            message: '${member.vorname} ${member.nachname}',
                            child: Icon(
                              Icons.person_pin_circle,
                              color: widget
                                      .elementColors?[member.mitgliedsNummer] ??
                                  Colors.red,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: ColoredBox(
                      color: Colors.black.withOpacity(0.5),
                      child: GestureDetector(
                        onTap: () async {
                          const url = 'https://openstreetmap.org/copyright';
                          if (await canLaunchUrl(Uri.parse(url))) {
                            await launchUrl(Uri.parse(url));
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(3),
                          child: Text('© OpenStreetMap',
                              style: TextStyle(fontSize: 10)),
                        ),
                      ),
                    ),
                  ),
                  if (addressLocations.isNotEmpty &&
                      addressLocations.length > 1)
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      icon: Icon(_isExpanded ? Icons.compress : Icons.expand),
                    )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double calculateDistance(LatLng start, LatLng end) {
    const int earthRadius = 6371; // Erdradius in Kilometern

    // Konvertierung der Längen- und Breitengrade in Radian
    double startLatRad = degreesToRadians(start.latitude);
    double startLngRad = degreesToRadians(start.longitude);
    double endLatRad = degreesToRadians(end.latitude);
    double endLngRad = degreesToRadians(end.longitude);

    double latDiffRad = endLatRad - startLatRad;
    double lngDiffRad = endLngRad - startLngRad;

    // Haversine-Formel zur Berechnung der Entfernung
    double a = pow(sin(latDiffRad / 2), 2) +
        cos(startLatRad) * cos(endLatRad) * pow(sin(lngDiffRad / 2), 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    double distance = earthRadius * c; // Entfernung in Kilometern
    return distance;
  }

  String formatDistance(double distance) {
    if (distance < 1) {
      int meters = (distance * 1000).round();
      return '$meters Meter';
    } else {
      return '${distance.toStringAsFixed(1)} km';
    }
  }

  double degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _addressLocation,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        } else if (snapshot.hasError) {
          return const Center(
            child: Text('Fehler beim Laden der Adressen'),
          );
        } else {
          final (:stammheim, :members) = snapshot.data!;
          return Column(
            children: <Widget>[
              _buildMap(members, stammheim),
              if (stammheim != null &&
                  members.isNotEmpty &&
                  members.length == 1)
                ListTile(
                  leading: const Icon(Icons.social_distance),
                  title: Text(
                    formatDistance(calculateDistance(
                        members.values.toList().first, stammheim)),
                  ),
                  subtitle: const Text("Entfernung"),
                ),
            ],
          );
        }
      },
    );
  }
}
