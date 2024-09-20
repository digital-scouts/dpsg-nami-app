import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:nami/utilities/helper_functions.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/notifications.dart';
import 'package:wiredash/wiredash.dart';

class StammHeimSetting extends StatefulWidget {
  const StammHeimSetting({super.key});

  @override
  State<StammHeimSetting> createState() => _StammHeimSettingState();
}

class _StammHeimSettingState extends State<StammHeimSetting> {
  final _stammheimTextController = TextEditingController(text: getStammheim());

  Future<void> downloadMapRegion(Location location) async {
    final region =
        CircleRegion(LatLng(location.latitude, location.longitude), 2);
    final downloadable = region.toDownloadable(
      minZoom: 3,
      maxZoom: 17,
      options: TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'de.jlange.nami.app',
      ),
    );
    final download = const FMTCStore('mapStore')
        .download
        .startForeground(region: downloadable);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    download.listen((progress) async {
      debugPrint(
          '${progress.elapsedDuration} Map Download progress: ${progress.attemptedTiles} of ${progress.maxTiles} (${(progress.attemptedTiles / progress.maxTiles * 100).toInt()}% | ${progress.estRemainingDuration.inSeconds} Seconds remaining)');
      if (progress.isComplete) {
        debugPrint(
            '${progress.elapsedDuration} Map Download progress: Complete (Successful: ${progress.successfulTiles} | Failed: ${progress.failedTiles} | Cached: ${progress.cachedTiles} | Size: ${(progress.successfulSize / 1024).toStringAsFixed(2)} MiB)');
        debugPrint(
            'Kartenspeichergröße: ${(await const FMTCStore('mapStore').stats.size / 1024).toStringAsFixed(2)} MiB}');
        scaffoldMessenger.showSnackBar(
          SnackBar(
              content: Text(
                  'Kartendownload abgeschlossen (Geladen: ${(progress.successfulSize / 1024).toStringAsFixed(0)} MiB)')),
        );
      }
    });
  }

  @override
  void dispose() {
    _stammheimTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: TextField(
        controller: _stammheimTextController,
        decoration: const InputDecoration(
          labelText: 'Stammheim Adresse',
        ),
      ),
      subtitle: const Text('Wird für die Kartenansicht genutzt'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            color: Theme.of(context).colorScheme.primary,
            onPressed: () async {
              Wiredash.trackEvent('Settings',
                  data: {'type': 'Stammesheim saved'});
              final text = _stammheimTextController.text;
              setStammheim(text);
              final scaffold = ScaffoldMessenger.of(context);
              try {
                final locations = await locationFromAddress(text);
                if (locations.length == 1) {
                  Wiredash.trackEvent('Settings',
                      data: {'type': 'Stammesheim location found'});
                  scaffold.showSnackBar(
                    const SnackBar(content: Text('Adresse gefunden')),
                  );
                  if (await isWifi() || !getDataLoadingOverWifiOnly()) {
                    downloadMapRegion(locations.first);
                  }
                } else {
                  // ignore: use_build_context_synchronously
                  showErrorSnackBar(context, 'Zu viele Adressen gefunden');
                }
              } on NoResultFoundException catch (_, __) {
                // ignore: use_build_context_synchronously
                showErrorSnackBar(context, 'Keine Adresse gefunden');
              }
            },
            icon: const Icon(Icons.save),
          )
        ],
      ),
    );
  }
}
