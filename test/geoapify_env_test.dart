import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/services/geoapify_env.dart';

void main() {
  test('verwendet Geoapify-Defaults ohne Env-Werte', () {
    dotenv.loadFromString(envString: '', isOptional: true);

    expect(GeoapifyEnv.negativeCacheTtl, const Duration(days: 7));
    expect(GeoapifyEnv.minConfidence, 0.5);
    expect(GeoapifyEnv.minStreetLevelConfidence, 0.5);
    expect(GeoapifyEnv.detailedLogEnabled, isFalse);
  });

  test('liest Geoapify-Konfiguration aus der Env', () {
    dotenv.loadFromString(
      envString: [
        'GEOAPIFY_NEGATIVE_CACHE_TTL_DAYS=14',
        'GEOAPIFY_MIN_CONFIDENCE=0.7',
        'GEOAPIFY_MIN_STREET_LEVEL_CONFIDENCE=0.6',
        'GEOAPIFY_DETAILED_LOG=true',
      ].join('\n'),
      isOptional: true,
    );

    expect(GeoapifyEnv.negativeCacheTtl, const Duration(days: 14));
    expect(GeoapifyEnv.minConfidence, 0.7);
    expect(GeoapifyEnv.minStreetLevelConfidence, 0.6);
    expect(GeoapifyEnv.detailedLogEnabled, isTrue);
  });

  test('faellt bei ungueltigen Geoapify-Werten auf Defaults zurueck', () {
    dotenv.loadFromString(
      envString: [
        'GEOAPIFY_NEGATIVE_CACHE_TTL_DAYS=0',
        'GEOAPIFY_MIN_CONFIDENCE=-1',
        'GEOAPIFY_MIN_STREET_LEVEL_CONFIDENCE=nein',
        'GEOAPIFY_DETAILED_LOG=false',
      ].join('\n'),
      isOptional: true,
    );

    expect(GeoapifyEnv.negativeCacheTtl, const Duration(days: 7));
    expect(GeoapifyEnv.minConfidence, 0.5);
    expect(GeoapifyEnv.minStreetLevelConfidence, 0.5);
    expect(GeoapifyEnv.detailedLogEnabled, isFalse);
  });
}
