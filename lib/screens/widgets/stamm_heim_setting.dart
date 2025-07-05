import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:nami/utilities/external_apis/geoapify.dart';
import 'package:nami/utilities/helper_functions.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:wiredash/wiredash.dart';

class StammHeimSetting extends StatefulWidget {
  const StammHeimSetting({super.key});

  @override
  State<StammHeimSetting> createState() => _StammHeimSettingState();
}

class _StammHeimSettingState extends State<StammHeimSetting> {
  final _stammheimTextController = TextEditingController(text: getStammheim());
  Timer? _adressAutocompleteDebounce;
  bool _adressAutocompleteActive = true;
  List<GeoapifyAdress> _adressAutocompleteAdressesResults = [];
  String _adressAutocompleteSearchString = '';
  String? _message;
  Timer? _messageTimer;

  Future<void> downloadMapRegion(Location location) async {
    final region = CircleRegion(
      LatLng(location.latitude, location.longitude),
      2,
    );
    final downloadable = region.toDownloadable(
      minZoom: 3,
      maxZoom: 17,
      options: TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'de.jlange.nami.app',
      ),
    );
    final download = const FMTCStore(
      'mapStore',
    ).download.startForeground(region: downloadable);
    download.downloadProgress.listen((progress) async {
      debugPrint(
        '${progress.elapsedDuration} Map Download progress: ${progress.attemptedTilesCount} of ${progress.maxTilesCount} (${(progress.attemptedTilesCount / progress.maxTilesCount * 100).toInt()}% | ${progress.estRemainingDuration.inSeconds} Seconds remaining)',
      );
      if (progress.maxTilesCount == progress.attemptedTilesCount) {
        debugPrint(
          '${progress.elapsedDuration} Map Download progress: Complete (Successful: ${progress.successfulTilesCount} | Failed: ${progress.failedTilesCount} | Size: ${(progress.successfulTilesCount / 1024).toStringAsFixed(2)} MiB)',
        );
        debugPrint(
          'Kartenspeichergröße: ${(await const FMTCStore('mapStore').stats.size / 1024).toStringAsFixed(2)} MiB}',
        );
        _showMessage(
          'Kartendownload abgeschlossen (Geladen: ${(progress.successfulTilesSize * 0.001024).toStringAsFixed(0)}MB)',
        );
      }
    });
  }

  void _showMessage(String message) {
    setState(() {
      _message = message;
    });
    _messageTimer?.cancel();
    _messageTimer = Timer(const Duration(seconds: 5), () {
      setState(() {
        _message = null;
      });
    });
  }

  @override
  void dispose() {
    _stammheimTextController.dispose();
    _messageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title:
          _adressAutocompleteActive
              ? Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) async {
                  if (_adressAutocompleteSearchString ==
                      textEditingValue.text) {
                    return _adressAutocompleteAdressesResults
                        .map((address) => address.formatted)
                        .toList();
                  }
                  _adressAutocompleteSearchString = textEditingValue.text;

                  if (_adressAutocompleteSearchString.length < 5) {
                    _adressAutocompleteAdressesResults = [];
                    return const Iterable<String>.empty();
                  }

                  if (_adressAutocompleteDebounce?.isActive ?? false) {
                    _adressAutocompleteDebounce!.cancel();
                  }
                  Completer<Iterable<String>> completer =
                      Completer<Iterable<String>>();

                  _adressAutocompleteDebounce = Timer(
                    const Duration(milliseconds: 500),
                    () async {
                      try {
                        _adressAutocompleteAdressesResults =
                            await autocompleteGermanAdress(
                              textEditingValue.text,
                            );
                        completer.complete(
                          _adressAutocompleteAdressesResults
                              .map((address) => address.formatted)
                              .toList(),
                        );
                      } catch (e) {
                        debugPrint(e.toString());
                        setState(() {
                          _adressAutocompleteActive = false;
                        });
                      }
                    },
                  );

                  return completer.future;
                },
                onSelected: (String selection) async {
                  _adressAutocompleteSearchString = selection;
                  GeoapifyAdress adress = _adressAutocompleteAdressesResults
                      .firstWhere((element) => element.formatted == selection);

                  setState(() {
                    _stammheimTextController.text =
                        '${adress.street} ${adress.housenumber ?? ''}, ${adress.postcode} ${adress.city}, ${adress.country}';
                  });
                },
                fieldViewBuilder: (
                  BuildContext context,
                  TextEditingController textEditingController,
                  FocusNode focusNode,
                  VoidCallback onFieldSubmitted,
                ) {
                  textEditingController.text = _stammheimTextController.text;
                  return TextFormField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Stammesheim Adresse',
                    ),
                  );
                },
              )
              : TextField(
                controller: _stammheimTextController,
                decoration: const InputDecoration(
                  labelText: 'Stammesheim Adresse',
                ),
              ),
      subtitle:
          _message == null
              ? const Text('Wird für die Kartenansicht genutzt')
              : Text(
                _message!,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            color: Theme.of(context).colorScheme.primary,
            onPressed: () async {
              Wiredash.trackEvent(
                'Settings',
                data: {'type': 'Stammesheim saved'},
              );
              final text = _stammheimTextController.text;
              setStammheim(text);
              try {
                final locations = await locationFromAddress(text);
                if (locations.length == 1) {
                  Wiredash.trackEvent(
                    'Settings',
                    data: {'type': 'Stammesheim location found'},
                  );
                  _showMessage('Adresse gefunden. Karte wird geladen...');
                  if (isMapTileCachingEnabled() &&
                      (await isWifi() || !getDataLoadingOverWifiOnly())) {
                    _showMessage('Adresse gefunden. Karte wird geladen...');
                    downloadMapRegion(locations.first);
                  } else {
                    _showMessage('Adresse gefunden.');
                  }
                } else {
                  _showMessage('Zu viele Adressen gefunden.');
                }
              } on NoResultFoundException catch (_) {
                _showMessage('Keine Adresse gefunden.');
              }
            },
            icon: const Icon(Icons.save),
          ),
        ],
      ),
    );
  }
}
