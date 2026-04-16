import 'dart:convert';
import 'dart:io';

import 'package:nami/domain/maps/stamm_map_marker.dart';
import 'package:nami/services/stamm_storelocator_service.dart';

Future<void> main() async {
  final service = StammStorelocatorService();
  final markers = await service.fetchMarkers();
  final snapshot = StammMapMarkerSnapshot(
    markers: markers,
    fetchedAt: DateTime.now().toUtc(),
    source: StammMapMarkerSource.asset,
  );

  final outputFile = File('assets/maps/stamm_markers.json');
  await outputFile.create(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  await outputFile.writeAsString('${encoder.convert(snapshot.toJson())}\n');

  stdout.writeln(
    'Stammmarker exportiert: ${markers.length} Eintraege -> ${outputFile.path}',
  );
}
