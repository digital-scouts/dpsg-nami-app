import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:nami/utilities/app.state.dart';
import 'package:nami/utilities/notifications.dart';

import '../../utilities/hive/settings.dart';

class Settings extends StatefulWidget {
  const Settings({Key? key}) : super(key: key);

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  bool stufenwechselDatumIsValid = true;

  final _stufenwechselTextController = TextEditingController();
  final _stammheimTextController = TextEditingController(text: getStammheim());

  Widget _buildSync() {
    return ListTile(
      title: const Text('Aktualisiere die Mitgliedsdaten'),
      leading: const Icon(Icons.sync),
      onTap: () {
        AppStateHandler().setLoadDataState(loadAll: false);
      },
      subtitle: Text(
          "Vor ${DateTime.now().difference(getLastNamiSync()).inDays.toString()} Tagen"),
    );
  }

  Widget _buildForceBSync() {
    return ListTile(
      title: const Text('Lade alle Daten neu'),
      leading: const Icon(Icons.sync),
      onTap: () {
        AppStateHandler().setLoadDataState(loadAll: true);
      },
    );
  }

  bool isValidInput(String text) {
    RegExp regex = RegExp(r'^\d{0,2}-\d{0,2}$');
    return regex.hasMatch(text);
  }

  Widget _buildStufenwechselDatumInput() {
    _stufenwechselTextController.text =
        '${getNextStufenwechselDatum().day.toString().padLeft(2, '0')}-${getNextStufenwechselDatum().month.toString().padLeft(2, '0')}';
    return ListTile(
      title: const Text('Stufenwechsel Datum: '),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 80,
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 8),
              child: TextField(
                controller: _stufenwechselTextController,
                decoration: InputDecoration(
                  hintText: 'DD-MM',
                  errorText: !stufenwechselDatumIsValid
                      ? 'Ungültiges Format'
                      : null, // Anzeige des Fehlers
                ),
              ),
            ),
          ),
          IconButton(
            color: Theme.of(context).colorScheme.primary,
            onPressed: () {
              if (!isValidInput(_stufenwechselTextController.text)) {
                setState(() {
                  stufenwechselDatumIsValid = false;
                });
              } else {
                DateTime stufenwechselDatum = DateTime(
                    DateTime.now().year,
                    int.parse(_stufenwechselTextController.text.split('-')[1]),
                    int.parse(_stufenwechselTextController.text.split('-')[0]));
                setStufenwechselDatum(stufenwechselDatum);
                setState(() {
                  stufenwechselDatumIsValid = true;
                });
              }
            },
            icon: const Icon(Icons.save),
          )
        ],
      ),
    );
  }

  Widget _buildStammHeimInput() {
    return ListTile(
      title: TextField(
        controller: _stammheimTextController,
        decoration: const InputDecoration(
          labelText: 'Stammheim Adresse',
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            color: Theme.of(context).colorScheme.primary,
            onPressed: () async {
              final text = _stammheimTextController.text;
              setStammheim(text);
              final scaffold = ScaffoldMessenger.of(context);
              try {
                final locations = await locationFromAddress(text);
                if (locations.length == 1) {
                  scaffold.showSnackBar(
                    const SnackBar(content: Text('Adresse gefunden')),
                  );
                  if (await isWifi() || !getSyncOverWifiOnly()) {
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

  Future<bool> isWifi() async {
    final res = await Connectivity().checkConnectivity();
    return res.contains(ConnectivityResult.wifi);
  }

  Future<void> downloadMapRegion(Location location) async {
    final region =
        CircleRegion(LatLng(location.latitude, location.longitude), 2);
    final downloadable = region.toDownloadable(
      3, // Minimum Zoom
      17, // Maximum Zoom
      TileLayer(
        urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
        subdomains: const ['a', 'b', 'c'],
        userAgentPackageName: 'de.jlange.nami.app',
      ),
    );
    final download = FMTC
        .instance('mapStore')
        .download
        .startForeground(region: downloadable);

    download.listen((progress) async {
      debugPrint(
          '${progress.elapsedDuration} Map Download progress: ${progress.attemptedTiles} of ${progress.maxTiles} (${(progress.attemptedTiles / progress.maxTiles * 100).toInt()}% | ${progress.estRemainingDuration.inSeconds} Seconds remaining)');
      if (progress.isComplete) {
        debugPrint(
            '${progress.elapsedDuration} Map Download progress: Complete (Successful: ${progress.successfulTiles} | Failed: ${progress.failedTiles} | Cached: ${progress.cachedTiles} | Size: ${(progress.successfulSize / 1024).toStringAsFixed(2)} MiB)');
        debugPrint(
            'Kartenspeichergröße: ${(FMTC.instance('mapStore').stats.storeSize / 1024).toStringAsFixed(2)} MiB}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Kartendownload abgeschlossen (Geladen: ${(progress.successfulSize / 1024).toStringAsFixed(0)} MiB)')),
        );
      }
    });
  }

  _buildSyncOverWifiOnly() {
    return ListTile(
      title: const Text('Automatischer Sync nur über WLAN'),
      leading: const Icon(Icons.wifi),
      trailing: Switch(
        value: getSyncOverWifiOnly(),
        onChanged: (value) {
          setSyncOverWifiOnly(value);
          setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Settings')),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSync(),
          _buildForceBSync(),
          const Divider(height: 1),
          _buildStufenwechselDatumInput(),
          _buildStammHeimInput(),
          _buildSyncOverWifiOnly(),
        ],
      ),
    );
  }
}
