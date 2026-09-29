import '../data/maps/asset_stamm_map_marker_repository.dart';
import '../data/maps/shared_prefs_stamm_map_marker_repository.dart';
import '../domain/maps/stamm_map_marker.dart';
import '../domain/maps/stamm_map_marker_repository.dart';
import 'logger_service.dart';
import 'stamm_storelocator_service.dart';

class StammMapSyncService implements StammMapMarkerRepository {
  StammMapSyncService({
    AssetStammMapMarkerRepository? assetRepository,
    SharedPrefsStammMapMarkerRepository? cacheRepository,
    StammStorelocatorService? remoteService,
    LoggerService? logger,
    Duration? refreshInterval,
    DateTime Function()? nowProvider,
  }) : _assetRepository =
           assetRepository ?? const AssetStammMapMarkerRepository(),
       _cacheRepository =
           cacheRepository ?? SharedPrefsStammMapMarkerRepository(),
       _logger = logger,
       _remoteService =
           remoteService ??
           StammStorelocatorService(
             log: logger == null
                 ? null
                 : (message) => logger.log('maps', message),
           ),
       _refreshInterval = refreshInterval ?? const Duration(days: 7),
       _now = nowProvider ?? DateTime.now;

  final AssetStammMapMarkerRepository _assetRepository;
  final SharedPrefsStammMapMarkerRepository _cacheRepository;
  final StammStorelocatorService _remoteService;
  final LoggerService? _logger;
  final Duration _refreshInterval;
  final DateTime Function() _now;

  Future<StammMapMarkerSnapshot>? _ongoingRefresh;

  @override
  Future<StammMapMarkerSnapshot> loadCachedOrFallback() async {
    final cached = await _cacheRepository.load();
    if (cached != null) {
      return cached;
    }
    return _assetRepository.loadFallback();
  }

  @override
  Future<StammMapMarkerSnapshot?> refreshIfDue() async {
    final cached = await _cacheRepository.load();
    if (cached != null && !_isRefreshDue(cached.fetchedAt)) {
      return null;
    }
    return _refresh();
  }

  @override
  Future<StammMapMarkerSnapshot> forceRefresh() {
    return _refresh();
  }

  bool _isRefreshDue(DateTime fetchedAt) {
    return _now().difference(fetchedAt) >= _refreshInterval;
  }

  Future<StammMapMarkerSnapshot> _refresh() {
    final ongoingRefresh = _ongoingRefresh;
    if (ongoingRefresh != null) {
      return ongoingRefresh;
    }

    final future = _refreshInternal();
    _ongoingRefresh = future;
    return future.whenComplete(() {
      _ongoingRefresh = null;
    });
  }

  Future<StammMapMarkerSnapshot> _refreshInternal() async {
    await _logger?.log('maps', 'Stammmarker-Refresh gestartet');
    final markers = await _remoteService.fetchMarkers();
    final snapshot = StammMapMarkerSnapshot(
      markers: markers,
      fetchedAt: _now(),
      source: StammMapMarkerSource.remote,
    );
    await _cacheRepository.save(snapshot);
    await _logger?.log(
      'maps',
      'Stammmarker-Refresh abgeschlossen: ${markers.length} Marker gespeichert',
    );
    return snapshot;
  }
}
