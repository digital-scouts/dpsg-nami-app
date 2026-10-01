import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/services/map_tile_cache_service.dart';

void main() {
  test('buildDownloadTileLayer verwendet keinen live TileProvider', () {
    final service = MapTileCacheService();

    final layer = service.buildDownloadTileLayer();

    expect(layer.urlTemplate, MapTileCacheService.tileUrlTemplate);
    expect(layer.tileProvider, isNot(isA<FMTCTileProvider>()));
  });

  test('erkennt offline fehlende Kacheln als erwarteten Fall', () {
    // FMTC erzeugt den Fehler nur intern; der Test baut ihn nach.
    FMTCBrowsingError browsingError(FMTCBrowsingErrorType type) =>
        // ignore: invalid_use_of_internal_member
        FMTCBrowsingError(
          type: type,
          networkUrl: 'https://tile.openstreetmap.org/15/1/1.png',
          storageSuitableUID: 'tile.openstreetmap.org/15/1/1.png',
        );

    expect(
      MapTileCacheService.isMissingOfflineTile(
        browsingError(FMTCBrowsingErrorType.missingInCacheOnlyMode),
      ),
      isTrue,
    );
    expect(
      MapTileCacheService.isMissingOfflineTile(
        browsingError(FMTCBrowsingErrorType.noConnectionDuringFetch),
      ),
      isFalse,
    );
    expect(
      MapTileCacheService.isMissingOfflineTile(StateError('kaputt')),
      isFalse,
    );
  });
}
