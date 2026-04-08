import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:http/http.dart';
import 'package:http/io_client.dart';
import 'package:latlong2/latlong.dart';

import 'logger_service.dart';
import 'maps_env.dart';

class MapTileCacheService {
  MapTileCacheService({
    FMTCBackend? backend,
    FMTCBackend Function()? backendFactory,
    Connectivity? connectivity,
    Client? httpClient,
    LoggerService? logger,
  }) : _backendFactory = backendFactory ?? FMTCObjectBoxBackend.new,
       _backend = backend ?? (backendFactory ?? FMTCObjectBoxBackend.new)(),
       _connectivity = connectivity ?? Connectivity(),
       _httpClient =
           httpClient ?? IOClient(HttpClient()..userAgent = userAgentValue),
       _logger = logger;

  static const String storeName = 'offline_map_tiles';
  static const String userAgentPackageName = 'de.jlange.nami.app';
  static const String userAgentValue =
      'dpsg-nami-app/1.0 (+https://github.com/digital-scouts/dpsg-nami-app)';
  static const int minCachedZoom = 10;
  static const int maxCachedZoom = 16;

  static String get tileUrlTemplate => MapsEnv.mapTileUrlTemplate;

  final FMTCBackend Function() _backendFactory;
  FMTCBackend _backend;
  final Connectivity _connectivity;
  final Client _httpClient;
  final LoggerService? _logger;

  bool _initialized = false;
  Future<void>? _initializing;
  FMTCTileProvider? _tileProvider;

  Future<void> initialize() {
    if (_initialized) {
      return Future.value();
    }
    final ongoing = _initializing;
    if (ongoing != null) {
      return ongoing;
    }
    final future = _initializeInternal();
    _initializing = future;
    return future.whenComplete(() {
      _initializing = null;
    });
  }

  Future<FMTCTileProvider> tileProvider() async {
    await initialize();
    return _tileProvider!;
  }

  TileLayer buildTileLayer(FMTCTileProvider tileProvider) {
    return TileLayer(
      urlTemplate: tileUrlTemplate,
      userAgentPackageName: userAgentPackageName,
      tileProvider: tileProvider,
      maxZoom: 19,
    );
  }

  Future<void> downloadRegion({
    required LatLng center,
    required double radiusKm,
    required String reason,
    bool wifiOnly = true,
  }) async {
    if (radiusKm <= 0) {
      return;
    }

    if (wifiOnly && !await _hasWifiConnection()) {
      await _log(
        'Offline-Download uebersprungen: reason=$reason, wifiOnly=true',
      );
      return;
    }

    try {
      final tileProvider = await this.tileProvider();
      final store = FMTCStore(storeName);
      final region = CircleRegion(center, radiusKm).toDownloadable(
        minZoom: minCachedZoom,
        maxZoom: maxCachedZoom,
        options: buildTileLayer(tileProvider),
      );
      final instanceId = '$reason:${DateTime.now().microsecondsSinceEpoch}';
      await _log(
        'Offline-Download gestartet: reason=$reason, radiusKm=$radiusKm, lat=${center.latitude}, lon=${center.longitude}',
      );
      final streams = store.download.startForeground(
        region: region,
        skipExistingTiles: true,
        parallelThreads: 3,
        maxBufferLength: 100,
        instanceId: instanceId,
      );
      unawaited(streams.tileEvents.drain<void>());
      await streams.downloadProgress.drain<void>();
      await _log('Offline-Download abgeschlossen: reason=$reason');
    } catch (error, stackTrace) {
      await _log('Offline-Download fehlgeschlagen: $error\n$stackTrace');
    }
  }

  Future<double> realSizeKiB() async {
    try {
      await initialize();
      return FMTCRoot.stats.realSize;
    } catch (error, stackTrace) {
      await _log('Map-Cache-Groesse nicht lesbar: $error\n$stackTrace');
      return 0;
    }
  }

  Future<void> deleteRoot() async {
    Object? deleteError;
    StackTrace? deleteStackTrace;

    try {
      if (!_initialized) {
        await _initializeBackend();
      }
      await _backend.uninitialise(deleteRoot: true);
      await _log('Map-Cache geloescht');
    } catch (error, stackTrace) {
      deleteError = error;
      deleteStackTrace = stackTrace;
    } finally {
      _backend = _backendFactory();
      _initialized = false;
      _initializing = null;
      _tileProvider = null;
    }

    if (deleteError != null) {
      await _log(
        'Map-Cache konnte nicht geloescht werden: $deleteError\n$deleteStackTrace',
      );
    }
  }

  Future<void> _initializeInternal() async {
    await _initializeBackend();
    final store = FMTCStore(storeName);
    if (!await store.manage.ready) {
      await store.manage.create();
    }
    final headers = <String, String>{'User-Agent': userAgentValue};
    _tileProvider ??= FMTCTileProvider(
      stores: {storeName: BrowseStoreStrategy.readUpdateCreate},
      loadingStrategy: BrowseLoadingStrategy.onlineFirst,
      recordHitsAndMisses: false,
      httpClient: _httpClient,
      headers: headers,
    );
    _initialized = true;
    await _log(
      MapsEnv.isUsingTileFallback
          ? 'Map-Cache initialisiert mit OSM-Fallback'
          : 'Map-Cache initialisiert mit konfiguriertem Tile-Provider',
    );
    await _log('Map-Cache initialisiert');
  }

  Future<void> _initializeBackend() {
    if (_backend case final FMTCObjectBoxBackend objectBoxBackend) {
      final rootIsolateToken =
          ServicesBinding.rootIsolateToken ?? RootIsolateToken.instance;
      if (rootIsolateToken == null) {
        throw StateError(
          'FMTC kann ohne RootIsolateToken nicht initialisiert werden.',
        );
      }

      return objectBoxBackend.initialise(rootIsolateToken: rootIsolateToken);
    }

    return _backend.initialise();
  }

  Future<bool> _hasWifiConnection() async {
    final results = await _connectivity.checkConnectivity();
    return results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet);
  }

  Future<void> _log(String message) async {
    await _logger?.log('maps', message);
  }
}
