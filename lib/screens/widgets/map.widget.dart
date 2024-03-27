import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';

class MapWidget extends StatefulWidget {
  final LatLng homeLocation;
  final String memberAddress;
  const MapWidget(
      {required this.homeLocation, required this.memberAddress, Key? key})
      : super(key: key);

  @override
  MapWidgetState createState() => MapWidgetState();
}

class MapWidgetState extends State<MapWidget> {
  MapController mapController = MapController();
  late Future<LatLng> _addressLocation;

  @override
  void initState() {
    super.initState();
    _addressLocation = _getAddressLocation();
  }

  Future<LatLng> _getAddressLocation() async {
    try {
      List<Location> locations =
          await locationFromAddress(widget.memberAddress);
      if (locations.isNotEmpty) {
        Location firstLocation = locations.first;
        return LatLng(firstLocation.latitude, firstLocation.longitude);
      } else {
        throw Exception('Adresse nicht gefunden');
      }
    } catch (e) {
      throw Exception('Fehler beim Abrufen der Adresse: $e');
    }
  }

  void adjustMapCenterAndZoom(LatLng marker1, LatLng marker2) {
    double minLat = min(marker1.latitude, marker2.latitude);
    double maxLat = max(marker1.latitude, marker2.latitude);
    double minLng = min(marker1.longitude, marker2.longitude);
    double maxLng = max(marker1.longitude, marker2.longitude);

    double centerLat = (minLat + maxLat) / 2;
    double centerLng = (minLng + maxLng) / 2;

    LatLngBounds bounds =
        LatLngBounds(LatLng(maxLat, maxLng), LatLng(minLat, minLng));

    CenterZoom zoom = mapController.centerZoomFitBounds(bounds);

    mapController.move(LatLng(centerLat, centerLng), zoom.zoom - 0.5);
  }

  Widget _buildMap(LatLng addressLocation, LatLng homeLocation) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      adjustMapCenterAndZoom(addressLocation, homeLocation);
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: double.infinity,
              height: 200.0, // Anpassen der Höhe nach Bedarf
              child: FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  center: addressLocation, // Position für die Karte
                  zoom: 13.0,
                  interactiveFlags:
                      InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 80.0,
                        height: 80.0,
                        point: addressLocation, // Position für den Marker
                        builder: (ctx) => const Icon(
                          Icons.person_pin_circle,
                          color: Colors.red,
                        ),
                      ),
                      Marker(
                        width: 80.0,
                        height: 80.0,
                        point: homeLocation, // Position für den Marker
                        builder: (ctx) => const Icon(
                          Icons.home_sharp,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
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
    late LatLng addressLocation;

    return FutureBuilder<LatLng>(
      future: _addressLocation,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        } else if (snapshot.hasError) {
          return Container();
        } else {
          addressLocation = snapshot.data!;
          return Column(
            children: <Widget>[
              _buildMap(addressLocation, widget.homeLocation),
              ListTile(
                leading: const Icon(Icons.social_distance),
                title: Text(
                  formatDistance(
                      calculateDistance(addressLocation, widget.homeLocation)),
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
