import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:nami/data/maps/shared_prefs_address_map_location_repository.dart';
import 'package:nami/domain/maps/address_map_location.dart';
import 'package:nami/domain/maps/address_map_location_repository.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/widgets/skeletton_map.dart';
import 'package:nami/services/geoapify_address_map_service.dart';
import 'package:nami/services/logger_service.dart';
import 'package:provider/provider.dart';

class AddressMapPreview extends StatefulWidget {
  const AddressMapPreview({
    super.key,
    required this.addressText,
    required this.cacheKey,
    required this.addressFingerprint,
    this.height = 200,
    this.previewTimeout = const Duration(seconds: 10),
    this.wifiOnlyRefresh = false,
    this.repository,
    this.mapService,
  });

  final String addressText;
  final String cacheKey;
  final String addressFingerprint;
  final double height;
  final Duration previewTimeout;
  final bool wifiOnlyRefresh;
  final AddressMapLocationRepository? repository;
  final GeoapifyAddressMapService? mapService;

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
        oldWidget.wifiOnlyRefresh != widget.wifiOnlyRefresh) {
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
              MapSkeleton(height: widget.height),
              const CircularProgressIndicator(),
            ],
          );
        }

        final result = snapshot.data;
        final imagePath = result?.location?.previewImagePath;
        if (imagePath != null && imagePath.isNotEmpty) {
          final file = File(imagePath);
          if (file.existsSync()) {
            return _PreviewImage(file: file, height: widget.height);
          }
        }

        final t = AppLocalizations.of(context);
        if (result?.blockedByWifiPolicy == true) {
          return _MapMessagePlaceholder(
            height: widget.height,
            message: t.t('map_wifi_only_refresh'),
          );
        }

        if (result?.apiKeyMissing == true) {
          return _MapMessagePlaceholder(
            height: widget.height,
            message: t.t('map_not_available'),
          );
        }

        if (result?.timedOut == true) {
          return _MapMessagePlaceholder(
            height: widget.height,
            message: t.t('map_not_available'),
          );
        }

        return MapSkeleton(height: widget.height);
      },
    );
  }

  Future<_AddressMapPreviewResult> _loadPreview() async {
    final logger = _resolveLogger();
    final repository =
        widget.repository ?? SharedPrefsAddressMapLocationRepository();
    final mapService =
        widget.mapService ??
        GeoapifyAddressMapService(
          logger: logger,
          requestTimeout: widget.previewTimeout,
        );
    _log(
      logger,
      'Vorschau geladen: cacheKey=${widget.cacheKey}, wifiOnly=${widget.wifiOnlyRefresh}',
    );
    final cached = await repository.load(widget.cacheKey);
    final cachedMatches =
        cached != null &&
        cached.addressFingerprint == widget.addressFingerprint;

    if (cachedMatches) {
      final cachedPath = cached.previewImagePath;
      if (cachedPath != null && cachedPath.isNotEmpty) {
        final file = File(cachedPath);
        if (await file.exists()) {
          _log(
            logger,
            'Cache-Treffer fuer Karten-Vorschau: ${widget.cacheKey}',
          );
          return _AddressMapPreviewResult(location: cached);
        }
        _log(
          logger,
          'Cache-Eintrag ohne vorhandene Vorschau-Datei: ${widget.cacheKey}',
        );
      }
    } else if (cached != null) {
      _log(
        logger,
        'Cache-Fingerprint veraltet, erneuere Vorschau: ${widget.cacheKey}',
      );
    } else {
      _log(logger, 'Kein Karten-Cache vorhanden: ${widget.cacheKey}');
    }

    if (widget.wifiOnlyRefresh) {
      var connectivityTimedOut = false;
      final connectionTypes = await Connectivity().checkConnectivity().timeout(
        widget.previewTimeout,
        onTimeout: () {
          connectivityTimedOut = true;
          return const <ConnectivityResult>[];
        },
      );
      if (connectivityTimedOut) {
        _log(logger, 'Connectivity-Pruefung Timeout: ${widget.cacheKey}');
        return _AddressMapPreviewResult(
          location: cachedMatches ? cached : null,
          timedOut: true,
          apiKeyMissing: !mapService.hasApiKey,
        );
      }
      final hasWifi =
          connectionTypes.contains(ConnectivityResult.wifi) ||
          connectionTypes.contains(ConnectivityResult.ethernet);
      if (!hasWifi) {
        _log(
          logger,
          'Karten-Refresh durch WLAN-Policy blockiert: ${widget.cacheKey}',
        );
        return _AddressMapPreviewResult(
          location: cachedMatches ? cached : null,
          blockedByWifiPolicy: true,
          apiKeyMissing: !mapService.hasApiKey,
        );
      }
    }

    if (!mapService.hasApiKey) {
      _log(logger, 'Kein Geoapify-API-Key verfuegbar: ${widget.cacheKey}');
      return _AddressMapPreviewResult(
        location: cachedMatches ? cached : null,
        apiKeyMissing: true,
      );
    }

    _log(logger, 'Starte Geocoding: ${widget.cacheKey}');
    var geocodeTimedOut = false;
    final location = await mapService
        .geocodeAddress(widget.addressText)
        .timeout(
          widget.previewTimeout,
          onTimeout: () {
            geocodeTimedOut = true;
            return null;
          },
        );
    if (geocodeTimedOut) {
      _log(logger, 'Geocoding Timeout: ${widget.cacheKey}');
      return _AddressMapPreviewResult(
        location: cachedMatches ? cached : null,
        timedOut: true,
      );
    }
    if (location == null) {
      _log(
        logger,
        'Geocoding ohne Treffer oder mit Fehler beendet: ${widget.cacheKey}',
      );
      if (cached != null && !cachedMatches) {
        await repository.remove(widget.cacheKey);
        _log(logger, 'Veralteten Karten-Cache entfernt: ${widget.cacheKey}');
      }
      return const _AddressMapPreviewResult();
    }

    _log(
      logger,
      'Geocoding erfolgreich, lade Vorschau herunter: ${widget.cacheKey}',
    );
    var downloadTimedOut = false;
    final previewImagePath = await mapService
        .downloadStaticMapPreview(
          cacheKey: widget.cacheKey,
          addressFingerprint: widget.addressFingerprint,
          latitude: location.latitude,
          longitude: location.longitude,
        )
        .timeout(
          widget.previewTimeout,
          onTimeout: () {
            downloadTimedOut = true;
            return null;
          },
        );
    if (downloadTimedOut) {
      _log(logger, 'Vorschau-Download Timeout: ${widget.cacheKey}');
      return _AddressMapPreviewResult(
        location: cachedMatches ? cached : null,
        timedOut: true,
      );
    }
    if (previewImagePath == null || previewImagePath.isEmpty) {
      _log(logger, 'Vorschau-Download fehlgeschlagen: ${widget.cacheKey}');
    }
    final resolved = AddressMapLocation(
      cacheKey: widget.cacheKey,
      latitude: location.latitude,
      longitude: location.longitude,
      resolvedAt: DateTime.now(),
      addressFingerprint: widget.addressFingerprint,
      previewImagePath: previewImagePath,
    );
    await repository.save(resolved);
    _log(logger, 'Karten-Cache gespeichert: ${widget.cacheKey}');
    return _AddressMapPreviewResult(location: resolved);
  }

  LoggerService? _resolveLogger() {
    try {
      return Provider.of<LoggerService>(context, listen: false);
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
}

class _PreviewImage extends StatelessWidget {
  const _PreviewImage({required this.file, required this.height});

  final File file;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.file(
        file,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _MapMessagePlaceholder extends StatelessWidget {
  const _MapMessagePlaceholder({required this.height, required this.message});

  final double height;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium,
      ),
    );
  }
}

class _AddressMapPreviewResult {
  const _AddressMapPreviewResult({
    this.location,
    this.blockedByWifiPolicy = false,
    this.apiKeyMissing = false,
    this.timedOut = false,
  });

  final AddressMapLocation? location;
  final bool blockedByWifiPolicy;
  final bool apiKeyMissing;
  final bool timedOut;
}
