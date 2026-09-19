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
}
