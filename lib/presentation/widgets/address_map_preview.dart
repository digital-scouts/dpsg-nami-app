import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:nami/data/maps/shared_prefs_address_map_location_repository.dart';
import 'package:nami/domain/maps/address_map_location.dart';
import 'package:nami/domain/maps/address_map_location_repository.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/widgets/map_recenter_button.dart';
import 'package:nami/presentation/widgets/skeletton_map.dart';
import 'package:nami/services/geoapify_address_map_service.dart';
import 'package:nami/services/geoapify_env.dart';
import 'package:nami/services/logger_service.dart';
import 'package:nami/services/map_tile_cache_service.dart';
import 'package:nami/services/network_access_policy.dart';
import 'package:provider/provider.dart';

class AddressMapPreview extends StatefulWidget {
  const AddressMapPreview({
    super.key,
    required this.addressText,
    required this.cacheKey,
    required this.addressFingerprint,
    this.secondaryAddressText,
    this.secondaryCacheKey,
    this.secondaryAddressFingerprint,
    this.height = 200,
    this.previewTimeout = const Duration(seconds: 10),
    this.wifiOnlyRefresh = false,
    this.repository,
    this.mapService,
    this.tileCacheService,
    this.offlineDownloadRadiusKm,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.onOpenInMaps,
  });

  final String addressText;
  final String cacheKey;
  final String addressFingerprint;
  final String? secondaryAddressText;
  final String? secondaryCacheKey;
  final String? secondaryAddressFingerprint;
  final double height;
  final Duration previewTimeout;
  final bool wifiOnlyRefresh;
  final AddressMapLocationRepository? repository;
  final GeoapifyAddressMapService? mapService;
  final MapTileCacheService? tileCacheService;
  final double? offlineDownloadRadiusKm;
  final BorderRadiusGeometry borderRadius;

  /// Aktion fuer „Adresse nicht gefunden“: Adresse in der Karten-App suchen.
  final Future<void> Function()? onOpenInMaps;

  @override
  State<AddressMapPreview> createState() => _AddressMapPreviewState();
}

class _AddressMapPreviewState extends State<AddressMapPreview> {
  late Future<_AddressMapPreviewResult> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadPreview();
  }

  @override
  void didUpdateWidget(covariant AddressMapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.addressText != widget.addressText ||
        oldWidget.cacheKey != widget.cacheKey ||
        oldWidget.addressFingerprint != widget.addressFingerprint ||
        oldWidget.secondaryAddressText != widget.secondaryAddressText ||
        oldWidget.secondaryCacheKey != widget.secondaryCacheKey ||
        oldWidget.secondaryAddressFingerprint !=
            widget.secondaryAddressFingerprint ||
        oldWidget.wifiOnlyRefresh != widget.wifiOnlyRefresh ||
        oldWidget.offlineDownloadRadiusKm != widget.offlineDownloadRadiusKm) {
      _future = _loadPreview();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AddressMapPreviewResult>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Stack(
            alignment: Alignment.center,
            children: [
              MapSkeleton(
                height: widget.height,
                borderRadius: widget.borderRadius,
                showShadow: false,
              ),
              const CircularProgressIndicator(),
            ],
          );
        }

        final result = snapshot.data;
        if (result?.primaryLocation != null && result?.tileProvider != null) {
          return _InteractiveMapPreview(
            height: widget.height,
            tileProvider: result!.tileProvider!,
            primaryLocation: result.primaryLocation!,
            secondaryLocation: result.secondaryLocation,
            borderRadius: widget.borderRadius,
          );
        }

        // Fehler bleiben eine flache Flaeche statt der vollen Kartenhoehe.
        final t = AppLocalizations.of(context);
        final retry = _MapHinweisAktion(
          label: t.t('map_retry'),
          onPressed: () => setState(() => _future = _loadPreview()),
        );
        final (icon, grund, aktion) = switch (result) {
          _AddressMapPreviewResult(blockedByWifiPolicy: true) => (
            Icons.wifi_off,
            t.t('map_wifi_only_refresh'),
            null,
          ),
          _AddressMapPreviewResult(deviceOffline: true) => (
            Icons.cloud_off_outlined,
            t.t('map_device_offline'),
            null,
          ),
          _AddressMapPreviewResult(mobileDataBlocked: true) => (
            Icons.signal_cellular_off_outlined,
            t.t('map_mobile_data_blocked'),
            null,
          ),
          _AddressMapPreviewResult(apiKeyMissing: true) => (
            Icons.error_outline,
            t.t('map_technical_error'),
            null,
          ),
          _AddressMapPreviewResult(timedOut: true) ||
          _AddressMapPreviewResult(
            technicalError: true,
          ) => (Icons.error_outline, t.t('map_technical_error'), retry),
          _ => (
            Icons.wrong_location_outlined,
            t.t('map_address_not_found'),
            widget.onOpenInMaps == null
                ? null
                : _MapHinweisAktion(
                    label: t.t('map_open_in_maps'),
                    onPressed: () => widget.onOpenInMaps!(),
                  ),
          ),
        };
        return _MapHinweis(
          icon: icon,
          titel: t.t('map_not_available'),
          grund: grund,
          aktion: aktion,
          borderRadius: widget.borderRadius,
        );
      },
    );
  }

  Future<_AddressMapPreviewResult> _loadPreview() async {
    final logger = _resolveLogger();
    final networkAccessPolicy = _resolveNetworkAccessPolicy();
    final repository =
        widget.repository ?? SharedPrefsAddressMapLocationRepository();
    final mapService =
        widget.mapService ??
        GeoapifyAddressMapService(
          logger: logger,
          networkAccessPolicy: networkAccessPolicy,
          requestTimeout: widget.previewTimeout,
        );
    final tileCacheService =
        widget.tileCacheService ?? _resolveTileCacheService();
    _log(logger, 'Vorschau geladen: wifiOnly=${widget.wifiOnlyRefresh}');
    final primary = await _resolveLocation(
      request: _AddressLocationRequest(
        addressText: widget.addressText,
        legacyCacheKey: widget.cacheKey,
        addressFingerprint: widget.addressFingerprint,
        wifiOnlyRefresh: widget.wifiOnlyRefresh,
        offlineDownloadRadiusKm: widget.offlineDownloadRadiusKm,
      ),
      logger: logger,
      repository: repository,
      mapService: mapService,
      tileCacheService: tileCacheService,
    );
    if (primary.location == null) {
      return _AddressMapPreviewResult(
        blockedByWifiPolicy: primary.blockedByWifiPolicy,
        deviceOffline: primary.deviceOffline,
        mobileDataBlocked: primary.mobileDataBlocked,
        apiKeyMissing: primary.apiKeyMissing,
        timedOut: primary.timedOut,
        addressNotFound: primary.addressNotFound,
        technicalError: primary.technicalError,
      );
    }

    AddressMapLocation? secondaryLocation;
    final secondaryText = widget.secondaryAddressText?.trim();
    final secondaryCacheKey = widget.secondaryCacheKey;
    final secondaryFingerprint = widget.secondaryAddressFingerprint;
    if (secondaryText != null &&
        secondaryText.isNotEmpty &&
        secondaryCacheKey != null &&
        secondaryFingerprint != null) {
      final secondary = await _resolveLocation(
        request: _AddressLocationRequest(
          addressText: secondaryText,
          legacyCacheKey: secondaryCacheKey,
          addressFingerprint: secondaryFingerprint,
        ),
        logger: logger,
        repository: repository,
        mapService: mapService,
        tileCacheService: tileCacheService,
      );
      secondaryLocation = secondary.location;
    }

    TileProvider? tileProvider;
    try {
      final allowNetwork =
          await networkAccessPolicy
              ?.evaluateAccess(
                trigger: 'map_preview_tiles',
                feature: 'Kartenansicht',
              )
              .then((decision) => decision.allowed) ??
          true;
      tileProvider = await tileCacheService.tileProvider(
        allowNetwork: allowNetwork,
      );
    } catch (error, stackTrace) {
      _log(
        logger,
        'Tile-Provider konnte nicht initialisiert werden: $error\n$stackTrace',
      );
      return _AddressMapPreviewResult(
        primaryLocation: primary.location,
        secondaryLocation: secondaryLocation,
        technicalError: true,
      );
    }
    return _AddressMapPreviewResult(
      primaryLocation: primary.location,
      secondaryLocation: secondaryLocation,
      tileProvider: tileProvider,
    );
  }

  LoggerService? _resolveLogger() {
    try {
      return Provider.of<LoggerService>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  MapTileCacheService _resolveTileCacheService() {
    try {
      return Provider.of<MapTileCacheService>(context, listen: false);
    } catch (_) {
      return MapTileCacheService(
        logger: _resolveLogger(),
        networkAccessPolicy: _resolveNetworkAccessPolicy(),
      );
    }
  }

  NetworkAccessPolicy? _resolveNetworkAccessPolicy() {
    try {
      return Provider.of<NetworkAccessPolicy>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  void _log(LoggerService? logger, String message) {
    if (logger == null) {
      return;
    }
    unawaited(logger.log('maps', message));
  }

  Future<_ResolvedAddressLocation> _resolveLocation({
    required _AddressLocationRequest request,
    required LoggerService? logger,
    required AddressMapLocationRepository repository,
    required GeoapifyAddressMapService mapService,
    required MapTileCacheService tileCacheService,
  }) async {
    final globalCacheKey = request.addressFingerprint;
    AddressMapLocation? cached = await repository.load(globalCacheKey);
    if (cached == null && request.legacyCacheKey != globalCacheKey) {
      final legacy = await repository.load(request.legacyCacheKey);
      final legacyMatches =
          legacy != null &&
          legacy.addressFingerprint == request.addressFingerprint;
      if (legacyMatches) {
        final migrated = legacy.copyWith(cacheKey: globalCacheKey);
        await repository.save(migrated);
        cached = migrated;
        _log(logger, 'Legacy-Adresscache migriert');
      }
    }

    final cachedMatches =
        cached != null &&
        cached.addressFingerprint == request.addressFingerprint;

    if (cachedMatches) {
      if (cached.addressNotFound) {
        if (!cached.isFreshNegativeCache(
          now: DateTime.now(),
          ttl: GeoapifyEnv.negativeCacheTtl,
        )) {
          _log(logger, 'Negativ-Cache abgelaufen');
        } else {
          _log(logger, 'Cache-Treffer fuer nicht gefundene Adresse');
          return const _ResolvedAddressLocation(addressNotFound: true);
        }
      } else {
        _log(logger, 'Cache-Treffer fuer Karten-Koordinaten');
        return _ResolvedAddressLocation(location: cached);
      }
    }
    if (cached != null) {
      _log(logger, 'Cache-Fingerprint veraltet');
    } else {
      _log(logger, 'Kein Karten-Cache vorhanden');
    }

    if (request.wifiOnlyRefresh) {
      var connectivityTimedOut = false;
      final connectionTypes = await Connectivity().checkConnectivity().timeout(
        widget.previewTimeout,
        onTimeout: () {
          connectivityTimedOut = true;
          return const <ConnectivityResult>[];
        },
      );
      if (connectivityTimedOut) {
        _log(logger, 'Connectivity-Pruefung Timeout');
        return _ResolvedAddressLocation(
          location: cachedMatches ? cached : null,
          timedOut: true,
          apiKeyMissing: !mapService.hasApiKey,
          technicalError: true,
        );
      }
      final hasWifi =
          connectionTypes.contains(ConnectivityResult.wifi) ||
          connectionTypes.contains(ConnectivityResult.ethernet);
      if (!hasWifi) {
        _log(logger, 'Karten-Refresh durch WLAN-Policy blockiert');
        return _ResolvedAddressLocation(
          location: cachedMatches ? cached : null,
          blockedByWifiPolicy: true,
          apiKeyMissing: !mapService.hasApiKey,
        );
      }
    }

    if (!mapService.hasApiKey) {
      _log(logger, 'Kein Geoapify-API-Key verfuegbar');
      return _ResolvedAddressLocation(
        location: cachedMatches ? cached : null,
        apiKeyMissing: true,
        technicalError: true,
      );
    }

    _log(logger, 'Starte Geocoding');
    var geocodeTimedOut = false;
    final geocodeResult = await mapService
        .resolveAddress(request.addressText)
        .timeout(
          widget.previewTimeout,
          onTimeout: () {
            geocodeTimedOut = true;
            return const GeoapifyGeocodeResult.technicalError();
          },
        );
    if (geocodeTimedOut) {
      _log(logger, 'Geocoding Timeout');
      return _ResolvedAddressLocation(
        location: cachedMatches ? cached : null,
        timedOut: true,
        technicalError: true,
      );
    }
    if (geocodeResult.addressNotFound) {
      _log(logger, 'Geocoding ohne Treffer beendet');
      final notFoundEntry = AddressMapLocation(
        cacheKey: globalCacheKey,
        resolvedAt: DateTime.now(),
        addressFingerprint: request.addressFingerprint,
        addressNotFound: true,
      );
      await repository.save(notFoundEntry);
      _log(logger, 'Negativ-Cache gespeichert');
      return const _ResolvedAddressLocation(addressNotFound: true);
    }
    if (geocodeResult.networkBlocked) {
      return _ResolvedAddressLocation(
        location: cachedMatches && cached.hasCoordinates ? cached : null,
        deviceOffline: geocodeResult.deviceOffline,
        mobileDataBlocked: geocodeResult.mobileDataBlocked,
      );
    }
    if (geocodeResult.technicalError || geocodeResult.location == null) {
      _log(logger, 'Geocoding mit technischem Fehler beendet');
      return _ResolvedAddressLocation(
        location: cachedMatches && cached.hasCoordinates ? cached : null,
        technicalError: true,
      );
    }

    final latLng = geocodeResult.location!;

    final resolved = AddressMapLocation(
      cacheKey: globalCacheKey,
      latitude: latLng.latitude,
      longitude: latLng.longitude,
      resolvedAt: DateTime.now(),
      addressFingerprint: request.addressFingerprint,
    );
    await repository.save(resolved);
    _log(logger, 'Karten-Koordinaten gespeichert');

    final offlineDownloadRadiusKm = request.offlineDownloadRadiusKm;
    if (offlineDownloadRadiusKm != null) {
      unawaited(
        tileCacheService.downloadRegion(
          center: latLng,
          radiusKm: offlineDownloadRadiusKm,
          reason: 'mitgliedsadresse',
          wifiOnly: true,
        ),
      );
    }

    return _ResolvedAddressLocation(location: resolved);
  }
}

class _InteractiveMapPreview extends StatefulWidget {
  const _InteractiveMapPreview({
    required this.height,
    required this.tileProvider,
    required this.primaryLocation,
    required this.borderRadius,
    this.secondaryLocation,
  });

  final double height;
  final TileProvider tileProvider;
  final AddressMapLocation primaryLocation;
  final AddressMapLocation? secondaryLocation;
  final BorderRadiusGeometry borderRadius;

  @override
  State<_InteractiveMapPreview> createState() => _InteractiveMapPreviewState();
}

class _InteractiveMapPreviewState extends State<_InteractiveMapPreview> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _recenterMap(List<LatLng> points) {
    if (points.length > 1) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(36),
          maxZoom: 16,
        ),
      );
      return;
    }

    _mapController.move(points.first, 15, id: 'recenter');
  }

  @override
  Widget build(BuildContext context) {
    final points = <LatLng>[
      LatLng(
        widget.primaryLocation.latitude!,
        widget.primaryLocation.longitude!,
      ),
      if (widget.secondaryLocation != null)
        LatLng(
          widget.secondaryLocation!.latitude!,
          widget.secondaryLocation!.longitude!,
        ),
    ];
    final initialCameraFit = points.length > 1
        ? CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(points),
            padding: const EdgeInsets.all(36),
            maxZoom: 16,
          )
        : null;

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: points.first,
                initialZoom: 15,
                maxZoom: 17,
                minZoom: 3,
                initialCameraFit: initialCameraFit,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: MapTileCacheService.tileUrlTemplate,
                  userAgentPackageName:
                      MapTileCacheService.userAgentPackageName,
                  tileProvider: widget.tileProvider,
                  maxZoom: 17,
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: points.first,
                      width: 44,
                      height: 44,
                      child: const _MapMarker(
                        icon: Icons.location_on,
                        color: Color(0xFFC62828),
                      ),
                    ),
                    if (widget.secondaryLocation != null)
                      Marker(
                        point: points.last,
                        width: 44,
                        height: 44,
                        child: const _MapMarker(
                          icon: Icons.home,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: MapRecenterButton(onTap: () => _recenterMap(points)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

class _MapHinweisAktion {
  const _MapHinweisAktion({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

/// Flache Kartenflaeche mit Grund und optionaler Aktion, wenn die Karte nicht
/// angezeigt werden kann.
class _MapHinweis extends StatelessWidget {
  const _MapHinweis({
    required this.icon,
    required this.titel,
    required this.grund,
    required this.borderRadius,
    this.aktion,
  });

  static const double hoehe = 76;

  final IconData icon;
  final String titel;
  final String grund;
  final _MapHinweisAktion? aktion;
  final BorderRadiusGeometry borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aktion = this.aktion;
    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        constraints: const BoxConstraints(minHeight: hoehe),
        color: theme.colorScheme.surfaceContainerHighest,
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.18,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.matrix(<double>[
                    0.33, 0.33, 0.33, 0, 0, //
                    0.33, 0.33, 0.33, 0, 0, //
                    0.33, 0.33, 0.33, 0, 0, //
                    0, 0, 0, 1, 0, //
                  ]),
                  child: Image.asset(
                    'assets/images/map_skeleton.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: theme.colorScheme.onSurface),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titel,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(grund, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  if (aktion != null)
                    TextButton(
                      onPressed: aktion.onPressed,
                      child: Text(aktion.label),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressMapPreviewResult {
  const _AddressMapPreviewResult({
    this.primaryLocation,
    this.secondaryLocation,
    this.tileProvider,
    this.blockedByWifiPolicy = false,
    this.deviceOffline = false,
    this.mobileDataBlocked = false,
    this.apiKeyMissing = false,
    this.timedOut = false,
    this.addressNotFound = false,
    this.technicalError = false,
  });

  final AddressMapLocation? primaryLocation;
  final AddressMapLocation? secondaryLocation;
  final TileProvider? tileProvider;
  final bool blockedByWifiPolicy;
  final bool deviceOffline;
  final bool mobileDataBlocked;
  final bool apiKeyMissing;
  final bool timedOut;
  final bool addressNotFound;
  final bool technicalError;
}

class _ResolvedAddressLocation {
  const _ResolvedAddressLocation({
    this.location,
    this.blockedByWifiPolicy = false,
    this.deviceOffline = false,
    this.mobileDataBlocked = false,
    this.apiKeyMissing = false,
    this.timedOut = false,
    this.addressNotFound = false,
    this.technicalError = false,
  });

  final AddressMapLocation? location;
  final bool blockedByWifiPolicy;
  final bool deviceOffline;
  final bool mobileDataBlocked;
  final bool apiKeyMissing;
  final bool timedOut;
  final bool addressNotFound;
  final bool technicalError;
}

class _AddressLocationRequest {
  const _AddressLocationRequest({
    required this.addressText,
    required this.legacyCacheKey,
    required this.addressFingerprint,
    this.wifiOnlyRefresh = false,
    this.offlineDownloadRadiusKm,
  });

  final String addressText;
  final String legacyCacheKey;
  final String addressFingerprint;
  final bool wifiOnlyRefresh;
  final double? offlineDownloadRadiusKm;
}
