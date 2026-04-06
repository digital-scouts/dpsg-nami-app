import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/services/maps_env.dart';

void main() {
  test('verwendet OSM-Fallback ohne MAP_TILE_URL', () {
    dotenv.loadFromString(envString: '', isOptional: true);

    expect(MapsEnv.mapTileUrlTemplate, MapsEnv.defaultTileUrlTemplate);
    expect(MapsEnv.isUsingTileFallback, isTrue);
  });

  test('liest konfigurierten Tile-Endpoint aus der Env', () {
    dotenv.loadFromString(
      envString:
          'MAP_TILE_URL=https://example.com/{z}/{x}/{y}.png\nMAPTILER_KEY=abc\n',
      isOptional: true,
    );

    expect(MapsEnv.mapTileUrlTemplate, 'https://example.com/{z}/{x}/{y}.png');
    expect(MapsEnv.isUsingTileFallback, isFalse);
  });

  test('ersetzt {key} in MAP_TILE_URL mit MAPTILER_KEY', () {
    dotenv.loadFromString(
      envString:
          'MAP_TILE_URL=https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key={key}\nMAPTILER_KEY=test-key\n',
      isOptional: true,
    );

    expect(
      MapsEnv.mapTileUrlTemplate,
      'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=test-key',
    );
    expect(MapsEnv.isUsingTileFallback, isFalse);
  });

  test('faellt bei fehlendem MAPTILER_KEY auf OSM zurueck', () {
    dotenv.loadFromString(
      envString:
          'MAP_TILE_URL=https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key={key}\n',
      isOptional: true,
    );

    expect(MapsEnv.mapTileUrlTemplate, MapsEnv.defaultTileUrlTemplate);
    expect(MapsEnv.isUsingTileFallback, isTrue);
  });
}
