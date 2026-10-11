import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nami/domain/member/member_address_utils.dart';
import 'package:nami/domain/settings/address_settings_repository.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/notifications/app_snackbar.dart';
import 'package:nami/presentation/widgets/address_map_preview.dart';
import 'package:nami/presentation/widgets/mobile_daten_hinweis.dart';
import 'package:nami/services/geoapify_address_map_service.dart';
import 'package:nami/services/map_tile_cache_service.dart';
import 'package:nami/services/maps_env.dart';
import 'package:nami/services/network_access_policy.dart';
import 'package:provider/provider.dart';

class StammAddressSettings extends StatefulWidget {
  final AddressSettingsRepository repository;
  final Future<List<String>> Function(String query) autocompleteProvider;
  final VoidCallback? onDownloadRegion;
  final GeoapifyAddressMapService? mapService;
  final MapTileCacheService? tileCacheService;

  const StammAddressSettings({
    super.key,
    required this.repository,
    required this.autocompleteProvider,
    this.onDownloadRegion,
    this.mapService,
    this.tileCacheService,
  });

  @override
  State<StammAddressSettings> createState() => _StammAddressSettingsState();
}

class _StammAddressSettingsState extends State<StammAddressSettings> {
  late final TextEditingController _controller;
  Timer? _debounce;
  String _lastQuery = '';
  List<String> _results = [];
  String? _savedAddress;
  TextEditingController? _feldController;
  FocusNode? _feldFokus;

  /// Vorschlaege warten wegen „Mobile Daten einschränken“ auf WLAN.
  bool _vorschlaegeImWlan = false;

  /// Nach Bestaetigung bis zum Verlassen der Seite ueber mobile Daten.
  bool _mobileDatenFreigegeben = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    widget.repository.loadAddress().then((value) {
      if (!mounted) {
        return;
      }
      setState(() {
        _savedAddress = value;
        if (value != null) {
          _controller.text = value;
          _feldController?.text = value;
        }
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue value) async {
                  final query = value.text;
                  if (query.length < 5) {
                    _results = [];
                    return const Iterable<String>.empty();
                  }

                  if (_lastQuery == query) {
                    return _results;
                  }
                  _lastQuery = query;

                  if (await _vorschlaegeGesperrt()) {
                    _debounce?.cancel();
                    _results = [];
                    _lastQuery = '';
                    return const Iterable<String>.empty();
                  }
                  if (_lastQuery != query) {
                    // Inzwischen weitergetippt; der neuere Aufruf fragt.
                    return const Iterable<String>.empty();
                  }
                  _debounce?.cancel();
                  final completer = Completer<Iterable<String>>();
                  _debounce = Timer(
                    const Duration(milliseconds: 400),
                    () async {
                      _results = await widget.autocompleteProvider(query);
                      completer.complete(_results);
                    },
                  );
                  return completer.future;
                },
                onSelected: (selection) async {
                  await widget.repository.saveAddress(selection);
                  unawaited(_downloadOfflineRegion(selection));
                  setState(() {
                    _savedAddress = selection;
                    _controller.text = selection;
                  });
                  widget.onDownloadRegion?.call();
                  AppSnackbar.show(
                    context,
                    message: AppLocalizations.of(context).t('address_saved'),
                    type: AppSnackbarType.success,
                  );
                },
                fieldViewBuilder:
                    (context, textController, focusNode, onSubmitted) {
                      // Nur beim ersten Aufbau vorbelegen: Ein Neuaufbau
                      // darf getippten Text nicht ueberschreiben.
                      if (!identical(_feldController, textController)) {
                        _feldController = textController;
                        textController.text = _controller.text;
                      }
                      _feldFokus = focusNode;
                      return TextFormField(
                        // Eingaben koennen Mitgliederdaten enthalten; die Tastatur soll sie
                        // nicht lernen.
                        enableIMEPersonalizedLearning: false,
                        controller: textController,
                        focusNode: focusNode,
                        style: theme.textTheme.bodySmall,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(
                            context,
                          ).t('address_label'),
                          labelStyle: theme.textTheme.labelMedium,
                          prefixIcon: const Icon(Icons.search),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      );
                    },
              ),
              if (_vorschlaegeImWlan) ...[
                const SizedBox(height: 12),
                MobileDatenHinweis(
                  key: const Key('mobile-daten-adresse-hinweis'),
                  icon: Icons.search,
                  titel: AppLocalizations.of(
                    context,
                  ).t('mobile_daten_adresse_titel'),
                  text: AppLocalizations.of(
                    context,
                  ).t('mobile_daten_adresse_text'),
                  knopf: AppLocalizations.of(
                    context,
                  ).t('mobile_daten_adresse_laden'),
                  onLaden: _vorschlaegeFreigeben,
                ),
              ],
            ],
          ),
        ),
        if ((_savedAddress ?? '').trim().isNotEmpty)
          Builder(
            builder: (context) {
              final savedAddress = (_savedAddress ?? '').trim();
              final fingerprint = MemberAddressUtils.fingerprintFromText(
                savedAddress,
              );
              return AddressMapPreview(
                addressText: savedAddress,
                cacheKey: fingerprint,
                addressFingerprint: fingerprint,
                mapService: widget.mapService,
                tileCacheService: widget.tileCacheService,
              );
            },
          ),
      ],
    );
  }

  Future<bool> _vorschlaegeGesperrt() async {
    final decision = await _resolveNetworkAccessPolicy()?.evaluateAccess(
      trigger: 'stamm_address_autocomplete',
      feature: 'Adresssuche',
      allowMobileDataOverride: _mobileDatenFreigegeben,
    );
    final gesperrt = decision?.isBlockedByNoMobileData ?? false;
    if (mounted && gesperrt != _vorschlaegeImWlan) {
      setState(() => _vorschlaegeImWlan = gesperrt);
    }
    return gesperrt;
  }

  void _vorschlaegeFreigeben() {
    setState(() {
      _mobileDatenFreigegeben = true;
      _vorschlaegeImWlan = false;
    });
    // Stoesst die Vorschlaege fuer den schon getippten Text erneut an; das
    // Autocomplete reagiert nur auf geaenderten Text.
    _feldFokus?.requestFocus();
    final feld = _feldController;
    if (feld != null && feld.text.isNotEmpty) {
      final wert = feld.value;
      feld.value = wert.copyWith(text: '${wert.text} ');
      feld.value = wert;
    }
  }

  Future<void> _downloadOfflineRegion(String addressText) async {
    final networkAccessPolicy = _resolveNetworkAccessPolicy();
    final mapService =
        widget.mapService ??
        GeoapifyAddressMapService(networkAccessPolicy: networkAccessPolicy);
    final tileCacheService =
        widget.tileCacheService ??
        MapTileCacheService(networkAccessPolicy: networkAccessPolicy);
    if (!mapService.hasApiKey) {
      return;
    }
    final geocodeResult = await mapService.resolveAddress(addressText);
    final location = geocodeResult.location;
    if (location == null) {
      return;
    }
    await tileCacheService.downloadRegion(
      center: location,
      radiusKm: MapsEnv.stammOfflineRadiusKm,
      reason: 'stammadresse',
      wifiOnly: true,
    );
  }

  NetworkAccessPolicy? _resolveNetworkAccessPolicy() {
    try {
      return context.read<NetworkAccessPolicy>();
    } catch (_) {
      return null;
    }
  }
}
