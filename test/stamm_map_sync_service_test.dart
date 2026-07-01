import 'package:flutter_test/flutter_test.dart';
import 'package:nami/data/maps/asset_stamm_map_marker_repository.dart';
import 'package:nami/data/maps/shared_prefs_stamm_map_marker_repository.dart';
import 'package:nami/domain/maps/stamm_map_marker.dart';
import 'package:nami/services/stamm_map_sync_service.dart';
import 'package:nami/services/stamm_storelocator_service.dart';

void main() {
  test('verwendet Cache wenn vorhanden', () async {
    final service = StammMapSyncService(
      assetRepository: _FakeAssetRepository(
        StammMapMarkerSnapshot(
          markers: const [
            StammMapMarker(
              id: 'asset',
              name: 'Asset',
              latitude: 1,
              longitude: 1,
              city: 'Assetstadt',
            ),
          ],
          fetchedAt: DateTime(2026, 4, 1),
          source: StammMapMarkerSource.asset,
        ),
      ),
      cacheRepository: _FakeCacheRepository(
        StammMapMarkerSnapshot(
          markers: const [
            StammMapMarker(
              id: 'cache',
              name: 'Cache',
              latitude: 2,
              longitude: 2,
              city: 'Cachetown',
            ),
          ],
          fetchedAt: DateTime(2026, 4, 7),
          source: StammMapMarkerSource.cache,
        ),
      ),
      remoteService: _FakeRemoteService(const []),
      nowProvider: () => DateTime(2026, 4, 8),
    );

    final snapshot = await service.loadCachedOrFallback();

    expect(snapshot.source, StammMapMarkerSource.cache);
    expect(snapshot.markers.single.name, 'Cache');
  });

  test(
    'refreshIfDue laedt remote und speichert Cache nach sieben Tagen',
    () async {
      final cacheRepository = _FakeCacheRepository(
        StammMapMarkerSnapshot(
          markers: const [],
          fetchedAt: DateTime(2026, 3, 30),
          source: StammMapMarkerSource.cache,
        ),
      );
      final remoteMarkers = const [
        StammMapMarker(
          id: 'remote',
          name: 'Remote',
          latitude: 3,
          longitude: 3,
          city: 'Remotestadt',
        ),
      ];
      final service = StammMapSyncService(
        assetRepository: _FakeAssetRepository(
          StammMapMarkerSnapshot(
            markers: const [],
            fetchedAt: DateTime(2026, 4, 1),
            source: StammMapMarkerSource.asset,
          ),
        ),
        cacheRepository: cacheRepository,
        remoteService: _FakeRemoteService(remoteMarkers),
        nowProvider: () => DateTime(2026, 4, 8),
      );

      final refreshed = await service.refreshIfDue();

      expect(refreshed, isNotNull);
      expect(refreshed!.source, StammMapMarkerSource.remote);
      expect(refreshed.markers.single.name, 'Remote');
      expect(cacheRepository.savedSnapshots, hasLength(1));
      expect(
        cacheRepository.savedSnapshots.single.markers.single.name,
        'Remote',
      );
    },
  );
}

class _FakeAssetRepository extends AssetStammMapMarkerRepository {
  _FakeAssetRepository(this.snapshot);

  final StammMapMarkerSnapshot snapshot;

  @override
  Future<StammMapMarkerSnapshot> loadFallback() async => snapshot;
}

class _FakeCacheRepository extends SharedPrefsStammMapMarkerRepository {
  _FakeCacheRepository(this.snapshot);

  StammMapMarkerSnapshot? snapshot;
  final List<StammMapMarkerSnapshot> savedSnapshots = [];

  @override
  Future<StammMapMarkerSnapshot?> load() async => snapshot;

  @override
  Future<void> save(StammMapMarkerSnapshot snapshot) async {
    savedSnapshots.add(snapshot);
    this.snapshot = snapshot.copyWith(source: StammMapMarkerSource.cache);
  }
}

class _FakeRemoteService extends StammStorelocatorService {
  _FakeRemoteService(this.markers);

  final List<StammMapMarker> markers;

  @override
  Future<List<StammMapMarker>> fetchMarkers() async => markers;
}
